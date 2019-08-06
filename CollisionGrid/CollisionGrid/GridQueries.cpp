
#include "API.h"
#include "GridTypes.h"
#include "GridMem.h"


#include "Objects_UE1.h"

#define return_invalid_helper { ExtraNodeFlags = 0xFFFFFFFF; return; }

//Constants:
cg::Vector Grid_Unit = cg::Vector( GRID_NODE_DIM, GRID_NODE_DIM, GRID_NODE_DIM, 0);
cg::Vector Grid_Mult = cg::Vector( GRID_MULT, GRID_MULT, GRID_MULT, 0);
cg::Vector SMALL_VECTOR = cg::Vector( SMALL_NUMBER, SMALL_NUMBER, SMALL_NUMBER, SMALL_NUMBER);
cg::Integers XYZi_One = cg::Integers( 1, 1, 1, 0);
cg::Vector ZNormals[2] = { cg::Vector( 0, 0, 1, 0), cg::Vector( 0 ,0,-1, 0) };
cg::Integers Vector3Mask = cg::Integers(0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0x00000000);

static uint32 CollisionTag = 0;

static uint32 RemoveBadResults( FCheckResult** Result)
{
	guard(RemoveBadResults);
	uint32 RemoveCount = 0;

	FCheckResult** FCR = Result;
	while ( *FCR )
	{
		if ( !G_Stack->Validate(*FCR) )
		{
			*FCR = nullptr;
			break;
		}

		bool bRemove = false;
		if ( cg::Vector( &(*FCR)->Location.X).InvalidBits() & 0b0111 ) //Something isn't valid
			bRemove = true;
		else
		{
			cg::Vector Normal( (*FCR)->Normal, E_Unsafe );
			if ( (Normal.InvalidBits() & 0b0111) || (Normal.SizeSq() > 2.f) )
				bRemove = true;
		}

		if ( bRemove )
		{
			UE_DEV_LOG( TEXT("[CG] Removing: %s L(%f,%f,%f) N(%f,%f,%f)"), (*FCR)->Actor->GetName(), (*FCR)->Location.X, (*FCR)->Location.Y, (*FCR)->Location.Z
																	, (*FCR)->Normal.X, (*FCR)->Normal.Y, (*FCR)->Normal.Z);
			FCheckResult* Next = (FCheckResult*) (*FCR)->Next;
			*FCR = Next;
			RemoveCount++;
		}
		else
			FCR = (FCheckResult**) &((*FCR)->Next);
	}
	return RemoveCount;
	unguard;
}


ActorInfo* ActorLinkContainer::Iterator::GetInfo()
{
	guard(ActorLinkContainer::Iterator::GetInfo);
	while ( Cur < Cont.ArrayNum )
	{
		ActorInfo* AInfo = Cont(Cur++);
		if ( !G_AIH->IsValid(AInfo) )
		{
			debugf_ansi( "[CG] Removing bad actor info reference");
			Cont.Remove(--Cur);
		}
		if ( AInfo->CollisionTag != CollisionTag )
		{
			AInfo->CollisionTag = CollisionTag;
			if ( AInfo->IsValid() )
				return AInfo;
			//Invalid AInfo, purge link and info (held in Last)
			debugf_ansi( "[CG] Removing expired actor info");
			G_AIH->ReleaseElement( AInfo);
			Cont.Remove(--Cur);
		}
	}
	return nullptr;
	unguard;
}

//*************************************************
//
// GSBaseMarker
//
//*************************************************

GSBaseMarker::GSBaseMarker()
{
	CollisionTag++;
	UE_DEV_THROW( G_Stack->Cur != 0, "Multiple GSBaseMarker stacked!" ); //Deprecate soon
}

GSBaseMarker::~GSBaseMarker()
{
	G_Stack->Cur = 0;
}


//*************************************************
//
// Grid
//
//*************************************************

FCheckResult* Grid::LineQuery( const PrecomputedRay& Ray, uint32 ExtraNodeFlags)
{
	guard(Grid::LineQuery);
	GSBaseMarker Marker;
	FCheckResult* Result = nullptr;

	cg::Vector OuterExtent( &Ray.Extent.X);
	if ( Ray.Org.X > Ray.End.X )		OuterExtent.X *= -1.f;
	if ( Ray.Org.Y > Ray.End.Y )		OuterExtent.Y *= -1.f;
	if ( Ray.Org.Z > Ray.End.Z )		OuterExtent.Z *= -1.f;

	cg::Integers iS;
	cg::Integers iE;
	{
		//Get start/end grid coordinates
		cg::Vector Start = (Ray.Org - OuterExtent) - Box.Min;
		cg::Vector End   = (Ray.End + OuterExtent) - Box.Min;
		Start *= Grid_Mult;
		End   *= Grid_Mult;
		//FAILS IF TRACE ORIGINATES OR ENDS OUTSIDE OF GRID!!!
		cg::Vector Max = cg::Vectorize( Size - XYZi_One);
		iS = Clamp(Start, cg::Vector(E_Zero), Max).Truncate32();
		iE = Clamp(End  , cg::Vector(E_Zero), Max).Truncate32();
	}
	//Calc directions
	int32 iD[3];
	for ( uint32 i=0 ; i<3 ; i++ )
	{
		int32 j = iE.coord(i)-iS.coord(i);
		iD[i] = (j>0) - (j<0); //Does this kill the branches?
	}

	//Check globals
	Ray.QueryContainer( Actors, Result);
	//Check nodes (start with local node), never goes beyond 255
	uint32 bGE = 0;
	uint32 iGE = 1;
	GridElement* GEStack[32]; //Tree stack
	cg::Integers CStack[32]; //Coordinate stack
	GEStack[0] = Node(iS); //A super wide trace can kill the grid
	GEStack[0]->CollisionTag = CollisionTag;
	CStack[0] = iS;
	guard(ScanNodes);
	do
	{
		GridElement* CurGE = GEStack[bGE];
		//Check actors (and tree optimal bounds) at GEStack[bGE]
		Ray.QueryContainer( CurGE->Actors, Result);
		if ( CurGE->Tree && CurGE->Tree->ShouldQuery() )
			CurGE->Tree->LineQuery( Ray, Result);

		GridElement* GB[3];
		cg::Integers CB[3];
		uint32 iGB = 0; //Next is necessary to prevent trace from going to the infinite
		for ( uint32 i=0 ; i<3 ; i++ )
			if ( CStack[bGE].coord(i) != iE.coord(i) ) //Stop at END
			{
				CB[iGB] = CStack[bGE];
				CB[iGB].coord(i) += iD[i];
				GB[iGB] = Node( CB[iGB] );
				iGB++;
			}

		for ( uint32 i=0 ; i<iGB ; i++ )
			if ( GB[i]->CollisionTag != CollisionTag )
			{
				GB[i]->CollisionTag = CollisionTag;

				bool bAdd = false;
				if ( iGB == 1 ) //Logic: axis aligned trace doesn't need box checks
					bAdd = true;
				else if ( GB[i]->Tree )
					bAdd = Ray.IntersectsBox( GB[i]->Tree->Bounds);
				else if ( Ray.IntersectsBox( GetNodeBoundingBox( GB[i]->Coords() ) ) )
					bAdd = true;

				if ( bAdd )
				{
					GEStack[iGE] = GB[i];
					CStack[iGE] = CB[i];
					iGE = (iGE + 1) & 31;
				}
			}
		bGE = (bGE + 1) & 31;
	}
	while ( iGE != bGE );
	unguardf( (TEXT("iS%s iE%s"), iS.String(), iE.String()) );

	uint32 Bads = RemoveBadResults( &Result);
	if ( Bads )
	{
		UE_DEV_LOG( TEXT("[CG] Removed %i actors from LineQuery"), Bads);
		UE_DEV_LOG( TEXT("[CG] Ray: Dir[%f,%f,%f]"), Ray.Dir.X, Ray.Dir.Y, Ray.Dir.Z);
		UE_DEV_LOG( TEXT("[CG] Ray: Segment[%f,%f,%f]-[%f,%f,%f]"), Ray.Org.X, Ray.Org.Y, Ray.Org.Z, Ray.End.X, Ray.End.Y, Ray.End.Z);
	}
	return Result;
	unguard;
}



//*************************************************
//
// MiniTree
//
//*************************************************

void MiniTree::GenericQuery( const GenericQueryHelper& Helper, FCheckResult*& ResultList)
{
	Helper.QueryContainer( Actors, ResultList);
	if ( ChildCount )
	{
		for ( uint32 i=0 ; i<8 ; i++ )
			if ( Children[i] && Children[i]->ShouldQuery() && Helper.IntersectsBox(Children[i]->Bounds) )
				Children[i]->GenericQuery( Helper, ResultList);
	}
}

void MiniTree::LineQuery( const PrecomputedRay& Ray, FCheckResult*& ResultList)
{ 
	guard(MiniTree::LineQuery);
	Ray.QueryContainer( Actors, ResultList);
	if ( ChildCount )
	{
		for ( uint32 i=0 ; i<8 ; i++ )
			if ( Children[i] && Children[i]->ShouldQuery() && Ray.IntersectsBox(Children[i]->Bounds) )
				Children[i]->LineQuery( Ray, ResultList);
	}
	unguard;
}

//*************************************************
//
// PrecomputedRay
//
//*************************************************

PrecomputedRay::PrecomputedRay( const FVector& TraceStart, const FVector& TraceEnd, const FVector& TraceExtent, uint32 ENF)
	:	iBoxV(E_Zero)
	,	ExtraNodeFlags(ENF)
{
	//HACK: Since parameters are on the stack (ActorLineCheck call)
	//It 'should' be safe to grab XYZ vectors from it using packed SSE instructions
	{
		cg::Vector V3Mask( cg::Vector::MASK_3D);
		Extent = cg::Vector( &TraceExtent.X) & V3Mask;
		End    = cg::Vector( &TraceEnd.X   ) & V3Mask;
		Org    = cg::Vector( &TraceStart.X ) & V3Mask;
		if ( !Extent.IsValid() || !End.IsValid() || !Org.IsValid() )
			return_invalid_helper;
	}

	cg::Vector Segment = End - Org;
	Dir = Segment.Normal();
	Length = Segment | Dir;
	if ( Length < 0.01f ) //Experimental
		return_invalid_helper;

	//Compute comparison
	cg::Vector Cmp = SMALL_VECTOR << (Segment*Segment);
	uint32 R = _mm_movemask_ps( Cmp );
	if ( R & 0b0011 ) //(X or Y) > SMALL_NUMBER
	{
		Inv = Dir.Reciprocal() & Cmp;
		if ( (R & 0b0111) == 0b0011 ) //Horizontal trace (Z=0)
			Hits_CylActor = &PrecomputedRay::Hits_HCylActor;
		else //Generic trace
		{
//			coX = Dir;
			Hits_CylActor = &PrecomputedRay::Hits_GCylActor;
		}
	}
	else if ( R & 0b0100 )
	{
		Inv = Dir;
		Hits_CylActor = &PrecomputedRay::Hits_VCylActor; //Optimizes vertical traces
	}
	else
		return_invalid_helper;

	//Intersection helpers
	iBoxV.i = (*(int32*)&Dir.X < 0) * 16;
	iBoxV.j = (*(int32*)&Dir.Y < 0) * 16;
	iBoxV.k = (*(int32*)&Dir.Z < 0) * 16;
}

void PrecomputedRay::QueryContainer(ActorLinkContainer& Container, FCheckResult*& Link) const
{
	guard(PrecomputedRay::QueryContainer);
	ActorLinkContainer::Iterator It(Container);
	while ( ActorInfo* AInfo = It.GetInfo() )
	{
		if ( AInfo->Flags.bUseCylinder )
		{
			if ( (this->*Hits_CylActor)( AInfo, Link) ) //Time is distance, convert to Unreal time
			{
				Link->Time = Clamp((Link->Time - Length * 0.001f) / Length, 0.f, 1.0f);
				Link->Location = FVector( Org + (End-Org) * Link->Time);
			}
		}
		else if ( IntersectsBox( AInfo->GridBox) && AInfo->Actor->Brush )
		{
			//Primitive->LineCheck
			FCheckResult* LinkNew = new(G_Stack) FCheckResult(Link);
			AActor* Actor = AInfo->Actor;
			FVector vStart( Org, E_NoSSEFPU);
			FVector vEnd( End, E_NoSSEFPU);
			FVector vExtent( Extent,E_NoSSEFPU);
			if ( Actor->Brush->LineCheck( *LinkNew, Actor, vEnd, vStart, vExtent, ExtraNodeFlags) ) //No hit
				G_Stack->Pop<FCheckResult>();
			else
			{
				Link = LinkNew;
				//Prevent CheckForActors crash!!!
				//Need Mover check here sooner or later
				Link->Location = FVector( cg::Vector( &Link->Location.X) - Dir * cg::Vector( 2.1f, 2.1f, 2.1f, 0) );
				Link->Time -= 2.1f / Length;
			}
		}
	}
	unguard;
}

bool PrecomputedRay::IntersectsBox( const cg::Box& Box) const
{
	cg::Box EBox = Box;
	EBox.ExpandBounds( Extent);

	if ( EBox.Contains(Org) )
		return true;

	cg::Vector T;
	//Forces MOV instead of SSE/FPU instructions
	//Eliminates 3 SHL instructions (iBoxV must be 16 instead of 4)
	//Creates branchless, uniform and legible assembly output
	{
		int32 i = iBoxV.i; //All 3 of these use EAX due to interleaving with the assignments below
		int32 j = iBoxV.j;
		int32 k = iBoxV.k;
		*(uint32*)&T.X    = *(uint32*) ( (uint8*)&EBox.Min.X + i); //Nearest X,Y,Z planes
		*(uint32*)&T.Y    = *(uint32*) ( (uint8*)&EBox.Min.Y + j);
		*(uint32*)&T.Z    = *(uint32*) ( (uint8*)&EBox.Min.Z + k);
	}
	T = (T - Org) * Inv; //The 'seconds' it takes to reach each plane (second = unit moved)

	if ( (T.X >= T.Y) && (T.X >= T.Z) ) //X is maximum
	{
		if ( (*(int32*)&T.X) >= 0 ) //Is this faster than loading a zero into XMM register?
		{
			float ptY = Org.Y + Dir.Y * T.X;
			float ptZ = Org.Z + Dir.Z * T.X;
			return ptY >= EBox.Min.Y && ptY <= EBox.Max.Y
				&& ptZ >= EBox.Min.Z && ptZ <= EBox.Max.Z;
		}
	}
	else if ( T.Y >= T.Z ) //Y is maximum
	{
		if ( (*(int32*)&T.Y) >= 0 )
		{
			float ptX = Org.X + Dir.X * T.Y;
			float ptZ = Org.Z + Dir.Z * T.Y;
			return ptX >= EBox.Min.X && ptX <= EBox.Max.X
				&& ptZ >= EBox.Min.Z && ptZ <= EBox.Max.Z;
		}
	}
	else //Z is maximum
	{
		if ( (*(int32*)&T.Z) >= 0 )
		{
			float ptX = Org.X + Dir.X * T.Z;
			float ptY = Org.Y + Dir.Y * T.Z;
			return ptX >= EBox.Min.X && ptX <= EBox.Max.X
				&& ptY >= EBox.Min.Y && ptY <= EBox.Max.Y;
		}
	}
	return false;
}


//True means cleanup!
bool PrecomputedRay::Hits_VCylActor( ActorInfo* AInfo, FCheckResult*& Link) const
{
	//Opposite directions mean no hit
	cg::Vector RelActor( cg::Vector(AInfo->Actor->Location, E_Unsafe) - Org);
	float DiffZ = End.Z - Org.Z;
	if ( RelActor.Z * DiffZ < 0.f) //Diff sign check
		return false;

	//Cylinder extent check
	if ( !RelActor.InCylinder( AInfo->Actor->CollisionRadius + Extent.X) ) 
		return false;

	float TouchDist = fabsf(RelActor.Z) - (AInfo->Actor->CollisionHeight + Extent.Z);
	float MaxDist = fabsf(DiffZ);
	if ( TouchDist < -1 || TouchDist > MaxDist + 1 ) //Check that not sunk into cylinder, or cylinder not unreachable
		return false; //Using +0.5 for test purposes

	if ( TouchDist > MaxDist ) //Normalize to MaxDist
		TouchDist = MaxDist;

	Link = new(G_Stack) FCheckResult(Link);
	Link->Actor = AInfo->Actor;
	Link->Time = TouchDist;
	Link->Normal = ZNormals[ DiffZ > 0 ];
	Link->Primitive = nullptr;
	return true;
}

//This is most commonly used during PHYS_Walking movement
//(Dist = HLength) so i don't need to measure trace length again!!!
bool PrecomputedRay::Hits_HCylActor( ActorInfo* AInfo, FCheckResult*& Link) const
{
//	debugf_ansi("[CG] Hit horizontal");
	float NetRadius = AInfo->Actor->CollisionRadius + Extent.X;
	float NetHeight = AInfo->Actor->CollisionHeight + Extent.Z;
	cg::Vector RelActor( cg::Vector(AInfo->Actor->Location,E_Unsafe) - Org);

	//Z reject (extent smaller-than difference)
	if ( Square(NetHeight) < Square(RelActor.Z) )
		return false;

	cg::Vector AdjustedActor = RelActor.TransformByXY( Dir);
	if ( (AdjustedActor.X <= KINDA_SMALL_NUMBER) || (AdjustedActor.X > Length + NetRadius) ) //Filter by X-bounds
		return false;

	//Check relative Y bounds, biggest reject chance (pawns are usually taller than wider)
	float XDeltaSq = Square(NetRadius) - Square(AdjustedActor.Y);
	if ( XDeltaSq < 0 )
		return false;

	//Refactored it looks like: (AdjX^2 + AdjY^ <= TS^2), this is a 'start inside actor' check
	if ( Square(AdjustedActor.X) <= XDeltaSq )
	{
		Link = new(G_Stack) FCheckResult(Link);
		Link->Actor = AInfo->Actor;
		Link->Normal = -RelActor.NormalXY();
		Link->Primitive = nullptr;
		Link->Time = 0;
		return true;
	}
	//Real X bound check
	//Move AdjX behind by corresponding cylinder extent
	float TargetX = AdjustedActor.X - appSqrt( XDeltaSq);
	if ( TargetX > Length )
		return false;
	Link = new(G_Stack) FCheckResult(Link);
	Link->Actor = AInfo->Actor;
	Link->Time = TargetX;
	cg::Vector HitLocation = Org + Dir * Link->Time;
	cg::Vector HitNormal = (HitLocation - cg::Vector(AInfo->Actor->Location,E_Unsafe)).NormalXY();
	if ( !HitNormal.IsValid() ) //If two small actors collide, hardcode hit normal as opposite of trace dir
		HitNormal = -Dir;
	Link->Normal = HitNormal;
	Link->Primitive = nullptr;
	return true;
}

//Generic trace (non H, non V)
bool PrecomputedRay::Hits_GCylActor( ActorInfo* AInfo, FCheckResult*& Link) const
{
	float NetRadius = AInfo->Actor->CollisionRadius + Extent.X;
	float NetHeight = AInfo->Actor->CollisionHeight + Extent.Z;
	cg::Vector RelActor( cg::Vector(AInfo->Actor->Location,E_Unsafe) - Org);
	cg::Vector Dir2D = Dir.NormalXY();
	cg::Vector AdjustedActor = RelActor.TransformByXY( Dir2D );

	//Check relative Y bounds, biggest reject chance (pawns are usually taller than wider)
	float XDeltaSq = Square(NetRadius) - Square(AdjustedActor.Y);
	if ( XDeltaSq < 0 )
		return false;

	float ZDif = End.Z - Org.Z;

	//Branchless Z bounds, 0 is low, 1 is high | One of them is always 0.f (before extent transformation)
	float ZBounds[2] = { -NetHeight, NetHeight};
	ZBounds[(ZDif >= 0)] += ZDif; //See if ZDif transformation should go in high or low slot

	//Actor out of trace's Z bounds
	if ( AdjustedActor.Z < ZBounds[0] || AdjustedActor.Z > ZBounds[1] )
		return false;

	//Refactored it looks like: (AdjX^2 + AdjY^ <= TS^2), inside XY cylinder
	if ( AdjustedActor.X * AdjustedActor.X <= XDeltaSq ) //Contained in the infinite XY cylinder
	{
		if ( fabsf(AdjustedActor.Z) <= NetHeight ) //Within Z slab (in Cylinder)
		{
			if ( AdjustedActor.X <= KINDA_SMALL_NUMBER )
				return false; //Tracing away from actor
			Link = new(G_Stack) FCheckResult(Link);
			Link->Actor = AInfo->Actor;
			if ( fabsf(AdjustedActor.Z * 0.98f) > NetHeight )
				Link->Normal = ZNormals[ ZDif > 0 ];
			else
				Link->Normal = -RelActor.NormalXY();
			Link->Primitive = nullptr;
			Link->Time = 0;
			return true;
		}
		if ( (*(INT*)&Dir.Z ^ *(INT*)&AdjustedActor.Z) < 0 ) //Not touching cylinder, negate if trace goes opposite sides
			return false;
	}
	else //When start occurs outside of XY cylinder bounds (perform length checks)
	{
		//This is a 'actor behind trace' check
		if ( *(INT*)&AdjustedActor.X < 0 )
			return false;
		//X bound check
		float XYDist = (End - Org) | Dir2D;
		float TargetX = AdjustedActor.X - appSqrt( XDeltaSq); //Move AdjX behind by corresponding cylinder extent
		if ( TargetX > XYDist )
			return false;

		if ( AdjustedActor.X * AdjustedActor.X >= XDeltaSq ) //We can move forward and position ourselves next to the cylinder (side by side)
		{
			float Delta = TargetX / (Dir | Dir2D); //1/HSize(Dir) * TargetX
			float ZEnd = Dir.Z * Delta;
			//Positioned point within Z slab, side hit
			if ( Square(ZEnd - AdjustedActor.Z) < Square(NetHeight) )
			{
				Link = new(G_Stack) FCheckResult(Link);
				Link->Actor = AInfo->Actor;
				Link->Time = Delta;
				cg::Vector HitLocation = Org + Dir * Delta;
				Link->Normal = (HitLocation - cg::Vector(AInfo->Actor->Location,E_Unsafe)).NormalXY();
				Link->Primitive = nullptr;
				return true;
			}
			if ( ZEnd*ZEnd > AdjustedActor.Z*AdjustedActor.Z ) //We passed the actor already!
				return false; //Appears to be an effective 'different sign' check
		}
	}

	//See if hits cylinder cap
	float Delta = Length / ZDif;
	if ( AdjustedActor.Z >= 0 )
		Delta *= AdjustedActor.Z - NetHeight;
	else
		Delta *= AdjustedActor.Z + NetHeight;

	//	VStart = Org + (End-Org) * (PlaneZ * _Reciprocal(ZDif));
	cg::Vector HitLocation = Org + Dir * Delta;
	if ( !(HitLocation - cg::Vector(AInfo->Actor->Location,E_Unsafe)).InCylinder(NetRadius) ) //TODO: REMOVE Z,W FROM CALCS
		return false;
	Link = new(G_Stack) FCheckResult(Link);
	Link->Actor = AInfo->Actor;
	Link->Time = Delta;
	Link->Normal = ZNormals[ZDif >= 0];
	Link->Primitive = nullptr;
	return true;
}

//*************************************************
//
// Unified Query Helpers
// Query bounds must be calculated in child class
//
//*************************************************

GenericQueryHelper::GenericQueryHelper( const FVector& Loc3, uint32 InENF, ActorQuery NewQuery)
{
	Location = cg::Vector( Loc3, E_Unsafe);
	if ( !Location.IsValid() )
		return_invalid_helper;
	ExtraNodeFlags = InENF;
	Query = NewQuery;
}

FCheckResult* GenericQueryHelper::QueryGrid( Grid* Grid)
{
	guard_slow(GenericQueryHelper::QueryGrid);
	FCheckResult* Results = nullptr;
	if ( IsValid() )
	{
		GSBaseMarker Marker;
		QueryContainer( Grid->Actors, Results); //Globals
		cg::Box TmpBox = Bounds - Grid->Box.Min;
		cg::Vector Top = cg::Vectorize( Grid->Size - XYZi_One);
		cg::Integers Min = Clamp((TmpBox.Min * Grid_Mult), cg::Vector(E_Zero), Top).Truncate32();
		cg::Integers Max = Clamp((TmpBox.Max * Grid_Mult), cg::Vector(E_Zero), Top).Truncate32();
		for ( int i=Min.i ; i<=Max.i ; i++ )
		for ( int j=Min.j ; j<=Max.j ; j++ )
		for ( int k=Min.k ; k<=Max.k ; k++ )			
		{
			GridElement* Node = Grid->Node(i,j,k);
			QueryContainer( Node->Actors, Results); //Big actors
			if ( Node->Tree && Node->Tree->ShouldQuery() )
				Node->Tree->GenericQuery( *this, Results); //Tree actors
		}
	}
	RemoveBadResults( &Results);
	uint32 Bads = RemoveBadResults( &Results);
	if ( Bads )
	{
		UE_DEV_LOG( TEXT("[CG] Removed %i actors from GenericQuery"), Bads );
	}
	return Results;
	unguard_slow;
}

void GenericQueryHelper::QueryContainer(ActorLinkContainer& Container, FCheckResult*& Result) const
{
	ActorLinkContainer::Iterator It(Container);
	while ( ActorInfo* AInfo = It.GetInfo() ) //Validity check is already done here!
		(this->*Query)( AInfo, Result);
}

bool GenericQueryHelper::IntersectsBox( const cg::Box& Box) const
{
	return Bounds.Intersects( Box);
}

//*************************************************
//
// PointHelper
//
//*************************************************

PointHelper::PointHelper( const FVector& InLocation, const FVector& InExtent, uint32 InExtraNodeFlags)
	: GenericQueryHelper( InLocation, InExtraNodeFlags, (ActorQuery)&PointHelper::PointQuery)
{
	if ( IsValid() )
	{
		Extent = cg::Vector( InExtent, E_Unsafe);
		Bounds = cg::Box( Location-Extent, Location+Extent, E_Strict);
	}
}

void PointHelper::PointQuery( ActorInfo* AInfo, FCheckResult*& ResultList) const
{
	if ( AInfo->Flags.bUseCylinder )
	{
		cg::Vector RelActor = Location - cg::Vector(AInfo->Actor->Location, E_Unsafe);
		if ( RelActor.InCylinder( AInfo->Actor->CollisionRadius+Extent.X, AInfo->Actor->CollisionRadius+Extent.X) )
		{
			ResultList = new(G_Stack) FCheckResult(ResultList);
			ResultList->Actor = AInfo->Actor;
			ResultList->Location = Location;
			if ( RelActor.Z >= AInfo->Actor->CollisionHeight )        ResultList->Normal = ZNormals[0];
			else if ( RelActor.Z <= -(AInfo->Actor->CollisionHeight)) ResultList->Normal = ZNormals[1];
			else                                                      ResultList->Normal = RelActor.NormalXY();
			ResultList->Primitive = nullptr;
		}
	}
	else if ( IntersectsBox( AInfo->GridBox) && AInfo->Actor->Brush )
	{
		FCheckResult* ResultNew = new(G_Stack) FCheckResult(ResultList);
		AActor* Actor = AInfo->Actor;
		if ( Actor->Brush->PointCheck( *ResultNew, Actor, FVector( Location, E_NoSSEFPU), FVector( Extent, E_NoSSEFPU), ExtraNodeFlags) ) //FIT, no hit
			G_Stack->Pop<FCheckResult>();
		else
			ResultList = ResultNew;
	}
}

//*************************************************
//
// RadiusHelper
//
//*************************************************

//TODO: MinGW may remove IR, see if Stack alignment is necessary
RadiusHelper::RadiusHelper( const FVector& InOrigin, float InRadius, uint32 InExtraNodeFlags)
	: GenericQueryHelper( InOrigin, InExtraNodeFlags, (ActorQuery)&RadiusHelper::RadiusQuery)
{
	if ( IsValid() )
	{
		RadiusSq = InRadius * InRadius;
		cg::Vector IR = cg::Vector(InRadius,InRadius,InRadius).Absolute();
		Bounds = cg::Box( Location-IR, Location+IR, E_Strict);
	}
}

void RadiusHelper::RadiusQuery( ActorInfo* AInfo, FCheckResult*& ResultList) const
{
	if ( (cg::Vector(AInfo->Actor->Location,E_Unsafe)-Location).SizeSq() <= RadiusSq )
	{
		ResultList = new(G_Stack) FCheckResult(ResultList);
		ResultList->Actor = AInfo->Actor;
	}
}

//*************************************************
//
// EncroachHelper
//
//*************************************************

//TODO: MinGW may remove Extent, see if Stack alignment is necessary
EncroachHelper::EncroachHelper( AActor* InActor, const FVector& Loc3, FRotator* Rot3, uint32 InExtraNodeFlags)
{
	if ( !InActor || !InActor->bCollideActors )
		return_invalid_helper;
	Location = cg::Vector( Loc3, E_Unsafe);
	if ( !Location.IsValid() )
		return_invalid_helper;

	Actor = InActor;
	Rotation = Rot3;

	ExtraNodeFlags = InExtraNodeFlags;

	if ( Actor->Brush )
	{
		Exchange( Actor->Location, *(FVector*)&Location);
		Exchange( Actor->Rotation, *Rotation);
		Bounds = (cg::Box)Actor->Brush->GetCollisionBoundingBox( Actor);
		Query = (ActorQuery)&EncroachHelper::EncroachmentQuery;
	}
	else
	{
		cg::Vector Extent = cg::Vector( Actor->CollisionRadius, Actor->CollisionRadius, Actor->CollisionHeight, 0);
		Bounds = cg::Box( Location-Extent, Location+Extent, E_Strict);
		Query = (ActorQuery)&EncroachHelper::EncroachmentQueryCyl;
	}

	//Prevent self-encroachment
	if ( Actor->CollisionTag != 0 )
	{
		ActorInfo* AInfo = reinterpret_cast<ActorInfo*>(Actor->CollisionTag);
		if ( G_AIH->IsValid( AInfo) )
			AInfo->CollisionTag = CollisionTag;
	}
}

EncroachHelper::~EncroachHelper()
{
	if ( IsValid() )
	{
		if ( Actor->Brush )
		{
			Exchange( Actor->Location, *(FVector*)&Location);
			Exchange( Actor->Rotation, *Rotation);
		}
	}
}

void EncroachHelper::EncroachmentQuery( ActorInfo* AInfo, FCheckResult*& ResultList) const
{
	if ( !AInfo->Flags.bIsMovingBrush && AInfo->Actor->bCollideWorld && Bounds.Intersects( AInfo->GridBox) )
	{
		FCheckResult* ResultNew = new(G_Stack) FCheckResult(ResultList);
		FVector Extent( AInfo->Actor->CollisionRadius, AInfo->Actor->CollisionRadius, AInfo->Actor->CollisionHeight);
		if ( Actor->Brush->PointCheck( *ResultNew, Actor, AInfo->Actor->Location, Extent, ExtraNodeFlags) ) //FIT, no hit
			G_Stack->Pop<FCheckResult>();
		else
		{
			ResultNew->Actor = AInfo->Actor; //Isn't this set?
			ResultNew->Primitive = nullptr;
			ResultList = ResultNew;
		}
	}
}

void EncroachHelper::EncroachmentQueryCyl( ActorInfo* AInfo, FCheckResult*& ResultList) const
{
	if ( !AInfo->Flags.bIsMovingBrush && Bounds.Intersects( AInfo->GridBox) )
	{
		cg::Vector RelActor = Location - cg::Vector(AInfo->Actor->Location,E_Unsafe);
		if ( AInfo->Actor->Brush ) //This is a custom primitive actor
		{
			//Exchange location temporarily
			FCheckResult* ResultNew = new(G_Stack) FCheckResult(ResultList);
			Exchange( Actor->Location, *(FVector*)&Location);
			FVector Extent( AInfo->Actor->CollisionRadius, AInfo->Actor->CollisionRadius, AInfo->Actor->CollisionHeight);
			if ( AInfo->Actor->Brush->PointCheck( *ResultNew, AInfo->Actor, Actor->Location, Extent, ExtraNodeFlags) ) //FIT, no hit
				G_Stack->Pop<FCheckResult>(); //ABOVE MAY BE BUGGY, REVIEW LOCATION
			else
			{
				ResultNew->Actor = AInfo->Actor;
				ResultList = ResultNew;
			}
			Exchange( Actor->Location, *(FVector*)&Location);
		}
		else if ( RelActor.InCylinder( Actor->CollisionRadius + AInfo->Actor->CollisionRadius, Actor->CollisionHeight + AInfo->Actor->CollisionRadius) )
		{
			ResultList = new(G_Stack) FCheckResult(ResultList);
			ResultList->Actor = AInfo->Actor;
			ResultList->Location = AInfo->Actor->Location;
			float Bound = (RelActor.SizeXYSq() < 0.001f) ? 0.f : AInfo->Actor->CollisionHeight; //If actors are too close (H), don't calc normal and instead push upwards or downwards
			if ( RelActor.Z >= Bound )
				ResultList->Normal = ZNormals[0];
			else if ( RelActor.Z <= -Bound )
				ResultList->Normal = ZNormals[1];
			else
				ResultList->Normal = RelActor.NormalXY();
			ResultList->Primitive = nullptr;
		}
	}
}