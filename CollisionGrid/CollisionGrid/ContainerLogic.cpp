

#include "GridTypes.h"
#include "API.h"
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
	static_assert( sizeof(ActorInfo) == 48, "Size of ActorInfo struct is not 48, check alignment/packing settings!");

	ObjIndex = InActor->Index;
	Actor = InActor;

	C.Location = cg::Vector( (float*)&Actor->Location);
	C.Location.W = 0;
	if ( !C.Location.IsValid() ) //Validate location
	{
		debugf( *(PlainText(TEXT("[CG] Invalid actor location: "))+Actor) );
		return false;
	}

	if ( InActor->Brush )
	{
		P.pBox = (cg::Box) InActor->Brush->GetCollisionBoundingBox( InActor);
		Flags.bUseCylinder = 0;
		Flags.bIsMovingBrush = InActor->IsMovingBrush() != 0;
	}
	else
	{
		C.Extent.X = C.Extent.Y = InActor->CollisionRadius;
		C.Extent.Z = InActor->CollisionHeight;
		C.Extent.W = 0;
		Flags.bUseCylinder = 1;
		Flags.bIsMovingBrush = 0;
	}
	Actor->CollisionTag = reinterpret_cast<uint32>(this);
	Flags.bCommited = 1;
//	debugf( *(PlainText( TEXT("[CG] Inserting actor "))+Actor));
	return true;
}

bool ActorInfo::IsValid()
{
#define ABORT(text) { debugf_ansi(text); return false; }
	if ( !Flags.bCommited )
		ABORT("[CG] ActorInfo::IsValid -> Using invalid memory");
	if ( (*GetIndexedObject)(ObjIndex) != Actor )
		ABORT("[CG] ActorInfo::IsValid -> Using invalid object");
	if ( Actor->bDeleteMe || !Actor->bCollideActors )
	{
		debugf( *(PlainText( TEXT("[CG] ActorInfo::IsValid -> Actor ")) + Actor + TEXT(" shouldn't be in the grid")));
		return false;
	}
	if ( reinterpret_cast<ActorInfo*>(Actor->CollisionTag) != this )
		ABORT("[CG] ActorInfo::IsValid -> Mismatching CollisionTag");
	return true;
}

//Calculate a box for Cylinder actors
cg::Box ActorInfo::cBox()
{
	cg::Box Result; //Using a result var produces correctly optimized output in MinGW
	if ( Flags.bUseCylinder )
		Result = cg::Box( C.Location-C.Extent, C.Location+C.Extent, E_Strict);
	else
		Result = P.pBox;
	return Result;
}

cg::Vector ActorInfo::cLocation()
{
	if ( Flags.bUseCylinder )
		return C.Location;
	else
		return (P.pBox.Min + P.pBox.Max) * 0.5;
}



//*************************************************
//
// ActorLink
//
//*************************************************

//Container is checked
void ActorLink::Decommit( ActorLink*& AL)
{
	G_AIH->ReleaseElement( AL->Info );
	ActorLink* Next = AL->Next; //TEST FIX
	G_ALH->ReleaseElement( AL);
	AL = Next;
}

bool ActorLink::Unlink( ActorLink** Container, ActorInfo* AInfo)
{
	ActorLink** ALR = Container;
	while ( *ALR )
	{
		UE_DEV_THROW( !G_ALH->IsValid(*ALR), "ActorLink::Unlink reached invalid container");
		if ( (*ALR)->Info == AInfo )
		{
			ActorLink* Next = (*ALR)->Next; //TEST FIX
			UE_DEV_THROW( Next && !G_ALH->IsValid(Next), "ActorLink::Unlink next is invalid");
			G_ALH->ReleaseElement( *ALR );
			*ALR = Next;
			return true;
		}
		ALR = &((*ALR)->Next);
	}
	return false;
}

uint32 ActorLink::UnlinkInvalid( ActorLink** Container)
{
	uint32 ActorCount = 0;
	ActorLink** ALR = Container;
	while ( *ALR )
	{
		ActorInfo* AInfo = (*ALR)->Info;
		if ( AInfo->IsValid() )
		{
			ActorCount++;
			ALR = &((*ALR)->Next);
		}
		else
		{
			UE_DEV_LOG_ANSI( "[CG] ActorLink::UnlinkInvalid decommited an invalid actor");
			Decommit( *ALR);
		}
	}
	return ActorCount;
}


//*************************************************
//
// Grid
//
//*************************************************

void Grid::Init()
{
	//Zero these 16 bytes using one MOVAPS instruction
	*(cg::Vector*)&GlobalActors = cg::Vector(E_Zero);
	for (int32 i = 0; i<Size.i ; i++)
	for (int32 j = 0; j<Size.j ; j++)
	for (int32 k = 0; k<Size.k ; k++)
		Node(i,j,k)->Init( i, j, k, 1);
}


Grid* Grid::AllocateFor(ULevel* Level)
{
	UModel* Model = Level->Model;
	Grid* Result = nullptr;
	//This is an additive map and has no bounds
	if ( Model->RootOutside )
		Result = AllocateFull();
	else
	{
		//Get dimensions from map
		cg::Box GridBox( &Model->Points(0), Model->Points.ArrayNum);
		cg::Integers GridSize = ((GridBox.Max - GridBox.Min) * Grid_Mult + cg::Vector(0.99f,0.99f,0.99f)).Truncate32();
		UE_DEV_THROW( GridSize.i > 128 || GridSize.j > 128 || GridSize.k > 128, "New grid exceeds 128^3 dimensions");

		//Allocate optimal grid
		Result = (Grid*)appMallocAligned(sizeof(Grid) + sizeof(GridElement) * GridSize.i * GridSize.j * GridSize.k, 16);
		Result->Box = GridBox;
		Result->Size = GridSize;
		Result->Size.l = 0;
		Result->Init();
		debugf( *(PlainText(TEXT("[CG] Grid allocated "))+Result->Size) );
	}
	return Result;
}

Grid* Grid::AllocateFull()
{
	Grid* NewGrid = (Grid*)appMallocAligned(sizeof(Grid) + sizeof(GridElement) * 128 * 128 * 128, 16);
	NewGrid->Size = cg::Integers( 128, 128, 128, 0);
	NewGrid->Box = cg::Box( cg::Vector(-32768,-32768,-32768,0), cg::Vector(32768,32768,32768,0), E_Strict);
	NewGrid->Init();

	debugf_ansi("[CG] Grid allocated [FULL]");
	return NewGrid;
}

void GridElement::Init( uint8 i, uint8 j, uint8 k, uint8 bValid) //Move to CPP
{
	X = i;
	Y = j;
	Z = k;
	IsValid = bValid;
	BigActors = nullptr;
	Tree = nullptr;
	CollisionTag = 0;
}

//Shut down the main grid
void Grid::Exit()
{

}

GridElement* Grid::Node( uint32 i, uint32 j, uint32 k)
{
	return &Nodes[ i*Size.j*Size.k + j*Size.k + k];
}

GridElement* Grid::Node( const cg::Integers& I)
{
	return Node( I.i, I.j, I.k);
}


bool Grid::InsertActor( AActor* Actor)
{
	UE_DEV_THROW( !Actor, "Grid::InsertActor with NULL parameter");
	if ( !Actor->bCollideActors || Actor->bDeleteMe ) //Validate actor flags
		return false;

	if ( Actor->CollisionTag != 0 )
	{
		//Attempt removal first, what to do upon failure?
		if ( !RemoveActor(Actor) )
		{
			debugf( *(PlainText(TEXT("[CG] Anomaly in InsertActor: CollisionTag not zero for "))+Actor) );
			return false;
		}
	}
	ActorInfo* AInfo = G_AIH->GrabElement( Actor);
	if ( !AInfo )
		return false;

	//Classify whether to add as boundary actor or inner actor
	//It may even be possible that an actor actually doesn't fit here!!
	cg::Box ActorBox = AInfo->cBox();

	GridElement* GridElements[MAX_NODE_LINKS];
	int32 iLinks = 0;
	bool bGlobalPlacement = false;

	cg::Box RRActorBox = (ActorBox-Box.Min) * Grid_Mult; //Transform to local coords
	cg::Integers Min = cg::Max(RRActorBox.Min, cg::Vector(E_Zero)).Truncate32();
	cg::Integers Max = cg::Min(RRActorBox.Max, cg::Vectorize( Size - XYZi_One) ).Truncate32();
			
	//Calculate how big the node list will be before doing any listing
	cg::Integers Total = XYZi_One + Max - Min;
	if ( Total.i <= 0 || Total.j <= 0 || Total.k <= 0 )
	{} //Force a no-placement
	else if ( Total.i*Total.j*Total.k >= MAX_NODE_LINKS )
		bGlobalPlacement = true;
	else
	{
		for ( int i=Min.i ; i<=Max.i ; i++ )
		for ( int j=Min.j ; j<=Max.j ; j++ )
		for ( int k=Min.k ; k<=Max.k ; k++ )
			GridElements[iLinks++] = Node(i,j,k);
	}

	//Placement is uniform, this is required to keep the same ActorInfo in all grids
	if ( bGlobalPlacement )
	{
		AInfo->LocationType = ELT_Global;
		G_ALH->GrabElement( GlobalActors, AInfo);
	}
	else if ( iLinks > 1 )
	{
		AInfo->LocationType = ELT_Node;
		while ( iLinks-- > 0 )
			G_ALH->GrabElement( GridElements[iLinks]->BigActors, AInfo);
	}
	else if ( iLinks == 1 )
	{
		AInfo->LocationType = ELT_Tree;
		if ( !GridElements[0]->Tree )
		{
			cg::Integers Coords( GridElements[0]->X, GridElements[0]->Y, GridElements[0]->Z, 0);
			GridElements[0]->Tree = new(G_MTH) MiniTree( this, Coords);
		}
		GridElements[0]->Tree->InsertActorInfo( AInfo, ActorBox);
	}
	else
	{
		G_AIH->ReleaseElement( AInfo);
		Actor->CollisionTag = 0;
		return false;
	}
	return true;
}


bool Grid::RemoveActor( class AActor* OutActor)
{
	//Already been removed
	if ( OutActor->CollisionTag == 0 )
		return false;

	ActorInfo* AInfo = reinterpret_cast<ActorInfo*>(OutActor->CollisionTag);
	if ( G_AIH->IsValid(AInfo) && AInfo->Flags.bCommited )
	{
		G_AIH->ReleaseElement( AInfo); //Fix IsValid (create AIH version for decommit flag)
		OutActor->CollisionTag = 0;

		cg::Box ActorBox = AInfo->cBox();

		if ( AInfo->LocationType == ELT_Global )
			ActorLink::Unlink( &GlobalActors, AInfo);
		else if ( AInfo->LocationType == ELT_Node )
		{
			cg::Box LocalBox = ActorBox - Box.Min;
			cg::Integers Min = cg::Max((LocalBox.Min * Grid_Mult), cg::Vector(E_Zero)).Truncate32();
			cg::Integers Max = cg::Min((LocalBox.Max * Grid_Mult), cg::Vectorize(Size-XYZi_One) ).Truncate32();
			for ( int i=Min.i ; i<=Max.i ; i++ )
			for ( int j=Min.j ; j<=Max.j ; j++ )
			for ( int k=Min.k ; k<=Max.k ; k++ )
				ActorLink::Unlink( &Node(i,j,k)->BigActors, AInfo);
		}
		else if ( AInfo->LocationType == ELT_Tree )
		{
			cg::Integers GridSlot = cg::Max( (ActorBox.Min - Box.Min) * Grid_Mult, cg::Vector(E_Zero)).Truncate32(); //Pick lowest coord, then clamp to 0,0,0
			if ( Node(GridSlot)->Tree )
				Node(GridSlot)->Tree->RemoveActorInfo( AInfo, ActorBox.Min);
		}
		AInfo->LocationType = ELT_Max;
	}
	else
		debugf( *(PlainText(TEXT("[CG] Anomaly in RemoveActor: "))+OutActor) );
	return true;
}


cg::Box Grid::GetNodeBoundingBox( const cg::Integers& Coords) const
{
	cg::Vector Min = Box.Min + cg::Vectorize(Coords) * Grid_Unit; //(VC2015) If I don't use this, two useless memory access MOVAPS are added
	return cg::Box( Min, Min+Grid_Unit, E_Strict);
}

void Grid::Tick()
{
	MiniTree** MTR = &TreeList;
	while ( *MTR )
	{
		MiniTree* T = *MTR;
		if ( (T->Timer > 0) && (T->Timer-- == 1) )
		{
			T->CleanupActors();
			T->CalcOptimalBounds();
		}
		MTR = &((*MTR)->Next);
	}

	int32 Weight = (Size.i+Size.j+Size.k)/2;
	uint32 Top = Size.i*Size.j*Size.k;
	while ( Weight-- > 0 )
	{
		if ( CurNodeCleanup < Top )
		{
			if ( Nodes[CurNodeCleanup].BigActors )
			{
				Weight -= ActorLink::UnlinkInvalid( &Nodes[CurNodeCleanup].BigActors);
				Weight--;
			}
			CurNodeCleanup++;
		}
		else
		{
			CurNodeCleanup = 0;
			ActorLink::UnlinkInvalid( &GlobalActors);
			Weight = 0;
		}
	}
	
}

//*************************************************
//
// MiniTree
//
//*************************************************


//Construct as GE's main node
MiniTree::MiniTree( Grid* G, const cg::Integers& C)
	:	RealBounds( G->GetNodeBoundingBox(C) )
	,	OptimalBounds( E_Zero)
	,	Depth(0)
	,	Timer(0)
	,	ChildCount(0)
	,	ChildIdx(0)
	,	ActorCount(0)
	,	Actors(nullptr)
{
	*(cg::Vector*)&Children[0] = cg::Vector(E_Zero); //Vectorized zero set
	*(cg::Vector*)&Children[4] = cg::Vector(E_Zero);
	Next = G->TreeList;
	G->TreeList = this;
}

//Construct a subnode, attempt to retrieve actor from parent node
MiniTree::MiniTree( MiniTree* T, uint32 SubOctant)
	:	RealBounds( T->GetSubOctantBox(SubOctant) )
	,	Depth( T->Depth+1)
	,	Timer(0)
	,	ChildCount(0)
	,	ChildIdx(SubOctant)
	,	ActorCount(0)
	,	Actors(nullptr)
{
	UE_DEV_THROW( T->Children[SubOctant] != nullptr, "[CG] Attempting to create MiniTree in already occupied subtree slot");
	T->Children[SubOctant] = this;
	T->ChildCount++;
	*(cg::Vector*)&Children[0] = cg::Vector(E_Zero); //Vectorized zero set
	*(cg::Vector*)&Children[4] = cg::Vector(E_Zero);

	ActorLink** ALR = &T->Actors;
	while ( *ALR )
	{
		UE_DEV_THROW( !G_ALH->IsValid(*ALR), "Invalid actor link in MiniTree constructor");
		ActorInfo* AInfo = (*ALR)->Info;
		UE_DEV_THROW( !G_AIH->IsValid(AInfo), "Invalid actor info in MiniTree constructor");
		if ( (AInfo->TopDepth >= Depth) && (GetSubOctant( AInfo->C.Location) == SubOctant) ) //Belongs here
		{
			cg::Box ActorBox = AInfo->cBox();
			AInfo->CurDepth = Depth;
			if ( Depth < MAX_TREE_DEPTH ) //Important to continue subdivision spree
				AInfo->TopDepth = Depth + (GetSubOctant( ActorBox.Min) == GetSubOctant( ActorBox.Max));
			ActorLink* AL = *ALR; //Remove from this chain, keep pointer
			*ALR = AL->Next;
			AL->Next = Actors;
			Actors = AL;
			ActorCount++;
		}
		else
			ALR = &(ALR[0]->Next); //No removal, advance pointer
	}
	CalcOptimalBounds(); //Parent tree doesn't need bounds update, no actors being removed
}


cg::Box MiniTree::GetSubOctantBox( uint32 Index) const
{
	cg::Integers Bits( Index << 31, (Index & 0b10) << 30, (Index & 0b100) << 29, 0);
	cg::Vector Mid = RealBounds.CenterPoint();
	cg::Vector Mod = cg::Vector( _mm_or_ps( (RealBounds.Max - Mid).mm(), *(__m128*)&Bits)); //Put sign bits
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
	cg::Vector Mid = RealBounds.CenterPoint();
	return (Point - Mid).SignBits() & 0b0111;
}


void MiniTree::InsertActorInfo( ActorInfo* AInfo, const cg::Box& Box)
{
	if ( ActorCount == 0 ) //Doesn't matter if it goes in this Node, but expand anyways
		OptimalBounds = Box;
	else
		OptimalBounds.Expand(Box);
	ActorCount++;

	uint32 Oc1 = GetSubOctant( Box.Min);
	uint32 Oc2 = GetSubOctant( Box.Max);
	AInfo->TopDepth = Min( Depth + (Oc1 == Oc2), MAX_TREE_DEPTH);
	UE_DEV_THROW( AInfo->TopDepth > MAX_TREE_DEPTH, "IAF: Bad TopDepth");

	//Add here, timer not needed
	if ( (AInfo->TopDepth == Depth) || (ActorCount < REQUIRED_FOR_SUBDIVISION) )
	{
		AInfo->CurDepth = Depth;
		G_ALH->GrabElement( Actors, AInfo);
	}
	//Add in sub box
	else
	{
		UE_DEV_THROW( Oc1 != Oc2, "MiniTree::InsertActorInfo attempting to subdivide using mismatching suboctants");
		if ( Children[Oc1] == nullptr )
			new(G_MTH) MiniTree( this, Oc1);
		Children[Oc1]->InsertActorInfo( AInfo, Box);
	}
	UE_DEV_THROW( CountActors() != ActorCount, "MiniTree::InsertActorInfo actor count mismatch");
}

//NOT RECURSIVE, location is absolute, AInfo has already been unlinked
//AInfo has already been validated
void MiniTree::RemoveActorInfo( ActorInfo* AInfo, const cg::Vector& Location)
{
	UE_DEV_THROW( Depth != 0, "[CG] RemoveActorInfo should only be called on top tree (Depth=0)");
	UE_DEV_THROW( AInfo->TopDepth > MAX_TREE_DEPTH, "RAF: Bad TopDepth");
	MiniTree* DepthLink[MAX_TREE_DEPTH+2];
	DepthLink[0] = this;
	int32 CurDepth = 0;
	while ( CurDepth < AInfo->CurDepth )
	{
		UE_DEV_THROW( CurDepth != DepthLink[CurDepth]->Depth, "[CG] RemoveActorInfo: MiniTree depth mismatch");
		UE_DEV_THROW( ActorLink::Unlink( &DepthLink[CurDepth]->Actors, AInfo), "[CG] RemoveActorInfo: unlinked before hitting CurDepth!!");
		uint32 OcIdx = DepthLink[CurDepth]->GetSubOctant( Location);
		DepthLink[CurDepth+1] = DepthLink[CurDepth]->Children[OcIdx];
		CurDepth++;
		if ( !DepthLink[CurDepth] ) //In case of error, cleanup immediately
		{
			Timer = 1;
			PlainText Error( TEXT("[CG] Error in RemoveActorInfo: Link at CurDepth="));
			debugf( *(Error + CurDepth + TEXT("[OCT=")+ OcIdx +TEXT("] is non-existant, Actor is ") + AInfo->Actor) );
			return;
		}
	}
	if ( ActorLink::Unlink( &DepthLink[CurDepth]->Actors, AInfo) )
	{
		while ( CurDepth >= 0 )
			DepthLink[CurDepth--]->ActorCount--;
	}
	UE_DEV_THROW( CountActors() != ActorCount, "MiniTree::RemoveActorInfo actor count mismatch");
	if ( Timer == 0 )
		Timer = 20;
}

void MiniTree::CalcOptimalBounds()
{
	if ( !ActorCount )
		OptimalBounds = cg::Box( E_Zero);
	else
	{
		if ( Actors )
		{
			OptimalBounds = Actors->Info->cBox(); //Take first box
			for ( ActorLink* Link=Actors->Next ; Link ; Link=Link->Next ) //Add others
				OptimalBounds.Expand( Link->Info->cBox() ); //Fast
		}
		if ( ChildCount )
		{
			for ( uint32 i=0 ; i<8 ; i++ )
				if ( Children[i] )
				{
					Children[i]->CalcOptimalBounds();
					OptimalBounds.Expand( Children[i]->OptimalBounds, E_NoZero); //Slow
				}
		}
	}

}

void MiniTree::CleanupActors()
{
	uint32 NewActorCount = ActorLink::UnlinkInvalid( &Actors);
	if ( ChildCount )
	{
		for ( uint32 i=0 ; i<8 ; i++ )
			if ( Children[i] )
			{
				Children[i]->CleanupActors();
				NewActorCount += Children[i]->ActorCount;
				if ( !Children[i]->ActorCount )
				{
					G_MTH->ReleaseElement( Children[i]);
					Children[i] = nullptr;
					ChildCount--;
				}
			}
	}
	ActorCount = NewActorCount;
}

uint32 MiniTree::CountActors()
{
	uint32 Count = 0;
	if ( ChildCount )
		for ( uint32 i=0 ; i<8 ; i++ )
			if ( Children[i] )
				Count += Children[i]->CountActors();
	for ( ActorLink* Link=Actors ; Link ; Link=Link->Next )
		Count++;
	return Count;
}

