/*=============================================================================
	PathBuilder.cpp
	Author: Fernando Velázquez

	Unreal Editor addon for path network generation.

	The goal is to be able to build paths with as little flaws or technical
	limitations as possible.
	In order to achieve this, it'll be necessary to evaluate the same nodes
	multiple times, which means saving and loading states on demand.

	First, we must process paths by proximity, it is necessary that paths that
	are the nearest to each other are processed first so that pruning isn't
	needed.

	In order to prevent constant relocations we'll need to build a relation
	list where nodes are paired, sorted by distance.
=============================================================================*/

#include "XC_Core.h"
#include "Engine.h"
#include "XC_CoreGlobals.h"
#include "API_FunctionLoader.h"

#include "FPathBuilderMaster.h"

#define MAX_DISTANCE 1000
#define MAX_WEIGHT 10000000

enum EReachSpecFlags
{
	R_WALK = 1,	//walking required
	R_FLY = 2,   //flying required 
	R_SWIM = 4,  //swimming required
	R_JUMP = 8,   // jumping required
	R_DOOR = 16,
	R_SPECIAL = 32,
	R_PLAYERONLY = 64
};

#define MAX_SCOUT_HEIGHT 200
#define MAX_SCOUT_RADIUS 150


static int JumpTo( APawn* Scout, AActor* Other);

//============== Partial actor list compactor
//
static void CompactActors( TTransArray<AActor*>& Actors, int32 StartFrom)
{
	Actors.ModifyAllItems();
	FTransactionBase* Undo = GUndo;
	GUndo = nullptr;

	int32 i=StartFrom;
	for ( int32 j=StartFrom ; j<Actors.Num() ; j++ )
	{
		GWarn->StatusUpdatef( j-StartFrom, Actors.Num()-StartFrom, TEXT("Compacting actor list (%i > %i)"), j, i);
		if ( (i != j) && Actors(j) )
			Actors(i++) = Actors(j);
	}
	GWarn->StatusUpdatef( 1, 1, TEXT("Removed %i entries (%i > %i)"), Actors.Num()-i, Actors.Num(), i);
	if( i != Actors.Num() )
		Actors.Remove( i, Actors.Num()-i );

	GUndo = Undo;
	Actors.ModifyAllItems();
}

//============== In Cylinder
//
static int InCylinder( const FVector& V, float R, float H)
{
	return Square(V.X) + Square(V.Y) <= Square(R)
	    && Square(V.Z)               <= Square(H);
}

//============== Actors are touching
//
static int ActorsTouching( AActor* Check, AActor* Other)
{
	float NetRadius = Check->CollisionRadius;
	float NetHeight = Check->CollisionHeight;
	if ( Other->bCollideActors )
	{
		NetRadius += Other->CollisionRadius;
		NetHeight += Other->CollisionHeight;
	}
	FVector Diff = Check->Location - Other->Location;
	return InCylinder( Diff, NetRadius, NetHeight);
}

//============== Discard route mapper data
//
static void RouteCleanup( ANavigationPoint* N)
{
	N->nextOrdered         = nullptr;
	N->prevOrdered         = nullptr;
	N->startPath           = nullptr;
	N->previousPath        = nullptr;
	N->OtherTag            = 0;
	N->visitedWeight       = 0;
	N->bestPathWeight      = 0;
}

//============== Cleanup a NavigationPoint
//
static void Cleanup( ANavigationPoint* N)
{
	N->nextNavigationPoint = nullptr;
	RouteCleanup( N);
	for ( int32 i=0; i<16; i++)
	{
		N->Paths[i]           = -1;
		N->upstreamPaths[i]   = -1;
		N->PrunedPaths[i]     = -1;
		N->VisNoReachPaths[i] = nullptr;
	}
}


//============== Counts amount of paths in array
//
static int CountPaths( int32* PathArray)
{
	int i;
	for ( i=0 ; i<16 && PathArray[i]>=0 ; i++ );
	return i;
}

//============== Gets a free slot in a Paths array (Paths, PrunedPaths, upstreamPaths)
//
static int FreePath( int32* PathArray)
{
	for ( int i=0 ; i<16 ; i++ )
		if ( PathArray[i] < 0 )
			return i;
	return INDEX_NONE;
}


//============== Distance sorted Navigation point query list
//
struct FQueryResult
{
	ANavigationPoint* Owner;
	float DistSq;
	FQueryResult* Next;

	FQueryResult( FQueryResult** Chain, ANavigationPoint* InOwner, float InDistSq )
		: Owner(InOwner) , DistSq( InDistSq), Next(nullptr)
	{
		while( *Chain && ((*Chain)->DistSq < DistSq) )
			Chain = &(*Chain)->Next;
		Next = *Chain;
		*Chain = this;
	}
};


//============== Sorted linked list element
//
template < class T > struct TUpwardsSortableLinkedRef
{
	T* Ref;
	TUpwardsSortableLinkedRef<T>* Next;

	TUpwardsSortableLinkedRef<T>* SortThis( int (*CompareFunc)(const T&, const T&) )
	{
		TUpwardsSortableLinkedRef<T>* Last = this;
		for ( TUpwardsSortableLinkedRef<T>* CompareTo=Next ; CompareTo ; Last=CompareTo, CompareTo=CompareTo->Next )
			if ( (*CompareFunc)(*this->Ref,*CompareTo->Ref) == 1 ) //Stop here
				break;

		if ( Last != this )
		{
			TUpwardsSortableLinkedRef<T>* Result = Next;
			Next = Last->Next;
			Last->Next = this;
			return Result;
		}
		return this;
	}
};


class FPathBuilderInfo
{
	struct Candidate
	{
		ANavigationPoint* Path;
		float DistSq;
	};
public:
	ANavigationPoint* Owner;
	TArray<Candidate> Candidates;

	//[+]=A stays, [-]=A goes forward in link
	static int Compare( const FPathBuilderInfo& A, const FPathBuilderInfo& B)
	{
		if ( !B.Candidates.Num() )                             return  1; //Whether A has candidates or not is irrelevant
		if ( !A.Candidates.Num() )                             return -1;
		if ( A.Candidates(0).DistSq > B.Candidates(0).DistSq ) return -1;
		return 1;
	}
};
static int32 InfoListRaw[3] = {0,0,0};
static TArray<FPathBuilderInfo>& InfoList = *(TArray<FPathBuilderInfo>*)InfoListRaw;
static void RegisterInfo( ANavigationPoint* N);
typedef TUpwardsSortableLinkedRef<FPathBuilderInfo> TPathInfoLink;



//============== Engine.dll manual imports
//


FString PathsRebuild( ULevel* Level, APawn* ScoutReference, UBOOL bBuildAir)
{
	FPathBuilderMaster Builder;
	if ( ScoutReference )
	{
		Builder.GoodRadius      = ScoutReference->CollisionRadius;
		Builder.GoodHeight      = ScoutReference->CollisionHeight;
		Builder.GoodJumpZ       = ScoutReference->JumpZ;
		Builder.GoodGroundSpeed = ScoutReference->GroundSpeed;
	}
	Builder.Level = Level;
	Builder.Aerial = bBuildAir;
	Builder.RebuildPaths();
	return Builder.BuildResult;
}

//============== FPathBuilderMaster main funcs
//
inline FPathBuilderMaster::FPathBuilderMaster()
{
	appMemzero( this, sizeof(*this));
}


inline void FPathBuilderMaster::RebuildPaths()
{
	guard(FPathBuilderMaster::RebuildPaths)
	GWarn->BeginSlowTask( TEXT("Paths Rebuild [XC]"), true, false);
	Setup();
	GetScout();
	UndefinePaths();
	DefinePaths();
	if ( InfoList.Num() > 0 )
		InfoList.Empty();
	if ( Scout )
		Level->DestroyActor( Scout);
	GWarn->EndSlowTask();
	unguard
}



//============== FPathBuilderMaster internals
//============== Build steps
//
void FPathBuilderMaster::Setup()
{
	guard(FPathBuilderMaster::Setup)
	if ( GoodDistance < 200 )	GoodDistance = 1000;
	if ( GoodHeight <= 5 )		GoodHeight = 39;
	if ( GoodRadius <= 5 )		GoodRadius = 17;
	if ( GoodJumpZ <= 5 )       GoodJumpZ = 325;
	if ( GoodGroundSpeed <= 5 ) GoodGroundSpeed = 400;
	if ( !InventorySpotClass )		InventorySpotClass  = FindObjectChecked<UClass>( ANY_PACKAGE, TEXT("InventorySpot") );
	if ( !WarpZoneMarkerClass )		WarpZoneMarkerClass = FindObjectChecked<UClass>( ANY_PACKAGE, TEXT("WarpZoneMarker") );
	if ( InfoList.Num() > 0 )	InfoList.Empty();

	TotalCandidates = 0;
	unguard
}


static TArray<int> FreeReachSpecs;
//============== Individual node definitor, useful for runtime definitions
//
void FPathBuilderMaster::AutoDefine( ANavigationPoint* NewPoint, AActor* AdjustTo)
{
	// Setup environment
	SafeEmpty( FreeReachSpecs);
	Level = NewPoint->GetLevel();
	if ( !Scout ) //Create scout on demand
		GetScout();
	if ( AdjustTo )
		AdjustToActor( NewPoint, AdjustTo);


	// Find unused reachspecs
	for ( int i=0 ; i<Level->ReachSpecs.Num() ; i++ )
		if ( !Level->ReachSpecs(i).Start && !Level->ReachSpecs(i).End )
			FreeReachSpecs.AddItem( i);

	// Create sorted list of navigation points
	FMemMark Mark(GMem);
	FQueryResult* Results = nullptr;
	float MaxDistSq = Square(GoodDistance);
	for ( ANavigationPoint* N=NewPoint->Level->NavigationPointList ; N ; N=N->nextNavigationPoint )
		if ( N != NewPoint )
		{
			float DistSq = (N->Location - NewPoint->Location).SizeSquared();
			if ( (DistSq <= MaxDistSq) && Level->Model->FastLineCheck(NewPoint->Location, N->Location) )
				new(GMem) FQueryResult( &Results, N, DistSq);
		}

	// Create links while reserving reachspecs
	for ( ; Results && NewPoint->Paths[10] == INDEX_NONE && NewPoint->upstreamPaths[10] == INDEX_NONE ; Results=Results->Next )
		DefineFor( NewPoint, Results->Owner);

	// Cleanup
	Mark.Pop();
	if ( Scout )
		Level->DestroyActor( Scout);
	SafeEmpty( FreeReachSpecs);
}



inline void FPathBuilderMaster::DefinePaths()
{
	debugf( NAME_DevPath, TEXT("Defining paths..."));

	// Setup initial list
	for ( int32 i=0 ; i<Level->Actors.Num() ; i++ )
		if ( Level->Actors(i) && Level->Actors(i)->IsA(ANavigationPoint::StaticClass()) )
			RegisterInfo( (ANavigationPoint*)Level->Actors(i));

	AddMarkers();
	DefineSpecials();
	BuildCandidatesLists();
	ProcessCandidatesLists();

	// Cleanup temporary data
	for ( ANavigationPoint* N=Level->GetLevelInfo()->NavigationPointList ; N ; N=N->nextNavigationPoint )
		RouteCleanup(N);

	BuildResult += FString::Printf( TEXT("Created %i reachSpecs."), Level->ReachSpecs.Num() );
}

inline void FPathBuilderMaster::UndefinePaths()
{
	debugf( NAME_DevPath, TEXT("Undefining paths..."));
	GWarn->StatusUpdatef( 1, 1, TEXT("Undefining paths..."));
	Level->ReachSpecs.Empty();
	Level->GetLevelInfo()->NavigationPointList = nullptr;

	int32 FirstDeleted = Level->Actors.Num();
	for ( int32 i=0; i<Level->Actors.Num(); i++ )
	{
		GWarn->StatusUpdatef( i, Level->Actors.Num(), TEXT("Undefining paths (Actor %i/%i)..."), i, Level->Actors.Num() );
		ANavigationPoint* Actor = Cast<ANavigationPoint>( Level->Actors(i));
		if ( Actor )
		{
			if ( Actor->IsA(AInventorySpot::StaticClass()) && Actor->bHiddenEd )
			{
				FirstDeleted = Min( FirstDeleted, i);
				if ( ((AInventorySpot*)Actor)->markedItem )
					((AInventorySpot*)Actor)->markedItem->myMarker = nullptr;
				Level->DestroyActor(Actor);
			}
			else if ( Actor->IsA(AWarpZoneMarker::StaticClass()) || Actor->IsA(ATriggerMarker::StaticClass()) || Actor->IsA(AButtonMarker::StaticClass()) )
			{
				FirstDeleted = Min( FirstDeleted, i);
				Level->DestroyActor(Actor);
			}
			else
				Cleanup( Actor);
		}
	}
	CompactActors( Level->Actors, FirstDeleted);
	AInventorySpot::StaticClass()->ClassUnique = 0;
}


//============== Creates special markers for items, warp zones
//
inline void FPathBuilderMaster::AddMarkers()
{
	int32 i;
	int32 BaseListSize = InfoList.Num();

	GWarn->StatusUpdatef( 0, 1, TEXT("Inserting markers...") );
	// Add InventorySpots
	for ( i=0 ; i<Level->Actors.Num() ; i++ )
	{
		AInventory* Actor = Cast<AInventory>( Level->Actors(i));
		if ( Actor )
			HandleInventory( Actor);
	}

	// Add WarpZoneMarkers
	for ( i=0 ; i<Level->Actors.Num() ; i++ )
	{
		AWarpZoneInfo* Actor = Cast<AWarpZoneInfo>( Level->Actors(i));
		if ( Actor )
			HandleWarpZone( Actor);
	}
	// TODO: Add custom markers

	BuildResult += FString::Printf( TEXT("Processed %i NavigationPoints (%i markers).\r\n"), InfoList.Num(), InfoList.Num()-BaseListSize);
}

//============== Special Reachspecs code
//
inline void FPathBuilderMaster::DefineSpecials()
{
	guard(FPathBuilderMaster::DefineSpecials)
	debugf( NAME_DevPath, TEXT("Defining special paths..."));
	FReachSpec SpecialSpec;
	SpecialSpec.distance = 500;
	SpecialSpec.CollisionRadius = 60;
	SpecialSpec.CollisionHeight = 60;
	SpecialSpec.reachFlags = R_SPECIAL;
	SpecialSpec.bPruned = 0;

	for ( int32 i=0 ; i<InfoList.Num() ; i++ )
	{
		//Tag->Event first
		if ( InfoList(i).Owner->Event != NAME_None )
		{
			for ( int32 j=0 ; j<InfoList.Num() ; j++ )
				if ( InfoList(j).Owner->Tag == InfoList(i).Owner->Event )
				{
					SpecialSpec.Start = InfoList(i).Owner;
					SpecialSpec.End = InfoList(j).Owner;
					AttachReachSpec( SpecialSpec);
				}
		}

		if ( InfoList(i).Owner->IsA(ALiftCenter::StaticClass()) )
		{
			ALiftCenter* LC = (ALiftCenter*)InfoList(i).Owner;
			for ( int32 j=0 ; j<InfoList.Num() ; j++ )
			{
				if ( InfoList(j).Owner->IsA(ALiftExit::StaticClass())
					&& (LC->LiftTag == ((ALiftExit*)InfoList(j).Owner)->LiftTag) )
				{
					SpecialSpec.Start = LC;
					SpecialSpec.End = InfoList(j).Owner;
					AttachReachSpec( SpecialSpec);
					Exchange( SpecialSpec.Start, SpecialSpec.End);
					AttachReachSpec( SpecialSpec);
				}
			}
		}
		else if ( InfoList(i).Owner->IsA(ATeleporter::StaticClass()) )
		{
			ATeleporter* Teleporter = (ATeleporter*)InfoList(i).Owner;
			for ( int32 j=0 ; j<InfoList.Num() ; j++ )
			{
				if ( (InfoList(j).Owner->IsA(ATeleporter::StaticClass()))
					&& ((ATeleporter*)InfoList(j).Owner)->URL == *Teleporter->Tag )
				{
					SpecialSpec.Start = InfoList(j).Owner;
					SpecialSpec.End = Teleporter;
					SpecialSpec.distance = 100;
					AttachReachSpec( SpecialSpec);
					SpecialSpec.distance = 500;
				}
			}
		}
		else if ( InfoList(i).Owner->IsA(AWarpZoneMarker::StaticClass()) )
		{
			AWarpZoneMarker* Warp = (AWarpZoneMarker*)InfoList(i).Owner;
			for ( int32 j=0 ; j<InfoList.Num() ; j++ )
			{
				if ( (InfoList(j).Owner->IsA(AWarpZoneMarker::StaticClass()))
					&& ((AWarpZoneMarker*)InfoList(j).Owner)->markedWarpZone->OtherSideURL == *Warp->markedWarpZone->ThisTag )
				{
					SpecialSpec.Start = InfoList(j).Owner;
					SpecialSpec.End = Warp;
					AttachReachSpec( SpecialSpec);
				}
			}
		}
		//TODO: Custom event (?)

	}
	unguard
}



//============== Candidates are possible connections
//
// Instead of connecting right away, candidates will be selected and sorted by distance
//
inline void FPathBuilderMaster::BuildCandidatesLists()
{
	debugf( NAME_DevPath, TEXT("Building candidates lists..."));
	float MaxDistSq = GoodDistance * GoodDistance * 2 * 2;

	uint32 MaxPossiblePairs = InfoList.Num() * InfoList.Num() / 2;

	for ( int32 i=0 ; i<InfoList.Num() ; i++ )
	{
		if ( InfoList(i).Owner->IsA( ALiftCenter::StaticClass()) ) 
			continue; //No LiftCenter

		for ( int32 j=i+1 ; j<InfoList.Num() ; j++ )
		{
			if ( InfoList(j).Owner->IsA( ALiftCenter::StaticClass()) ) 
				continue; //No LiftCenter

			float DistSq = (InfoList(i).Owner->Location - InfoList(j).Owner->Location).SizeSquared();
			if ( DistSq > MaxDistSq ) 
				continue; //Too far

			if ( !Level->Model->FastLineCheck( InfoList(i).Owner->Location, InfoList(j).Owner->Location) ) 
				continue; //Not visible

			uint32 CurrentPair = (InfoList.Num() * 2 - i) * i / 2 + j - i;
			GWarn->StatusUpdatef( CurrentPair, MaxPossiblePairs, TEXT("Building candidates lists (%i/%i)"), CurrentPair, MaxPossiblePairs);
				
			int32 k = 0;
			while ( (k < InfoList(i).Candidates.Num()) && (InfoList(i).Candidates(k).DistSq < DistSq) )
				k++;
			InfoList(i).Candidates.Insert( k);
			InfoList(i).Candidates(k).Path = InfoList(j).Owner;
			InfoList(i).Candidates(k).DistSq = DistSq;
			TotalCandidates++;
		}
	}
}

//============== Connect candidates to each other
//
// Connection must pass reachability checks
// Actors on full path lists
//
inline void FPathBuilderMaster::ProcessCandidatesLists()
{
	guard(FPathBuilderMaster::ProcessCandidatesLists)
	debugf( NAME_DevPath, TEXT("Processing candidates lists..."));
	FMemMark Mark(GMem);

	// Build initial sorted list
	int32 i;
	TPathInfoLink* InfoData = new(GMem,MEM_Zeroed,InfoList.Num()) TPathInfoLink();
	TPathInfoLink* InfoLink = nullptr;
	for ( i=0 ; i<InfoList.Num() ; i++ )
		if ( InfoList(i).Candidates.Num() > 0 )
		{
			GWarn->StatusUpdatef( i, InfoList.Num(), TEXT("Sorting candidates lists (%i)"), i);
			InfoData[i].Ref = &InfoList(i);
			InfoData[i].Next = InfoLink;
			InfoLink = InfoData[i].SortThis( &FPathBuilderInfo::Compare );
		}

	// Process and re-sort list until done
	i = 0;
	while ( InfoLink )
	{
		i++;
		GWarn->StatusUpdatef( i, TotalCandidates, TEXT("Processing candidates  (%i/%i)"), i, TotalCandidates);
		DefineFor( InfoLink->Ref->Owner, InfoLink->Ref->Candidates(0).Path);
		InfoLink->Ref->Candidates.Remove(0);
		if ( !InfoLink->Ref->Candidates.Num() )
			InfoLink = InfoLink->Next;
		else
			InfoLink = InfoLink->SortThis( &FPathBuilderInfo::Compare );
	}

	Mark.Pop();
	unguard
}
/*
static int ConnectedIdx( ANavigationPoint* Start, ANavigationPoint* End)
{
	for ( int i=0 ; (i<16) && (Start->Paths[i]>=0) ; i++ )
	{
		FReachSpec& Spec = Start->GetLevel()->ReachSpecs(Start->Paths[i]);
		if ( Spec.Start == Start && Spec.End == End )
			return i;
	}
	return INDEX_NONE;
}
*/

//============== Connect two candidates with physics checks
//
// Both nodes are visible to each other
//
inline void FPathBuilderMaster::DefineFor( ANavigationPoint* A, ANavigationPoint* B)
{
	guard(FPathBuilderMaster::DefineFor)
	int32 i, k;
	float Distance;
	FVector X;
	FMemMark Mark(GMem);

	//The higher the value, the more likely to be pruned
	//Formula is 32 + Str + Dist * (1.1+Str/100)
	float PruneStrength = (float)(CountPaths(A->Paths) + CountPaths(A->upstreamPaths) + CountPaths(B->Paths) + CountPaths(B->upstreamPaths));
	
	//Get normalized direction and distance (A -> B)
	X = (B->Location - A->Location);
	if ( (Distance=X.Size()) < 1 ) //Do not define ridiculously near paths
		return;
	X /= Distance; //Normalize

	//Construct a list of nodes contained within prunable field (check formula)
	float MaxPrunableDistance = (Distance * 1.1 + 32) * (PruneStrength / 100 + 1);
	int32 MiddleCount = 0;
	ANavigationPoint** Paths;

	//Editor
	if ( InfoList.Num() ) 
	{
		Paths = new(GMem,InfoList.Num()) ANavigationPoint*;
		for ( i=0 ; i<InfoList.Num() ; i++ )
		{
			ANavigationPoint* N = InfoList(i).Owner;
			if ( N==A || N==B )
				continue; //Discard origins

			FVector ADelta = N->Location - A->Location; //Dir . ADelta > 0 (req)
			FVector BDelta = N->Location - B->Location; //Dir . BDelta < 0 (req)
			if ( ((ADelta | X) + 16.0) * ((BDelta | X) - 16.0) >= 0 )
				continue; //Fast: Only consider nodes in the band between A and B (parallel planes)

			float ExistingDistance = ADelta.Size() + BDelta.Size();
			if ( ExistingDistance > MaxPrunableDistance )
				continue; //Slow: Only consider nodes in a 3d ellipsis around the points

			Paths[MiddleCount++] = N;
			N->bestPathWeight = 1; //FLAG MIDDLE POINTS!
		}
	}
	//Game (needs sorting, no cached list)
	else
	{
		FQueryResult* Results = nullptr;
		for ( ANavigationPoint* N=A->Level->NavigationPointList ; N ; N=N->nextNavigationPoint )
		{
			N->bestPathWeight = 0;
			if ( N==A || N==B )
				continue; //Discard origins

			FVector ADelta = N->Location - A->Location; //Dir . ADelta > 0 (req)
			FVector BDelta = N->Location - B->Location; //Dir . BDelta < 0 (req)
			if ( ((ADelta | X) + 16.0) * ((BDelta | X) - 16.0) >= 0 )
				continue; //Fast: Only consider nodes in the band between A and B (parallel planes)

			float ExistingDistance = ADelta.Size() + BDelta.Size();
			if ( ExistingDistance > MaxPrunableDistance )
				continue; //Slow: Only consider nodes in a 3d ellipsis around the points

			new(GMem) FQueryResult( &Results, N, ExistingDistance );
			N->bestPathWeight = 1; //FLAG MIDDLE POINTS!
			MiddleCount++;
		}
		Paths = new(GMem,MiddleCount+20) ANavigationPoint*;
		for ( i=0 ; Results ; Results=Results->Next )
			Paths[i++] = Results->Owner;
	}

	//Move middle points to their own list, release general path list
	ANavigationPoint** MiddlePoints = nullptr;
	if ( MiddleCount > 0 )
	{
		MiddlePoints = new(GMem,MiddleCount) ANavigationPoint*;
		appMemcpy( MiddlePoints, Paths, MiddleCount * sizeof(ANavigationPoint*));
	}

	//A=Start, B=End
	for ( int32 RoundTrip=0 ; RoundTrip<2 ; RoundTrip++, Exchange(A,B) )
	{
		// Do not consider one way
		if ( A->bOneWayPath && (((B->Location - A->Location) | A->Rotation.Vector()) <= 0) )
			continue;

		//Evaluate pruning first
		int32 Prune = 0;
		if ( MiddleCount )
		{
			for ( i=0 ; i<MiddleCount ; i++ ) 
				MiddlePoints[i]->visitedWeight = MAX_WEIGHT; //PREPARE MIDDLE POINTS
			A->visitedWeight = B->visitedWeight = 0; //In-game requires this
			#define FINISHED_QUERY 1
			#define PENDING_QUERY 2
			i = k = 0;
			Paths[k++] = A;
			while ( i < k )
			{
				ANavigationPoint* Start = Paths[i++];
				for ( int32 j=0 ; j<16 && Start->Paths[j]>=0 ; j++ )
				{
					const FReachSpec& Spec = Level->ReachSpecs(Start->Paths[j]);
					ANavigationPoint* End = (ANavigationPoint*)Spec.End;
					//CUT HERE!!
					if ( End == B ) //Connection exists!
					{
						i = k;
						Prune = 1;
						break;
					}
					int32 CurWeight = Max( 1, Spec.distance) + Start->visitedWeight;
					if ( End->bestPathWeight && (End->visitedWeight > CurWeight) )
					{
						End->visitedWeight = CurWeight;
						if ( (End->OtherTag == FINISHED_QUERY) && (i > 0)  ) //Already queried during this route
							Paths[--i] = End; //Check ASAP
						else if ( End->OtherTag != PENDING_QUERY ) //Not queried during this route
							Paths[k++] = End; //Check last
						End->OtherTag = PENDING_QUERY;
					}
				}
				Start->OtherTag = FINISHED_QUERY; //FLAG AS QUERIED
			}
			for ( i=0 ; i<MiddleCount ; i++ ) 
			{
				MiddlePoints[i]->OtherTag = 0;
				MiddlePoints[i]->visitedWeight = 0; //RESET MIDDLE POINTS
			}
			A->OtherTag = B->OtherTag = 0;
		}

		if ( !Prune )
		{
			FReachSpec Spec = CreateSpec( A, B);
			if ( Spec.Start && Spec.End )
				AttachReachSpec( Spec);
			else
			{
				for ( i=0 ; i<16 ; i++ )
					if ( !A->VisNoReachPaths[i] )
					{
						A->VisNoReachPaths[i] = B;
						break;
					}
			}
		}
	}

	for ( i=0 ; i<MiddleCount ; i++ )
		MiddlePoints[i]->bestPathWeight = 0; //UNFLAG MIDDLE POINTS!

	Mark.Pop();
	unguard
}

inline FReachSpec FPathBuilderMaster::CreateSpec( ANavigationPoint* Start, ANavigationPoint* End)
{
	FReachSpec Spec;
	Spec.Init();
	Spec.Start = Start;
	Spec.End = End;
	Spec.CollisionRadius = appRound(GoodRadius + 1);
	Spec.CollisionHeight = appRound(GoodHeight + 1);
	Scout->JumpZ = GoodJumpZ;
	Scout->GroundSpeed = GoodGroundSpeed;
	Scout->Physics = PHYS_Walking;
	Scout->bCanWalk = 1;
	Scout->bCanSwim = 1;
	Scout->bCanJump = 1;
	Scout->bCanFly = 0;
	Scout->MaxStepHeight = 25;
	FCollisionHashBase* Hash = Level->Hash;
	Level->Hash = nullptr;

	int Reachable = 0;

	//Fat mode
	FVector Fat = End->Location - Start->Location;
	if ( (Fat.SizeSquared2D() <= Square(129.0)) && Square(Fat.Z) < Square(60) )
	{
		Scout->SetCollisionSize( Fat.Size2D() + 5, GoodHeight + Abs(Fat.Z) * 0.5);
		if ( FindStart(Start->Location + Fat * 0.5) && ActorsTouching(Scout,End) && ActorsTouching(Scout,Start) )
		{
			Spec.CollisionRadius = Max( Spec.CollisionRadius, appRound(Scout->CollisionRadius) + 2);
			Spec.CollisionHeight = Max( Spec.CollisionHeight, appRound(Scout->CollisionHeight) + 2);
			Scout->SetCollisionSize( GoodRadius, GoodHeight);
			int Walkables = FindStart(Start->Location) + FindStart(End->Location);
			if ( Walkables >= 2 )
			{
				Reachable = 1;
				Spec.reachFlags |= R_WALK;
				Spec.distance = appRound(Fat.Size());
			}
//			debugf( NAME_DevNet, L"FAT %f -> %i", Fat.Size2D(), Walkables ); 
		}
	}

	//IMPORTANT: SCOUT NEEDS pointReachable() REPLACEMENT TO ALLOW BETTER JUMPING
	//This also sets reachflags
	if ( !Reachable )
		Reachable = Spec.findBestReachable( Start->Location, End->Location, Scout);

	//Try with MaxStepHeight big enough to simulate PickWallAdjust() jumps
	if ( !Reachable )
	{
		//Free fall
		// v_end^2 = v_start^2 + 2.gravity.h = 0
		// h = -(v_start^2) / (2.gravity)
		Scout->MaxStepHeight = -(GoodJumpZ*GoodJumpZ) / (Start->Region.Zone->ZoneGravity.Z * 2);
		Reachable = Spec.findBestReachable( Start->Location, End->Location, Scout); //Increase step height to that of a jump
		if ( !Reachable ) //Try a FerBotz jump
		{
			Scout->SetCollisionSize( GoodRadius, GoodHeight);
			if ( Scout->GetLevel()->FarMoveActor( Scout, Start->Location) )
			{
				Reachable = JumpTo( Scout, End);
				if ( Reachable )
				{//Manually set flags
					Spec.reachFlags |= R_WALK;
					Spec.distance = appRound((Start->Location - End->Location).Size());
				}
				else
				{
					Reachable = Spec.findBestReachable( Scout->Location, End->Location, Scout);
					Spec.distance += appRound((Scout->Location - Start->Location).Size());
				}
					
			}
		}
		Spec.reachFlags |= Reachable;
	}

	if ( Aerial && !Reachable )
	{
		Scout->MaxStepHeight = 25;
		Scout->bCanFly = 1;
		Scout->Physics = PHYS_Flying;
		Reachable = Spec.findBestReachable( Start->Location, End->Location, Scout);
	}


	if ( Reachable )
	{
		if ( !(Spec.reachFlags & R_SWIM) && (Start->Region.Zone->bWaterZone || End->Region.Zone->bWaterZone) )
		{
			Spec.reachFlags |= R_SWIM;
			Spec.distance *= 2;
		}
	}
	else
		Spec.Init();

	Level->Hash = Hash;
	return Spec;
}

inline int FPathBuilderMaster::AttachReachSpec( const FReachSpec& Spec, int32 bPrune)
{
	ANavigationPoint* Start = (ANavigationPoint*)Spec.Start;
	ANavigationPoint* End   = (ANavigationPoint*)Spec.End;

	int32 SpecIdx;
	if ( FreeReachSpecs.Num() )
	{
		SpecIdx = FreeReachSpecs( FreeReachSpecs.Num()-1);
		FreeReachSpecs.Remove( FreeReachSpecs.Num()-1);
		Level->ReachSpecs(SpecIdx) = Spec;
	}
	else
		SpecIdx = Level->ReachSpecs.AddItem( Spec);

	int32 i = INDEX_NONE;
	if ( bPrune )
	{
		if ( (i=FreePath(Start->PrunedPaths)) >= 0 )
			Start->PrunedPaths[i] = SpecIdx;
	}
	else
	{
		//Upstream required
		int j;
		if ( (i=FreePath(Start->Paths)) >= 0 && (j=FreePath(End->upstreamPaths)) >= 0 )
		{
			Start->Paths[i] = SpecIdx;
			End->upstreamPaths[j] = SpecIdx;
		}
	}

	if ( i == INDEX_NONE )
	{
		Level->ReachSpecs.Remove( SpecIdx);
		return 0;
	}
	return 1;
}

//============== Physics utils
//
static int IsVisible( AActor* From, AActor* To)
{
	if ( To->XLevel->Model->FastLineCheck( To->Location, From->Location) )
		return 1;

	int Result = 0;
	FMemMark Mark(GMem);
	FCheckResult* Hit = From->GetLevel()->MultiLineCheck( GMem, To->Location, From->Location, FVector(0,0,0), 1, To->Level, 0);
	for ( ; Hit && (Hit->Actor != From->Level) ; Hit=Hit->GetNext() )
	{
		if ( Hit->Actor == To )
		{
			Result = 1;
			break;
		}
	}
	Mark.Pop();
	return Result;
}

static int FlyTo( APawn* Scout, AActor* Other, UBOOL bVisible=0)
{
//	debugf( NAME_DevPath, TEXT("FlyTo %s, %i"), Other->GetName(), bVisible);
	ULevel* Level = Scout->GetLevel();
	float NetRadius = Scout->CollisionRadius;
	float NetHeight = Scout->CollisionHeight;
	if ( Other->bCollideActors && !Other->Brush )
	{
		NetRadius += Other->CollisionRadius;
		NetHeight += Other->CollisionHeight;
	}

	FVector StartPos = Scout->Location;
	FVector EndPos = Other->Location;
	if ( bVisible || Other->Brush )
	{
		FVector Dir = (EndPos - StartPos).SafeNormal() * 5;
		for ( int32 vLoops=0 ; vLoops<8 ; vLoops++ )
		{
			if ( Level->Model->FastLineCheck(StartPos, EndPos) )
				break;
			EndPos -= Dir;
		}
	}

	for ( int32 Loops=0 ; Loops<8 ; Loops++ )
	{
		//Up and down 4 times each
		FVector Moved = Scout->Location;
		FVector Offset( 0, 0, Scout->MaxStepHeight * ((Loops&1) ? 1.0 : -1.0 ) );
		Scout->moveSmooth( Offset);
		Scout->moveSmooth( EndPos - Scout->Location);
		FVector Delta = EndPos - Scout->Location;
		//Adjust Scout to Mover
		if ( Other->Brush )
		{
			Moved -= Scout->Location;
			if ( (Moved.SizeSquared() < 5) && IsVisible( Scout, Other) )
			{
				if ( (StartPos.Z < Scout->Location.Z) && !Scout->Region.Zone->bWaterZone )
				{
					FVector GoodLocation = Scout->Location;
					for ( Loops=0 ; Loops<8 && !Scout->Region.Zone->bWaterZone ; Loops++ )
					{
						FCheckResult Hit(1.0);
						Level->MoveActor( Scout, FVector(0,0,-8), Scout->Rotation, Hit, 0, 1);
						if ( (Scout->Location - GoodLocation).SizeSquared() < 4 )
							Loops = 8;
						Hit.Time = 1.0;
						Level->MoveActor( Scout, EndPos - Scout->Location, Scout->Rotation, Hit, 0, 1);
						if ( !IsVisible(Scout,Other) || !Level->Model->FastLineCheck(StartPos, Scout->Location) )
							break;
						GoodLocation = Scout->Location;
					}
					Level->FarMoveActor( Scout, GoodLocation, 0, 1);
				}
				return 1;
			}
		}
		//Adjust Scout to cylinder
		else if ( InCylinder( Delta, NetRadius, NetHeight) )
		{
			if ( (StartPos.Z < Scout->Location.Z) && !Scout->Region.Zone->bWaterZone )
			{
				FVector GoodLocation = Scout->Location;
				for ( Loops=0 ; Loops<8 && !Scout->Region.Zone->bWaterZone ; Loops++ )
				{
					FCheckResult Hit(1.0);
					Level->MoveActor( Scout, FVector(0,0,-8), Scout->Rotation, Hit, 0, 1);
					if ( (Scout->Location - GoodLocation).SizeSquared() < 4 )
						Loops = 8;
					if ( !InCylinder(Scout->Location - Other->Location, NetRadius, NetHeight) || !Level->Model->FastLineCheck(StartPos, Scout->Location) )
						break;
					GoodLocation = Scout->Location;
				}
				Level->FarMoveActor( Scout, GoodLocation, 0, 1);
			}
			return 1;
		}
	}
	return 0;
}

static int BadWater( AZoneInfo* Zone)
{
	return Zone->bWaterZone
	&& (Zone->ZoneFluidFriction > 2
	|| Zone->DamagePerSec > 3
	|| Zone->ZoneTerminalVelocity < 50);
}

static int JumpTo( APawn* Scout, AActor* Other)
{
	float Gravity = Scout->Region.Zone->ZoneGravity.Z;
	if ( Gravity >= -0.1 )
		return 0;

	#define STEP_ALPHA 0.05
	float NetRadius = Scout->CollisionRadius;
	float NetHeight = Scout->CollisionHeight;
	if ( Other->bCollideActors )
	{
		NetRadius += Other->CollisionRadius;
		NetHeight += Other->CollisionHeight;
	}
	FVector Offset = Other->Location - Scout->Location;
	if ( Square(Offset.X) + Square(Offset.Y) < Square(NetRadius) && Square(Offset.Z) < Square(NetHeight) )
		return R_WALK;

	int bTriedJump = 0;
	do
	{
		float JumpZ = bTriedJump ? 0 : Scout->JumpZ; //Try a normal jump first, then fall
		float DeltaY = Other->Location.Z - Scout->Location.Z;
		float disc = JumpZ*JumpZ - 4 * (-DeltaY) * (Gravity * 0.5); //b^2 - 4*c*a
		if ( disc >= 0 ) //Reachable
		{
			disc = appSqrt(disc);

			float DeltaT = (-JumpZ - disc) / Gravity; //b - disc    /  2*a

			FVector HDir = FVector( Other->Location.X - Scout->Location.X,
									Other->Location.Y - Scout->Location.Y,
									0);
			float HDist = HDir.Size2D();
			if ( HDist > 1 )
				HDir /= HDist;
			float HVel = Min( HDist / DeltaT, Scout->GroundSpeed);

			Scout->Velocity.X = HDir.X * HVel;
			Scout->Velocity.X = HDir.Y * HVel;
			Scout->Velocity.Z = JumpZ;
			
			int Reached = 0;
			int Near = 0;
			for ( float f=0 ; f<=DeltaT+STEP_ALPHA ; f+=STEP_ALPHA )
			{
				//Make steps 4x smaller near end
				if ( Near ) 
					f -= STEP_ALPHA * 0.75;
				FVector NextLoc;( Scout->Location + Scout->Velocity);
				NextLoc.X = Scout->Location.X + Scout->Velocity.X * STEP_ALPHA; //MRU
				NextLoc.Y = Scout->Location.Y + Scout->Velocity.Y * STEP_ALPHA; //MRU
				NextLoc.Z = Scout->Location.Z + Scout->Velocity.Z * STEP_ALPHA + Gravity * 0.5 * (STEP_ALPHA * STEP_ALPHA); //MRUA
				FVector OldPos = Scout->Location;
				Scout->flyMove( NextLoc - Scout->Location, Other);
				//Simulate press forward a bit
				Offset = Other->Location - Scout->Location;
				Scout->Velocity.X *= 0.6;
				Scout->Velocity.Y *= 0.6;
				Scout->Velocity.Z += Gravity * STEP_ALPHA;
				Scout->Velocity += HDir * (HVel * 0.2) + FVector( Offset.X, Offset.Y, 0).SafeNormal() * (HVel * 0.2);
				Near += (Offset | HDir) <= Scout->CollisionRadius;
//				if ( HVel < Scout->GroundSpeed )
//					debugf( NAME_DevNet, L"Diff %f=[%f(%f), %f]", f, Offset | HDir, Offset.Size2D(), Offset.Z);
				if ( Square(Offset.X) + Square(Offset.Y) <= Square(NetRadius) && Square(Offset.Z) <= Square(NetHeight) )
				{
//					if ( HVel < Scout->GroundSpeed )
//						debugf( NAME_DevNet, L"SUCCESS MOVEMENT");
					Reached = R_WALK | R_JUMP;
					break;
				}
				if ( (Offset.Z > NetHeight) || (Scout->Location - OldPos).SizeSquared() <= 1 )
					break;
			}
			if ( !Reached )
			{
				if ( BadWater(Scout->Region.Zone) )
					return 0;
//				if ( HVel < Scout->GroundSpeed )
//					debugf( NAME_DevNet, L"TEST REACH");
				Scout->Physics = Scout->Region.Zone->bWaterZone ? PHYS_Swimming : PHYS_Walking;
				Reached = Scout->pointReachable( Other->Location);
				if ( Reached )
					Reached |= R_WALK | R_JUMP | (R_SWIM * Scout->Region.Zone->bWaterZone);
//				if ( HVel < Scout->GroundSpeed && !Reached )
//					debugf( NAME_DevNet, L"FAIL");
			}
			if ( Reached )
				return Reached;
		}
	}
	#undef STEP_ALPHA
	while ( !bTriedJump++ );
	return 0;
}


//============== Data utils
//
static void RegisterInfo( ANavigationPoint* N)
{
	FPathBuilderInfo& Info = InfoList( InfoList.AddZeroed());

	Info.Owner = N;
	N->nextNavigationPoint = N->Level->NavigationPointList;
	N->Level->NavigationPointList = N;
}

static int TraverseTo( APawn* Scout, AActor* To, float MaxDistance, int Visible)
{
//	debugf( NAME_DevPath, TEXT("Traversing to %s (%i)"), To->GetName(), Visible );
	FQueryResult* Results = nullptr;
	MaxDistance = MaxDistance * MaxDistance;

	FMemMark Mark(GMem);
	for ( ANavigationPoint* N=Scout->Level->NavigationPointList ; N ; N=N->nextNavigationPoint )
	{
		float DistSq = (N->Location - To->Location).SizeSquared();
		if ( (DistSq <= MaxDistance) && (!Visible || IsVisible( N, To))  )
		{
			//Do not traverse from warp zones
			if ( !N->Region.Zone->IsA(AWarpZoneInfo::StaticClass()) )
				new(GMem) FQueryResult( &Results, N, DistSq);
		}
	}

	int Found;
	for ( Found=0 ; !Found && Results ; Results=Results->Next ) //Auto-sorted by distance
	{
		if ( To->GetLevel()->FarMoveActor( Scout, Results->Owner->Location) && FlyTo(Scout,To,Visible) )
			Found = 1;
	}
	Mark.Pop();
	return Found;
}


//============== Adds inventory marker
//
inline void FPathBuilderMaster::HandleInventory( AInventory* Inv)
{
	guard(FPathBuilderMaster::HandleInventory)
	if ( Inv->bHiddenEd || Inv->myMarker || Inv->bDeleteMe )
		return;

	//Adjust Scout using player dims
	Scout->SetCollisionSize( GoodRadius, GoodHeight);

	//Attempt to stand at item
	if ( !FindStart(Inv->Location) 
		|| (Abs(Scout->Location.Z - Inv->Location.Z) > Scout->CollisionHeight) 
		|| (Scout->Location-Inv->Location).SizeSquared2D() > Square(Scout->CollisionRadius+Inv->CollisionRadius) )
	{
		//Failed, attempt to move towards item from elsewhere
		if ( !TraverseTo( Scout, Inv, GoodDistance * 0.5, 0) || !TraverseTo( Scout, Inv, GoodDistance * 1.5, 1) )
		{
			//Failed, just place above item
			Level->FarMoveActor(Scout, Inv->Location + FVector(0,0,GoodHeight-Inv->CollisionHeight), 1, 1);
		}
	}

	AActor* Default = InventorySpotClass->GetDefaultActor();
	int bOldCol = Default->bCollideWhenPlacing;
	Default->bCollideWhenPlacing = 0;
	Inv->myMarker = (AInventorySpot*)Level->SpawnActor( InventorySpotClass, NAME_None, NULL, NULL, Scout->Location);
	Default->bCollideWhenPlacing = bOldCol;
	if ( Inv->myMarker )
	{
		Inv->myMarker->markedItem = Inv;
		Inv->myMarker->bAutoBuilt = 1;
		RegisterInfo( Inv->myMarker);
	}
	unguard
}

//============== Adds warp zone marker
//
inline void FPathBuilderMaster::HandleWarpZone( AWarpZoneInfo* Info)
{
	guard(FPathBuilderMaster::HandleWarpZone)
	//Adjust Scout using player dims
	Scout->SetCollisionSize( GoodRadius, GoodHeight);
	if ( !FindStart(Info->Location) || (Scout->Region.Zone != Info) )
	{
		//Failed, attempte to traverse from nearest pathnode
		if ( !TraverseTo( Scout, Info, GoodDistance, 1) )
		{
			//Failed, just place on the warp zone
			Level->FarMoveActor( Scout, Info->Location, 1, 1);
		}
	}

	AWarpZoneMarker *Marker = (AWarpZoneMarker*)Level->SpawnActor( WarpZoneMarkerClass, NAME_None, NULL, NULL, Scout->Location);
	Marker->markedWarpZone = Info;
	Marker->bAutoBuilt = 1;
	RegisterInfo( Marker);
	unguard
}

//============== Adjusts navigation point to touch actor
//
void FPathBuilderMaster::AdjustToActor( ANavigationPoint* N, AActor* Actor)
{
	if ( !N || !Actor )
		return;

//	debugf( NAME_DevPath, TEXT("AdjustToActor %s -> %s"), N->GetName(), Actor->GetName() );
	
	//Adjust Scout using player dims
	int bOldCollideWorld = N->bCollideWorld;
	N->bCollideWorld = 0;
	Scout->SetCollisionSize( GoodRadius, GoodHeight);
	if ( !Actor->Brush && !Actor->bBlockActors && FindStart(Actor->Location) )
		Level->FarMoveActor( N, Scout->Location);
	else if ( TraverseTo( Scout, Actor, GoodDistance * 1.5, 1) || TraverseTo( Scout, Actor, GoodDistance * 0.5, 0) )
		Level->FarMoveActor( N, Scout->Location);
	else
		Level->FarMoveActor( N, Actor->Location);
	N->bCollideWorld = bOldCollideWorld;
}

//============== FPathBuilder forwards
//
inline void FPathBuilderMaster::GetScout()
{
	FPathBuilder::getScout();
	check( Scout );

	Scout->GroundSpeed = GoodGroundSpeed;
	Scout->JumpZ = GoodJumpZ;
	Scout->SetCollisionSize( GoodRadius, GoodHeight);
}

inline int FPathBuilderMaster::FindStart( FVector V)
{
	return FPathBuilder::findScoutStart(V); 
}