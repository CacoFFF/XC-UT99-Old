
#include "XC_Engine.h"
#include "UnLinker.h"


class FSurfaceInfo;
class FTransTexture;
class FSurfaceFacet;
#include "UnRenDev.h" //Avoid including UnRender.h to reduce compile times
#include "XC_Networking.h"
#include "UnCon.h"
#include "UnXC_Lev.h"
#include "UnXC_Travel.h"
#include "UnXC_NetClientProc.h"
#include "XC_LZMA.h"
#include "Cacus/CacusThread.h"
#include "Cacus/Atomics.h"
#include "Cacus/CacusString.h"
#include "Cacus/AppTime.h"


IMPLEMENT_CLASS(UXC_Level);

INT UXC_Level::XC_Init = 0;

//Shitty solution to be able to use the stack
enum EPlace   {E_Place = 1};
inline void* operator new( size_t Size, void* Loc, EPlace Tag )
{
	return Loc;
}



struct FBatch
{
	FBatch* NextBatch;
	INT Count;
	INT Size;
	INT Indices[4096]; //Size is variable

	FBatch( FBatch* InNext=NULL)
		: NextBatch(InNext)
		, Count(0)
	{}
	
	static FBatch* AllocateBatch( INT BatchSize, FBatch* Other=NULL)
	{
		guard(FBatch::AllocateBatch);

		BatchSize = Clamp( BatchSize, 32, 4096);
		FBatch* Result = (FBatch*)appMalloc( 12 + BatchSize * 4, TEXT("FBatch"));
		Result->NextBatch = Other;
		Result->Count = 0;
		Result->Size = BatchSize;
		return Result;

		unguard;
	}
};

struct FNameBatchMap : public TMap<INT,FBatch*>
{
	TArray<INT> TransientNames;
	
	INT GetNameHash( const TCHAR* InStr)
	{
		guard(FNameBatchMap::GetNameHash);
		INT Len = Min( appStrlen(InStr), 63);
		TCHAR NewName[64];
		NewName[Len--] = 0;
		while ( (Len > 0) && appIsDigit(InStr[Len]) )
			NewName[Len--] = 0;
		for ( ; Len >= 0 ; Len-- )
			NewName[Len] = InStr[Len];
		return appStrihash( NewName) & 0x7FFFFFFF;
		unguard;
	}
	FName Request( UObject* Parent, UClass* ForClass )
	{
		guard(FNameBatchMap::Request);
		INT iHash = GetNameHash( ForClass->GetName() );
		if ( !Hash )
			Rehash();
		FBatch* Batch = FindRef( iHash);
		while ( Batch )
		{
			while ( Batch->Count > 0 )
			{
				//If object matches class and is deleted, pick it up
				Batch->Count--;
				FNameEntry* Entry = FName::GetEntry( Batch->Indices[Batch->Count] );
				if ( Entry && (Entry->Flags & RF_Transient) && (GetNameHash( Entry->Name) == iHash) && !UObject::StaticFindObject( NULL, Parent, Entry->Name ) )
					return *((FName*)&Entry->Index);
			}
			FBatch* NextBatch = Batch->NextBatch;
			delete Batch;
			Batch = NextBatch;
			if ( Batch )
			{
//				debugf( TEXT("Next batch in queue: (%i/%i)"), Batch->Count, Batch->Size);
				Set( iHash, Batch);
				check( FindRef(iHash) );
			}
			else
				Remove( iHash);
		}
		return NAME_None;
		unguard;
	}

	void Store( FName AName)
	{
		guard(FNameBatchMap::Store);
		INT iHash = GetNameHash( *AName);
		FBatch* Batch = FindRef( iHash );
		guard(BatchSetup);
		if ( !Batch )
		{
			Batch = FBatch::AllocateBatch(32);
			Set( iHash, Batch);
		}
		else if ( Batch->Count >= Batch->Size )
		{
			Batch = FBatch::AllocateBatch( Batch->Size + (Batch->Size >> 2) + (iHash%8), Batch);
			Set( iHash, Batch);
		}
		check( Batch->Count < Batch->Size );	
		unguard;
		//Add single name
		Batch->Indices[Batch->Count++] = *(INT*)&AName;
		unguard;
	}
	
	void Cleanup()
	{
		guard(FNameBatchMap::Cleanup);
		INT i;
		for ( i=0 ; i<TransientNames.Num() ; i++ )
		{
			FNameEntry* NEntry = FName::GetEntry(TransientNames(i));
			if ( NEntry )
				NEntry->Flags &= ~RF_Destroyed;
		}
		SafeEmpty(TransientNames);
/*		INT MaxNames = FName::GetMaxNames();
		for ( i=0 ; i<MaxNames ; i++ )
		{
			FNameEntry* NEntry = FName::GetEntry(i);
			if ( NEntry )
				NEntry->Flags &= ~RF_Destroyed;
		}
*/		for ( i=0 ; i<Pairs.Num() ; i++ )
		{
			FBatch* Batch = Pairs(i).Value;
			while ( Batch )
			{
				FBatch* Next = Batch->NextBatch;
				delete Batch;
				Batch = Next;
			}
		}
		Empty();
		unguard;
	}
};

static INT BatchData[8] = { 0, 0, 0, 0, 8, 0, 0, 0 };
static FNameBatchMap* UnusedNamePool = (FNameBatchMap*)BatchData;

//Stats
static INT ST_Traces = 0;

//Map loader stuff
static volatile INT GMapLoadCount = 0;
static volatile UBOOL GIsLoadingMap = 0; //Needed to avoid critical errors
static volatile UBOOL GLockPackageMap = 0;



//====================================================
//====================================================
// Level hack
//====================================================
//====================================================

//BROWSE IS CALLED TOWARDS LOCALMAPURL DURING INIT, WHICH THEN CALLS LOADMAP!
UBOOL UXC_GameEngine::Browse( FURL URL, const TMap<FString,FString>* TravelInfo, FString& Error )
{
	//We're initializing UGameEngine, we no longer need this hack
	if ( UXC_GameEngine::StaticClass()->PropertiesSize < UGameEngine::StaticClass()->PropertiesSize )
		Exchange( UGameEngine::StaticClass()->PropertiesSize, UXC_GameEngine::StaticClass()->PropertiesSize );

	UBOOL bDisconnected = URL.HasOption( TEXT("failed")) || URL.HasOption( TEXT("entry"));
	if ( bDisconnected )
	{
		if ( Level() )
			Level()->SetActorCollision(0);
		UnHookEngine();
	}

	//Forbidden to execute files using this command
	if ( !appStricmp( *URL.Protocol, TEXT("file")) )
		return false;

	//Remote connection attempt, remove unnecesary parameters (privacy)
	if ( !appStricmp( *URL.Protocol, TEXT("unreal"))  && URL.Host.Len() )
	{
		for ( INT i=URL.Op.Num()-1 ; i>=0 ; i-- )
		{
			if( appStrnicmp( *URL.Op(i), TEXT("Engine="), 5 )==0 )
				URL.Op.Remove(i);
			else if( appStrnicmp( *URL.Op(i), TEXT("Mutator="), 8 )==0 )
				URL.Op.Remove(i);
		}
	}

	if ( bEnableDebugLogs )
		debugf( NAME_XC_Engine, TEXT("Browse() Start: %s %s %i"), *URL.Protocol, *URL.Host, URL.Port);
	UBOOL result = Super::Browse( URL, TravelInfo, Error);
	if ( bEnableDebugLogs )
		debugf( NAME_XC_Engine, TEXT("Browse() End"));

	if ( PendingLevel() )
		FNetworkNotifyPL::Instance.SetPending( (UPendingLevelMirror*)PendingLevel() );
	
	// Entry
	if ( Level() == Entry() )
	{
		HookNatives( true); //Full GNative hooks
		HookEngine( NULL ); //Forces limited hook of standard stuff
		AdminLoginHook = NULL;
		UClass* CL = StaticLoadClass( AActor::StaticClass(), NULL, TEXT("XC_Engine.XC_Engine_Actor"), NULL, LOAD_NoFail, NULL);
		AActor* XCGEA = Entry()->SpawnActor(CL);
		if ( XCGEA )
		{
			XCGEA->ProcessEvent( FindBaseFunction( XCGEA->GetClass(), TEXT("XC_Init") ) , NULL);
			Entry()->DestroyActor( XCGEA);
		}


//		CollectGarbage(RF_Native); //EXPERIMENTAL
	}

	return result;
}


/////////////////////
// Compressor thread
/////////////////////
struct FAutoCompressorThread : public CThread
{
public:
	// Variables.
	UPackageMap*	PackageMap;
	INT				MapCount;
	TCHAR			CompressedExt[12];

	// Functions.
	FAutoCompressorThread()	{}
	FAutoCompressorThread( UPackageMap* InPackageMap, INT InMapCount);
};


static UBOOL IsDefaultPackage( const TCHAR* Pkg)
{
	//Get rid of paths...
	const TCHAR* Filename;
	for ( Filename=Pkg ; *Pkg ; Pkg++ )
		if ( *Pkg == '\\' || *Pkg == '/' )
			Filename = Pkg + 1;
	
	//Save as ANSI text
	static const TCHAR* DefaultList[] = 
		{	TEXT("Botpack.u")
		,	TEXT("Engine.u")
		,	TEXT("Core.u")
		,	TEXT("Unreali.u")
		,	TEXT("UnrealShare.u")
		,	TEXT("Editor.u")
		,	TEXT("Fire.u")
		,	TEXT("Credits.utx")
		,	TEXT("LadderFonts.utx")
		,	TEXT("LadrStatic.utx")
		,	TEXT("LadrArrow.utx")	};

	// Compare
	const int max = ARRAY_COUNT( DefaultList);
	for ( int i=0 ; i<max ; i++ )
		if ( !appStricmp( Filename, DefaultList[i]) )
			return 1;
	return 0;
}

// Priority thread entrypoint.
static DWORD AutoCompressorThreadEntry( void* Arg)
{
	appSleep( 0.1f);
	FAutoCompressorThread* ACT = (FAutoCompressorThread*)Arg;
	INT LenExt = appStrlen( ACT->CompressedExt);

	INT i = 0;
	INT CompressCount = 0;
	UBOOL bLeave = 0;
	while ( !bLeave )
	{
		appSleep( 0.001f);
		if ( GIsRequestingExit) //Engine about to exit
			return 0;
		if ( GMapLoadCount != ACT->MapCount) //New map has loaded
			break;
		if ( GIsLoadingMap != 0) //Map is loading!!
		{
			appSleep( 0.1f);
			continue;
		}
		if ( FPlatformAtomics::InterlockedCompareExchange(&GLockPackageMap, 1, 0)) //Other thread is compressing
		{
			appSleep( 0.1f);
			continue;
		}
		if ( i < ACT->PackageMap->List.Num() )
		{
			ULinker* LNKh = (ULinker*)ACT->PackageMap->List(i).Linker;
			INT Len = LNKh->Filename.Len();
			if ( (Len < 250 - LenExt) && !IsDefaultPackage(*LNKh->Filename) ) //Avoid string formatting crash
			{
				TCHAR FileName_Base[256];
				appStrcpy( FileName_Base, *LNKh->Filename);
				TCHAR FileName_LZMA[256];
				appSprintf( FileName_LZMA, TEXT("%s%s"), FileName_Base, ACT->CompressedExt);


				if ( GFileManager->FileSize( FileName_LZMA) <= 0 )
				{	//Unsafe operations ended, let's unlock main thread's loaders
					FPlatformAtomics::InterlockedExchange(&GLockPackageMap, 0);
					TCHAR Error[256]; Error[0] = 0;
					TCHAR FileName_Temp[256];
					appStrcpy( FileName_Temp, FileName_LZMA);
					FileName_Temp[Len + LenExt - 1] = 't'; //TEMP INDICATOR
					TCHAR Msg[768];
					appSprintf( Msg, TEXT("AutoCompressing %s to %s"), FileName_Base, FileName_LZMA);
//					debugf( NAME_Log, Msg);
					GLog->Log( Msg);
					LzmaCompress( FileName_Base, FileName_Temp, Error);
					CompressCount++;
					GFileManager->Move( FileName_LZMA, FileName_Temp);
				}
			}
		}
		else
			bLeave = 1;
		i++;
		FPlatformAtomics::InterlockedExchange(&GLockPackageMap, 0);
	}
	if ( CompressCount )
		debugf( NAME_Log, TEXT("LZMA Compressor ended (%i files)"), CompressCount);

	ACT->Detach(); //UGLY TODO
	delete ACT;
	return THREAD_END_OK;
}

FAutoCompressorThread::FAutoCompressorThread(UPackageMap* InPackageMap, INT InMapCount)
	:	CThread()
	,	PackageMap(InPackageMap)
	,	MapCount(InMapCount)
{
	guard(FAutoCompressorThread);

	appSprintf( CompressedExt, COMPRESSED_EXTENSION);
	debugf(NAME_Log, TEXT("Starting LZMA compressor...") );
	if ( Run( &AutoCompressorThreadEntry, (void*)this) )
		debugf(NAME_XC_Engine, TEXT("Thread ID: %i"), ThreadId());
	unguard;
}

//******************************************
// Demoplay shouldn't verify these packages.
static UBOOL PackageNeedsDemoFix( const TCHAR* PkgName)
{
	guard( PackageNeedsDemoFix);
	const TCHAR* DemoPkgs[] = { TEXT("Announcer"), TEXT("Credits")};

	for ( INT i=0 ; i<2 ; i++ )
		if ( appStricmp(DemoPkgs[i], PkgName) == 0 )
			return 1;
	return 0;
	unguard;
}

//***************************
// Match Viewports to actors.
static void MatchViewportsToActors( UClient* Client, ULevel* Level, const FURL& URL )
{
	guard(MatchViewportsToActors);
	for( INT i=0; i<Client->Viewports.Num(); i++ )
	{
		FString Error;
		UViewport* Viewport = Client->Viewports(i);
		debugf( NAME_Log, TEXT("Spawning new actor for Viewport %s"), Viewport->GetName() );
		if( !Level->SpawnPlayActor( Viewport, ROLE_SimulatedProxy, URL, Error ) )
			appErrorf( TEXT("%s"), *Error );
	}
	unguardf(( TEXT("(%s)"), *Level->URL.Map ));
}

//***********************
// Rearranges actor list.
static void RearrangeActorList( ULevel* Level)
{
	guard(RearrangeActorList)
		TArray<AActor*> Actors;
	Actors.AddItem( Level->Actors(0));
	Actors.AddItem( Level->Actors(1));

	INT i;
	// Add Static non relevant actors
	for( i=2; i<Level->Actors.Num(); i++ )
		if( Level->Actors(i) && Level->Actors(i)->bStatic && !Level->Actors(i)->bAlwaysRelevant )
		{
			Actors.AddItem( Level->Actors(i) );
			Level->Actors(i) = NULL;
		}
	Level->iFirstNetRelevantActor=Actors.Num();

	// Add Static relevant actors
	for( i=2; i<Level->Actors.Num(); i++ )
		if( Level->Actors(i) && Level->Actors(i)->bStatic /*&& Level->Actors(i)->bAlwaysRelevant*/ )
		{
			Actors.AddItem( Level->Actors(i) );
			Level->Actors(i) = NULL;
		}
	Level->iFirstDynamicActor=Actors.Num();

	// Put XC_Engine actor stuff first in dynamic list
	for ( i=2 ; i<Level->Actors.Num() ; i++ )
		if ( Cast<AXC_Engine_Actor>(Level->Actors(i)) /*&& !Level->Actors(i)->bStatic*/ )
		{
			Actors.AddItem( Level->Actors(i) );
			Level->Actors(i) = NULL;
		}

	// Add remaining actors
	for( i=2; i<Level->Actors.Num(); i++ )
		if( Level->Actors(i) /*&& !Level->Actors(i)->bStatic*/ )
			Actors.AddItem( Level->Actors(i) );

	// The level's actor list is now the arranged list, delete old (via out of scope)
	ExchangeArray( Level->Actors, Actors); //This prevents unnecessary GMalloc usage
	unguard
}



#include "XCL_Private.h"

void UXC_Level::CleanupDestroyed( UBOOL bForce )
{
	guard(UXC_Level::CleanupDestroyed);
	if ( bForce ) //Likely on level switch
	{
		Super::CleanupDestroyed( bForce);
		return;
	}

	// Pack actor list.
	CompactActors();

	// If nothing deleted, exit.
	if( !FirstDeleted )
		return;

	// Don't do anything unless a bunch of actors are in line to be destroyed.
	guard(CheckDeleted);
	INT c=0;
	for( AActor* A=FirstDeleted; A; A=A->Deleted )
		c++;
	if( c<128 )
		return;
	unguard;

	// Remove all references to actors tagged for deletion.
	guard(CleanupRefs);
	for( INT iActor=0; iActor<Actors.Num(); iActor++ )
	{
		AActor* Actor = Actors(iActor);
		if( Actor )
		{
			// Would be nice to say if(!Actor->bStatic), but we can't count on it.
			checkSlow(!Actor->bDeleteMe);
			Actor->GetClass()->CleanupDestroyed( (BYTE*)Actor );
		}
	}
	unguard;
	
	guard(FinishDestroyedActors);
	while( FirstDeleted!=NULL )
	{
		// Physically destroy the actor-to-delete.
		check(FirstDeleted->bDeleteMe);
		AActor* ActorToKill = FirstDeleted;
		FirstDeleted        = FirstDeleted->Deleted;
		check(ActorToKill->bDeleteMe);

		FNameEntry* NEntry = FName::GetEntry( ActorToKill->GetFName().GetIndex() );
		if ( NEntry->Flags & RF_Transient ) //I tagged this name upon it's creation
			UnusedNamePool->Store( ActorToKill->GetFName() );
		
		// Destroy the actor.
		delete ActorToKill;
	}
	unguard;

	unguard;
}


//****************************************
// Returns index where to put new actor
static INT SpawnActorIndex( ULevel* Level)
{
	TArray<AActor*>& Actors = Level->Actors;
	INT i = Actors.Num();
	while ( i>2 && Actors(i-1)==NULL )
		i--;
	if ( i == Actors.Num() )
		Actors.Add();
	return i;
}


//
// Create a new actor. Returns the new actor, or NULL if failure.
//
AActor* UXC_Level::SpawnActor
(
	UClass*			SpawnClass,
	FName			InName,
	AActor*			Owner,
	class APawn*	Instigator,
	FVector			Location,
	FRotator		Rotation,
	AActor*			Template,
	UBOOL			bNoCollisionFail,
	UBOOL			bRemoteOwned
)
{
	guard(UXC_Level::SpawnActor);

	// Make sure this class is spawnable.
	if ( !SpawnClass)
	{
		debugf( NAME_Warning, TEXT("SpawnActor failed because no class was specified") );
		return NULL;
	}
	else if ( SpawnClass->ClassFlags & CLASS_Abstract )
	{
		debugf( NAME_Warning, TEXT("SpawnActor failed because class %s is abstract"), SpawnClass->GetName() );
		return NULL;
	}
	else if ( !SpawnClass->IsChildOf(AActor::StaticClass()) )
	{
		debugf( NAME_Warning, TEXT("SpawnActor failed because %s is not an actor class"), SpawnClass->GetName() );
		return NULL;
	}
	else if ( !GIsEditor && (SpawnClass->GetDefaultActor()->bStatic || SpawnClass->GetDefaultActor()->bNoDelete) )
	{
		debugf( NAME_Warning, TEXT("SpawnActor failed because class %s has bStatic or bNoDelete"), SpawnClass->GetName() );
		return NULL;		
	}

	// Use class's default actor as a template.
	if( !Template )
		Template = SpawnClass->GetDefaultActor();
	check(Template!=NULL);

	// Make sure actor will fit at desired location, and adjust location if necessary.
	if ( (Template->bCollideWorld || (Template->bCollideWhenPlacing && (GetLevelInfo()->NetMode != NM_Client))) && !bNoCollisionFail )
		if ( !FindSpot( Template->GetCylinderExtent(), Location, 0, 1 ) )
			return NULL;

	// Add at end of list.
	INT iActor = SpawnActorIndex(this);
//	INT iActor = Actors.Add();
	AActor* Actor = NULL;
	
	guard(CreateActor);
	if ( InName == NAME_None )
		InName = UnusedNamePool->Request( GetOuter(), SpawnClass);
	Actor = Actors(iActor) = (AActor*)StaticConstructObject(SpawnClass, GetOuter(), InName, 0, Template );
	if ( InName == NAME_None ) //Name was created instead!!!
	{
		Actor->GetFName().SetFlags(RF_Transient);
		UnusedNamePool->TransientNames.AddItem( Actor->GetFName().GetIndex());
	}
	unguard;
	Actor->SetFlags( RF_Transactional );

	// Set base actor properties.
	Actor->Tag		= SpawnClass->GetFName();
	Actor->Region	= FPointRegion( GetLevelInfo() );
	Actor->Level	= GetLevelInfo();
	Actor->bTicked  = !Ticked;
	Actor->XLevel	= this;

	check(Actor->Role==ROLE_Authority);
	if( bRemoteOwned )
		Exchange( Actor->Role, Actor->RemoteRole );

	// Remove the actor's brush, if it has one, because moving brushes are not duplicatable.
	if( Actor->Brush )
		Actor->Brush = NULL;

	// Set the actor's location and rotation.
	Actor->Location = Location;
	Actor->OldLocation = Location;
	Actor->Rotation = Rotation;
	if( Actor->bCollideActors && Hash  )
		Hash->AddActor( Actor );

	// Init the actor's zone.
	Actor->Region = FPointRegion(GetLevelInfo());
	if( Actor->IsA(APawn::StaticClass()) )
		((APawn*)Actor)->FootRegion = ((APawn*)Actor)->HeadRegion = FPointRegion(GetLevelInfo());

	// Set owner/instigator
	Actor->SetOwner( Owner );
	Actor->Instigator = Instigator;

	// Send messages.
	Actor->InitExecution();
	Actor->Spawned();
	Actor->eventSpawned();
	if ( !XC_Init )
	{
		Actor->eventPreBeginPlay();
		Actor->eventBeginPlay();
	}
	if( Actor->bDeleteMe )
		return NULL;

	if ( !XC_Init )
	{
		// Set the actor's zone.
		SetActorZone( Actor, iActor==0, 1 );

		// Send PostBeginPlay.
		Actor->eventPostBeginPlay();
	}

	// Check for encroachment.
	if( !bNoCollisionFail && CheckEncroachment( Actor, Actor->Location, Actor->Rotation, 0 ) )
	{
		DestroyActor( Actor );
		return NULL;
	}

	// Init scripting.
	if ( !XC_Init )
	{
		Actor->eventSetInitialState();

		// Find Base
		if( !Actor->Base && Actor->bCollideWorld
			 && (Actor->IsA(ADecoration::StaticClass()) || Actor->IsA(AInventory::StaticClass()) || Actor->IsA(APawn::StaticClass())) 
			 && ((Actor->Physics == PHYS_None) || (Actor->Physics == PHYS_Rotating)) )
			Actor->FindBase();

		// Success: Return the actor.
		if( InTick )
			NewlySpawned = new(GEngineMem)FActorLink(Actor,NewlySpawned);
	}


	static UBOOL InsideNotification = 0;
	if( !InsideNotification )
	{
		InsideNotification = 1;
		// Spawn notification
		for( ASpawnNotify* N = GetLevelInfo()->SpawnNotify; N; N = N->Next )
		{
			if( N->ActorClass && Actor->IsA(N->ActorClass) )
				Actor = N->eventSpawnNotification( Actor );
		}
		InsideNotification = 0;
	}

	return Actor;
	unguardf(( TEXT("(%s)"), SpawnClass->GetName() ));
}

void UXC_Level::SetActorCollision( UBOOL bCollision )
{
	guard(UXC_Level::SetActorCollision);

	UXC_GameEngine* XCGE = Cast<UXC_GameEngine>(Engine);
	if ( !XCGE || !XCGE->bCollisionHashHook )
		Super::SetActorCollision(bCollision);
	else if( bCollision && !Hash )
	{
		guard(StartCollision);
		debugf( NAME_XC_Engine, TEXT("Setting up collision grid [Level Hook] for %s"), GetOuter()->GetName() );
		if ( NewCollisionHashFunc )
		{
			CollisionGrid = (*NewCollisionHashFunc)(this);
			Hash = CollisionGrid;
		}
		if ( Hash )
		{
			for( INT i=0; i<Actors.Num(); i++ )
				if( Actors(i) && Actors(i)->bCollideActors )
					Hash->AddActor( Actors(i) );
		}
		else
			Super::SetActorCollision(bCollision);
		unguard;
	}
	else if( Hash && !bCollision )
	{
		// Destroy gridded octree, no need to remove actors.
		guard(EndCollision);
		if ( CollisionGrid == Hash )
		{
			delete CollisionGrid;
			Hash = CollisionGrid = NULL;
		}
		else
			Super::SetActorCollision(bCollision);
		unguard;
	}

	unguard;
}

void UXC_Level::Destroy()
{
	guard(ULevel::Destroy);

	// Free allocated stuff.
	SetActorCollision(0);

	if( BrushTracker )
	{
		delete BrushTracker;
		BrushTracker = NULL; /* Required because brushes may clean themselves up. */
	}

	ULevelBase::Destroy();
	unguard;
}


//
//
// DEBUGGING CODE
//
//
/*
UBOOL UXC_Level::MoveActor
(
	AActor*			Actor,
	FVector			Delta,
	FRotator		NewRotation,
	FCheckResult&	Hit,
	UBOOL			bTest,
	UBOOL			bIgnorePawns,
	UBOOL			bIgnoreBases,
	UBOOL			bNoFail
)
{
	guard(ULevel::MoveActor);
	check(Actor!=NULL);
	if( (Actor->bStatic || !Actor->bMovable) && !GIsEditor )
		return 0;

	// Skip if no vector.
	if( Delta.IsNearlyZero() )
	{
		if( NewRotation==Actor->Rotation )
		{
			return 1;
		}
		else if( !Actor->StandingCount && !Actor->IsMovingBrush() )
		{
			Actor->Rotation  = NewRotation;
			return 1;
		}
	}

	// Set up.
	Hit = FCheckResult(1.0);
	NumMoves++;
	clock(MoveCycles);
	FMemMark Mark(GMem);
	FLOAT DeltaSize;
	FVector DeltaDir;
	if( Delta.IsNearlyZero() )
	{
		DeltaSize = 0;
		DeltaDir = Delta;
	}
	else
	{
		DeltaSize = Delta.Size();
		DeltaDir       = Delta/DeltaSize;
	}
	FLOAT TestAdjust	   = 2.0;
	FVector TestDelta      = Delta + TestAdjust * DeltaDir;
	INT     MaybeTouched   = 0;
	FCheckResult* FirstHit = NULL;

	// Perform movement collision checking if needed for this actor.
	if( (Actor->bCollideActors || Actor->bCollideWorld) && !Actor->IsMovingBrush() && Delta!=FVector(0,0,0) )
	{
		// Check collision along the line.
		FirstHit = MultiLineCheck
		(
			GMem,
			Actor->Location + TestDelta,
			Actor->Location,
			Actor->GetCylinderExtent(),
			(Actor->bCollideActors && !Actor->IsMovingBrush()) ? 1              : 0,
			(Actor->bCollideWorld  && !Actor->IsMovingBrush()) ? GetLevelInfo() : NULL,
			0
		);

		// Handle first blocking actor.
		guard(TestBlockers);
		if( Actor->bCollideWorld || Actor->bBlockActors || Actor->bBlockPlayers )
		{
			for( FCheckResult* Test=FirstHit; Test; Test=Test->GetNext() )
			{
				if
				(	(!bIgnorePawns || Test->Actor->bStatic || (!Test->Actor->IsA(APawn::StaticClass()) && !Test->Actor->IsA(ADecoration::StaticClass())))
				&&	(!bIgnoreBases || !Actor->IsBasedOn(Test->Actor))
				&&	(!Test->Actor->IsBasedOn(Actor)               ) )
				{
					MaybeTouched = 1;
					if( Actor->IsBlockedBy(Test->Actor) )
					{
						Hit = *Test;
						break;
					}
				}
			}
		}
		unguard;
	}

	// Attenuate movement.
	FVector FinalDelta = Delta;
	if( Hit.Time < 1.0 && !bNoFail )
	{
		// Fix up delta, given that TestDelta = Delta + TestAdjust.
		FLOAT FinalDeltaSize = (DeltaSize + TestAdjust) * Hit.Time;
		if ( FinalDeltaSize <= TestAdjust)
		{
			FinalDelta = FVector(0,0,0);
			Hit.Time = 0;
		}
		else 
		{
			FinalDelta = TestDelta * Hit.Time - TestAdjust * DeltaDir;
			Hit.Time   = (FinalDeltaSize - TestAdjust) / DeltaSize;
		}
	}

	// Move the based actors (before encroachment checking).
	if( Actor->StandingCount && !bTest )
	{
		for( int i=0; i<Actors.Num(); i++ )
		{
			AActor* Other = Actors(i);
			if( Other && Other->Base==Actor )
			{
				// Move base.
				FVector   RotMotion( 0, 0, 0 );
				FRotator DeltaRot ( 0, NewRotation.Yaw - Actor->Rotation.Yaw, 0 );
				if( NewRotation != Actor->Rotation )
				{
					// Handle rotation-induced motion.
					FRotator ReducedRotation = FRotator( 0, ReduceAngle(NewRotation.Yaw) - ReduceAngle(Actor->Rotation.Yaw), 0 );
					FVector   Pointer         = Actor->Location - Other->Location;
					RotMotion                 = Pointer - Pointer.TransformVectorBy( GMath.UnitCoords * ReducedRotation );
				}
				FCheckResult Hit(1.0);
				MoveActor( Other, FinalDelta + RotMotion, Other->Rotation + DeltaRot, Hit, 0, 0, 1 );

				// Update pawn view.
				if( Other->IsA(APawn::StaticClass()) )
					((APawn*)Other)->ViewRotation += DeltaRot;
			}
		}
	}

	// Abort if encroachment declined.
	if( !bTest && !bNoFail && !Actor->IsA(APawn::StaticClass()) && CheckEncroachment( Actor, Actor->Location + FinalDelta, NewRotation, 0 ) )
	{
		unclock(MoveCycles);
		return 0;
	}

	// Update the location.
	guard(Unhash);
	if( Actor->bCollideActors && Hash )
		Hash->RemoveActor( Actor );
	unguardf( (TEXT("%s, [%f,%f,%f]"), Actor->GetName(), Actor->Location.X, Actor->Location.Y, Actor->Location.Z) );
	Actor->Location += FinalDelta;
	Actor->Rotation  = NewRotation;
	guard(Hash);
	if( Actor->bCollideActors && Hash )
		Hash->AddActor( Actor );
	unguard;

	// Handle bump and touch notifications.
	if( !bTest )
	{
		// Notify first bumped actor unless it's the level or the actor's base.
		if( Hit.Actor && Hit.Actor!=GetLevelInfo() && !Actor->IsBasedOn(Hit.Actor) )
		{
			// Notify both actors of the bump.
			Hit.Actor->eventBump(Actor);
			Actor->eventBump(Hit.Actor);
		}

		// Handle Touch notifications.
		if( MaybeTouched || !Actor->bBlockActors || !Actor->bBlockPlayers )
			for( FCheckResult* Test=FirstHit; Test && Test->Time<Hit.Time; Test=Test->GetNext() )
				if
				(	(!Test->Actor->IsBasedOn(Actor))
				&&	(!bIgnoreBases || !Actor->IsBasedOn(Test->Actor))
				&&	(!Actor->IsBlockedBy(Test->Actor)) )
					Actor->BeginTouch( Test->Actor );

		// UnTouch notifications.
		for( int i=0; i<ARRAY_COUNT(Actor->Touching); i++ )
			if( Actor->Touching[i] && !Actor->IsOverlapping(Actor->Touching[i]) )
				Actor->EndTouch( Actor->Touching[i], 0 );
	}

	// Set actor zone.
	SetActorZone( Actor, bTest );
	Mark.Pop();

	// Return whether we moved at all.
	unclock(MoveCycles);
	return Hit.Time>0.0;
	unguard;
}*/
/*
FCheckResult* UXC_Level::MultiLineCheck
(
	FMemStack&		Mem,
	FVector			End,
	FVector			Start,
	FVector			Extent,
	UBOOL			bCheckActors,
	ALevelInfo*		LevelInfo,
	BYTE			ExtraNodeFlags
)
{
	guard(UXC_Level::MultiLineCheck);
	INT NumHits=0;
	FCheckResult Hits[64];

	// Check for collision with the level, and cull by the end point for speed.
	FLOAT Dilation = 1.0;
	INT bOnlyCheckForMovers = 0;
	INT bHitWorld = 0;

	guard(CheckWithLevel);
	if( LevelInfo && LevelInfo->GetLevel()->Model->LineCheck( Hits[NumHits], NULL, End, Start, Extent, ExtraNodeFlags )==0 )
	{
		bHitWorld = 1;
		Hits[NumHits].Actor = LevelInfo;
		FLOAT Dist = (Hits[NumHits].Location - Start).Size();
		Dilation = ::Min(1.f, Hits[NumHits].Time * (Dist + 5)/(Dist+0.0001f));
		End = Start + (End - Start) * Dilation;
		if( (Hits[NumHits].Time < 0.01) && (Dist < 30) )
			bOnlyCheckForMovers = 1;
		NumHits++;
	}
	unguard;

	// Check with actors.
	guard(CheckWithActors);
	if( bCheckActors && Hash )
	{
		FCheckResult* Link;
		guard(Hash);
		Link = Hash->ActorLineCheck( Mem, End, Start, Extent, ExtraNodeFlags );
		unguard;
		for( ; Link && NumHits<ARRAY_COUNT(Hits); Link=Link->GetNext() )
		{
			guard(PostLink);
			if ( !bOnlyCheckForMovers || Link->Actor->IsA(AMover::StaticClass()) )
			{
				if ( bHitWorld && Link->Actor->IsA(AMover::StaticClass()) 
					&& (Link->Normal == Hits[0].Normal)
					&& ((Link->Location - Hits[0].Location).SizeSquared() < 4) ) // make sure it wins compared to world
				{
					guard(Mover);
					FVector TraceDir = End - Start;
					FLOAT TraceDist = TraceDir.Size();
					TraceDir = TraceDir/TraceDist;
					Link->Location = Hits[0].Location - 2 * TraceDir;
					Link->Time = (Link->Location - Start).Size();
					Link->Time = Link->Time/TraceDist;
					unguard;
				}
				Link->Time *= Dilation;
				Hits[NumHits++] = *Link;
			}
			unguard;
		}
	}
	unguard;

	// Sort the list.
	FCheckResult* Result = NULL;
	if( NumHits )
	{
		appQsort( Hits, NumHits, sizeof(Hits[0]), (QSORT_COMPARE)CompareHits );
		Result = new(Mem,NumHits)FCheckResult;
		for( INT i=0; i<NumHits; i++ )
		{
			Result[i]      = Hits[i];
			Result[i].Next = (i+1<NumHits) ? &Result[i+1] : NULL;
		}
	}
	return Result;
	unguard;
}
*/
/**/

//====================================================
//====================================================
// Brush tracker fixer
//====================================================
//====================================================

FXC_BrushTrackerFixer::FXC_BrushTrackerFixer( UXC_GameEngine* InEngine)
	:	StaticMovers(0)
	,	Engine(InEngine)
	,	Level(InEngine->Level())
{};

UBOOL FXC_BrushTrackerFixer::Init()
{
	guard( FXC_BrushTrackerFixer::Init);
	Engine->bHackingTracker = 0;

	// Brush tracker was created outside of here, so we don't need to maintain
	if ( !Level || Level->BrushTracker )
		return false;

	// The engine doesn't want to create a brush tracker
	if ( Engine->bDisableBrushTracker )
		return false;
	{for ( INT i=0; i<Engine->NoBrushTrackerFix.Num() ; i++ )
		if ( !appStricmp( Level->GetOuter()->GetName(), *Engine->NoBrushTrackerFix(i)) )
			return false;}

	// Count 'static' movers.
	{for ( INT i=0; i<Level->Actors.Num(); i++ )
	{
		AMover* Mover = Cast<AMover>(Level->Actors(i));
		if ( Mover && Mover->Brush && (Mover->bNoDelete || Mover->bStatic) )
			StaticMovers.AddItem( Mover);
	}}
	if ( !StaticMovers.Num() )
		return false;

	// Finish up
	Level->BrushTracker = GNewBrushTracker( Level);
	StaticMovers.Shrink();
	Engine->bHackingTracker = 1;
	return true;

	unguard;
}

void FXC_BrushTrackerFixer::Exit()
{
	if ( StaticMovers.Num() > 0 )
		StaticMovers.Empty();
}

UBOOL FXC_BrushTrackerFixer::IsTyped( const TCHAR* Type)
{
	return appStricmp( Type, TEXT("BrushTrackerFixer")) == 0;
}

INT FXC_BrushTrackerFixer::Tick( FLOAT DeltaSeconds)
{
	guard( FXC_BrushTrackerFixer::Tick)
	if ( !Level || StaticMovers.Num() <= 0 || !Level->BrushTracker )
		return 0; //Should deinitialize
	if ( Level->Actors.Num() <= 0 || !Level->Actors(0) || !Level->GetLevelInfo()->bBegunPlay )
		return 1; //Should not deinitialize
	for( INT i=0; i<StaticMovers.Num(); i++ )
	{
		if ( !StaticMovers(i) || StaticMovers(i)->bDeleteMe || StaticMovers(i)->bHidden )
		{}//	StaticMovers.Remove(i);
		else
			Level->BrushTracker->Update( StaticMovers(i) );
	}
	//TestLevel->BrushTracker->Flush( TestLevel->Actors(i) );

	return 1;
	unguard;
}



