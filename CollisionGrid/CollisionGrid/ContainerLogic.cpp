

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

	C.Location = cg::Vector( &Actor->Location.X);
	if ( C.Location.InvalidBits() & 0x0111 ) //Validate location
	{
		debugf( TEXT("[CG] Invalid actor location: %s [%f,%f,%f]"), Actor->GetName(), C.Location.X, C.Location.Y, C.Location.Z );
		cg::Vector NewLoc( &Actor->ColLocation.X);
		if ( NewLoc.InvalidBits() & 0x0111 ) //EXPERIMENTAL, RELOCATE ACTOR
			return false;
		C.Location = NewLoc;
		Actor->Location = FVector( NewLoc);
		debugf( TEXT("[CG] Relocating to [%f,%f,%f]"), Actor->Location.X, Actor->Location.Y, Actor->Location.Z);
	}
	C.Location.W = 0;

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
	return true;
}

bool ActorInfo::IsValid()
{
#define ABORT(text) { debugf_ansi(text); return false; }
	if ( !Flags.bCommited ) //Can happen in grid elements
		return false;
	if ( (*GetIndexedObject)(ObjIndex) != Actor )
		ABORT("[CG] ActorInfo::IsValid -> Using invalid object");
	if ( Actor->bDeleteMe || !Actor->bCollideActors )
	{
		debugf( TEXT("[CG] ActorInfo::IsValid -> %s shouldn't be in the grid"), Actor->GetName() );
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

uint32 ActorLink::UnlinkInvalid( ActorLink** Container)
{
	guard(ActorLink::UnlinkInvalid);
	uint32 ActorCount = 0;
	ActorLink** ALR = Container;
	while ( *ALR )
	{
		UE_DEV_THROW( !G_ALH->IsValid(*ALR), "ActorLink::UnlinkInvalid -> reached invalid container");
		ActorInfo* AInfo = (*ALR)->Info;
		if ( AInfo->IsValid() )
		{
			ActorCount++;
			ALR = &((*ALR)->Next);
		}
		else
		{
			UE_DEV_LOG_ANSI( "[CG] ActorLink::UnlinkInvalid decommited an invalid actor");
			G_AIH->ReleaseElement( AInfo);
			ActorLink* Next = (*ALR)->Next;
			UE_DEV_THROW( Next && !G_ALH->IsValid(Next), "ActorLink::UnlinkInvalid -> Next is invalid");
			G_ALH->ReleaseElement( *ALR );
			*ALR = Next;
		}
	}
	return ActorCount;
	unguard;
}

//*************************************************
//
// ActorLinkContainer
//
//*************************************************

void ActorLinkContainer::Add( ActorInfo* AInfo)
{
	ActorLink* NewLink = G_ALH->GrabElement();
	NewLink->Info = AInfo;
	NewLink->Next = ActorList;
	ActorList = NewLink;
	ActorCount++;
}

bool ActorLinkContainer::Remove( ActorInfo* AInfo)
{
	guard(ActorLinkContainer::Remove);
	for ( ActorLink** LinkScan = &ActorList ; *LinkScan ; LinkScan = &(*LinkScan)->Next )
		if ( G_ALH->IsValid(*LinkScan) && ((*LinkScan)->Info == AInfo) )
		{
			G_ALH->ReleaseElement(*LinkScan);
			*LinkScan = (*LinkScan)->Next;
			ActorCount--;
			return true;
		}
	return false;
	unguard;
}

void ActorLinkContainer::MoveAll(ActorLinkContainer& Destination) //Should only move less than 3 actor links
{
	Destination.ActorCount += ActorCount;
	ActorCount = 0;
	while ( ActorList )
	{
		ActorLink* Next = ActorList->Next;
		ActorList->Next = Destination.ActorList;
		Destination.ActorList = ActorList;
		ActorList = Next;
	}
}

uint32 ActorLinkContainer::DebugCount()
{
	uint32 i = 0;
	for ( ActorLink* ALink=ActorList ; ALink ; ALink=ALink->Next )
		i++;
	return i;
}


//*************************************************
//
// Grid
//
//*************************************************

void Grid::Init()
{
	//Zero these 16 bytes using one MOVAPS instruction
	*(cg::Vector*)&Actors = cg::Vector(E_Zero);
	for (int32 i = 0; i<Size.i ; i++)
	for (int32 j = 0; j<Size.j ; j++)
	for (int32 k = 0; k<Size.k ; k++)
		Node(i,j,k)->Init( i, j, k);
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
		debugf( TEXT("[CG] Grid allocated %s"), Result->Size.String() );
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

void GridElement::Init( uint8 i, uint8 j, uint8 k) //Move to CPP
{
//	X = i;
//	Y = j;
//	Z = k;
	Actors = ActorLinkContainer();
	Tree = nullptr;
	CollisionTag = 0;
}

cg::Integers GridElement::CalcCoords(Grid* FromGrid)
{
	uint32 k = ((uint32)this - (uint32) FromGrid->Nodes) / sizeof(struct GridElement);
	uint32 mult = FromGrid->Size.j * FromGrid->Size.k;
	uint32 i = k / mult;
	k -= i * mult;
	mult = FromGrid->Size.k;
	uint32 j = k / mult;
	k -= j * mult;
	UE_DEV_THROW( FromGrid->Node(i,j,k) != this, "Error in coordinate calculation");
	return cg::Integers(i,j,k,0);
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
			debugf( TEXT("[CG] Anomaly in InsertActor: CollisionTag not zero for %s"), Actor->GetName() );
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
		Actors.Add( AInfo);
	}
	else if ( iLinks > 1 )
	{
		AInfo->LocationType = ELT_Node;
		while ( iLinks-- > 0 )
			GridElements[iLinks]->Actors.Add( AInfo);
	}
	else if ( iLinks == 1 )
	{
		AInfo->LocationType = ELT_Tree;
		if ( !GridElements[0]->Tree )
			GridElements[0]->Tree = new(G_MTH) MiniTree( this, GridElements[0]->CalcCoords(this) );
		GridElements[0]->Tree->InsertActorInfo( AInfo, ActorBox);
	}
	else
	{
		G_AIH->ReleaseElement( AInfo);
		Actor->CollisionTag = 0;
		return false;
	}
	Actor->ColLocation = Actor->Location;
	return true;
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

		cg::Box ActorBox = AInfo->cBox();

		if ( AInfo->LocationType == ELT_Global )
			Actors.Remove( AInfo);
		else if ( AInfo->LocationType == ELT_Node )
		{
			cg::Box LocalBox = ActorBox - Box.Min;
			cg::Integers Min = cg::Max((LocalBox.Min * Grid_Mult), cg::Vector(E_Zero)).Truncate32();
			cg::Integers Max = cg::Min((LocalBox.Max * Grid_Mult), cg::Vectorize(Size-XYZi_One) ).Truncate32();
			for ( int i=Min.i ; i<=Max.i ; i++ )
			for ( int j=Min.j ; j<=Max.j ; j++ )
			for ( int k=Min.k ; k<=Max.k ; k++ )
				Node(i,j,k)->Actors.Remove( AInfo);
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
	MiniTree** MTR = &TreeList;
	while ( *MTR )
	{
		MiniTree* T = *MTR;
		if ( (T->Timer > 0) && (T->Timer-- == 1) )
			T->CleanupActors();
		MTR = &((*MTR)->Next);
	}

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

	ActorLink** ALR = &T->Actors.ActorList;
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
			AL->Next = Actors.ActorList;
			Actors.ActorList = AL;
			Actors.ActorCount++;
			T->Actors.ActorCount--;
		}
		else
			ALR = &(*ALR)->Next; //No removal, advance pointer
	}

	if ( Actors.ActorCount ) //Tell parent we have actors
		T->HasActors |= (1 << SubOctant);
}


cg::Box MiniTree::GetSubOctantBox( uint32 Index) const
{
	cg::Integers Bits( Index << 31, (Index & 0b10) << 30, (Index & 0b100) << 29, 0);
	cg::Vector Mid = Bounds.CenterPoint();
	cg::Vector Mod = cg::Vector( _mm_or_ps( (Bounds.Max - Mid).mm(), *(__m128*)&Bits)); //Put sign bits
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
	uint32 Oc1 = GetSubOctant( Box.Min);
	uint32 Oc2 = GetSubOctant( Box.Max);
	AInfo->TopDepth = Min( Depth + (Oc1 == Oc2), MAX_TREE_DEPTH);

	//Add here, timer not needed
	if ( (AInfo->TopDepth == Depth) || (Actors.ActorCount < REQUIRED_FOR_SUBDIVISION) )
	{
		AInfo->CurDepth = Depth;
		Actors.Add( AInfo);
		UE_DEV_THROW( Actors.DebugCount() != Actors.ActorCount, "MiniTree::InsertActorInfo actor count mismatch");
	}
	//Add in sub box
	else
	{
		UE_DEV_THROW( Oc1 != Oc2, "MiniTree::InsertActorInfo attempting to subdivide using mismatching suboctants");
		if ( Children[Oc1] == nullptr )
			new(G_MTH) MiniTree( this, Oc1);
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
		if ( !DepthLink[CurDepth] ) //In case of error, cleanup immediately // DEPRECATE LATER
		{
			Timer = 1;
			debugf( TEXT("[CG] Error in RemoveActorInfo: Link at CurDepth=%i [OCT=%i] is non-existant for %s"), CurDepth, OcIdx, AInfo->Actor->GetName() );
			return;
		}
	}
	//Optimization
	if ( DepthLink[CurDepth]->Actors.Remove( AInfo) )
	{
		for ( ; CurDepth >= 0 && !DepthLink[CurDepth]->ShouldQuery() ; CurDepth-- )
			DepthLink[CurDepth]->HasActors &= ~(1 << OctIdx[CurDepth]);
	}
	if ( Timer == 0 )
		Timer = 20;
}

void MiniTree::CleanupActors() //Queries already perform-cleanup operations, just check flags and count
{
	if ( ChildCount )
	{
		for ( uint32 i=0 ; i<8 ; i++ )
			if ( Children[i] )
			{
				Children[i]->CleanupActors();
				if ( !Children[i]->ShouldQuery() )
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
}
