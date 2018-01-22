
#include "GridTypes.h" //Must go before API to enable FVector::operator=
#include "API.h"
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

inline float appSqrt( float F)
{
	float result;
	__m128 res = _mm_sqrt_ss( _mm_load_ss( &F));
	_mm_store_ss( &result, res);
	return result;
}


//*************************************************
//
// GSBaseMarker
//
//*************************************************

GSBaseMarker::GSBaseMarker()
{
	CollisionTag++;
	UE_DEV_THROW( G_Stack->Cur != 0, "Multiple GSBaseMarker stacked!" );
}

GSBaseMarker::~GSBaseMarker()
{
	G_Stack->Cur = 0;
}

//*************************************************
//
// ActorInfo
//
//*************************************************

void ActorInfo::LineQuery( ActorLink* ALink, const PrecomputedRay& Ray, FCheckResult*& Link)
{
	for ( ; ALink ; ALink=ALink->Next )
	{
		// Try to trace this back one of these days
		UE_DEV_THROW( !G_ALH->IsValid( ALink), "Invalid actor link in LineQuery");
		ActorInfo* AInfo = ALink->Info;
		UE_DEV_THROW( !G_AIH->IsValid( AInfo), "Invalid actor info in LineQuery");
		//Prevent querying same actor multiple times
		if ( AInfo->CollisionTag != ::CollisionTag )
		{
			AInfo->CollisionTag = ::CollisionTag;
			if ( AInfo->Flags.bUseCylinder )
			{
				FCheckResult* OldResult = Link;
				(Ray.*Ray.Hits_CylActor)( AInfo, Link);
				//Time is distance, convert to Unreal time
				if ( OldResult != Link )
				{
					float nX = Link->Normal.X; //SSE instructions will override this, keep it
					Link->Time = Clamp((Link->Time - Ray.Length * 0.001f) / Ray.Length, 0.f, 1.f);
					Link->Location = Ray.Org + (Ray.End-Ray.Org) * Link->Time;
					Link->Normal.X = nX; //Restore
				}
			}
			else if ( Ray.IntersectsBox( AInfo->P.pBox) && AInfo->IsValid() )
			{
				//Primitive->LineCheck
				FCheckResult* LinkNew = new(G_Stack) FCheckResult(Link);
				AActor* Actor = AInfo->Actor;
				if ( !Actor->Brush ||
					Actor->Brush->LineCheck( *LinkNew, Actor, FVector(Ray.End,E_NoSSEFPU), FVector(Ray.Org,E_NoSSEFPU), FVector(Ray.Extent,E_NoSSEFPU), /*ExtraNodeFlags*/0) ) //No hit
					G_Stack->Pop<FCheckResult>();
				else
				{
					Link = LinkNew;
					//Prevent CheckForActors crash!!!
					//Need Mover check here sooner or later
					uint32 NormalX = *(uint32*)&Link->Normal.X; //Store in x86 register
					cg::Vector Add = Ray.Dir * cg::Vector( 2.1f, 2.1f, 2.1f, 0);
					//Normal.X shouldn't be modified due to Add.W being zero... but we never know
					Link->Location = cg::Vector( &Link->Location.X) - Add;
					*(uint32*)&Link->Normal.X = NormalX; //Put back in place
					Link->Time -= 2 / Ray.Length;
				}

			}
		}
	}			
}

void ActorInfo::PointQuery( ActorLink* ALink, const PointHelper& Helper, FCheckResult*& ResultList)
{
	for ( ; ALink ; ALink=ALink->Next )
	{
		UE_DEV_THROW( !G_ALH->IsValid( ALink), "Invalid actor link in PointQuery");
		ActorInfo* AInfo = ALink->Info;
		UE_DEV_THROW( !G_AIH->IsValid( AInfo), "Invalid actor info in PointQuery");
		if ( AInfo->CollisionTag != ::CollisionTag )
		{
			AInfo->CollisionTag = ::CollisionTag;
			//Intersect a cylinder
			if ( AInfo->Flags.bUseCylinder )
			{
				cg::Vector RelActor = Helper.Location - AInfo->C.Location;
				if ( RelActor.InCylinder( Helper.Extent + AInfo->C.Extent) && AInfo->IsValid() )
				{
					ResultList = new(G_Stack) FCheckResult(ResultList);
					ResultList->Actor = AInfo->Actor;
					ResultList->Location = Helper.Location;
					if ( RelActor.Z >= AInfo->C.Extent.Z )        ResultList->Normal = ZNormals[0];
					else if ( RelActor.Z <= -(AInfo->C.Extent.Z)) ResultList->Normal = ZNormals[1];
					else                                        ResultList->Normal = RelActor.NormalXY();
					ResultList->Primitive = nullptr;
				}
			}
			else if ( Helper.IntersectsBox( AInfo->P.pBox) && AInfo->IsValid() && AInfo->Actor->Brush )
			{
				FCheckResult* ResultNew = new(G_Stack) FCheckResult(ResultList);
				AActor* Actor = AInfo->Actor;
				if ( Actor->Brush->PointCheck( *ResultNew, Actor, /*Actor->Location*/FVector( Helper.Location, E_NoSSEFPU), FVector( Helper.Extent, E_NoSSEFPU), Helper.ExtraNodeFlags) ) //FIT, no hit
					G_Stack->Pop<FCheckResult>();
				else
					ResultList = ResultNew;
			}
		}
	}			
}


void ActorInfo::RadiusQuery( ActorLink* ALink, const RadiusHelper& Helper, FCheckResult*& ResultList)
{
	for ( ; ALink ; ALink=ALink->Next )
	{
		UE_DEV_THROW( !G_ALH->IsValid( ALink), "Invalid actor link in RadiusQuery");
		ActorInfo* AInfo = ALink->Info;
		UE_DEV_THROW( !G_AIH->IsValid( AInfo), "Invalid actor info in RadiusQuery");
		if ( AInfo->CollisionTag != ::CollisionTag )
		{
			AInfo->CollisionTag = ::CollisionTag;
			cg::Vector Location = AInfo->cLocation();
			if ( ((Location-Helper.Location).SizeSq() <= Helper.RadiusSq) && AInfo->IsValid() )
			{
				ResultList = new(G_Stack) FCheckResult(ResultList);
				ResultList->Actor = AInfo->Actor;
			}
		}
	}			
}

void ActorInfo::EncroachmentQuery( ActorLink* ALink, const EncroachHelper& Helper, FCheckResult*& ResultList)
{
	for ( ; ALink ; ALink=ALink->Next )
	{
		UE_DEV_THROW( !G_ALH->IsValid( ALink), "Invalid actor link in EncroachmentQuery");
		ActorInfo* AInfo = ALink->Info;
		UE_DEV_THROW( !G_AIH->IsValid( AInfo), "Invalid actor info in EncroachmentQuery");
		if ( AInfo->CollisionTag != ::CollisionTag )
		{
			AInfo->CollisionTag = ::CollisionTag;
			if ( !AInfo->Flags.bIsMovingBrush && Helper.Bounds.Intersects( AInfo->cBox()) && AInfo->IsValid() && AInfo->Actor->bCollideWorld )
			{
				FCheckResult* ResultNew = new(G_Stack) FCheckResult(ResultList);
				AActor* Actor = Helper.Actor;
				if ( Actor->Brush->PointCheck( *ResultNew, Actor, FVector(AInfo->C.Location,E_NoSSEFPU), FVector(AInfo->C.Extent,E_NoSSEFPU), Helper.ExtraNodeFlags) ) //FIT, no hit
					G_Stack->Pop<FCheckResult>();
				else
				{
					ResultNew->Actor = AInfo->Actor;
					ResultNew->Primitive = nullptr;
					ResultList = ResultNew;
				}
			}
		}
	}
}

//Actor is a Cylinder
void ActorInfo::EncroachmentQueryCyl( ActorLink* ALink, const EncroachHelper& Helper, FCheckResult*& ResultList)
{
	for ( ; ALink ; ALink=ALink->Next )
	{
		UE_DEV_THROW( !G_ALH->IsValid( ALink), "Invalid actor link in EncroachmentQueryCyl");
		ActorInfo* AInfo = ALink->Info;
		UE_DEV_THROW( !G_AIH->IsValid( AInfo), "Invalid actor info in EncroachmentQueryCyl");
		if ( AInfo->CollisionTag != ::CollisionTag )
		{
			AInfo->CollisionTag = ::CollisionTag;
			if ( !AInfo->Flags.bIsMovingBrush && Helper.Bounds.Intersects( AInfo->cBox()) && AInfo->IsValid() )
			{
				AActor* Actor = Helper.Actor;
				cg::Vector RelActor = Helper.Location - AInfo->C.Location;
				if ( Actor->Brush ) //This is a custom primitive actor
				{
					//Exchange location temporarily
					FCheckResult* ResultNew = new(G_Stack) FCheckResult(ResultList);
					Exchange( Actor->Location, *(FVector*)&Helper.Location);
					if ( Actor->Brush->PointCheck( *ResultNew, Actor, Actor->Location, FVector( AInfo->C.Extent, E_NoSSEFPU), Helper.ExtraNodeFlags) ) //FIT, no hit
						G_Stack->Pop<FCheckResult>(); //ABOVE MAY BE BUGGY, REVIEW LOCATION
					else
					{
						ResultNew->Actor = AInfo->Actor;
						ResultList = ResultNew;
					}
					Exchange( Actor->Location, *(FVector*)&Helper.Location);
				}
				else if ( RelActor.InCylinder( Actor->CollisionRadius + AInfo->C.Extent.X) )
				{
					ResultList = new(G_Stack) FCheckResult(ResultList);
					ResultList->Actor = AInfo->Actor;
					ResultList->Location = AInfo->C.Location;
					float Bound = (RelActor.SizeXYSq() < 0.001f) ? 0.f : AInfo->C.Extent.Z; //If actors are too close (H), don't calc normal and instead push upwards or downwards
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
	}			
}



//*************************************************
//
// Grid
//
//*************************************************

static GridElement* GEStack[256];//Extra 3 for memory safety

FCheckResult* Grid::LineQuery( const PrecomputedRay& Ray, uint32 ExtraNodeFlags)
{
	GSBaseMarker Marker;
	FCheckResult* Result = nullptr;
	
	//Get start/end grid coordinates
	cg::Vector Start = (Ray.Org - Ray.Extent) - Box.Min;
	cg::Vector End   = (Ray.End + Ray.Extent) - Box.Min;
	//FAILS IF TRACE ORIGINATES OR ENDS OUTSIDE OF GRID!!!
	cg::Integers Min = cg::Max((Start * Grid_Mult)-Grid_Mult*4, cg::Vector(E_Zero)           ).Truncate32();
	cg::Integers Max = cg::Min((End   * Grid_Mult)+Grid_Mult*4, cg::Vectorize(Size-XYZi_One) ).Truncate32();
	int32 iS[3];
	for ( uint32 i=0 ; i<3 ; i++ )
	{
		int32 j = Max.coord(i)-Min.coord(i);
		iS[i] = (j>0) - (j<0); //Does this kill the branches?
	}	

	//Check globals
	ActorInfo::LineQuery( GlobalActors, Ray, Result);
	//Check nodes (start with local node), never goes beyond 255
	uint8 bGE = 0;
	uint8 iGE = 1;
	GEStack[0] = Node(Min); //A super wide trace can kill the grid
	GEStack[0]->CollisionTag = CollisionTag;
	do
	{
		GridElement* CurGE = GEStack[bGE];
		//Check actors (and tree optimal bounds) at GEStack[bGE]
		ActorInfo::LineQuery( CurGE->BigActors, Ray, Result);
		if ( CurGE->Tree && CurGE->Tree->ActorCount && Ray.IntersectsBox( CurGE->Tree->OptimalBounds) )
			CurGE->Tree->LineQuery( Ray, Result);

		int32 X = CurGE->X;
		int32 Y = CurGE->Y;
		int32 Z = CurGE->Z;
		GridElement* GB[3];
		uint32 iGB = 0; //Next is necessary to prevent trace from going to the infinite
		if ( X != Max.i )	GB[iGB++] = Node( X+iS[0], Y      , Z      );
		if ( Y != Max.j )	GB[iGB++] = Node( X      , Y+iS[1], Z      );
		if ( Z != Max.k )	GB[iGB++] = Node( X      , Y      , Z+iS[2]);

		for ( uint32 i=0 ; i<iGB ; i++ )
			if ( GB[i]->CollisionTag != CollisionTag )
			{
				GB[i]->CollisionTag = CollisionTag;

				if ( iGB == 1 ) //Logic: axis aligned trace doesn't need box checks
					GEStack[iGE++] = GB[0]; //Does this speed anything up?
				else if ( GB[i]->Tree )
				{
					if ( Ray.IntersectsBox( GB[i]->Tree->RealBounds) )
						GEStack[iGE++] = GB[i];
				}
				else if ( Ray.IntersectsBox( GetNodeBoundingBox(cg::Integers(GB[i]->X,GB[i]->Y,GB[i]->Z,0)) ) )
					GEStack[iGE++] = GB[i];
			}
		bGE++;
	}
	while ( iGE != bGE );

	return Result;
}



//*************************************************
//
// MiniTree
//
//*************************************************

void MiniTree::GenericQuery( const GenericQueryHelper& Helper, FCheckResult*& ResultList)
{
	(*(Helper.Query))( Actors, Helper, ResultList);
	if ( ChildCount )
	{
		for ( uint32 i=0 ; i<8 ; i++ )
			if ( Children[i] && Helper.IntersectsBox(Children[i]->OptimalBounds) )
				Children[i]->GenericQuery( Helper, ResultList);
	}
}

void MiniTree::LineQuery( const PrecomputedRay& Ray, FCheckResult*& ResultList)
{ 
	ActorInfo::LineQuery( Actors, Ray, ResultList);
	if ( ChildCount )
	{
		for ( uint32 i=0 ; i<8 ; i++ )
			if ( Children[i] && Ray.IntersectsBox(Children[i]->OptimalBounds) )
				Children[i]->LineQuery( Ray, ResultList);
	}
}

//*************************************************
//
// PrecomputedRay
//
//*************************************************

PrecomputedRay::PrecomputedRay( const FVector& TraceStart, const FVector& TraceEnd, const FVector& TraceExtent, uint32 ENF)
	:	iBoxV(E_Zero)
{
	//HACK: Since parameters are on the stack (ActorLineCheck call)
	//It 'should' be safe to grab XYZ vectors from it using packed SSE instructions
	{
		cg::Vector& V3Mask = (cg::Vector&)Vector3Mask;
		Extent = cg::Vector( & TraceExtent.X) & V3Mask;
		End    = cg::Vector( & TraceEnd.X   ) & V3Mask;
		Org    = cg::Vector( & TraceStart.X ) & V3Mask;
		if ( !Extent.IsValid() || !End.IsValid() || !Org.IsValid() )
			return_invalid_helper;
	}

/*	__m128 mask = _mm_castsi128_ps( _mm_load_si128( Vector3Mask.mm() ));
	_mm_store_ps( Extent.fa(), _mm_and_ps( _mm_loadu_ps((float*)&TraceExtent), mask)  );
	_mm_store_ps( End.fa()   , _mm_and_ps( _mm_loadu_ps((float*)&TraceEnd   ), mask)  );
	_mm_store_ps( Org.fa()   , _mm_and_ps( _mm_loadu_ps((float*)&TraceStart ), mask)  );
	*/
	cg::Vector Segment = End - Org;
	Dir = Segment.Normal();
	Length = Segment | Dir;

	//Compute comparison
	cg::Vector Cmp;
	Segment *= Segment;
	_mm_store_ps( Cmp.fa(), _mm_cmpge_ps( _mm_load_ps(Segment.fa()), _mm_load_ps(SMALL_VECTOR.fa()) ));
	uint32 R = _mm_movemask_ps( _mm_load_ps(Cmp.fa()) );
	if ( R & 0b0011 ) //(X or Y) > SMALL_NUMBER
	{
		Inv = Dir.Reciprocal() & Cmp;
		if ( (R & 0b0111) == 0b0011 ) //Horizontal trace (Z=0)
			Hits_CylActor = &PrecomputedRay::Hits_HCylActor;
		else //Generic trace
		{
//			coX = Dir;
			Hits_CylActor = &PrecomputedRay::Hits_UCylActor;
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
	cg::Vector RelActor( AInfo->C.Location - Org);
	float DiffZ = End.Z - Org.Z;
	if ( (*(int32*)&(RelActor.Z) ^ *(int32*)&DiffZ) < 0) //Diff sign check
		return false;

	//Cylinder extent check
//	bool bLog = (AInfo->Extent.Z == 8.f) && (Extent.X > 0);
	cg::Vector NetExtent( AInfo->C.Extent + Extent );
	if ( !RelActor.InCylinder( NetExtent.X) ) 
		return false;

	float TouchDist = fabsf(RelActor.Z) - NetExtent.Z;
	if ( TouchDist < 0 || TouchDist > fabsf(DiffZ) ) //Check that not sunk into cylinder, or cylinder not unreachable
		return false;

	if ( AInfo->IsValid() )
	{
		Link = new(G_Stack) FCheckResult(Link);
		Link->Actor = AInfo->Actor;
		Link->Time = TouchDist;
		Link->Normal = ZNormals[ DiffZ > 0 ];
		Link->Primitive = nullptr;
		return false;
	}
	return true;
}

//This is most commonly used during PHYS_Walking movement
//(Dist = HLength) so i don't need to measure trace length again!!!
bool PrecomputedRay::Hits_HCylActor( ActorInfo* AInfo, FCheckResult*& Link) const
{
//	debugf_ansi("[CG] Hit horizontal");
	cg::Vector NetExtent( AInfo->C.Extent + Extent );
	cg::Vector RelActor( AInfo->C.Location - Org);

	//Z reject (extent smaller-than difference)
	if ( NetExtent.Z < fabsf(RelActor.Z) )
		return false;

	cg::Vector AdjustedActor = RelActor.TransformByXY( Dir);
	if ( (AdjustedActor.X <= KINDA_SMALL_NUMBER) || (AdjustedActor.X > Length + NetExtent.X) ) //Filter by X-bounds
		return false;

	//Check relative Y bounds, biggest reject chance (pawns are usually taller than wider)
	float XDeltaSq = NetExtent.X*NetExtent.X - AdjustedActor.Y*AdjustedActor.Y;
	if ( XDeltaSq < 0 )
		return false;

	//Get rid of anomalies here
	if ( !AInfo->IsValid() )
		return true;

	//Refactored it looks like: (AdjX^2 + AdjY^ <= TS^2), this is a 'start inside actor' check
	if ( AdjustedActor.X * AdjustedActor.X <= XDeltaSq )
	{
		Link = new(G_Stack) FCheckResult(Link);
		Link->Actor = AInfo->Actor;
		Link->Normal = -RelActor.NormalXY();
		Link->Primitive = nullptr;
		Link->Time = 0;
		return false;
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
	Link->Normal = (HitLocation - AInfo->C.Location).NormalXY();
	Link->Primitive = nullptr;
	return false;
}

//Implement later
bool PrecomputedRay::Hits_GCylActor( ActorInfo* AInfo, FCheckResult*& Link) const
{
	return false;
}

//Generic UT cylinder component trace
bool PrecomputedRay::Hits_UCylActor( ActorInfo* AInfo, FCheckResult*& Link) const
{
	if ( !AInfo->IsValid() )
		return true;

	// Treat this actor as a cylinder.
	cg::Vector NetExtent = Extent + AInfo->C.Extent;
	cg::Vector Normal;

	//De-branch bound checks
	cg::Box Bounds = cg::Box( AInfo->C.Location - NetExtent, AInfo->C.Location + NetExtent, E_Strict);
	if ( !Bounds.Intersects( cg::Box(Org,End)) )
		return false;
#define BotZ Bounds.Min.Z
#define TopZ Bounds.Max.Z

	// Clip to top of cylinder.
	float T0=0, T1=1.0;
	if( Org.Z>TopZ && End.Z<TopZ )
	{
		float T = (TopZ - Org.Z)/(End.Z - Org.Z);
		if( T > T0 )
		{
			T0 = ::Max(T0,T);
			Normal = ZNormals[0];
		}
	}
	else if( Org.Z<TopZ && End.Z>TopZ )
		T1 = ::Min( T1, (TopZ - Org.Z)/(End.Z - Org.Z) );

	// Clip to bottom of cylinder.
	if( Org.Z<BotZ && End.Z>BotZ )
	{
		float T = (BotZ - Org.Z)/(End.Z - Org.Z);
		if( T > T0 )
		{
			T0 = ::Max(T0,T);
			Normal = ZNormals[1];
		}
	}
	else if( Org.Z>BotZ && End.Z<BotZ )
		T1 = ::Min( T1, (BotZ - Org.Z)/(End.Z - Org.Z) );

	// Reject.
	if( T0 >= T1 )
		return false;

	// Test setup.
	float   Kx        = Org.X - AInfo->C.Location.X;
	float   Ky        = Org.Y - AInfo->C.Location.Y;

	// 2D circle clip about origin.
	float   Vx        = End.X - Org.X;
	float   Vy        = End.Y - Org.Y;
	float   A         = Vx*Vx + Vy*Vy;
	float   B         = 2.0 * (Kx*Vx + Ky*Vy);
	float   C         = Kx*Kx + Ky*Ky - (NetExtent.X * NetExtent.X);
	float   Discrim   = B*B - 4.0*A*C;

	// If already inside sphere, oppose further movement inward.
	if( C<1.0f && Org.Z>BotZ && Org.Z<TopZ )
	{
		float fDir = ((End-Org)*cg::Vector(1,1,0,0)) | (Org-AInfo->C.Location);
		if( fDir < -0.1 )
		{
			Link = new(G_Stack) FCheckResult(Link);
			Link->Actor     = AInfo->Actor;
			Link->Time      = 0.0;
//			Link->Location  = Org;
			Link->Normal    = ((Org-AInfo->C.Location)*cg::Vector(1,1,0,0)).Normal(); //Should be safe normal
			Link->Primitive = nullptr;
		}
		return false;
	}

	// No intersection if discriminant is negative.
	if( Discrim < 0 )
		return false;

	// Unstable intersection if velocity is tiny.
	if( A < SMALL_NUMBER )
	{
		// Outside.
		if( C > 0 )
			return false;
	}
	else
	{
		// Compute intersection times.
		Discrim   = appSqrt(Discrim);
		float R2A = 0.5/A;
		T1        = ::Min( T1, +(Discrim-B) * R2A );
		float T   = -(Discrim+B) * R2A;
		if( T > T0 )
		{
			T0 = T;
			Normal = (Org + (End-Org)*T0 - AInfo->C.Location);
			Normal = Normal.NormalXY();
		}
		if( T0 >= T1 )
			return false;
	}
	Link = new(G_Stack) FCheckResult(Link);
	Link->Actor     = AInfo->Actor;
	Link->Time = T0 * Length;
//	Link->Time      = Clamp(T0-0.001,0.0,1.0);
//	Link->Location  = Org + (End-Org) * Link->Time;
	Link->Normal    = Normal;
	Link->Primitive = nullptr;
	return 0;

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

FCheckResult* GenericQueryHelper::QueryGrids( Grid* Grid)
{
	FCheckResult* Results = nullptr;
	if ( IsValid() )
	{
		GSBaseMarker Marker;
		(*Query)( Grid->GlobalActors, *this, Results); //Globals
		cg::Box TmpBox = Bounds - Grid->Box.Min;
		cg::Integers Min = cg::Max((TmpBox.Min * Grid_Mult), cg::Vector(E_Zero)).Truncate32();
		cg::Integers Max = cg::Min((TmpBox.Max * Grid_Mult), cg::Vectorize(Grid->Size-XYZi_One) ).Truncate32();
		for ( int i=Min.i ; i<=Max.i ; i++ )
		for ( int j=Min.j ; j<=Max.j ; j++ )
		for ( int k=Min.k ; k<=Max.k ; k++ )			
		{
			GridElement* Node = Grid->Node(i,j,k);
			(*Query)( Node->BigActors, *this, Results); //Big actors
			if ( Node->Tree && Node->Tree->ActorCount && IntersectsBox(Node->Tree->OptimalBounds) )
				Node->Tree->GenericQuery( *this, Results); //Tree actors
		}
	}
	return Results;
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
	: GenericQueryHelper( InLocation, InExtraNodeFlags, (ActorQuery)&ActorInfo::PointQuery)
{
	if ( IsValid() )
	{
		Extent = cg::Vector( InExtent, E_Unsafe);
		Bounds = cg::Box( Location-Extent, Location+Extent, E_Strict);
	}
}

//*************************************************
//
// RadiusHelper
//
//*************************************************

//TODO: MinGW may remove IR, see if Stack alignment is necessary
RadiusHelper::RadiusHelper( const FVector& InOrigin, float InRadius, uint32 InExtraNodeFlags)
	: GenericQueryHelper( InOrigin, InExtraNodeFlags, (ActorQuery)&ActorInfo::RadiusQuery)
{
	if ( IsValid() )
	{
		RadiusSq = InRadius * InRadius;
		cg::Vector IR = cg::Vector(InRadius,InRadius,InRadius).Absolute();
		Bounds = cg::Box( Location-IR, Location+IR, E_Strict);
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
		Query = (ActorQuery)&ActorInfo::EncroachmentQuery;
	}
	else
	{
		cg::Vector Extent = cg::Vector( Actor->CollisionRadius, Actor->CollisionRadius, Actor->CollisionHeight, 0);
		Bounds = cg::Box( Location-Extent, Location+Extent, E_Strict);
		Query = (ActorQuery)&ActorInfo::EncroachmentQueryCyl;
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
	if ( Actor->Brush && (ExtraNodeFlags != 0xFFFFFFFF) )
	{
		Exchange( Actor->Location, *(FVector*)&Location);
		Exchange( Actor->Rotation, *Rotation);
	}
}
