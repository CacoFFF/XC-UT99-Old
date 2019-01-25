
#include "XC_Engine.h"
#include "UnLinker.h"

#if 0
	#define guard_win32(func) {
	#define unguard_win32 }
	#define unguardf_win32(msg) }
#else
	#define guard_win32(func) guard(func)
	#define unguard_win32 unguard
	#define unguardf_win32(msg) unguardf(msg)
#endif

#if 0
	#define check_test(expr) 
#else
	#define check_test(expr) check(expr)
#endif



class FSurfaceInfo;
class FTransTexture;
class FSurfaceFacet;
#include "UnRenDev.h" //Avoid including UnRender.h to reduce compile times
#include "XC_Networking.h"
#include "UnCon.h"
#include "UnXC_Lev.h"
#include "UnXC_Travel.h"
#include "XC_LZMA.h"
#include "Cacus/CacusThread.h"
#include "Cacus/Atomics.h"
#include "Cacus/CacusString.h"
#include "Cacus/AppTime.h"

//CANNOT INCLUDE!
XC_CORE_API UBOOL FindPackageFile( const TCHAR* In, const FGuid* Guid, TCHAR* Out );
//Because I don't want to add extra includes
//Need to get rid of this

IMPLEMENT_CLASS(UXC_Level);

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

//Throw warning to compiler if one of these hacks is missing
inline void CompilerCheck()
{
/** Add these extra bitfield values in AActor as follows:

    BITFIELD bClientDemoNetFunc:1;
	//
	BITFIELD bNotRelevantToOwner:1; //Lag compensators love this
	BITFIELD bRelevantIfOwnerIs:1; //Good for player attachments
	BITFIELD bRelevantToTeam:1;
	BITFIELD bTearOff:1;
	BITFIELD bNetDirty:1;
	//
    class UClass* RenderIteratorClass GCC_PACK(4);

*/
	AActor* TestActor;
	TestActor->bNotRelevantToOwner = TestActor->bNotRelevantToOwner;
	TestActor->bRelevantIfOwnerIs = TestActor->bRelevantIfOwnerIs;
	TestActor->bRelevantToTeam = TestActor->bRelevantToTeam;
	TestActor->bSuperClassRelevancy = TestActor->bSuperClassRelevancy;
	TestActor->bTearOff = TestActor->bTearOff;
	TestActor->bNetDirty = TestActor->bNetDirty;
}



//====================================================
//====================================================
// Pending level hack
//====================================================
//====================================================

static FNetworkNotifyPL NetworkNotifyPL;

void FNetworkNotifyPL::CountBytesLeft( UNetConnection* Connection)
{
	BytesLeft = 0;
	for( INT i=0; i<Connection->PackageMap->List.Num(); i++ )
		if( Connection->PackageMap->List(i).PackageFlags & PKG_Need )
			BytesLeft += Connection->PackageMap->List(i).FileSize;
}


void FNetworkNotifyPL::SetPending( UPendingLevelMirror* NewPendingLevel)
{
	PendingLevel = NewPendingLevel;
	if ( PendingLevel->NetDriver )
		PendingLevel->NetDriver->Notify = this;
	LastPackageIndex = INDEX_NONE;
	CurrentDownloader = 0;
	DownloadedCount = 0;
}

void FNetworkNotifyPL::ReceiveNextFile( UNetConnection* Connection )
{
	UXC_NetConnectionHack* Conn = (UXC_NetConnectionHack*)Connection;
	guard(FNetworkNotifyPL::ReceiveNextFile);
	for( INT i=0; i<Conn->PackageMap->List.Num(); i++ )
		if( Conn->PackageMap->List(i).PackageFlags & PKG_Need )
		{
			Connection->ReceiveFile( i );
			if ( LastPackageIndex < 0 ) //First download
				LastPackageIndex = i;
			return;
		}
	if( *Conn->GetDownload() )
		delete *Conn->GetDownload();
	unguard;
}

EAcceptConnection FNetworkNotifyPL::NotifyAcceptingConnection()
{
	return PendingLevel->NotifyAcceptingConnection();
}

void FNetworkNotifyPL::NotifyAcceptedConnection( class UNetConnection* Connection )
{
	PendingLevel->NotifyAcceptedConnection( Connection );
}

UBOOL FNetworkNotifyPL::NotifyAcceptingChannel( class UChannel* Channel )
{
	return PendingLevel->NotifyAcceptingChannel( Channel );
}

ULevel* FNetworkNotifyPL::NotifyGetLevel()
{
	return PendingLevel->NotifyGetLevel();
}

void FNetworkNotifyPL::NotifyReceivedText( UNetConnection* Connection, const TCHAR* Text )
{
	if( ParseCommand( &Text, TEXT("WELCOME") ) )
	{
		UXC_NetConnectionHack* Conn = (UXC_NetConnectionHack*)Connection;

		check(Conn==PendingLevel->NetDriver->ServerConnection);
		debugf( NAME_DevNet, TEXT("Welcomed by server: WELCOME %s"), Text );

		// Parse welcome message.
		Parse( Text, TEXT("LEVEL="), PendingLevel->URL.Map );
		ParseUBOOL( Text, TEXT("LONE="), PendingLevel->LonePlayer );
		Parse( Text, TEXT("CHALLENGE="), Conn->Challenge );

		INT i;
		// Make sure all packages we need are downloadable.
		for( i=0; i<Conn->PackageMap->List.Num(); i++ )
		{
			TCHAR Filename[256];
			FPackageInfo& Info = Conn->PackageMap->List(i);
			if( !FindPackageFile( Info.Parent->GetName(), &Info.Guid, Filename ) )
			{
				appSprintf( Filename, TEXT("%s%s"), Info.Parent->GetName(), DLLEXT );
				if( !Filename[0] || GFileManager->FileSize(Filename) <= 0 )
				{
					// We need to download this package.
					PendingLevel->FilesNeeded++;
					Info.PackageFlags |= PKG_Need;

					if( !PendingLevel->NetDriver->AllowDownloads || !(Info.PackageFlags & PKG_AllowDownload) )
					{
						PendingLevel->Error = FString::Printf( TEXT("Downloading '%s' not allowed"), Info.Parent->GetName() );
						PendingLevel->NetDriver->ServerConnection->State = USOCK_Closed;
						return;
					}
				}
			}
		}

		guard(ExamineDownloaders);
		if ( PendingLevel->FilesNeeded )
		{
			UClass* XC_DL_CL = UObject::StaticLoadClass( UDownload::StaticClass(), NULL, TEXT("XC_IpDrv.XC_HTTPDownload"), NULL, LOAD_NoWarn | LOAD_Quiet, NULL );
			if ( XC_DL_CL )
			{
				//Find all standard IpDrv downloaders
				for ( i=0 ; i<Conn->GetDownloadInfo()->Num() ; i++ )
				{
					FDownloadInfo* InfoBase = &(*Conn->GetDownloadInfo())(i);
					if ( InfoBase->ClassName == TEXT("IpDrv.HTTPDownload") )
					{
						//Find matching XC_IpDrv downloader, delete IpDrv one if found
						UBOOL Found = 0;
						for ( INT j=0 ; j<Conn->GetDownloadInfo()->Num() ; j++ )
						{
							FDownloadInfo* InfoSub = &(*Conn->GetDownloadInfo())(j);
							if ( i != j
								&& InfoSub->Class == XC_DL_CL
								&& !appStricmp( *InfoSub->Params, *InfoBase->Params) )
							{
								Found = 1;
								debugf( NAME_DevNet, TEXT("Removing DownloadInfo(%i) due to redundancy with XC version"), i);
								Conn->GetDownloadInfo()->Remove(i--);
								break;
							}
						}

						//Not found, upgrade to XC_IpDrv
						if ( !Found )
						{
							InfoBase->ClassName = TEXT("XC_IpDrv.XC_HTTPDownload");
							InfoBase->Class = XC_DL_CL;
							debugf( NAME_DevNet, TEXT("Upgrading DownloadInfo(%i) to XC_HTTPDownload"), i);
						}
					}
				}
			}
		}
		unguard;

		ReceiveNextFile( Conn );
		CountBytesLeft( Conn );
		PendingLevel->Success = 1;
		return;
	}
	
	PendingLevel->NotifyReceivedText( Connection, Text );
}

UBOOL FNetworkNotifyPL::NotifySendingFile( UNetConnection* Connection, FGuid GUID )
{
	return PendingLevel->NotifySendingFile( Connection, GUID);
}


void FNetworkNotifyPL::NotifyReceivedFile( UNetConnection* Connection, INT PackageIndex, const TCHAR* InError, UBOOL Skipped )
{
	UXC_NetConnectionHack* Conn = (UXC_NetConnectionHack*)Connection;

	guard(UXC_PendingLevel::NotifyReceivedFile);
	check(Conn->PackageMap->List.IsValidIndex(PackageIndex));

	//New package means that we tried with method 0
	if ( LastPackageIndex != PackageIndex )
		CurrentDownloader = 0;

	// Map pack to package.
	FPackageInfo& Info = Conn->PackageMap->List(PackageIndex);
	TCHAR Filename[256];
	if( *InError || !FindPackageFile( Info.Parent->GetName(), &Info.Guid, Filename) )
	{
		if ( LastPackageIndex == PackageIndex ) //Redownload attempt detected
			CurrentDownloader++;
		
		if( Conn->GetDownloadInfo()->Num() > CurrentDownloader ) //Was 1
		{
			// Try with the next download method.
			//Connection->DownloadInfo.Remove(0);
			Exchange( (*Conn->GetDownloadInfo())(0), (*Conn->GetDownloadInfo())(CurrentDownloader));
			ReceiveNextFile( Conn );
			Exchange( (*Conn->GetDownloadInfo())(0), (*Conn->GetDownloadInfo())(CurrentDownloader));
		}
		else
		{
			// All download methods failed
			if( PendingLevel->Error==TEXT("") )
				PendingLevel->Error = FString::Printf( LocalizeError(TEXT("DownloadFailed"),TEXT("Engine")), Info.Parent->GetName(), InError );
		}
	}
	else
	{
		// Now that a file has been successfully received, mark its package as downloaded.
		check(Conn==PendingLevel->NetDriver->ServerConnection);
		check(Info.PackageFlags&PKG_Need);
		Info.PackageFlags &= ~PKG_Need;
		PendingLevel->FilesNeeded--;
		if( Skipped )
			Conn->PackageMap->List.Remove( PackageIndex );
		else
			DownloadedCount++;
		// Send next download request.
		ReceiveNextFile( Conn );
	}
	LastPackageIndex = PackageIndex;
	CountBytesLeft( Conn);
	unguard;
}

void FNetworkNotifyPL::NotifyProgress( const TCHAR* Str1, const TCHAR* Str2, FLOAT Seconds )
{
	INT TotalFiles = PendingLevel->FilesNeeded + DownloadedCount;
	TCHAR RemainingData[64] = TEXT("");
	INT KBytes = BytesLeft / 1024;
	if ( KBytes < 1 )
		appSprintf( RemainingData, TEXT("%iB"), BytesLeft);
	else if ( KBytes < 10 ) //KBytes with dots
		appSprintf( RemainingData, TEXT("%i.%iK"), KBytes, (BytesLeft % 1024) / 103);
	else if ( KBytes < 1024 ) //KBytes
		appSprintf( RemainingData, TEXT("%iK"), KBytes);
	else if ( KBytes < 1024*10 ) //MBytes with dots
		appSprintf( RemainingData, TEXT("%i.%iM"), KBytes / 1024, (KBytes % 1024) / 103);
	else
		appSprintf( RemainingData, TEXT("%iM"), KBytes / 1024);
	
	//Compose a list of full package data
	FString NewStr2 = FString(Str2) + TEXT("\n") + FString::Printf( LocalizeProgress(TEXT("RemainingFiles"),TEXT("XC_Core")), DownloadedCount+1, TotalFiles, RemainingData);
	PendingLevel->NotifyProgress( Str1, *NewStr2, Seconds);
}




//====================================================
//====================================================
// Level hack
//====================================================
//====================================================



enum EOwned { EPri_Owned=1 };
enum EGeneral { EPri_General=0 };

struct FActorPriority
{
	INT			Priority;	// Update priority, higher = more important.
	AActor*			Actor;		// Actor.
	UActorChannel*	Channel;	// Actor channel.
	UBOOL		SuperRelevant; //Skip owner checks later
	
	FActorPriority()
	{}
	//Use this on owned actors (NetOwner)
	FActorPriority( EOwned, FVector4& Location, FVector4& Dir, UNetConnection* InConnection, UActorChannel* InChannel, AActor* Target)
	{
		Actor = Target;
		Channel = InChannel;
		if ( Actor->bNotRelevantToOwner )
		{
			SuperRelevant = -1;
			Priority = -3000000;
			return;
		}
		FLOAT Time  = Channel ? (InConnection->Driver->Time - Channel->LastUpdateTime) : InConnection->Driver->SpawnPrioritySeconds;
		FLOAT Dot = (Actor == InConnection->Actor) ? 4.f : 1.5f;
		SuperRelevant = 1;
		if ( !Actor->bAlwaysRelevant )
		{
			if ( InConnection->Actor->Weapon == Actor )
				Dot += 1.0f;
			else if ( (Actor->RemoteRole > ROLE_DumbProxy) || (Actor->Physics != PHYS_None) )
			{
				FVector4 Delta( Actor->Location - Location);
				Dot += (Delta.Dot4(Dir) >= 0) ? 1.f : -1.f;  //Linux version doesn't have ASM, safe to use FVector4 local
			}
		}

		AActor* Sent = (Channel && Channel->Recent.Num()) ? (AActor*) &Channel->Recent(0) : NULL;
		FLOAT Pri = Actor->GetNetPriority( Sent, Time, InConnection->BestLag);
		Priority = appRound( (Dot + 3.0f) * Pri * 65536.f);

		if ( Actor->bNetOptional )
			Priority -= 3000000;
	}
	//Don't use this on owned actors (NetOwner)
	FActorPriority( EGeneral, FVector4& Location, FVector4& Dir, UNetConnection* InConnection, UActorChannel* InChannel, AActor* Target)
	{
		Actor = Target;
		Channel = InChannel;
		FLOAT Time  = Channel ? (InConnection->Driver->Time - Channel->LastUpdateTime) : InConnection->Driver->SpawnPrioritySeconds;
		FLOAT Dot = 0.f;
		SuperRelevant = 0;

		if ( !Actor->bAlwaysRelevant )
		{
			if ( (Actor->RemoteRole > ROLE_DumbProxy) || (Actor->Physics != PHYS_None) )
			{
				FVector4 Delta( Actor->Location - Location);
				Dot = (Delta.Dot4(Dir) >= 0) ? 1.f : -1.f;  //Linux version doesn't have ASM, safe to use FVector4 local
			}
		}
		APlayerPawn* NetOwner = InConnection->Actor;
		AActor* Sent = (Channel && Channel->Recent.Num()) ? (AActor*) &Channel->Recent(0) : NULL;

		if ( Actor == NetOwner->ViewTarget )
		{
			SuperRelevant = 1;
			Dot = 2.0f;
		}
		else if ( Actor->bAlwaysRelevant )
			SuperRelevant = 1;
		else if ( NetOwner->ViewTarget && (Actor->IsOwnedBy(NetOwner->ViewTarget) || Actor->Instigator == NetOwner->ViewTarget) )
		{
			if( !NetOwner->ViewTarget->IsA(APawn::StaticClass()) //ViewTarget not a pawn
				|| !Actor->IsA(AInventory::StaticClass())  //Actor not an item
				|| ((APawn*)NetOwner->ViewTarget)->Weapon == Actor ) //Actor is the pawn's weapon
				SuperRelevant = 1; //This prevents bursting a viewtarget's inventory chain
		}

		FLOAT Pri = Actor->GetNetPriority( Sent, Time, InConnection->BestLag);
		Priority = appRound( (Dot + 3.0f) * Pri * 65536.f);

		if ( Actor->bNetOptional )
			Priority -= 3000000;
	}

	friend INT Compare( const FActorPriority* A, const FActorPriority* B )
	{
		if ( A->SuperRelevant != B->SuperRelevant )
			return B->SuperRelevant - A->SuperRelevant;
		return B->Priority - A->Priority;
	}
};

static UBOOL OwnedByAPlayer( const AActor* Test)
{
	for ( ; Test ; Test=Test->Owner )
		if ( Test->IsA(APlayerPawn::StaticClass()) && Cast<UNetConnection>(((APlayerPawn*)Test)->Player) )
			return true;
	return false;
}



MS_ALIGN(16) struct LineCheckHelper
{
	FBspNode* Nodes;
	FBspSurf* Surfs;
	INT Depth; //Cutoff at 63 depth, avoid stack overflows
	INT Pad;
	FVector4 V[63]; //0=End

	LineCheckHelper( FBspNode* InNodes, FBspSurf* InSurfs)
		: Nodes(InNodes)
		, Surfs(InSurfs)
		, Depth(1)
	{
		ST_Traces++;
	}

	BYTE CheckTransAlt( INT iNode, FVector4* End, FVector4* Start, BYTE Outside )
	{
		if ( Depth >= 63 )
			return 0;
		FVector4 *Middle = &V[Depth++];
		while( iNode != INDEX_NONE )
		{
			const FBspNode&	Node = (const FBspNode&)Nodes[iNode];
			FLOAT Dist[2];
			DoublePlaneDotU( &Node.Plane, Start, End, Dist);
			BYTE  NotCsg = (Node.NodeFlags & NF_NotCsg);
			INT   G1 = *(INT*)&Dist[0] >= 0;
			INT   G2 = *(INT*)&Dist[1] >= 0;
			if( G1!=G2 )
			{
				*Middle = FLinePlaneIntersectDist( Start, End, Dist); //GCC may crash here
				if ( !CheckTransAlt(Node.iChild[G2],Middle,End,G2^((G2^Outside) & NotCsg)) )
				{
					Depth--;
					return 0;
				}
				End = Middle;
			}
			Outside = G1^((G1^Outside)&NotCsg);
			//Collision against non occluding surf
			if ( !Outside && (Node.iSurf != INDEX_NONE) && (Surfs[Node.iSurf].PolyFlags & PF_NoOcclude) )
				Outside = 1;
			iNode = Node.iChild[G1];
		}
		Depth--;
		return Outside;
	}

} GCC_ALIGN(16);


//See if actor is relevant to a player
static UBOOL ActorIsRelevant( AActor* Actor, APlayerPawn* Player, AActor* Viewer, FVector4* ViewPos, const FVector4& EndOffset)
{
//	if ( Actor->bAlwaysRelevant ) //Handled by super relevant
//		return 1;
	if ( Actor->AmbientSound && ((*ViewPos-Viewer->Location).SizeSquared() < Square(25.0f*Actor->SoundRadius)) )
		return 1;
	if ( Actor->Owner )
	{
		// Added extra conditions to prevent replicating items from view target
		if ( Actor->IsOwnedBy(Viewer) && (Viewer == Player || !Actor->IsA(AInventory::StaticClass())) ) 
			return 1;
		if ( Actor->Owner->bIsPawn && ((APawn*)Actor->Owner)->Weapon == Actor )
			return ActorIsRelevant( Actor->Owner, Player, Viewer, ViewPos, EndOffset);
	}
	if ( (Actor->bHidden || Actor->bOnlyOwnerSee) && !Actor->bBlockPlayers && !Actor->AmbientSound )
		return 0;
	if ( !Viewer->XLevel->Model->Nodes.Num() ) //Additive level?
		return Viewer->XLevel->Model->RootOutside;

	BYTE Buffer[sizeof(LineCheckHelper)+16];
	LineCheckHelper* Helper = new( (void*)((((DWORD)&Buffer)+15)&0xFFFFFFF0), E_Place) 
		LineCheckHelper(&Viewer->XLevel->Model->Nodes(0),&Viewer->XLevel->Model->Surfs(0));
	*(DWORD*)&ViewPos->W = 0xBF800000; //-1.f, no FPU
	Helper->V[0].X = Actor->Location.X + EndOffset.X * Actor->CollisionRadius;
	Helper->V[0].Y = Actor->Location.Y + EndOffset.Y * Actor->CollisionRadius;
	Helper->V[0].Z = Actor->Location.Z + EndOffset.Z * Actor->CollisionHeight;
	*(DWORD*)&Helper->V[0].W = 0xBF800000; //-1.f, no FPU

	return Helper->CheckTransAlt( 0, ViewPos, Helper->V, Viewer->XLevel->Model->RootOutside);
}

static UBOOL ActorIsNeverRelevant( AActor* Actor) //Helps discard a few dozens more actors
{
	if ( Actor->RemoteRole == ROLE_None )
		return 1;
	if ( Actor->bAlwaysRelevant || Actor->bRelevantIfOwnerIs || Actor->bRelevantToTeam || Actor->NetTag ) //NetTag tells us the actor has possibly been replicated!
		return 0;
	if ( Actor->IsA(APlayerPawn::StaticClass()) && ((APlayerPawn*)Actor)->Player )
		return 0;
	if ( Actor->bHidden && !Actor->Owner && !Actor->AmbientSound && !Actor->bBlockPlayers )
		return 1;
	return 0;
}

//Fix this if old relevancy was toggled
//If True, actor is to be globally checked
static FLOAT UpdateNetTag( AActor* Other, FLOAT DeltaTime)
{
	Other->NetTag &= 0x7FFFFFFF; //Become positive
	FLOAT& NetTime = *(FLOAT*) &Other->NetTag;
	FLOAT OldValue;
	if ( NetTime > 99.f || appIsNan(NetTime) )
		OldValue = NetTime = 0;
	else
	{
		OldValue = NetTime;
		NetTime += DeltaTime;
	}
	return OldValue;
}


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

	if ( (&GPendingLevel)[b451Setup] )
		NetworkNotifyPL.SetPending( (UPendingLevelMirror*) (&GPendingLevel)[b451Setup] );
	
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
//					TCHAR Msg[512];
//					appSprintf( Msg, TEXT("AutoCompressing %s to %s"), FileName_Base, FileName_LZMA);
//					debugf( NAME_Log, Msg);
					TCHAR* Msg;
#ifdef UNICODE
					Msg = (TCHAR*)CWSprintf( TEXT("AutoCompressing %s to %s"), FileName_Base, FileName_LZMA);
#else
					Msg = CSprintf( "AutoCompressing %s to %s", FileName_Base, FileName_LZMA);
#endif
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

static UBOOL PackageNeedsDemoFix( const TCHAR* PkgName)
{
	guard( PackageNeedsDemoFix);
	TCHAR AnnouncerText[] = {'A','n','n','o','u','n','c','e','r', 0 };
	TCHAR CreditsText[] = {'C','r','e','d','i','t','s', 0 };
	const TCHAR* DemoPkgs[] = { AnnouncerText, CreditsText};

	for ( INT i=0 ; i<2 ; i++ )
		if ( appStricmp(DemoPkgs[i], PkgName) == 0 )
			return 1;
	return 0;
	unguard;
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
	if( !SpawnClass)
	{
		debugf( NAME_Warning, TEXT("SpawnActor failed because no class was specified") );
		return NULL;
	}
	if(SpawnClass->ClassFlags & CLASS_Abstract )
	{
		debugf( NAME_Warning, TEXT("SpawnActor failed because class %s is abstract"), SpawnClass->GetName() );
		return NULL;
	}
	else if( !SpawnClass->IsChildOf(AActor::StaticClass()) )
	{
		debugf( NAME_Warning, TEXT("SpawnActor failed because %s is not an actor class"), SpawnClass->GetName() );
		return NULL;
	}
	else if( !GIsEditor && (SpawnClass->GetDefaultActor()->bStatic || SpawnClass->GetDefaultActor()->bNoDelete) )
	{
		debugf( NAME_Warning, TEXT("SpawnActor failed because class %s has bStatic or bNoDelete"), SpawnClass->GetName() );
		return NULL;		
	}

	// Use class's default actor as a template.
	if( !Template )
		Template = SpawnClass->GetDefaultActor();
	check(Template!=NULL);

	// Make sure actor will fit at desired location, and adjust location if necessary.
	if( (Template->bCollideWorld || (Template->bCollideWhenPlacing && (GetLevelInfo()->NetMode != NM_Client))) && !bNoCollisionFail )
		if( !FindSpot( Template->GetCylinderExtent(), Location, 0, 1 ) )
			return NULL;

	// Add at end of list.
	INT iActor = Actors.Add();
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
	Actor->eventPreBeginPlay();
	Actor->eventBeginPlay();
	if( Actor->bDeleteMe )
		return NULL;

	// Set the actor's zone.
	SetActorZone( Actor, iActor==0, 1 );

	// Send PostBeginPlay.
	Actor->eventPostBeginPlay();

	// Check for encroachment.
	if( !bNoCollisionFail && CheckEncroachment( Actor, Actor->Location, Actor->Rotation, 0 ) )
	{
		DestroyActor( Actor );
		return NULL;
	}

	// Init scripting.
	Actor->eventSetInitialState();

	// Find Base
	if( !Actor->Base && Actor->bCollideWorld
		 && (Actor->IsA(ADecoration::StaticClass()) || Actor->IsA(AInventory::StaticClass()) || Actor->IsA(APawn::StaticClass())) 
		 && ((Actor->Physics == PHYS_None) || (Actor->Physics == PHYS_Rotating)) )
		Actor->FindBase();

	// Success: Return the actor.
	if( InTick )
		NewlySpawned = new(GEngineMem)FActorLink(Actor,NewlySpawned);

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
// Welcome a new player joining this server.
//
void UXC_Level::WelcomePlayer( UNetConnection* Connection, TCHAR* Optional )
{
	guard(ULevel::WelcomePlayer);

	Connection->PackageMap->Copy( Connection->Driver->MasterMap );
	Connection->SendPackageMap();
	Connection->Logf( TEXT("XC_ENGINE VERSION=%i"), ((UXC_GameEngine*)Engine)->Version ); //Find a way to make clients interpret this
	if( Optional[0] )
		Connection->Logf( TEXT("WELCOME LEVEL=%s LONE=%i %s"), GetOuter()->GetName(), GetLevelInfo()->bLonePlayer, Optional );
	else
		Connection->Logf( TEXT("WELCOME LEVEL=%s LONE=%i"), GetOuter()->GetName(), GetLevelInfo()->bLonePlayer );
	Connection->FlushNet();

	unguard;
}

static int32 LastServerSecond = -1;
void UXC_Level::TickNetServer( FLOAT DeltaSeconds )
{
	guard(UXC_Level::TickNetServer);

	if ( ! ((UXC_GameEngine*)Engine)->bUseNewRelevancy )
	{
		Super::TickNetServer( DeltaSeconds);
		return;
	}

	// Update window title
	{	//FTime's high 32 bits are seconds
		int32 CurServerSecond = ((int32*)&TimeSeconds)[1];
		if ( LastServerSecond != CurServerSecond )
		{
			debugf( NAME_Title, LocalizeProgress(TEXT("RunningNet"),TEXT("Engine")), *GetLevelInfo()->Title, *URL.Map, NetDriver->ClientConnections.Num() );
			LastServerSecond = CurServerSecond;
		}
	}
//	if( (INT)(TimeSeconds-DeltaSeconds)!=(INT)(TimeSeconds.GetFloat()) )
//		debugf( NAME_Title, LocalizeProgress(TEXT("RunningNet"),TEXT("Engine")), *GetLevelInfo()->Title, *URL.Map, NetDriver->ClientConnections.Num() );
	
	clock(NetTickCycles);
	INT Updated = ServerTickClients( DeltaSeconds);
	unclock(NetTickCycles);

	// Stats.
	static INT SkipCount = 0;
	static FLOAT AccTickRate = 0;

	if ( Updated )
	{
		SkipCount++;
		AccTickRate += DeltaSeconds;
	}
	if( Updated && (20.f > appFrand()*Engine->CurrentTickRate) )
	{
		static INT NumActors;
		NumActors = 0;
		FLOAT TickRate = 0;
		for( INT i=0; i<NetDriver->ClientConnections.Num(); i++ )
		{
			UNetConnection* Connection = NetDriver->ClientConnections(i);
			if( Connection->Actor && Connection->State==USOCK_Open )
			{
				if( Connection->UserFlags&1 )
				{
					if ( !NumActors ) //Prevent multiple UserFlag clients from using extra CPU cycles
					{
						AccTickRate = GetLevelInfo()->TimeDilation * (FLOAT)SkipCount / AccTickRate;
						TickRate = Engine->GetMaxTickRate();
						NumActors = iFirstDynamicActor - 1; //No brush lol
						for( INT ii=iFirstDynamicActor; ii<Actors.Num(); ii++ )
							NumActors += Actors(ii)!=NULL;
					}

					TCHAR FPS_Str[16];
					appSprintf(FPS_Str, (TickRate < 100.f) ? TEXT("%04.1f") : TEXT("%05.1f"), AccTickRate);
					FString Stats = FString::Printf
					(
						TEXT("r=%s (%02.0f) cli=%i act=%03.1f (%i) net=%03.1f pv/c=%i rep/c=%i trace/c=%i"),
						FPS_Str,
						TickRate,
						NetDriver->ClientConnections.Num(),
						GSecondsPerCycle*1000*ActorTickCycles,
						NumActors,
						FPlatformTime::ToMilliseconds( NetTickCycles),
						NumPV/NetDriver->ClientConnections.Num(),
						NumReps/NetDriver->ClientConnections.Num(),
						ST_Traces/(NetDriver->ClientConnections.Num() * SkipCount)
					);
					Connection->Actor->eventClientMessage( *Stats, NAME_None, 0 );

				}
				if( Connection->UserFlags&2 )
				{
					FString Stats = FString::Printf
					(
						TEXT("snd=%02.1f recv=%02.1f"),
						GSecondsPerCycle*1000*Connection->Driver->SendCycles,
						GSecondsPerCycle*1000*Connection->Driver->RecvCycles
					);
					Connection->Actor->eventClientMessage( *Stats, NAME_None, 0 );
				}
			}
		}
		AccTickRate = 0;
		SkipCount = 0;
		ST_Traces = 0;
	}
	NumPV = 0;
	NumReps = 0;

	unguard;
}


//Burst forces actors to be replicated at full rate if not relevant
//Has to be used with extreme care as it increases check count
#define BURST_OWNED_COUNT 100
#define BURST_AR_COUNT 50

//Multithreaded relevancy builder (one of these days)
MS_ALIGN(16) struct FConnectionRelevancyList
{
	UXC_NetConnectionHack* Connection;	//O=0
	FConnectionRelevancyList* Next;	//O=4

	FActorPriority* PriorityArray;	//O=8
	FActorPriority** PriorityRefs;	//O=12

	AActor** ConsiderList;			//O=16
	INT ConsiderListSize;			//O=20
	INT OwnedConsiderListStart;		//O=24 (where our owned actors start in main consider list, not used in relevancy loop)
	INT OwnedConsiderListSize;		//O=28
	INT SpecialConsiderListSize;	//O=32

	FRotator Rotation;				//O=36
	FVector4 Location;				//O=48 (FVector4 has alignment=16)
	FVector4 ViewDir;				//O=64 (FVector4 has alignment=16)
	AActor* Viewer;					//O=80
	INT PriorityCount;				//O=84
	INT Pad[2];

	FConnectionRelevancyList( UNetConnection* InConn, FConnectionRelevancyList* InNext, INT InID)
		:	Connection( (UXC_NetConnectionHack*)InConn)
		,	Next( InNext)
	{};

	//This is a multithread nightmare, let's put it on main thread for now
	void GetViewerCoordinates()
	{
		// Get viewer coordinates.
		Location  = FVector4( Connection->Actor->Location, -1.f);
		Rotation  = Connection->Actor->ViewRotation;
		Viewer    = Connection->Actor;
		Connection->Actor->eventPlayerCalcView( Viewer, Location, Rotation );
		check(Viewer);
	}
	
	void AddPriority( AActor* Actor, UActorChannel* Channel, UBOOL bOwned, UBOOL SuperRelevancyCondition=0, INT SuperRelevancyValue=0)
	{
		if ( bOwned )	PriorityArray[PriorityCount] = FActorPriority( EPri_Owned,   Location, ViewDir, Connection, Channel, Actor);
		else			PriorityArray[PriorityCount] = FActorPriority( EPri_General, Location, ViewDir, Connection, Channel, Actor);
		if ( SuperRelevancyCondition )
			PriorityArray[PriorityCount].SuperRelevant = SuperRelevancyValue;
		PriorityRefs[PriorityCount] = PriorityArray + PriorityCount;
		PriorityCount++;
	}

	// Returns amount of Super Relevants
	INT SortPriorities()
	{
		guard_win32(SortPriorities);

		INT i;
#if 0 && _WINDOWS
		//Sorts first by super relevancy (3 blocks), then by priority within each block
		Sort( PriorityRefs, PriorityCount);
		for ( i=0 ; i<PriorityCount && PriorityRefs[i]->SuperRelevant>0 ; i++);
		INT SuperRelevantCount = i;
		for ( ; i<PriorityCount && PriorityRefs[i]->SuperRelevant==0 ; i++ );
		PriorityCount = i; //Leave negative SuperRelevants out
#else
		//For some reason Sort template is broken in linux
		INT SuperRelevantCount = 0;
		for ( i=0 ; i<PriorityCount ; i++ )
		{
			if ( PriorityRefs[i]->SuperRelevant > 0 )
				Exchange( PriorityRefs[i], PriorityRefs[SuperRelevantCount++]);
			else if ( PriorityRefs[i]->SuperRelevant < 0 )
				Exchange( PriorityRefs[i--], PriorityRefs[--PriorityCount]); //'i' needs to be checked again
		}
		const INT Bounds[3] = { 0, SuperRelevantCount, PriorityCount};
		for ( INT Stage=1 ; Stage<ARRAY_COUNT(Bounds) ; Stage++ )
		{
			const INT Top = Bounds[Stage];
			for ( i=Bounds[Stage-1] ; i<Top ; i++ ) //i=Base
			{
				INT Highest = i;
				for ( INT j=i+1 ; j<Top ; j++ ) //j=Comparand
					if ( PriorityRefs[Highest]->Priority < PriorityRefs[j]->Priority )
						Highest = j;
				if ( Highest != i )
					Exchange( PriorityRefs[Highest], PriorityRefs[i]);
			}
		}
#endif


		return SuperRelevantCount;
		unguard_win32;
	}


	void ReplicatePawn( UActorChannel* Channel)
	{
		guard(ReplicatePawn);
		INT RepFlags = 0;
		FVector ModifyLocation;
		*(INT*)&ModifyLocation = 0; //Kill a warning by setting bogus loc
		//0x01 = Location (skip)
		//0x02 = Location (force higher Z)
		//
		APawn* NewPawn = (APawn*)Channel->Actor;
		if ( Channel->Recent.Num() )
		{
			APawn* OldPawn = (APawn*)Channel->Recent.GetData();
			FLOAT Delta = Connection->Driver->Time - Channel->LastUpdateTime;

			INT SkippedVelocity = 0;
			if ( (appRound(NewPawn->Velocity.X) == appRound(OldPawn->Velocity.X))
				&& (appRound(NewPawn->Velocity.Y) == appRound(OldPawn->Velocity.Y))
				&& (appRound(NewPawn->Velocity.Z) == appRound(OldPawn->Velocity.Z)) )
			{
				OldPawn->Velocity = NewPawn->Velocity;
				SkippedVelocity = 1;
			}

			//Pawn walked up, likely stairs
			if ( (NewPawn->Physics == PHYS_Walking) && (NewPawn->Location.Z - OldPawn->Location.Z > 7.f) )
				OldPawn->ColLocation.X = 0.1;

			//If walked up, burst location updates for 0.1 second
			if ( OldPawn->ColLocation.X > 0 )
			{
				RepFlags |= 0x02;
				OldPawn->ColLocation.X -= Delta;
			}
			else if ( NewPawn->Physics == PHYS_None || NewPawn->Physics == PHYS_Rotating )
			{}
			else if ( SkippedVelocity ) //Only do this if we're sure the client has the correct velocity
			{
				ModifyLocation = OldPawn->Location + OldPawn->Velocity * Delta;
				FVector ModifyDelta = NewPawn->Location - ModifyLocation;
				//Pawn is running
				if ( NewPawn->Physics == PHYS_Walking )
				{
					//Consider skipping location update
					if ( (ModifyDelta.SizeSquared2D() < 4.0f) && (ModifyDelta.Z < 7.f) && (ModifyDelta.Z > -15.f) )
					{
						RepFlags |= 0x01;
						OldPawn->Location = NewPawn->Location; //Do not update
					}
				}
				else if ( ((ModifyLocation - NewPawn->Location) * FVector(1.0f,1.0f,0.2f)).SizeSquared() < 4.0f)
				{
					RepFlags |= 0x01;
					OldPawn->Location = NewPawn->Location;
				}
		

			}
			OldPawn->OldLocation.Z = OldPawn->ColLocation.Z;
			OldPawn->ColLocation.Z = OldPawn->Location.Z;
		}

		float ZTransform = 0.0f;
		if ( RepFlags & 0x02 ) //Forcing an update
			ZTransform += 1.5f;
		if ( !(RepFlags & 0x01) && NewPawn->Physics == PHYS_Walking )
			ZTransform += 1.0f;
		NewPawn->Location.Z += ZTransform;
		Channel->ReplicateActor();
		NewPawn->Location.Z -= ZTransform;
		if ( RepFlags & 0x01 )
			((APawn*)Channel->Recent.GetData())->Location = ModifyLocation;
		
		unguard;
	}
	
	void ReplicateActor( UActorChannel* Channel)
	{
		AActor* Actor = Channel->Actor;
		if ( Channel->Recent.Num() ) //This forces a skip in rotation update if only the first byte changed
		{
			AActor* OldActor = (AActor*)Channel->Recent.GetData();
			*(uint8*)&OldActor->Rotation.Pitch = *(uint8*)&Actor->Rotation.Pitch;
			*(uint8*)&OldActor->Rotation.Yaw   = *(uint8*)&Actor->Rotation.Yaw;
			*(uint8*)&OldActor->Rotation.Roll  = *(uint8*)&Actor->Rotation.Roll;
		}
		UClass*& ActorClass = *(UClass**)((BYTE*)Actor + 36);
		UClass* RealClass = ActorClass;
//		check_test( Channel->ActorClass);
		ActorClass = Channel->ActorClass;
		if ( Actor->bSimulatedPawn )
			ReplicatePawn( Channel);
		else
			Channel->ReplicateActor();
		ActorClass = RealClass;
	}
	
	UClass* FindNetworkSuperClass( AActor* Actor) //Actor->bSuperClassRelevancy
	{
		UClass* Result = Actor->GetClass();
		while ( Result && (Result != AActor::StaticClass()) )
		{
			if ( (Result->ClassFlags & CLASS_Abstract) || (Connection->PackageMap->ObjectToIndex(Result) == INDEX_NONE) )
				Result = Result->GetSuperClass();
			else
				return Result;
		}
		return NULL;
	}

	
	void RelevancyLoop( FLOAT RealDelta, FLOAT MaxTickRate, INT ConnID)
	{
		guard_win32(RelevancyLoop);
		PriorityCount = 0;


		guard_win32(SetupTraceStart);
		GetViewerCoordinates();
		if ( Connection->TickCount & 1 ) //Happens every 2 frames
		{
			FLOAT TMult = (Connection->TickCount & 2) ? 0.4f : 0.9f; //Pick 0.4 or 0.9 seconds (one frame 0.4, next 0.9 and so on)
			FVector4 Ahead = Location + Viewer->Velocity * TMult;
			if ( Viewer->Base ) //Add platform/lift velocity to the Ahead calc
				Ahead += Viewer->Base->Velocity * TMult;
			if ( Viewer->XLevel->Model->FastLineCheck( Ahead, Location) )
				Location = Ahead;
		}
		unguard_win32;

		TArray<AActor*>* ST = Connection->GetSentTemporaries();
		INT i;

		//Skip sent temporaries (set NetTag to negative)
		for ( i=0 ; i<ST->Num() ; i++ )
			(*ST)(i)->NetTag |= 0x80000000;

		FVector4 Dir( Rotation.Vector(), 0.f); //0.f is critical
		TMap<AActor*,UActorChannel*>* AC = Connection->GetActorChannels();
		TArray<UChannel*>* OC = Connection->GetOpenChannels();
		
		//Ez mode
		FLOAT OffsetFloat = (FLOAT)ConnID * 0.045;
		INT ChannelCount = OC->Num();
		INT ExpectedChannelCount = ChannelCount + Min(OwnedConsiderListSize, BURST_OWNED_COUNT);
		UBOOL bChannelsSaturated = ChannelCount > 800; //Change later!

		//Prioritize owned actors first
		guard_win32(PrioritizeOwned);
		AActor** OwnedConsiderList = &ConsiderList[OwnedConsiderListStart];
		for ( i=0 ; i<OwnedConsiderListSize ; i++ )
		{
			AActor* Actor = OwnedConsiderList[i];
			if ( Actor->NetTag >= 0 )
			{
				UBOOL bPrioritize = 0;
				UActorChannel* Channel = AC->FindRef(Actor);

				if ( !Channel && (i < BURST_OWNED_COUNT) ) //Force prioritization when bursting
					bPrioritize = 1;
				else if ( Actor->bAlwaysRelevant ) //Already passed general check time earlier
				{
					bPrioritize = !( Actor->CheckRecentChanges() && Channel && Channel->Recent.Num() && !Channel->Dirty.Num() && Actor->NoVariablesToReplicate( (AActor*) &Channel->Recent(0)) );
					if ( !bPrioritize ) //bAlwaysRelevant actor skips an update
						Channel->RelevantTime = Connection->Driver->Time;
				}
				else
				{
					FLOAT UF = Actor->UpdateFrequency( Viewer, Dir, Location);
					bPrioritize = (UF >= MaxTickRate) || (appRound( (*(FLOAT*)&Actor->NetTag + OffsetFloat)*UF) != appRound( (*(FLOAT*)&Actor->NetTag + OffsetFloat - RealDelta)* UF));
					//Owned actors shouln't spread updates, do not add to OffsetFloat
				}

				if ( bPrioritize )
				{
					AddPriority( Actor, Channel, EPri_Owned);
					if ( bChannelsSaturated && (i >= BURST_OWNED_COUNT) && (PriorityArray[PriorityCount-1].SuperRelevant == 1) && !Actor->bHidden && !Actor->Inventory && (Actor != Connection->Actor) )
						PriorityArray[PriorityCount-1].SuperRelevant = 0; //We can afford to lose visible owned actors above burst capacity
				}
			}
		}
		unguardf_win32( (TEXT("[%i/%i]"), i, OwnedConsiderListSize));

		//Spectator: artificially reduce tickrate to half when updating non-owned stuff
		//Update owned stuff as usual, but update others at half the rate
		UBOOL bSkipMainPri = 0; //Do not prioritize, simply fix NetTag
		if ( (Connection->UserFlags&32) || (Connection->Actor->PlayerReplicationInfo && Connection->Actor->PlayerReplicationInfo->bIsSpectator) )
		{
			bSkipMainPri = Connection->TickCount & 1; //This will prevent the general loop
			RealDelta *= 2.f;
			MaxTickRate *= 0.5f;
		}

		//If this is negative, then the channel list is expected to be FULL by end of this function
		INT DiscardCount = Max( 0, ExpectedChannelCount-923); //Use 100+(0 to FrameRate) channels as 'empty' buffer

		//Actors exist, have role
		guard_win32(PrioritizeActors);
		i = bSkipMainPri ? ConsiderListSize : 0; //If skipping, set i=ConsiderListSize to avoid updating
		for ( ; i<SpecialConsiderListSize ; i++ ) //Process specials, super branchy code
		{
			AActor* Actor = ConsiderList[i];
			if ( Actor->NetTag > 0 )
			{
				FLOAT UF = Actor->NetUpdateFrequency;
				OffsetFloat += 0.023f;
				if ((UF >= MaxTickRate) || (appRound((*(FLOAT*)&Actor->NetTag + OffsetFloat)*UF) != appRound((*(FLOAT*)&Actor->NetTag + OffsetFloat - RealDelta)* UF)))
				{
					UBOOL SuperRelevancy = 1; //SuperRelevancy override
					UActorChannel* Channel = AC->FindRef(Actor);

					if ( Actor->bRelevantIfOwnerIs && (!Actor->Owner || !AC->FindRef(Actor->Owner)) ) //Immediately close channel if owner isn't relevant
					{
						if (Channel)
							Channel->Close();
						continue;
					}

					if (Actor->bRelevantToTeam) //Can be combined with above condition
					{
						APlayerReplicationInfo* PRI = Connection->Actor->PlayerReplicationInfo;
						if ( !PRI || (PRI->bIsSpectator && !PRI->bWaitingPlayer) )
							continue;
						UByteProperty* TeamProperty = Cast<UByteProperty>(FindScriptVariable(Actor->GetClass(), TEXT("Team"), NULL));
						SuperRelevancy = -1;
						if (TeamProperty && (*(((BYTE*)Actor) + TeamProperty->Offset) == PRI->Team)) //Same team
						{
							SuperRelevancy = 1;
							//Treated as bAlwaysRelevant, can skip updates
							if (Actor->CheckRecentChanges() && Channel && Channel->Recent.Num() && !Channel->Dirty.Num() && Actor->NoVariablesToReplicate((AActor*)&Channel->Recent(0)))
							{
								Channel->RelevantTime = Connection->Driver->Time;
								continue;
							}
						}
						else if (!Channel) //No channel, don't even bother prioritizing
							continue;
					}

					AddPriority( Actor, Channel, Actor->IsOwnedBy(Connection->Actor), true, SuperRelevancy);
				}
			}
		}
		
		INT Top = OwnedConsiderListStart;
		while ( i<ConsiderListSize )
		{
			for ( ; i<Top ; i++ )
			{
				AActor* Actor = ConsiderList[i];
				check(Actor);
				if ( Actor->NetTag > 0 )
				{
					UBOOL bPrioritize = 0;
					UActorChannel* Channel = AC->FindRef(Actor);
					if ( Actor->bAlwaysRelevant ) //Already passed general check time earlier
					{
						bPrioritize = !( Actor->CheckRecentChanges() && Channel && Channel->Recent.Num() && !Channel->Dirty.Num() && Actor->NoVariablesToReplicate( (AActor*) &Channel->Recent(0)) );
						if ( !bPrioritize ) //bAlwaysRelevant actor skips an update
							Channel->RelevantTime = Connection->Driver->Time;
					}
					else
					{
						FLOAT UF = Actor->UpdateFrequency( Viewer, Dir, Location);
						bPrioritize = (UF >= MaxTickRate) || (appRound( (*(FLOAT*)&Actor->NetTag + OffsetFloat)*UF) != appRound( (*(FLOAT*)&Actor->NetTag + OffsetFloat - RealDelta)* UF));
						OffsetFloat += 0.023f;
					}
	
					if ( bPrioritize ) //In case of saturation, visible actors can be lost
						AddPriority( Actor, Channel, 0, bChannelsSaturated && !Actor->bHidden && (Actor != Connection->Actor), 0);
				}
			}
			//Reached owner list, bypass it
			if ( Top == OwnedConsiderListStart )
				i = OwnedConsiderListStart + OwnedConsiderListSize;
			else
				i = ConsiderListSize;
			Top = ConsiderListSize;
		}
		unguardf_win32( (TEXT("[%i/%i]"), i, ConsiderListSize));
		Connection->LastRepTime = Connection->Driver->Time;

		//SentTemporaries skipped, reset
		for ( i=0 ; i<ST->Num() ; i++ )
			(*ST)(i)->NetTag &= 0x7FFFFFFF;
		
		//Too many super relevants, discard less
		INT SuperRelevantCount = SortPriorities();
		if ( PriorityCount - DiscardCount < SuperRelevantCount )
			DiscardCount = PriorityCount - SuperRelevantCount;

		UNetDriver* NetDriver = Connection->Driver;
		
		//Close 1 channel or discard every 0.25 second
		if ( DiscardCount > 0 )
		{
			guard_win32(DiscardOne);
			INT FrameRate = Clamp( appRound(MaxTickRate) >> 2, 5, 50);
			if ( Connection->TickCount % FrameRate == 0 )
			{
				if ( PriorityRefs[PriorityCount-1]->Channel )
					PriorityRefs[PriorityCount-1]->Channel->Close();
				PriorityCount--;
			}
			unguard_win32;
		}

		INT Updated = 0;
		static FVector4 EndOffset; //Not thread safe, but 100% exception free
		EndOffset = FVector4(VRand(), 1.f);
		EndOffset.X *= 0.95;
		EndOffset.Y *= 0.95;
		EndOffset.Z *= 0.95;

		guard_win32(Relevancy);
		for ( i=0 ; i<PriorityCount ; i++ )
		{
			UActorChannel* Channel = PriorityRefs[i]->Channel;
			if ( !Channel && ChannelCount > 1022 ) //We don't need to perform a check if the list is saturated
				continue;

			AActor* Actor = PriorityRefs[i]->Actor;
			UBOOL IsRelevant = PriorityRefs[i]->SuperRelevant;
			if ( IsRelevant == -1 ) //Do not run relevancy checks
				IsRelevant = 0;
			else if ( !IsRelevant && (!Channel || (NetDriver->Time - Channel->RelevantTime > 0.3f)) )
				IsRelevant = ActorIsRelevant( Actor, Connection->Actor, Viewer, &Location, EndOffset);

			
			if( IsRelevant || (Channel && NetDriver->Time-Channel->RelevantTime < NetDriver->RelevantTimeout) )
			{
				Actor->XLevel->NumPV++;
				
				if( !Channel )
				{
					UClass* BestClass = Actor->GetClass();
					if ( (Connection->PackageMap->ObjectToIndex(BestClass) != INDEX_NONE) ||
						(Actor->bSuperClassRelevancy && ((BestClass=FindNetworkSuperClass(Actor)) != NULL)) )
					{
						Channel = (UActorChannel*)Connection->CreateChannel( CHTYPE_Actor, 1, INDEX_NONE);
						if ( Channel )
						{
							if ( BestClass != Actor->GetClass() ) //SuperHack
							{
								UClass** ClassAddr = ((UClass**)Actor) + 9; //Offset 36
								Exchange( BestClass, ClassAddr[0]);
								Channel->SetChannelActor( Actor );
								Exchange( BestClass, ClassAddr[0]);
							}
							else
								Channel->SetChannelActor( Actor );
							ChannelCount++;
						}
					}
				}
				if ( Channel )
				{
					if ( !Connection->IsNetReady(0) )
						break;
					if( IsRelevant )
						Channel->RelevantTime = NetDriver->Time + (0.1f + appFrand());
					if( Channel->IsNetReady(0) )
					{
						ReplicateActor( Channel);
						Updated++;
					}
					if ( !Connection->IsNetReady(0) )
						break;
				}
			}
			else if ( Channel && (Actor != Connection->Actor)) //Never close the local player's channel
				Channel->Close();
				
		}

		//Saturation flag
		if ( i < PriorityCount )
			Connection->UserFlags |= 32;
		else
			Connection->UserFlags &= ~32;
		
		//Make sure channels don't go past RelevantTimeout if they don't have to during saturation
		for ( ; i<PriorityCount ; i++ )
		{
			UActorChannel* Channel = PriorityRefs[i]->Channel;
			if ( Channel && (NetDriver->Time-Channel->RelevantTime < NetDriver->RelevantTimeout - 1.1f) )
			{
				AActor* Actor = PriorityRefs[i]->Actor;
				UBOOL IsRelevant = PriorityRefs[i]->SuperRelevant;
				if ( IsRelevant == -1 ) //Do not run relevancy checks
					IsRelevant = 0;
				else if ( !IsRelevant )
					IsRelevant = ActorIsRelevant( Actor, Connection->Actor, Viewer, &Location, EndOffset);
				//Reset the relevancy timers if the channels are saturated
				if ( IsRelevant )
					Channel->RelevantTime = NetDriver->Time + (1.1f - NetDriver->RelevantTimeout);
			}
		}
		
		unguardf_win32( (TEXT("[%i/%i] %s"), i, PriorityCount, PriorityRefs[i]->Actor->GetName() ));
	
		
		unguard_win32;
	}


} GCC_ALIGN(16);


INT UXC_Level::ServerTickClients( FLOAT DeltaSeconds )
{
	guard(UXC_Level::ServerTickClients);

	DeltaSeconds *= _Reciprocal( GetLevelInfo()->TimeDilation);

	INT i;
	INT Updated=0;
	FMemMark Mark(GMem);
	FConnectionRelevancyList* ConnList = NULL;

	guard( MakeConnectionLists);
	for( i=NetDriver->ClientConnections.Num()-1; i>=0; i-- ) //Reverse order, so chained list isn't flipped
	{
		UNetConnection* Conn = NetDriver->ClientConnections(i);
		check( Conn);
		check( Conn->State==USOCK_Pending || Conn->State==USOCK_Open || Conn->State==USOCK_Closed);

		if ( !Conn->Actor || !Conn->IsNetReady(0) || Conn->State!=USOCK_Open )
			continue;
		if ( Conn->Driver->Time - Conn->LastReceiveTime > 1.5f )
			continue;
		ConnList = new(GMem,1,16) FConnectionRelevancyList( Conn, ConnList, Updated);
		Updated++;
	}
	//No clients, abort here
	if ( !Updated )
		return 0;
	unguard;

	AActor** ConsiderList;
	INT ConsiderListSize = 0;
	INT NO_ConsiderListSize = 0;
	INT NO_OwnedConsiderListSize = 0;
	
	guard( MakeConsiderList);
	INT ActorListSize = Actors.Num() + 2 + 1 - iFirstNetRelevantActor; //That +1 is a buffer!!!
	INT OwnedListPos = ActorListSize;
	ConsiderList = new(GMem, ActorListSize+1) AActor*;
	// Add LevelInfo
	if( Actors(0) && (Actors(0)->RemoteRole!=ROLE_None) )
	{
		FLOAT OldTime = UpdateNetTag( Actors(0), DeltaSeconds);
		FLOAT& ActorTime = *(FLOAT*)&Actors(0)->NetTag;
		if ( appRound( OldTime*Actors(0)->NetUpdateFrequency) != appRound( ActorTime*Actors(0)->NetUpdateFrequency) )
		{
			Actors(0)->bAlwaysRelevant = true; //Important to enforce this
			ActorTime += appFrand() * 0.05; //Randomizer
			ConsiderList[ConsiderListSize++] = Actors(0);
		}
	}
	//Non-owned actors from (0 to max), owned actors from (max to 0)
	FLOAT ArOffset = 0.f; //bAlwaysRelevant actors spreader
	INT SpecialConsiders = 0;
	for( i=iFirstNetRelevantActor; i<Actors.Num(); i++ ) //Consider all actors for now
	{
		AActor* Actor = Actors(i);

		if ( Actor && !ActorIsNeverRelevant(Actor) ) //Discards more than ROLE_None check
		{
			//NetTag rules: always positive, between 0 and 99 (up to 120)
			FLOAT OldTime = UpdateNetTag( Actor, DeltaSeconds);
			UBOOL bPass = 0;
			
			//Special actors go first in the list, push any other out to last!
			if ( Actor->bRelevantIfOwnerIs || Actor->bRelevantToTeam )
			{
				ConsiderList[ConsiderListSize++] = ConsiderList[SpecialConsiders];
				ConsiderList[SpecialConsiders++] = Actor;
			}
			else if ( Actor->bAlwaysRelevant )
			{
				FLOAT& ActorTime = *(FLOAT*)&Actor->NetTag;
				//bAlwaysRelevant actors are checked at the same time
				if ( appRound( (OldTime+ArOffset)*Actor->NetUpdateFrequency*2) != appRound( (ActorTime+ArOffset)*Actor->NetUpdateFrequency*2) )
				{ //HACK: NETUPDATEFREQUENCY X 2 DUE TO SOME OBSCURE BUG
					ActorTime += appFrand() * 0.05; //Randomizer (is it necessary?)
					ArOffset += 0.023f;
					bPass = 1;
				}
			}
			else if ( !(Actor->bNetOptional && (Actor->GetClass()->GetDefaultActor()->LifeSpan - 0.15f >= Actor->LifeSpan)) )
				bPass = 1;

			if ( bPass )
			{
				if ( OwnedByAPlayer(Actor) )
					ConsiderList[--OwnedListPos] = Actor;
				else
					ConsiderList[ConsiderListSize++] = Actor;
			}
		}
	}

	NO_ConsiderListSize = ConsiderListSize;
	//Sort owned list by ConnectionID and move to end of ConsiderList incrementally
	for ( FConnectionRelevancyList* ConnLink=ConnList ; ConnLink ; ConnLink=ConnLink->Next )
	{
		ConnLink->OwnedConsiderListStart	= ConsiderListSize;
		ConnLink->OwnedConsiderListSize		= 0;
		ConnLink->SpecialConsiderListSize	= SpecialConsiders;
		APlayerPawn* NetOwner = ConnLink->Connection->Actor;
		//Grab all owned actors
		for ( i=OwnedListPos ; i<ActorListSize ; i++ )
			if ( ConsiderList[i]->IsOwnedBy(NetOwner) )
			{
				ConsiderList[ConsiderListSize++] = ConsiderList[i];
				ConsiderList[i] = ConsiderList[OwnedListPos++];
				ConnLink->OwnedConsiderListSize++;
			}
	}

	//Move any leftovers not belonging to connected players (filter them out?, useful for bot games)
	//Ideally, it's zero moves
	while ( OwnedListPos < ActorListSize )
	{
		ConsiderList[ConsiderListSize++] = ConsiderList[OwnedListPos++];
		NO_OwnedConsiderListSize++;
	}
	unguard;


	guard( ArrayProcess);

	FLOAT MaxTickRate = Engine->GetMaxTickRate(); //This should become an argument
	if ( MaxTickRate == 0 && (DeltaSeconds != 0.f) )
		MaxTickRate = _Reciprocal( DeltaSeconds);
	//Allocate general chunks, they will be reused by each connection
	FActorPriority* GPriorityArray = new(GMem,ConsiderListSize) FActorPriority;
	FActorPriority** GPriorityRefs = new(GMem,ConsiderListSize) FActorPriority*;

	i = 1;
	for ( FConnectionRelevancyList* ConnLink=ConnList ; ConnLink ; ConnLink=ConnLink->Next )
	{
		ConnLink->PriorityArray		= GPriorityArray;
		ConnLink->PriorityRefs		= GPriorityRefs;
		ConnLink->ConsiderList		= ConsiderList;
		ConnLink->ConsiderListSize	= ConsiderListSize;
		ConnLink->Connection->TickCount++;
		NetTag++;
		ConnLink->RelevancyLoop( DeltaSeconds, MaxTickRate, i-1); //Internal processing starts with 0, not 1
		i++;
	}
	unguardf( (TEXT("[%i/%i] NOG=%i, NOW=%i, NOO=%i"), i, Updated, NO_ConsiderListSize, ConsiderListSize-NO_ConsiderListSize, NO_OwnedConsiderListSize));

	Mark.Pop();
	return Updated;
	unguard;
}

//Prevents heavy log spamming
static       FTime LastNAC = 0;
EAcceptConnection UXC_Level::NotifyAcceptingConnection()
{
	check(NetDriver);
	if ( LastNAC > TimeSeconds ) //Level was switched, reset
		LastNAC = 0;
	if( NetDriver->ServerConnection )
	{
		// We are a client and we don't welcome incoming connections.
		// Don't fill a client's log
		if ( TimeSeconds - LastNAC > 1.f )
		{
			LastNAC = TimeSeconds;
			debugf( NAME_DevNet, TEXT("NotifyAcceptingConnection: Client refused") );
		}
		return ACCEPTC_Reject;
	}
	else if( GetLevelInfo()->NextURL != TEXT("") )
	{
		// Server is switching levels.
		// 100% useless, populated v436 servers suffer a lot from this
//		debugf( NAME_DevNet, TEXT("NotifyAcceptingConnection: Server %s refused"), GetName() );
		return ACCEPTC_Ignore;
	}
	else
	{
		// Server is up and running.
		// Log everything during the first second of the level
		// Otherwise add a 0.25s interval to avoid DDoS's from filling log
		if ( (NetDriver->Time < FTime(1)) || (TimeSeconds - LastNAC > 0.25f) )
		{
			LastNAC = TimeSeconds;
			debugf( NAME_DevNet, TEXT("NotifyAcceptingConnection: Server %s accept"), GetName() );
		}
		return ACCEPTC_Accept;
	}
}

void UXC_Level::NotifyAcceptedConnection( class UNetConnection* Connection )
{
	Super::NotifyAcceptedConnection( Connection);
}

//Detaches parameter from login
static UBOOL RemoveParam( FString& Str, FString& Parsed, const TCHAR* ParamName)
{
	guard(RemoveParam);
	INT PLen = appStrlen( ParamName);
	if ( !PLen || (Str.Len() == 0) )
		return 0;
	INT Location = 0;
	INT STLen = Str.Len();
	while ( Location < STLen)
	{
		while ( (*Str)[Location] == '?' )
			Location++;
		if ( Str.Mid(Location, PLen) == ParamName )
		{
			//Parameter validated, extract!
			Parsed = Str.Mid( Location);
			Str = Str.Left( Location);
			INT NewLocation = Parsed.InStr( TEXT("?") );
			if ( NewLocation > 0 )
			{
				Str += Parsed.Mid( NewLocation+1); //Get rid of a ? char
				Parsed = Parsed.Left( NewLocation);
			}
			return 1;
		}
		while ( (Location < STLen) && ((*Str)[Location] != '?') )
			Location++;
	}
	return 0;
	unguard;
}

static const TCHAR HelloText[]	= { 'H', 'E', 'L', 'L', 'O', 0 };
static const TCHAR JoinText[]		= { 'J', 'O', 'I', 'N', 0 };
static const TCHAR LoginText[]	= { 'L', 'O', 'G', 'I', 'N', 0 };
static const TCHAR UserFlagText[]	= { 'U', 'S', 'E', 'R', 'F', 'L', 'A', 'G', 0 }; //Do not userflag pre-join
static const TCHAR HaveText[]		= { 'H', 'A', 'V', 'E', 0 };
static const TCHAR SkipText[]		= { 'S', 'K', 'I', 'P', 0 };
static const TCHAR NetspeedText[]	= { 'N', 'E', 'T', 'S', 'P', 'E', 'E', 'D', 0 };

static const TCHAR* ValidClientCommands[] = { UserFlagText, NetspeedText };
static const TCHAR* ValidJoinCommands[] = { HelloText, JoinText, LoginText, HaveText, SkipText, NetspeedText};

void UXC_Level::NotifyReceivedText(UNetConnection* Connection, const TCHAR* Text)
{
	guard(UXC_Level::NotifyReceivedText);
	if ( NetDriver->ServerConnection )
	{
	}
	else
	{
		if (Connection->State == USOCK_Closed)
			return;

		const TCHAR* Str = Text;
		//Only allow post player join commands after join is complete
		if ( Connection->Actor )
		{
			UBOOL bFail = 1;
			for ( INT i=0 ; i<ARRAY_COUNT(ValidClientCommands) ; i++ )
				if ( ParseCommand( &Str, ValidClientCommands[i]) )
				{
					bFail = 0;
					break;
				}
			if ( bFail )
				return;
		}
		//Only allow player join commands when needed
		else
		{
			UBOOL bFail = 1;
			for (INT i = 0; i<ARRAY_COUNT(ValidJoinCommands); i++)
				if (ParseCommand(&Str, ValidJoinCommands[i]))
				{
					bFail = 0;
					break;
				}
			if (bFail)
				return;
		}

		Str = Text;

		if (ParseCommand(&Str, TEXT("LOGIN")))
		{
			if ( Connection->RequestURL.Len() )
				return;
		}
		else if ( ParseCommand(&Str, TEXT("JOIN")) )
		{
			// See that RequestURL is appropiate before doing any extra processing
			FString LoginParams = Connection->RequestURL;
			FString Name;
			FString Class;

			FString Error;
			if ( LoginParams == TEXT("") ) //Did player even LOGIN?
				Error = TEXT("[XCGE] LOGIN command invalid or not received");
			else if ( !RemoveParam( LoginParams, Name, TEXT("Name=")) ) //Player has a name?
				Error = TEXT("[XCGE] No player name in login request");
			else if ( !RemoveParam( LoginParams, Class, TEXT("Class=")) ) //Player has a class?
				Error = TEXT("[XCGE] No player class in login request");

			// Finish computing the package map.
			if ( !Error.Len() ) //No error
				Connection->PackageMap->Compute();

			debugf(NAME_DevNet, TEXT("Join request: %s"), *Connection->RequestURL);
			// Spawn the player-actor for this network player.
			if ( Error.Len() || !SpawnPlayActor(Connection, ROLE_AutonomousProxy, FURL(NULL, *Connection->RequestURL, TRAVEL_Absolute), Error) )
			{
				// Failed to connect.
				debugf(NAME_DevNet, TEXT("Join failure: %s"), *Error);
				Connection->Logf(TEXT("FAILURE %s"), *Error);
				Connection->FlushNet();
				Connection->State = USOCK_Closed;
			}
			else
			{
				// Successfully in game.
				debugf(NAME_DevNet, TEXT("Join succeeded: %s"), *Connection->Actor->PlayerReplicationInfo->PlayerName);
			}
			return;
		}
	}

	Super::NotifyReceivedText( Connection, Text);
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

#ifndef DISABLE_ADDONS

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

#endif


