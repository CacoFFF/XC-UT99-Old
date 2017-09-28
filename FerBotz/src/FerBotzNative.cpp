/*=============================================================================
	FerBotzNative.cpp
	You are permitted to use and distribute this code
	Higor:
	Just saying, if you make something out of this let me know.
	I'd love to see what comes out of this
	caco_fff@hotmail.com
=============================================================================*/

// Includes.
#include "Ferbotz.h"

/*-----------------------------------------------------------------------------
	The following must be done once per package (.dll).
-----------------------------------------------------------------------------*/

// This is some necessary C++/UnrealScript glue logic.
// If you forget this, you get a VC++ linker errors like:
// SampleClass.obj : error LNK2001: unresolved external symbol "class FName  SAMPLENATIVEPACKAGE_SampleEvent" (?SAMPLENATIVEPACKAGE_SampleEvent@@3VFName@@A)
#define NAMES_ONLY
#define AUTOGENERATE_NAME(name) FERBOTZ_API FName FERBOTZ_##name;
#define AUTOGENERATE_FUNCTION(cls,idx,name) IMPLEMENT_FUNCTION(cls,idx,name)
#include "FerBotzClasses.h"
#undef AUTOGENERATE_FUNCTION
#undef AUTOGENERATE_NAME
#undef NAMES_ONLY
void RegisterNames()
{
	static INT Registered=0;
	if(!Registered++)
	{
		#define NAMES_ONLY
		#define AUTOGENERATE_NAME(name) extern FERBOTZ_API FName FERBOTZ_##name; FERBOTZ_##name=FName(TEXT(#name),FNAME_Intrinsic);
		#define AUTOGENERATE_FUNCTION(cls,idx,name)
		#include "FerBotzClasses.h"
		#undef DECLARE_NAME
		#undef NAMES_ONLY
	}
}


#if _MSC_VER
	#define IMPLEMENT_REDIRECTED_FUNCTION(cls,num,func,othercls) \
		extern "C" DLL_EXPORT Native int##othercls##func = (Native)&cls::func; \
		static BYTE othercls##func##Temp = GRegisterNative( num, int##othercls##func );
#else
	#define IMPLEMENT_REDIRECTED_FUNCTION(cls,num,func,othercls) \
		extern "C" DLL_EXPORT { Native int##othercls##func = (Native)&cls::func; } \
		static BYTE othercls##func##Temp = GRegisterNative( num, int##othercls##func );
#endif

#if _MSC_VER
	#define IMPLEMENT_RENAMED_FUNCTION(cls,num,func,othersymbol) \
		extern "C" DLL_EXPORT Native int##cls##othersymbol = (Native)&cls::func; \
		static BYTE cls##othersymbol##Temp = GRegisterNative( num, int##cls##othersymbol );
#else
	#define IMPLEMENT_RENAMED_FUNCTION(cls,num,func,othersymbol) \
		extern "C" DLL_EXPORT { Native int##cls##othersymbol = (Native)&cls::func; } \
		static BYTE cls##othersymbol##Temp = GRegisterNative( num, int##cls##othersymbol );
#endif

// Package implementation.
IMPLEMENT_PACKAGE(Ferbotz);


/*-----------------------------------------------------------------------------
	ABotz_NavigBase functions
-----------------------------------------------------------------------------*/

//Redirect this function to Botz and DynamicBotzPlayer classes
#define MAX_WEIGHT 10000000
static INT SearchTag = 0;

void ABotz_NavigBase::execMapRoutes( FFrame &Stack, RESULT_DECL)
{
	guard(Botz_execMapRoutes );

	P_GET_NAVIG(StartAnchor);
	P_GET_INT_OPTX(MinWidth,0);
	P_GET_INT_OPTX(MinHeight,0);
	P_GET_INT_OPTX(Modifiers,0);
	P_GET_NAME_OPTX(PostHardResetEvent,NAME_None);
	P_FINISH;

	if ( !StartAnchor )
		return;

	//0: mark for rescan
	if ( ++SearchTag <= 1 )
		SearchTag = 2;

	FReachSpec* RS = (FReachSpec*) GetLevel()->ReachSpecs.GetData();
	//127 means ALL locomotion methods allowed
	INT MoveFlags = IsA(APawn::StaticClass()) ? ((APawn*)this)->calcMoveFlags() : 127;
	MoveFlags &= ~Modifiers;

	INT BufferSize = 0;
	if ( Modifiers & 0x80 ) //soft-reset 
	{
		for ( ANavigationPoint* N=Level->NavigationPointList ; N ; N=N->nextNavigationPoint )
		{
			N->visitedWeight = MAX_WEIGHT;
			N->prevOrdered = NULL;
			N->nextOrdered = NULL;
			BufferSize++;
		}
	}
	else
	{
		for ( ANavigationPoint* N=Level->NavigationPointList ; N ; N=N->nextNavigationPoint )
		{
			N->visitedWeight = MAX_WEIGHT;
			N->nextOrdered = NULL;
			N->prevOrdered = NULL;
			if ( N->bSpecialCost )
				N->cost = N->eventSpecialCost( Cast<APawn>(this));
			else
				N->cost = N->ExtraCost;
			BufferSize++;
		}
		if ( PostHardResetEvent != NAME_None )
		{
			UFunction* func = FindFunction(PostHardResetEvent);
			if ( func && (func->ParmsSize == 0) )
				ProcessEvent( func, NULL);
		}
	}


	if ( BufferSize == 0 )
		BufferSize = GetLevel()->Actors.Num();

	FMemMark Mark(GMem);
	ANavigationPoint** NList = new(GMem, BufferSize+1) ANavigationPoint*;
	INT iN = 0;
	INT iBase = 0;

	StartAnchor->visitedWeight = 0;
	StartAnchor->prevOrdered = NULL;
	NList[iN++] = StartAnchor;


	while( iBase < iN )
	{
		ANavigationPoint* CurStart = NList[iBase++];
		CurStart->OtherTag = 1; //SearchTag is never 0 or 1
		INT rIdx;
		for ( INT i=0 ; (i<16) && ((rIdx=CurStart->Paths[i]) != -1); i++ )
		{
			ANavigationPoint* CurEnd = Cast<ANavigationPoint>( RS[rIdx].End );
			if ( CurEnd && RS[rIdx].supports(MinWidth,MinHeight,MoveFlags) )
			{
				INT CurWeight = RS[rIdx].distance + CurEnd->cost;
				if ( CurWeight < 1 )
					CurWeight = 1;
				CurWeight += CurStart->visitedWeight;
				if ( (CurWeight < MAX_WEIGHT) && (CurEnd->visitedWeight > CurWeight) && (CurEnd != CurStart) )
				{
					CurEnd->visitedWeight = CurWeight; //Expand/update route
					CurEnd->prevOrdered = CurStart;
					if ( (CurEnd->OtherTag == 1) && (iBase > 0)  ) //Already queried during this route
						NList[--iBase] = CurEnd; //Check ASAP
					else if ( CurEnd->OtherTag != SearchTag ) //Not queried during this route
						NList[iN++] = CurEnd; //Check last
					CurEnd->OtherTag = SearchTag;
				}
			}
		}
	}

/*	while( iN > 0 )
	{
		ANavigationPoint* CurStart = NList[--iN];
		CurStart->OtherTag = 0; //SearchTag is never zero
		INT rIdx;
		for ( INT i=0 ; (i<16) && ((rIdx=CurStart->Paths[i]) != -1); i++ )
		{
			ANavigationPoint* CurEnd = Cast<ANavigationPoint>( RS[rIdx].End );
			if ( CurEnd && RS[rIdx].supports(MinWidth,MinHeight,MoveFlags) )
			{
				INT CurWeight = RS[rIdx].distance + CurEnd->cost;
				if ( CurWeight < 1 )
					CurWeight = 1;
				CurWeight += CurStart->visitedWeight;
				if ( (CurWeight < MAX_WEIGHT) && (CurEnd->visitedWeight > CurWeight) && (CurEnd != CurStart) )
				{
					CurEnd->visitedWeight = CurWeight; //Expand/update route
					CurEnd->prevOrdered = CurStart;
					if ( CurEnd->OtherTag != SearchTag )
					{
						CurEnd->OtherTag = SearchTag;
						NList[iN++] = CurEnd;
					}
				}
			}
		}
	}*/

	Mark.Pop();
	unguard;
}
IMPLEMENT_REDIRECTED_FUNCTION(ABotz_NavigBase,-1,execMapRoutes,ABotz);
IMPLEMENT_REDIRECTED_FUNCTION(ABotz_NavigBase,-1,execMapRoutes,ADynamicBotzPlayer);


void ABotz_NavigBase::execBuildRouteCache( FFrame &Stack, RESULT_DECL)
{
	guard(Botz_execBuildRouteCache);
	P_GET_NAVIG(EndPoint);
	Stack.Step( Stack.Object, NULL); //Do not paste back result
	ANavigationPoint** CacheList = (ANavigationPoint**)GPropAddr;
	P_FINISH;

	if ( !EndPoint || !CacheList || (EndPoint->visitedWeight >= MAX_WEIGHT) )
		return;

	INT i = 0; //Loop counter, safety against infinity
	while ( EndPoint->prevOrdered )
	{
		EndPoint->prevOrdered->nextOrdered = EndPoint;
		EndPoint = EndPoint->prevOrdered;
		if ( ++i >= 15000 )
			return;
	}

	//Skip nearby nodes
	while ( EndPoint
	&&	(Square(EndPoint->Location.Z-Location.Z) < Square(EndPoint->CollisionHeight+CollisionHeight))
	&&	(Square(EndPoint->Location.X-Location.X)+Square(EndPoint->Location.Y-Location.Y) < Square(EndPoint->CollisionRadius+CollisionRadius)) )
		EndPoint = EndPoint->nextOrdered;

	i = 0; 
	*(ANavigationPoint**)Result = EndPoint;
	while ( EndPoint && (i<16) )
	{
		CacheList[i++] = EndPoint;
		EndPoint = EndPoint->nextOrdered;
	}
	while ( i<16 )
		CacheList[i++] = NULL;

	unguard;
}
IMPLEMENT_REDIRECTED_FUNCTION(ABotz_NavigBase,-1,execBuildRouteCache,ABotz);
IMPLEMENT_REDIRECTED_FUNCTION(ABotz_NavigBase,-1,execBuildRouteCache,ADynamicBotzPlayer);


void ABotz_NavigBase::execResetScriptRunaway( FFrame &Stack, RESULT_DECL)
{
	P_FINISH;
	GInitRunaway();
}

void ABotz_NavigBase::execCollideTrace( FFrame &Stack, RESULT_DECL)
{
	guard(Botz_execCollideTrace );
	P_GET_VECTOR_REF(HitLocation);
	P_GET_VECTOR_REF(HitNormal);
	P_GET_VECTOR(TraceEnd);
	P_GET_VECTOR_OPTX(TraceStart,Location);
	P_GET_UBOOL_OPTX(bOnlyStatic,0);
	P_FINISH;

	FMemMark Mark(GMem);
	FCheckResult* Hit = XLevel->MultiLineCheck( GMem, TraceEnd, TraceStart, FVector(0,0,0), 1, Level, 0 );
	while ( Hit )
	{
		if ( Hit->Actor && (Hit->Actor->bStatic || Hit->Actor->bNoDelete || !bOnlyStatic) && (Hit->Actor->bBlockActors || Hit->Actor->bBlockPlayers || (Hit->Actor == Level)) )
		{
			*(AActor**)Result = Hit->Actor;
			*HitLocation = Hit->Location;
			*HitNormal = Hit->Normal;
			break;
		}
		Hit = Hit->GetNext();
	}
	if ( !Hit )
	{
		*HitLocation = TraceEnd;
		*HitNormal = (TraceEnd - TraceStart).SafeNormal();
	}
	Mark.Pop();
	unguard;
}
IMPLEMENT_REDIRECTED_FUNCTION(ABotz_NavigBase,-1,execCollideTrace,ABotz);

/*
//*******************CollideTrace - MOVE TO NATIVE LATER!
final function actor CollideTrace( out vector HitLocation, out vector HitNormal, vector End, optional vector Start)
{
	local vector tempStart;
	local actor tempActor;
	tempActor = self;
	if ( Start == vect(0,0,0) )		Start = Location;
	ForEach TraceActors ( class'Actor', tempActor, HitLocation, HitNormal, End, Start)
	{
		if ( BFM.IsSolid(tempActor) )
			return tempActor;
	}
	HitLocation = End;
	HitNormal = normal( Start - End);
	return none;
}*/


//Limitation: doesn't set bStatic to true
void ABotz_NavigBase::execLockActor(FFrame &Stack, RESULT_DECL)
{
	guard(ABotz_NavigBase::execLockActor);
	P_GET_UBOOL(bLock);
	P_GET_NAVIG_OPTX( nBase, this);
	P_FINISH;

	if ( (nBase->bStatic | nBase->bNoDelete) != bLock )
	{
		nBase->bNoDelete = bLock;
		if ( bLock )
		{
			nBase->nextNavigationPoint = Level->NavigationPointList;
			Level->NavigationPointList = nBase;
		}
		else
		{
			nBase->bStatic = false;
			if ( Level->NavigationPointList == nBase )
			{
				Level->NavigationPointList = nBase->nextNavigationPoint;
				nBase->nextNavigationPoint = NULL;
			}
			else
			{
				ANavigationPoint *N = Level->NavigationPointList;
				while ( N )
				{
					if ( N->nextNavigationPoint == nBase )
					{
						N->nextNavigationPoint = nBase->nextNavigationPoint;
						nBase->nextNavigationPoint = NULL;
						N = NULL;
					}
					else
						N = N->nextNavigationPoint;
				}
			}
		}
	}
	unguard;
}

inline INT FindExistingDest( ANavigationPoint *Org, AActor *A)
{
	for ( INT i=0 ; (i<16 && Org->Paths[i] >= 0) ; i++ )
		if ( Org->XLevel->ReachSpecs( Org->Paths[i] ).End == A )
			return Org->Paths[i];
	return -1;
}

inline INT FindPrunedDest( ANavigationPoint *Org, AActor *A)
{
	for ( INT i=0 ; (i<16 && Org->PrunedPaths[i] >= 0) ; i++ )
		if ( Org->XLevel->ReachSpecs( Org->PrunedPaths[i] ).End == A )
			return Org->PrunedPaths[i];
	return -1;
}


//Does not check pruned paths
void ABotz_NavigBase::execExistingPath(FFrame &Stack, RESULT_DECL)
{
	guard(ABotz_NavigBase::execExistingPath);
	P_GET_ACTOR(A);
	P_FINISH;

	*(INT*)Result = FindExistingDest( this, A);
	unguard;
}

void ABotz_NavigBase::execUnusedReachSpec(FFrame &Stack, RESULT_DECL)
{
	P_FINISH;

	INT B = -1;
	for ( INT i = 0; i<XLevel->ReachSpecs.Num() ; i++ )
	{
		FReachSpec *RS;
		RS = &XLevel->ReachSpecs(i);
		if ( RS->Start == NULL && RS->End == NULL )
		{
			B = i;
			break;
		}
	}
	*(INT*)Result = B;
}

void ABotz_NavigBase::execEditReachSpec(FFrame &Stack, RESULT_DECL)
{
	guard(ABotz_NavigBase::execEditReachSpec);
	P_GET_INT(i);
	P_GET_ACTOR(A);
	P_GET_ACTOR(B);
	P_GET_FLOAT_OPTX(C, 60);
	P_GET_FLOAT_OPTX(D, 40);
	P_GET_UBOOL_OPTX(bTele, false);
	P_FINISH;

/* Reach flags description:
1 = Walking required.
2 = Flying required.
4 = Swimming required.
8 = Jumping required.
16 = Door way.
32 = Special path (teleporter, LiftCenter/Exit).
64 = Players only path. */

	if ( i >= 0 && i < XLevel->ReachSpecs.Num() )
	{
		INT ReachFlags = 0;
		if ( A && B )
		{
			if ( A->Region.Zone->bWaterZone || B->Region.Zone->bWaterZone )
				ReachFlags = ReachFlags | 4;
			if ( A->IsA( ABotz_NavigBase::StaticClass()) )
			{
				if ( ((ABotz_NavigBase*)A)->bFlying )
					ReachFlags = ReachFlags | 2;
				if ( ((ABotz_NavigBase*)A)->bCustomFlags )
					ReachFlags = eventModifyFlags( (ANavigationPoint*)B, ReachFlags);
			}
			if ( B->IsA( ABotz_NavigBase::StaticClass()) )
			{
				if ( ((ABotz_NavigBase*)B)->bFlying )
					ReachFlags = ReachFlags | 2;
				if ( ((ABotz_NavigBase*)B)->bCustomFlags )
					ReachFlags = eventModifyFlags( (ANavigationPoint*)A, ReachFlags);
			}
		}

		FReachSpec *RS;
		RS = &XLevel->ReachSpecs(i);
		RS->Start = A;
		RS->End = B;
		RS->CollisionHeight = (INT) C;
		RS->CollisionRadius = (INT) D;
		RS->reachFlags = ReachFlags;
		RS->bPruned = 0;
		if ( !bTele && A && B )
		{
			RS->distance = (INT) FVector(A->Location - B->Location).Size();
			if ( ReachFlags & 4 )
				RS->distance *= 2;
		}
		else if ( !bTele )
			RS->bPruned = 1;
		else
			RS->distance = 0;

		if ( !bTele && (ReachFlags & 32) )
			RS->distance = 100;
		
		*(UBOOL*)Result = true;
	}
	else
		*(UBOOL*)Result = false;
	unguard;
}

void ABotz_NavigBase::execIsConnectedTo(FFrame &Stack, RESULT_DECL)
{
	guard(ABotz_NavigBase::execIsConnectedTo);
	P_GET_NAVIG(A);
	P_GET_NAVIG(B);
	P_GET_UBOOL_OPTX( pruned, false);
	P_FINISH;

	INT found = -1;
	if ( A && B )
	{
		found = FindExistingDest( A, B);
		if ( pruned && found < 0 )
			found = FindPrunedDest( A, B);
	}
	*(INT*)Result = found;
	unguard;
}

void ABotz_NavigBase::execCreateReachSpec(FFrame &Stack, RESULT_DECL)
{
	guard(ABotz_NavigBase::execCreateReachSpec);
	P_FINISH;

	INT i = XLevel->ReachSpecs.Num();
	XLevel->ReachSpecs.Add(1);
	*(INT*)Result = i;

	unguard;
}


inline INT CanTakeIncomingPath( ABotz_NavigBase *aEnd, ANavigationPoint *aStart)
{
//	return 1; //WHY IS THIS HAPPENING?
	//Incoming checks
	if ( aEnd->bOneWayInc )
	{
		FVector dir = aStart->Location - aEnd->Location;
		if ( dir.Normalize() == 0 ) //Vectors nearly equal
			return 0;
		return FVector(dir + aEnd->Rotation.Vector() ).SizeSquared() >= 2;
	}
	return 1;
}

inline INT CanSendOutgoingPath( ABotz_NavigBase *aStart, ANavigationPoint *aEnd)
{
	if ( aStart->bOneWayOut )
	{
		FVector dir = aEnd->Location + aStart->Location;
		if ( dir.Normalize() == 0 ) //Vectors nearly equal
			return 0;
		return FVector(dir + aStart->Rotation.Vector() ).SizeSquared() >= 2;
	}
	return 1;
}

inline INT _FreeSlot( INT *Elem)
{
	for ( INT i=0 ; i<16 ; i++ )
		if ( *(Elem+i) == -1 )
			return i;
	return -1;
}

inline INT _CountFreeSlots( INT *Elem)
{
	INT j = 0;
	for ( INT i=0 ; i<16 ; i++ )
		if ( *(Elem+i) == -1 )
			j++;
	return j;
}

inline UBOOL _RemoveFromSlots( INT *Elem, INT Idx)
{
	for ( INT i=0 ; i<16 ; i++ )
		if ( Elem[i] == Idx )
		{
			if ( i < 15 )
				appMemmove( &Elem[i], &Elem[i+1], 4*(15-i) );
			Elem[15] = -1;
			return true;
		}
	return false;
}

void ABotz_NavigBase::execFreePathSlot(FFrame &Stack, RESULT_DECL)
{
	P_GET_NAVIG(N);
	P_FINISH;
		*(INT*)Result = _FreeSlot( &(N->Paths[0]) );
}
void ABotz_NavigBase::execFreeUpstreamSlot(FFrame &Stack, RESULT_DECL)
{
	P_GET_NAVIG(N);
	P_FINISH;
		*(INT*)Result = _FreeSlot( &(N->upstreamPaths[0]) );
}


void ABotz_NavigBase::execPruneReachSpec(FFrame &Stack, RESULT_DECL)
{
	guard(ABotz_NavigBase::execPruneReachSpec);
	P_GET_INT(rIdx);
	P_FINISH;
	
	if ( rIdx < 0 )
		return;
	FReachSpec* RS = &XLevel->ReachSpecs(rIdx);
	if ( RS->bPruned == 0 )
	{

		ANavigationPoint* Start = Cast<ANavigationPoint>(RS->Start);
		ANavigationPoint* End = Cast<ANavigationPoint>(RS->End);
		if ( Start )
		{
			_RemoveFromSlots( Start->Paths, rIdx);
			INT iFree = _FreeSlot( Start->PrunedPaths);
			if ( iFree > 0 )
				Start->PrunedPaths[iFree] = rIdx;
		}
		if ( End )
			_RemoveFromSlots( End->upstreamPaths, rIdx);
	}
	
	unguard;
}


inline void _CleanReachSpec( FReachSpec *RS)
{
	RS->Start = NULL;
	RS->End = NULL;
	RS->bPruned = 1;
	RS->reachFlags = 0;
}

struct FReachIterator
{
	INT Idx;
	AActor* Start;
	AActor* End;
	FReachIterator* Next;

	FReachIterator() {};
	FReachIterator( INT InIdx, AActor* InStart, AActor* InEnd, FReachIterator* InNext)
	:	Idx(InIdx)
	,	Start(InStart)
	,	End(InEnd)
	,	Next(InNext)
	{};
};

void ABotz_NavigBase::execClearAllPaths(FFrame &Stack, RESULT_DECL)
{
	guard(ABotz_NavigBase::execClearAllPaths);
	P_GET_NAVIG(N);
	P_GET_UBOOL_OPTX( bRestorePrunes, false);
	P_FINISH;

	if ( N == NULL )
		return;

	FMemMark Mark(GMem);
	FReachIterator* Link = NULL; //Paths coming from N
	FReachIterator* UpLink = NULL; //Paths coming into N
	FReachIterator* PruneLink = NULL; //Pruned paths to be restored
	FReachSpec* RS = &N->XLevel->ReachSpecs(0);
	INT ReachNum = N->XLevel->ReachSpecs.Num();

	//Prune restorer, first we enumerate and let the cleanup open up some spaces
	guard(ListPrunes);
	if ( bRestorePrunes )
	{
		ANavigationPoint* StartPoints[16];
		ANavigationPoint* EndPoints[16];
		INT iS = 0;
		INT iE = 0;
		INT i;

		//List start/end routes going through this node
		for ( i=0 ; i<16 ; i++ )
		{
			INT Ui = N->upstreamPaths[i];
			if ( (Ui != -1) && Cast<ANavigationPoint>(RS[Ui].Start) )
				StartPoints[iS++] = (ANavigationPoint*)RS[Ui].Start;

			INT Pi = N->Paths[i];
			if ( (Pi != -1) && Cast<ANavigationPoint>(RS[Pi].End) )
				EndPoints[iE++] = (ANavigationPoint*)RS[Pi].End;
		}

		//Find prunes discarded over this node, create links
		for ( i=0 ; i<iS ; i++ )
		for ( INT k=0 ; (k<16) && (StartPoints[i]->PrunedPaths[k] != -1) ; k++ )
		for ( INT j=0 ; j<iE ; j++ )
			if ( RS[StartPoints[i]->PrunedPaths[k]].End == EndPoints[j] )
			{
				PruneLink = new(GMem) FReachIterator( StartPoints[i]->PrunedPaths[k], StartPoints[i], EndPoints[j], PruneLink);
				break;
			}
	}
	unguard;


	INT i;
	guard( Step1 );
	for ( i=0 ; i<ReachNum ; i++ )
	{
		if ( RS[i].End == N ) //Rogue reachspec!
		{
			UpLink = new(GMem) FReachIterator(i, RS[i].Start, N, UpLink);
			_CleanReachSpec( RS+i );
		}
		else if ( RS[i].Start == N ) //Rogue reachspec!
		{
			Link = new(GMem) FReachIterator(i, N, RS[i].End, Link);
			_CleanReachSpec( RS+i );
		}
	}
	unguard;

	//Clear other upstreams
	while ( Link )
	{
		ANavigationPoint* End = (ANavigationPoint*) Link->End;
		if ( End )
			_RemoveFromSlots( End->upstreamPaths, Link->Idx);
		Link = Link->Next;
	}
	while ( UpLink )
	{
		ANavigationPoint* Start = (ANavigationPoint*) UpLink->Start;
		if ( Start )
		{
			if ( !_RemoveFromSlots( Start->Paths, UpLink->Idx) ) //Pruned?
				_RemoveFromSlots( Start->PrunedPaths, UpLink->Idx);
		}
		UpLink = UpLink->Next;
	}
	while ( PruneLink )
	{
		ANavigationPoint* Start = (ANavigationPoint*) PruneLink->Start;
		ANavigationPoint* End = (ANavigationPoint*) PruneLink->End;

		i = _FreeSlot( Start->Paths);
		if ( i != -1 ) //Transfer from pruned to real paths
		{
			Start->Paths[i] = PruneLink->Idx;
			RS[ PruneLink->Idx].bPruned = 0;
			_RemoveFromSlots( Start->PrunedPaths, PruneLink->Idx);

			INT j = _FreeSlot( End->upstreamPaths);
			if ( j != -1 )
				End->upstreamPaths[j] = PruneLink->Idx;
		}
		PruneLink = PruneLink->Next;
	}


	for ( i=0 ; i<16 ; i++ )
	{
		N->Paths[i] = -1;
		N->upstreamPaths[i] = -1;
		N->VisNoReachPaths[i] = NULL;
	}




	Mark.Pop();
	unguard;
}


void ABotz_NavigBase::execPathCandidates(FFrame &Stack, RESULT_DECL)
{
	RegisterNames();

	guard(ABotz_NavigBase::execPathCandidates);
	P_FINISH;

	ANavigationPoint *N = Level->NavigationPointList;
	FLOAT dist = MaxDistance * MaxDistance;
	ABotz_NavigBase *B;
	UClass *BaseClass = ABotz_NavigBase::StaticClass();

	if ( N == this )
		N = N->nextNavigationPoint;

	while ( N )
	{
		if ( (FVector(Location - N->Location).SizeSquared() <= dist) && (FindExistingDest(this, N) < 0) && (FindPrunedDest(this, N) < 0) )
		{
			BYTE pathType = 0;
			if ( N->IsA( BaseClass) ) //Logic for NavigBase <> NavigBase
			{
				B = (ABotz_NavigBase*)N;
				if ( CanTakeIncomingPath( B, this) && CanSendOutgoingPath(this, N) ) //This path will check back in it's own PathCandidates function, safe to deny here
				{
					pathType = B->eventIsCandidateTo( this);
					if ( pathType == PM_Normal )
						pathType = eventOtherIsCandidate( N);
				}
			}
			else //Logic for NavigBase <> NavigationPoint
			{
				B = NULL;
				if ( CanSendOutgoingPath(this, N) )
					pathType = eventOtherIsCandidate( N);
			}

			if ( pathType )
			{
				if (_CountFreeSlots( &Paths[0] ) > ReservePaths )
					eventAddPathHere( this, N, pathType == PM_Forced );
				if ( B == NULL && (_CountFreeSlots( &upstreamPaths[0] ) > ReserveUpstreamPaths) && (FindExistingDest(N, this) < 0)/* && (FindPrunedDest(N,this) < 0) */) //We just make sure we didn't apply a 2 way path here
					eventAddPathHere( N, this, pathType == PM_Forced ); //Removed conditions... because older Navigbases won't connect with newer ones otherwise
			}
		}

		N = N->nextNavigationPoint;
		if ( N == this )
			N = N->nextNavigationPoint;
	}
	bFinishedPathing = 1;
	eventFinishedPathing();

	unguard;
}

/*
//Backwards check is faster because we operate on newer elements
inline bool FoundPruned( ABotz_PathLoader *Loader, FPrunedComp *Navs )
{
	for ( INT i=Loader->Pruned.Num()-1; i>=0 ; i-- )
		if ( Loader->Pruned(i) == *Navs )
			return true;
	return false;
}

void ABotz_PathLoader::execIsPruned(FFrame &Stack, RESULT_DECL)
{
	P_GET_NAVIG(A);
	P_GET_NAVIG(B);
	P_FINISH;

	FPrunedComp C;
	C.Navs[0] = A;
	C.Navs[1] = B;

	*(UBOOL*)Result = FoundPruned( this, &C);
}

void ABotz_PathLoader::execClearPrunes(FFrame &Stack, RESULT_DECL)
{
	P_FINISH;
	Pruned.Empty();
}

void ABotz_PathLoader::execAddPrune(FFrame &Stack, RESULT_DECL)
{
	P_GET_NAVIG(A);
	P_GET_NAVIG(B);
	P_FINISH;

	FPrunedComp C;
	C.Navs[0] = A;
	C.Navs[1] = B;

	if ( !FoundPruned( this, &C) )
		Pruned.AddItem(C);
}

void ABotz_PathLoader::execInitPruned(FFrame &Stack, RESULT_DECL)
{
	guard(ABotz_PathLoader::execInitPruned);
	P_FINISH;

	INT i = XLevel->ReachSpecs.Num() - 1;

	while ( i >= 0 )
	{
		if ( XLevel->ReachSpecs(i).bPruned && XLevel->ReachSpecs(i).Start && XLevel->ReachSpecs(i).End )
		{
			FPrunedComp C;
			C.Navs[0] = (ANavigationPoint*) XLevel->ReachSpecs(i).Start; //Copy pointers, don't even convert to ANavigationPoint
			C.Navs[1] = (ANavigationPoint*) XLevel->ReachSpecs(i).End;
			Pruned.AddItem(C);
			//Experimental:
			_CleanReachSpec( &XLevel->ReachSpecs(i) );
//			XLevel->ReachSpecs(i).Start = NULL;
//			XLevel->ReachSpecs(i).End = NULL;
//			XLevel->ReachSpecs(i).reachFlags = 0;
		}
		i--;
	}

	ANavigationPoint *N = Level->NavigationPointList;
	INT PrunedBlock[16] = { -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};

	while ( N )
	{
		if ( N->PrunedPaths != PrunedBlock )
			appMemcpy( &(N->PrunedPaths), &PrunedBlock, 64); //FAST: Copy the entire array in a single operation
		N = N->nextNavigationPoint;
	}
	unguard;
}*/

IMPLEMENT_CLASS(ABotz_NavigBase);


/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
