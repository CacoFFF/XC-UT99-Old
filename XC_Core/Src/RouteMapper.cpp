/*=============================================================================
	RouteMapper.cpp
	Author: Fernando Velázquez

	UT's NavigationPoint route mapping, originally implemented in FerBotz
=============================================================================*/

#include "XC_Core.h"
#include "Engine.h"
#include "UnXC_Script.h"

#define MAX_WEIGHT          10000000
#define PATH_LISTED         0x01
#define PATH_VISITABLE      0x02
#define PATH_UNUSABLE       0x04
#define PATH_VISIT_CHECKED  (PATH_VISITABLE | PATH_UNUSABLE)


static INT ExtraCost( ANavigationPoint* N, APawn* Seeker);
static UBOOL CanVisit( ANavigationPoint* N, APawn* Seeker);
static void GetAnchors( TArray<ANavigationPoint*>& Anchors, APawn* Seeker);


struct MapRoutesEventParams
{
	APawn* Seeker;
	TArray<ANavigationPoint*> StartAnchors;

	MapRoutesEventParams()
		: Seeker(NULL) {}
};


//**************************** MapRoutes - start *******************************
//
// Main route mapping function.
//
// Locates anchors if not provided.
// Calls 'RouteMapperEvent' if provided
//
// Returns nearest bEndPoint=True path found (if any).
//
ANavigationPoint* UXC_CoreStatics::MapRoutes( APawn* Reference, TArray<ANavigationPoint*>& StartAnchors, FName RouteMapperEvent)
{
	guard(UXC_CoreStatics::MapRoutes);
	check(Reference);

	if ( !Reference->Level->NavigationPointList || !Reference->GetLevel()->ReachSpecs.Num() )
		return NULL;

	if ( !StartAnchors.Num() )
	{
		GetAnchors( StartAnchors, Reference);
		if ( !StartAnchors.Num() )
			return NULL;
	}

	// Memory stack setup
	FMemMark Mark(GMem);
	INT i;
	INT BufferSize = 0;

	// Reset network
	for ( ANavigationPoint* N=Reference->Level->NavigationPointList ; N ; N=N->nextNavigationPoint )
	{
		N->cost = ExtraCost( N, Reference); //BRANCH!
		N->startPath = NULL;
		N->prevOrdered = NULL;
		N->bestPathWeight = 0; //Path bitmasks here
		N->bEndPoint = 0;
		BufferSize++;
	}
	for ( i=0 ; i<StartAnchors.Num() ; i++ )
		StartAnchors(i)->startPath = StartAnchors(i);

	// Call event after resetting the network, give coder opportunity to alter the behaviour of the mapper.
	if ( RouteMapperEvent != NAME_None )
	{
		UFunction* func = FindFunction(RouteMapperEvent);
		if ( func && !func->GetReturnProperty() && (func->NumParms <= 2) )
		{
			TArray<UProperty*> Parameters = GetScriptParameters( func);
			MapRoutesEventParams EventParams;
			INT Ok = 1;
			if ( Ok && Parameters.Num() >= 1 )
			{
				EventParams.Seeker = Reference;
				Ok = Parameters(0)->IsA(UObjectProperty::StaticClass())
					&& ((UObjectProperty*)Parameters(0))->PropertyClass == APawn::StaticClass();
				if ( !Ok )
					debugf( NAME_Warning, TEXT("MapRoutes Event %s >> Wrong parameter 1, needs to be 'Pawn'"), func->GetName());
			}
			if ( Ok && Parameters.Num() >= 2 )
			{
				EventParams.StartAnchors = StartAnchors;
				Ok = Parameters(1)->IsA(UArrayProperty::StaticClass())
					&& ((UArrayProperty*)Parameters(1))->Inner->IsA(UObjectProperty::StaticClass())
					&& ((UObjectProperty*)(((UArrayProperty*)Parameters(1))->Inner))->PropertyClass == ANavigationPoint::StaticClass();
				if ( !Ok )
					debugf( NAME_Warning, TEXT("MapRoutes Event %s >> Wrong parameter 2, needs to be 'array<NavigationPoint>'"), func->GetName());
			}

			if ( Ok )
				ProcessEvent( func, &EventParams);
		}
	}

	// Setup list of operational nodes, it will hold all to-be-checked nodes.
	ANavigationPoint** NList = new(GMem, BufferSize+1) ANavigationPoint*;
	for ( i=0 ; i<StartAnchors.Num() ; i++ )
	{
		if ( StartAnchors(i)->cost < MAX_WEIGHT ) //This anchor is eligible
		{
			NList[i] = StartAnchors(i);
			NList[i]->bestPathWeight = PATH_LISTED | PATH_VISITABLE;
			if ( NList[i]->visitedWeight == MAX_WEIGHT )
				NList[i]->visitedWeight = 0;
		}
		else
			StartAnchors(i)->bestPathWeight = PATH_UNUSABLE;
	}

	// Setup loop environment
	INT Remaining = i;
	const INT W = appFloor( Reference->CollisionRadius);
	const INT H = appFloor( Reference->CollisionHeight);
	const INT M = Reference->calcMoveFlags();
	FReachSpec* RS = &Reference->GetLevel()->ReachSpecs(0);
	INT MaxWeight = MAX_WEIGHT;
	ANavigationPoint* NearestEndPoint = NULL;

	// Process node list by order of 'visitedWeight'
	// When a node is removed from this list, it'll not be checked again.
	// When processing in said order, we can be 99.9% sure that there's no need to
	// re-add a node that's been left out.
	while( Remaining > 0 )
	{
		//Grab node with lowest 'visitedWeight'
		INT lowest = 0;
		for ( i=1 ; i<Remaining ; i++ )
			if ( NList[i]->visitedWeight < NList[lowest]->visitedWeight )
				lowest = i;
		ANavigationPoint* Start = NList[lowest]; //Start always has OtherTag=SearchTag
		if ( Start->visitedWeight >= MaxWeight ) //Going past this point is unnecessary
			break;
		NList[lowest] = NList[--Remaining];

		INT rIdx;
		for ( i=0 ; (i<16) && ((rIdx=Start->Paths[i]) >= 0) ; i++ )
		{
			check( rIdx < Reference->GetLevel()->ReachSpecs.Num() );
			ANavigationPoint* End = Cast<ANavigationPoint>( RS[rIdx].End );
			if ( !End )
				continue;

			if ( (End->bestPathWeight & PATH_VISIT_CHECKED) == 0 )
			{
				if ( !CanVisit( End, Reference) || (End->cost >= MaxWeight) )
					End->bestPathWeight |= PATH_UNUSABLE; //Not visitable
				else
				{
					End->bestPathWeight |= PATH_VISITABLE; //Visitable
					End->visitedWeight = MAX_WEIGHT;
				}
			}

			if ( (End->bestPathWeight & PATH_VISITABLE) && RS[rIdx].supports(W,H,M) )
			{
				INT Weight = Max( 1, RS[rIdx].distance + End->cost) + Start->visitedWeight;
				if ( (Weight < MaxWeight) && (Weight < End->visitedWeight) && (End != Start) )
				{
					End->visitedWeight = Weight; //Expand/update route
					End->prevOrdered = Start;
					End->startPath = Start->startPath;
					if ( (End->bestPathWeight & PATH_LISTED) == 0 )
					{
						End->bestPathWeight |= PATH_LISTED;
						NList[Remaining++] = End;
					}
					if ( End->bEndPoint )
					{
						MaxWeight = End->visitedWeight;
						NearestEndPoint = End;
					}
				}
			}
		}
	}

	Mark.Pop();
	return NearestEndPoint;
	unguard;
}
//**************************** MapRoutes - end *********************************



//**************************** ExtraCost - start *******************************
//
// Encapsulate the setting of NavigationPoint's cost here
//
static INT ExtraCost( ANavigationPoint* N, APawn* Seeker)
{
	if ( N->bSpecialCost )
		return N->eventSpecialCost( Seeker);
	return N->ExtraCost;
}
//**************************** ExtraCost - end *********************************


//**************************** CanVisit - start *******************************
//
static UBOOL CanVisit( ANavigationPoint* N, APawn* Seeker)
{
	if ( !Seeker->bIsPlayer && N->bPlayerOnly )
		return 0; // Only players and bots can use this

	if ( !Seeker->bCanSwim && N->Region.Zone->bWaterZone )
		return 0; // Creature can't swim

	if ( Seeker->bCanSwim && !Seeker->bCanWalk && !Seeker->bCanFly && !N->Region.Zone->bWaterZone )
		return 0; // Creature can't leave water

	return 1;
}
//**************************** CanVisit - end *********************************


//**************************** FAnchorLink class - start *******************************
//
// Sortable linked element, precalculates Squares of 3d and 2d distances
//
struct FAnchorLink
{
	FAnchorLink* Next;
	ANavigationPoint* Owner;
	float DistSq;
	float Dist2DSq;

	FAnchorLink() {}

	void Setup( ANavigationPoint* InOwner, APawn* Seeker)
	{
		Owner = InOwner;
		FVector Delta = Owner->Location - Seeker->Location;
		Dist2DSq = Square(Delta.X) + Square(Delta.Y);
		DistSq = Dist2DSq + Square(Delta.Z);
	}

	void AttachSorted( FAnchorLink** List)
	{
		checkSlow(List);
		//Find where to attach to
		while ( true )
		{
			if ( (*List == NULL) || ((*List)->DistSq >= DistSq) )
				break;
			List = &(*List)->Next;
		}
		Next = *List;
		*List = this;
	}
};
//**************************** FAnchorLink class - end *********************************


//**************************** GetAnchors - start *******************************
//
// Locate possible initial NavigationPoint's of a route.
//
static void GetAnchors( TArray<ANavigationPoint*>& Anchors, APawn* Seeker)
{
	guard(GetAnchors);
	FMemMark Mark(GMem);
	FAnchorLink* SortedList = NULL;
	FAnchorLink* Current = new(GMem) FAnchorLink;

	// Scan for nodes we can use as Start Anchors, do quick rejects
	for ( ANavigationPoint* N=Seeker->Level->NavigationPointList ; N ; N=N->nextNavigationPoint )
	{
		if ( (N->Region.ZoneNumber == 0) || !CanVisit( N, Seeker) )
			continue; // Path is not eligible for use

		Current->Setup( N, Seeker);
		if ( Current->DistSq > 2000 * 2000 )
			continue; // Too far

		Current->AttachSorted( &SortedList);
		Current = new(GMem) FAnchorLink;
	}

	// Nothing to be had
	if ( !SortedList )
	{
		Mark.Pop();
		return;
	}

	UModel* Primitive = Seeker->GetLevel()->Model;

	// Attempt to find 'walk' anchors first, prioritize by H distance
	if ( Seeker->Physics == PHYS_Walking )
	{
		const float HDistSq = Square(Seeker->CollisionRadius);
		float ZBounds[2];
		ZBounds[0] = -Seeker->CollisionHeight;
		ZBounds[1] = Max( 120.f - Seeker->CollisionHeight, Seeker->CollisionHeight);

		//Go through the list and remove those we add as anchors
		FAnchorLink** Ptr = &SortedList;
		while ( *Ptr )
		{
			if ( (*Ptr)->Dist2DSq <= HDistSq )
			{
				ANavigationPoint* Path = (*Ptr)->Owner;
				float RelativeZ = Path->Location.Z - Seeker->Location.Z;
				if ( (RelativeZ >= ZBounds[0]) && (RelativeZ <= ZBounds[1])
					&& Primitive->FastLineCheck( Seeker->Location, Path->Location) ) //Visible
				{
					Anchors.AddItem( Path);
					Path->visitedWeight = appRound( appSqrt((*Ptr)->Dist2DSq));
					*Ptr = (*Ptr)->Next;
					continue;
				}
			}
			Ptr = &(*Ptr)->Next;
		}
	}

	// Proceed to select up to 6 anchors
	INT WeightAdd = appRound( Seeker->CollisionRadius);
	INT ExtraSearches = 6; //Helps prevent too much resource usage
	for ( Current=SortedList ; Current && Anchors.Num()<6 ; Current=Current->Next )
	{
		UBOOL bAdd = 0;
		ANavigationPoint* Path = Current->Owner;
		if ( Seeker->bCanFly || Seeker->Physics == PHYS_Flying || Seeker->Physics == PHYS_None ) //Visible is good enough
			bAdd = Primitive->FastLineCheck( Seeker->Location, Path->Location);
		else
		{
			bAdd = Seeker->pointReachable( Path->Location);
			if ( !bAdd && Seeker->Physics == PHYS_Walking && (Seeker->CollisionHeight < 60) && (ExtraSearches-- > 0) ) //Try a second time with lower location
			{
				FVector ReachPosition = Path->Location + (Seeker->Location - Path->Location).UnsafeNormal() * FVector(Seeker->CollisionRadius,Seeker->CollisionRadius,0);
				ReachPosition.Z -= 30; //Not ideal, need to do box checks
				bAdd = Seeker->pointReachable( ReachPosition);
			}
		}

		if ( bAdd )
		{
			ExtraSearches--;
			Anchors.AddItem( Path);
			Path->visitedWeight = appRound( appSqrt(Current->DistSq) * 1.5) + WeightAdd;
		}
	}
	Mark.Pop();
	unguard;
}
//**************************** GetAnchors - end *********************************
