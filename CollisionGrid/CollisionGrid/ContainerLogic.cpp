

#include "API.h"
#include "GridTypes.h"
#include "GridMem.h"


#include "Objects_UE1.h"

//*************************************************
//
// ActorInfo
//
//*************************************************

//Set important variables
bool ActorInfo::Init( AActor* InActor)
{
	guard_slow(ActorInfo::Init);
	ObjIndex = InActor->Index;
	Actor = InActor;

	cg::Vector Location( Actor->Location, E_Unsafe);
	if ( Location.InvalidBits() & 0x0111 ) //Validate location
	{
		debugf( TEXT("[CG] Invalid actor location: %s [%f,%f,%f]"), Actor->GetName(), Actor->Location.X, Actor->Location.Y, Actor->Location.Z );
		cg::Vector NewLoc( Actor->ColLocation, E_Unsafe);
		if ( NewLoc.InvalidBits() & 0x0111 ) //EXPERIMENTAL, RELOCATE ACTOR
			return false;
		Location = NewLoc;
		Actor->Location = FVector( NewLoc);
		debugf( TEXT("[CG] Relocating to [%f,%f,%f]"), Actor->Location.X, Actor->Location.Y, Actor->Location.Z);
	}

	if ( InActor->Brush )
	{
		GridBox = (cg::Box) InActor->Brush->GetCollisionBoundingBox( InActor);
		GridBox.ExpandBounds( cg::Vector( 8.f, 8.f, 8.f, 0)); //Obscure bug makes encroachment checks fail
		Flags.bUseCylinder = 0;
		Flags.bIsMovingBrush = InActor->IsMovingBrush() != 0;
	}
	else
	{
		cg::Vector Extent( InActor->CollisionRadius + 2.f, InActor->CollisionRadius + 2.f, InActor->CollisionHeight + 2.f);
		GridBox = cg::Box( Location - Extent, Location + Extent, E_Strict);
		Flags.bUseCylinder = 1;
		Flags.bIsMovingBrush = 0;
	}
	Actor->CollisionTag = reinterpret_cast<uint32>(this);
	CurDepth = 0;
	TopDepth = 0;
	Flags.bCommited = 1;
	return true;
	unguard_slow;
}

bool ActorInfo::IsValid() const
{
	if ( !Flags.bCommited )
	{}
	else if ( (*GetIndexedObject)(ObjIndex) != Actor )
		debugf( TEXT("[CG] ActorInfo::IsValid -> Using invalid object"));
	else if ( Actor->bDeleteMe || !Actor->bCollideActors )
		debugf( TEXT("[CG] ActorInfo::IsValid -> %s shouldn't be in the grid"), Actor->GetName() );
	else if ( reinterpret_cast<ActorInfo*>(Actor->CollisionTag) != this )
		debugf( TEXT("[CG] ActorInfo::IsValid -> Mismatching CollisionTag"));
	else
		return true;
	return false;
}


//*************************************************
//
// Grid
//
//*************************************************

Grid::Grid( ULevel* Level)
	: Actors()
	, TreeList(nullptr)
{
	UModel* Model = Level->Model;
	if ( Model->RootOutside )
	{
		Size = cg::Integers( 128, 128, 128, 0);
		Box = cg::Box( cg::Vector(-32768,-32768,-32768,0), cg::Vector(32768,32768,32768,0), E_Strict);
	}
	else
	{
		cg::Box GridBox( &Model->Points(0), Model->Points.ArrayNum);
		Size = ((GridBox.Max - GridBox.Min) * Grid_Mult + cg::Vector(0.99f,0.99f,0.99f)).Truncate32();
		Size.l = 0;
		Box = GridBox;
		UE_DEV_THROW( Size.i > 128 || Size.j > 128 || Size.k > 128, "New grid exceeds 128^3 dimensions"); //Never deprecate
	}
	uint32 BlockSize = Size.i * Size.j * Size.k * sizeof(struct GridElement);
	Nodes = (GridElement*) appMalloc( BlockSize);
	uint32 l = 0;
	for ( int32 i=0 ; i<Size.i ; i++ )
	for ( int32 j=0 ; j<Size.j ; j++ )
	for ( int32 k=0 ; k<Size.k ; k++ )
		new ( Nodes + l++, E_Stack) GridElement(i,j,k);
	debugf( TEXT("[CG] Grid allocated [%i,%i,%i]"), Size.i, Size.j, Size.k );
}

Grid::~Grid()
{
	uint32 Total = Size.i * Size.j * Size.k;
	for ( uint32 i=0 ; i<Total ; i++ )
		Nodes[i].~GridElement();
	appFree( Nodes);
}

GridElement::GridElement( uint32 i, uint32 j, uint32 k)
	: Actors()
	, Tree(nullptr)
	, CollisionTag(0)
	, X(i), Y(j), Z(k), W(0)
{}

GridElement* Grid::Node( int32 i, int32 j, int32 k)
{
	UE_DEV_THROW( i >= Size.i || j >= Size.j || k >= Size.k , "Bad node request"); //Never deprecate
	return &Nodes[ i*Size.j*Size.k + j*Size.k + k];
}

GridElement* Grid::Node( const cg::Integers& I)
{
	return Node( I.i, I.j, I.k);
}

bool Grid::InsertActor( AActor* Actor)
{
	guard_slow(Grid::InsertActor);
	if ( !Actor->bCollideActors || Actor->bDeleteMe ) //Validate actor flags
		return false;

	if ( Actor->CollisionTag != 0 )
	{
		//Attempt removal first, what to do upon failure?
		if ( !RemoveActor(Actor) )
		{
			debugf( TEXT("[CG] Anomaly in InsertActor: CollisionTag not zero for %s"), Actor->GetName() );
			return false;
		}
	}
	ActorInfo* AInfo = G_AIH->GrabElement( Actor);
	if ( !AInfo )
		return false;

	//Classify whether to add as boundary actor or inner actor
	//It may even be possible that an actor actually doesn't fit here!!

	GridElement* GridElements[MAX_NODE_LINKS];
	int32 iLinks = 0;
	bool bGlobalPlacement = false;

	if ( Box.Intersects(AInfo->GridBox) )
	{
		cg::Box RRActorBox = (AInfo->GridBox-Box.Min) * Grid_Mult; //Transform to local coords
		cg::Vector fMax = cg::Vectorize(Size - XYZi_One);
		cg::Integers Min = Clamp(RRActorBox.Min, cg::Vector(E_Zero), fMax).Truncate32();
		cg::Integers Max = Clamp(RRActorBox.Max, cg::Vector(E_Zero), fMax).Truncate32();

		//Calculate how big the node list will be before doing any listing
		cg::Integers Total = XYZi_One + Max - Min;
		UE_DEV_THROW( Total.i <= 0 || Total.j <= 0 || Total.k <= 0, "Bad iBounds calculation"); 
		if ( Total.i <= 0 || Total.j <= 0 || Total.k <= 0 )
		{} //Force a no-placement
		else if ( Total.i*Total.j*Total.k >= MAX_NODE_LINKS ) //Temporary
			bGlobalPlacement = true;
		else
		{
			for ( int32 i=Min.i ; i<=Max.i ; i++ )
			for ( int32 j=Min.j ; j<=Max.j ; j++ )
			for ( int32 k=Min.k ; k<=Max.k ; k++ )
				GridElements[iLinks++] = Node( i, j, k);
		}
	}

	//Placement is uniform, this is required to keep the same ActorInfo in all grids
	if ( bGlobalPlacement )
	{
		AInfo->LocationType = ELT_Global;
		Actors.AddItem( AInfo);
	}
	else if ( iLinks > 1 )
	{
		AInfo->LocationType = ELT_Node;
		while ( iLinks-- > 0 )
			GridElements[iLinks]->Actors.AddItem( AInfo);
	}
	else if ( iLinks == 1 )
	{
		AInfo->LocationType = ELT_Tree;
		if ( !GridElements[0]->Tree )
			GridElements[0]->Tree = new(G_MTH->GrabElement(),E_Stack) MiniTree( this, GridElements[0]->Coords() );
		GridElements[0]->Tree->InsertActorInfo( AInfo, AInfo->GridBox);
	}
	else
	{
		G_AIH->ReleaseElement( AInfo);
		Actor->CollisionTag = 0;
		return false;
	}
	Actor->ColLocation = Actor->Location;
	return true;
	unguard_slow;
}


bool Grid::RemoveActor( class AActor* OutActor)
{
	//Already been removed
	if ( OutActor->CollisionTag == 0 )
		return false;

	//FAILS IN LINUX
//	if ( OutActor->Location != OutActor->ColLocation )
//		debugf( TEXT("[CG] %s moved without proper hashing"), OutActor->GetName() );

	ActorInfo* AInfo = reinterpret_cast<ActorInfo*>(OutActor->CollisionTag);
	if ( G_AIH->IsValid(AInfo) && AInfo->Flags.bCommited )
	{
		G_AIH->ReleaseElement( AInfo); //Fix IsValid (create AIH version for decommit flag)
		OutActor->CollisionTag = 0;

		if ( AInfo->LocationType == ELT_Global )
			Actors.RemoveItem( AInfo);
		else if ( AInfo->LocationType == ELT_Node )
		{
			cg::Box LocalBox = AInfo->GridBox - Box.Min;
			cg::Integers Min = cg::Max((LocalBox.Min * Grid_Mult), cg::Vector(E_Zero)).Truncate32();
			cg::Integers Max = cg::Min((LocalBox.Max * Grid_Mult), cg::Vectorize(Size-XYZi_One) ).Truncate32();
			for ( int i=Min.i ; i<=Max.i ; i++ )
			for ( int j=Min.j ; j<=Max.j ; j++ )
			for ( int k=Min.k ; k<=Max.k ; k++ )
				Node(i,j,k)->Actors.RemoveItem( AInfo);
		}
		else if ( AInfo->LocationType == ELT_Tree )
		{
			cg::Integers GridSlot = cg::Max( (AInfo->GridBox.Min - Box.Min) * Grid_Mult, cg::Vector(E_Zero)).Truncate32(); //Pick lowest coord, then clamp to 0,0,0
			if ( Node(GridSlot)->Tree )
				Node(GridSlot)->Tree->RemoveActorInfo( AInfo, AInfo->GridBox.Min);
		}
		AInfo->LocationType = ELT_Max;
	}
	else
		debugf( TEXT("[CG] Anomaly in RemoveActor: %s"), OutActor->GetName() );
	return true;
}


cg::Box Grid::GetNodeBoundingBox( const cg::Integers& Coords) const
{
	cg::Vector Min = Box.Min + cg::Vectorize(Coords) * Grid_Unit; //(VC2015) If I don't use this, two useless memory access MOVAPS are added
	return cg::Box( Min, Min+Grid_Unit, E_Strict);
}

void Grid::Tick()
{
	guard(Grid::Tick);
	MiniTree** MTR = &TreeList;
	while ( *MTR )
	{
		MiniTree* T = *MTR;
		if ( (T->Timer > 0) && (T->Timer-- == 1) )
			T->CleanupActors();
		MTR = &((*MTR)->Next);
	}
	unguard;
}

//*************************************************
//
// MiniTree
//
//*************************************************


//Construct as GE's main node
MiniTree::MiniTree( Grid* G, const cg::Integers& C)
	:	Bounds( G->GetNodeBoundingBox(C) )
{
	*(cg::Vector*)&Children[0] = cg::Vector(E_Zero); //Vectorized zero set
	*(cg::Vector*)&Children[4] = cg::Vector(E_Zero);
	*(cg::Vector*)&Children[8] = cg::Vector(E_Zero); //Init other stuff as zero as well
	Next = G->TreeList;
	G->TreeList = this;
}

//Construct a subnode, attempt to retrieve actor from parent node
MiniTree::MiniTree( MiniTree* T, uint32 SubOctant)
	:	Bounds( T->GetSubOctantBox(SubOctant) )
{
	UE_DEV_THROW( T->Children[SubOctant] != nullptr, "[CG] Attempting to create MiniTree in already occupied subtree slot");
	T->Children[SubOctant] = this;
	T->ChildCount++;
	*(cg::Vector*)&Children[0] = cg::Vector(E_Zero); //Vectorized zero set
	*(cg::Vector*)&Children[4] = cg::Vector(E_Zero);
	*(cg::Vector*)&Children[8] = cg::Vector(E_Zero); //Init other stuff as zero as well
	Depth = T->Depth + 1;

	for ( int32 i=T->Actors.ArrayNum-1 ; i>=0 ; i-- )
	{
		ActorInfo* AInfo = T->Actors(i);
		if ( G_AIH->IsValid(AInfo) && AInfo->IsValid() )
		{
			UE_DEV_THROW( AInfo->CurDepth == Depth, "AInfo in parent tree has my Depth"); //Destroyed tree must be memzero'd
			if ( (AInfo->TopDepth >= Depth) && (GetSubOctant( AInfo->GridBox.Min) == SubOctant) ) //Belongs here
			{
				AInfo->CurDepth = Depth;
				if ( Depth < MAX_TREE_DEPTH ) //Important to continue subdivision spree
					AInfo->TopDepth = Depth + (GetSubOctant( AInfo->GridBox.Min) == GetSubOctant( AInfo->GridBox.Max));
				Actors.AddItem(AInfo);
				T->Actors.Remove(i);
			}
		}
	}

	if ( Actors.ArrayNum ) //Tell parent we have actors
		T->HasActors |= (1 << SubOctant);
}

MiniTree::~MiniTree()
{}

cg::Box MiniTree::GetSubOctantBox( uint32 Index) const
{
	cg::Integers Bits( Index << 31, (Index & 0b10) << 30, (Index & 0b100) << 29, 0);
	cg::Vector Mid = Bounds.CenterPoint();
	cg::Vector Mod = cg::Vector( _mm_or_ps( Bounds.Max-Mid, Bits)); //Put sign bits
	return cg::Box( Mid, Mid+Mod);
}


/** Return codes:
	X+ Y+ Z+: 0
	X- Y+ Z+: 1
	X+ Y- Z+: 2
	X- Y- Z+: 3
	X+ Y+ Z-: 4
	X- Y+ Z-: 5
	X+ Y- Z-: 6
	X- Y- Z-: 7
*/
uint32 MiniTree::GetSubOctant( const cg::Vector& Point) const
{
	cg::Vector Mid = Bounds.CenterPoint();
	return (Point - Mid).SignBits() & 0b0111;
}


void MiniTree::InsertActorInfo( ActorInfo* AInfo, const cg::Box& Box)
{
	uint32 Oc1;
	uint32 Oc2;
	if ( Depth == MAX_TREE_DEPTH )
		AInfo->TopDepth = Depth;
	else
	{
		Oc1 = GetSubOctant( Box.Min);
		Oc2 = GetSubOctant( Box.Max);
		AInfo->TopDepth = Depth + (Oc1 == Oc2);
	}

	//Add here, timer not needed
	if ( (AInfo->TopDepth == Depth) || (Actors.ArrayNum < REQUIRED_FOR_SUBDIVISION) )
	{
		AInfo->CurDepth = Depth;
		Actors.AddItem( AInfo);
	}
	//Add in sub box
	else
	{
		if ( Children[Oc1] == nullptr )
			new( G_MTH->GrabElement(), E_Stack) MiniTree( this, Oc1);
		Children[Oc1]->InsertActorInfo( AInfo, Box);
		HasActors |= (uint8)(1 << Oc1);
	}
}

//NOT RECURSIVE, location is absolute, AInfo has already been unlinked
//AInfo has already been validated
void MiniTree::RemoveActorInfo( ActorInfo* AInfo, const cg::Vector& Location)
{
	MiniTree* DepthLink[MAX_TREE_DEPTH+2];
	uint32 OctIdx[MAX_TREE_DEPTH+2];
	DepthLink[0] = this;
	OctIdx[0] = 0;
	int32 CurDepth = 0;
	while ( CurDepth < AInfo->CurDepth )
	{
		uint32 OcIdx = DepthLink[CurDepth]->GetSubOctant( Location);
		DepthLink[CurDepth+1] = DepthLink[CurDepth]->Children[OcIdx];
		OctIdx[CurDepth+1] = OcIdx;
		CurDepth++;
		if ( !DepthLink[CurDepth] ) //In case of error, cleanup immediately
		{
			Timer = 1;
			debugf( TEXT("[CG] Error in RemoveActorInfo: Link at CurDepth=%i/%i [OCT=%i] is non-existant for %s"), CurDepth, AInfo->CurDepth, OcIdx, AInfo->Actor->GetName() );
			return;
		}
	}
	//Optimization
	if ( DepthLink[CurDepth]->Actors.RemoveItem( AInfo) )
	{
		for ( ; CurDepth >= 0 && !DepthLink[CurDepth]->ShouldQuery() ; CurDepth-- )
			DepthLink[CurDepth]->HasActors &= ~(1 << OctIdx[CurDepth]);
	}
	else
		debugf( TEXT("[CG] Failed to remove Actor %s from tree at Depth=%i"), AInfo->Actor->GetName(), CurDepth);
	if ( Timer == 0 )
		Timer = 20;
}

void MiniTree::CleanupActors() //Queries already perform-cleanup operations, just check flags and count
{
	guard(MiniTree::CleanupActors);
/*	for ( int32 i=Actors.ArrayNum-1 ; i>=0 ; i-- )
		if ( !Actors(i)->IsValid() )
		{
			debugf( TEXT("Removing invalid actor %i"), i);
			G_AIH->ReleaseElement(Actors(i));
			Actors.Remove(i);
		}*/

	if ( ChildCount )
	{
		for ( uint32 i=0 ; i<8 ; i++ )
			if ( Children[i] )
			{
				Children[i]->CleanupActors();
				if ( !Children[i]->ShouldQuery() && !Children[i]->ChildCount )
				{
					G_MTH->ReleaseElement( Children[i]);
					Children[i] = nullptr;
					ChildCount--;
					HasActors &= ~(1 << i); 
				}
			}
	}
	else
		HasActors = 0;
	unguard;
}
