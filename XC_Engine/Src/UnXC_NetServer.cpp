/*=============================================================================
	UnXC_NetServer.cpp
	Author: Fernando Velázquez

	Unreal Tournament relevancy Netcode replacement
=============================================================================*/

#include "XC_Engine.h"

#include "XC_CoreGlobals.h"
#include "XC_Networking.h"

#include "UnXC_Lev.h"
#include "UnXC_ServerProc.h"

#include "Cacus/Math/Math.h"
#include "Cacus/AppTime.h"

// TODO: PRIORITIZATION BY DISTANCE (?)


//Throw error to compiler if one of these hacks is missing
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

//
// Net Driver has received a connection attempt
//
static FTime LastNAC = 0;
EAcceptConnection UXC_Level::NotifyAcceptingConnection()
{
	check(NetDriver);

	//Level was switched, reset
	if ( LastNAC > TimeSeconds )
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
		// Server is switching levels, silently ignore connection attempts (v436 servers get heavily spammed here)
		return ACCEPTC_Ignore;
	}
	else
	{
		// Server is up and running.
		// Log everything during the first second of the level
		// Otherwise add a 0.25s interval to avoid DoS's from filling log
		if ( (NetDriver->Time < FTime(1)) || (TimeSeconds - LastNAC > 0.25f) )
		{
			LastNAC = TimeSeconds;
			debugf( NAME_DevNet, TEXT("NotifyAcceptingConnection: Server %s accept"), GetName() );
		}
		return ACCEPTC_Accept;
	}
}

//
// Receive pointer to recently accepted connection
//
void UXC_Level::NotifyAcceptedConnection( class UNetConnection* Connection )
{
	Super::NotifyAcceptedConnection( Connection);

	//Required to create the client info
	FXC_ServerProc* Proc = (FXC_ServerProc*)((UXC_GameEngine*)Engine)->XCGESystems.FindByType( TEXT("ServerProc"));
	if ( Proc )
		Proc->GetClient( Connection);

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
static const TCHAR TickRateText[]	= { 'T', 'I', 'C', 'K', 'R', 'A', 'T', 'E', 0 };

static const TCHAR* ValidClientCommands[] = { UserFlagText, NetspeedText, TickRateText };
static const TCHAR* ValidJoinCommands[] = { HelloText, JoinText, LoginText, HaveText, SkipText, NetspeedText, TickRateText};

//
// The control channel has received a message
//
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
		else if ( ParseCommand(&Str, TEXT("TICKRATE")) )
		{
			INT TickRate = appAtoi(Str);
			if( TickRate >= 4 && TickRate <= 200 )
			{
				FXC_ServerProc* Proc = (FXC_ServerProc*)((UXC_GameEngine*)Engine)->XCGESystems.FindByType( TEXT("ServerProc"));
				FNetClientInfo* Info = Proc ? Proc->GetClient( Connection) : NULL;
				if ( Info )
					Info->TickRate = TickRate;
			}
			return;
		}
	}

	Super::NotifyReceivedText( Connection, Text);
	unguard;
}




//======================================================================
//======================================================================
//
//============ ACTOR RELEVANCY - v3
//
//======================================================================
//======================================================================

//Fix this if old relevancy was toggled
static void UpdateNetTag( AActor* Other, FLOAT DeltaTime)
{
	Other->NetTag &= 0x7FFFFFFF; //Become positive
	FLOAT& NetTime = *(FLOAT*) &Other->NetTag;
	if ( NetTime > 499.f || appIsNan(NetTime) )
		NetTime = 0;
	else
		NetTime += DeltaTime;
}

static inline FLOAT NetTime( AActor* Actor)
{
	return *(FLOAT*)&Actor->NetTag;
}

// Returns the fraction of a FTime
static inline FLOAT TimeFraction( const FTime& Time)
{
	return ((FLOAT) *(INT*)&Time) / FIXTIME;
}

// Returns the integral part of FTime
static inline INT TimeInteger( const FTime& Time)
{
	return ((INT*)&Time)[1];
}

UClass* GetNetworkSuperClass( AActor* Actor, UPackageMap* PackageMap) //Actor->bSuperClassRelevancy
{
	UClass* Result = Actor->GetClass();
	while ( Result && (Result != AActor::StaticClass()) )
	{
		if ( (Result->ClassFlags & CLASS_Abstract) || (PackageMap->ObjectToIndex(Result) == INDEX_NONE) )
			Result = Result->GetSuperClass();
		else
			return Result;
	}
	return NULL;
}


//======================================================================
//============ ACTOR PRIORITY
//
static AActor* CachedViewTarget = NULL;
static UActorChannel* CachedViewTargetChannel = NULL;

enum ESuperRelevancy
{
	SR_NeverRelevant = -1,
	SR_CheckVisible  =  0,
	SR_AlwaysVisible =  1,
	SR_SuperRelevant =  2,
};

struct FActorPriority
{
	INT            Priority;	// Update priority, higher = more important.
	AActor*        Actor;		// Actor.
	UActorChannel* Channel;	// Actor channel.
	INT            SuperRelevant; //Skip owner checks later

	FActorPriority()
	{}

	static FLOAT DirectionalPri( const FVector& ActorLoc, const CFVector4& ViewLoc, const CFVector4& Dir)
	{
		FLOAT Result;
#ifdef __LINUX_X86__
		__asm__ __volatile__("movups     (%%eax),%%xmm1 \n" : : "a" (&ActorLoc) : "memory"	); // Load ActorLoc
		__asm__ __volatile__("movups     (%%eax),%%xmm0 \n" : : "a" (&ViewLoc)  : "memory"	); // Load ViewLoc
		__asm__ __volatile__("subps       %%xmm0,%%xmm1 \n"                                    // Delta = ActorLoc-ViewLoc
		                     "movaps      %%xmm1,%%xmm0 \n"
		                     "mulps       %%xmm1,%%xmm0 \n"                                    // Delta * Delta
		                     "movaps      %%xmm0,%%xmm2 \n"
		                     "shufps $177,%%xmm0,%%xmm2 \n"
		                     "addps       %%xmm2,%%xmm0 \n"                                    // x+z, y+w (Delta)
		                     "movhlps     %%xmm0,%%xmm2 \n"
		                     "addss       %%xmm0,%%xmm2 \n"                                    // x+y+z+w (Delta)
		                     "rsqrtss     %%xmm2,%%xmm2 \n"
		                     "mulps       %%xmm1,%%xmm2 \n"                                    // Delta / Delta.Size(approx)
		                     "movups     (%%eax),%%xmm1 \n" : : "a" (&Dir)      : "memory"	); // Load Dir
		__asm__ __volatile__("mulps       %%xmm2,%%xmm1 \n"                                    // Delta.Normal(approx) * Dir
		                     "movaps      %%xmm1,%%xmm0 \n"
		                     "shufps $177,%%xmm1,%%xmm0 \n"
		                     "addps       %%xmm0,%%xmm1 \n"                                    // x+z, y+w
		                     "movhlps     %%xmm1,%%xmm0 \n"
		                     "addss       %%xmm1,%%xmm0 \n"                                    // x+z+y+w
		                     "movss       %%xmm0,    %0 \n" : "=m" (Result) );                 // Store in Result
#else
		Result = ((CFVector4( &ActorLoc.X) - ViewLoc).Normal_Approx() | Dir);
#endif
		return Result;
	}

	void SetPriority( UNetConnection* InConnection, FLOAT Dot)
	{
		FLOAT Time = Channel ? (InConnection->Driver->Time - Channel->LastUpdateTime) : InConnection->Driver->SpawnPrioritySeconds;
		//CACUS: Lower priority for actors updated within last 2 seconds
		if ( Time < 2.0f )
			Time = Square(Time) * 0.5f;
		AActor* Sent = (Channel && Channel->Recent.Num()) ? (AActor*) &Channel->Recent(0) : NULL;
		Priority = appRound( Dot * Actor->GetNetPriority(Sent,Time,InConnection->BestLag) * 65536.f);

		if ( Actor->bNetOptional )
			Priority -= 3000000;
	}

	//General
	FActorPriority( const CFVector4& Location, const CFVector4& Dir, UXC_NetConnectionHack* InConnection, UActorChannel* InChannel, AActor* Target)
	{
		Actor = Target;
		Channel = InChannel;

		//LocalPlayer=2, Weapon=2, Owned=1, ViewTarget=1
		APlayerPawn* Player = InConnection->Actor;
		SuperRelevant = (Actor==Player || Actor==Player->Weapon) 
		              + (Actor->bAlwaysRelevant || Actor->IsOwnedBy(Player) || Actor==CachedViewTarget || (Actor->Instigator==Player && Actor->IsA(AProjectile::StaticClass()) ) );

		//Special case, discard bNotRelevantToOwner actors
		if ( (SuperRelevant == SR_AlwaysVisible) && Actor->bNotRelevantToOwner && Actor->IsOwnedBy(Player) )
		{
			SuperRelevant = SR_NeverRelevant;
			return;
		}

		//When viewtarget is relevant: ViewTarget=2, ViewTargetOwned=1 (Inventory does not qualify)
		if ( CachedViewTarget && CachedViewTargetChannel && !Actor->IsA(AInventory::StaticClass()) )
			SuperRelevant = Max( SuperRelevant, (Actor==CachedViewTarget) + Actor->IsOwnedBy(CachedViewTarget));

		SetPriority
		(
			InConnection,
			3.0f + (SuperRelevant ? (FLOAT)SuperRelevant : DirectionalPri( Actor->Location, Location, Dir))
		);
	}
};


//======================================================================
//============ VISIBILITY CHECK HELPER CLASS
//

static INT ST_Traces = 0;

struct LineCheckHelper
{
	FBspNode* Nodes;
	FBspSurf* Surfs;

	LineCheckHelper( FBspNode* InNodes, FBspSurf* InSurfs)
		: Nodes(InNodes), Surfs(InSurfs)
	{
		ST_Traces++;
	}

	BYTE LineCheck( INT iNode, CFVector4* End, CFVector4* Start, BYTE Outside );
};

BYTE LineCheckHelper::LineCheck( INT iNode, CFVector4* End, CFVector4* Start, BYTE Outside )
{
	CFVector4 Middle;
	FBspSurf* LastSurf = NULL;
	while( iNode != INDEX_NONE )
	{
		const FBspNode&	Node = (const FBspNode&)Nodes[iNode];
		FLOAT Dist[2];
		DoublePlaneDot( Node.Plane, *Start, *End, Dist);
		BYTE  NotCsg = (Node.NodeFlags & NF_NotCsg);
		BYTE  G1 = *(INT*)&Dist[0] >= 0;
		BYTE  G2 = *(INT*)&Dist[1] >= 0;
		if( G1!=G2 ) // Crosses plane
		{
			Middle = LinePlaneIntersectDist( *Start, *End, Dist); //GCC may crash here
			if ( !LineCheck( Node.iChild[G2], &Middle, End, G2^((G2^Outside) & NotCsg)) )
				return 0;
			End = &Middle;
		}
		Outside = G1^((G1^Outside)&NotCsg);
		iNode = Node.iChild[G1];
		if ( Node.iSurf != INDEX_NONE )
			LastSurf = &Surfs[Node.iSurf];
	}
	BYTE IsTranslucent = 0;
	if ( LastSurf )
		IsTranslucent = (LastSurf->PolyFlags & PF_NoOcclude) || (LastSurf->Texture && (LastSurf->Texture->PolyFlags & PF_NoOcclude));

	return IsTranslucent || Outside;
}

//======================================================================
//============ ACTOR RELEVANCY TEST
//

//See if actor is relevant to a player
static UBOOL ActorIsVisible( AActor* Actor, APlayerPawn* Player, AActor* Viewer, CFVector4* ViewPos, const CFVector4& EndOffset)
{
//	if ( Actor->bAlwaysRelevant ) //Handled by Super Relevant
//		return 1;
	if ( Actor->AmbientSound && (*(FVector*)ViewPos - Actor->Location).SizeSquared() < Square(Actor->WorldSoundRadius() * 0.8f) )
		return 1;
	if ( Actor->Owner )
	{
/*		if ( Actor->IsOwnedBy(Viewer) ) //Handled by Super Relevant
			return 1;*/
		if ( Actor->Owner->bIsPawn && ((APawn*)Actor->Owner)->Weapon == Actor )
			return ActorIsVisible( Actor->Owner, Player, Viewer, ViewPos, EndOffset);
	}
	if ( (Actor->bHidden || Actor->bOnlyOwnerSee) && !Actor->bBlockPlayers && !Actor->AmbientSound )
		return 0;
	if ( !Actor->GetLevel()->Model->Nodes.Num() ) //Additive level?
		return Actor->GetLevel()->Model->RootOutside;

	CFVector4 EndTrace;
#ifdef __LINUX_X86__
	__asm__ __volatile__(
		"movups  400(%%esi),%%xmm0 \n" // Load Collision
		"shufps  $80,%%xmm0,%%xmm0 \n" // Rearrange as Extent (Radius, Radius, Height, Height)
		"movups     (%%eax),%%xmm1 \n" // Load EndOffset
		"mulps       %%xmm0,%%xmm1 \n" // EndOffset * Extent
		"movups  208(%%esi),%%xmm0 \n" // Load Actor->Location
		"addps       %%xmm0,%%xmm1 \n" // Actor->Location + EndOffset * Extent
		"movups      %%xmm1,%0 \n"     // Store in EndTrace
		: "=m"(EndTrace)               // Outputs
		: "a"(&EndOffset), "S"(Actor)  // Inputs
		: "memory" );
#else
	CFVector4 Extent( &Actor->CollisionRadius);
	Extent = _mm_shuffle_ps( Extent, Extent, 0b01010000); //Radius, Radius, Height, Height
	EndTrace = CFVector4(&Actor->Location.X) + EndOffset * Extent;
#endif
	LineCheckHelper Helper( &Viewer->GetLevel()->Model->Nodes(0), &Viewer->GetLevel()->Model->Surfs(0));
//	return Actor->GetLevel()->Model->FastLineCheck( *(FVector*)&EndTrace, *(FVector*)ViewPos);
	return Helper.LineCheck( 0, &EndTrace, ViewPos, Viewer->GetLevel()->Model->RootOutside);
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


//======================================================================
//============ SERVER PROCESSOR
//

FNetClientInfo::FNetClientInfo( UNetConnection* InConnection)
	: Connection(InConnection)
	, ObjectIndex(InConnection ? InConnection->GetIndex() : INDEX_NONE)
	, TickRate(200)
	, BandwidthFraction(0)
{
	appMemzero( Saturation, (SATURATION_FRACTIONS + 3) * sizeof(DWORD));
}

void FNetClientInfo::AddSaturation( FLOAT NewSaturation, FLOAT DeltaTime)
{
	Saturation[SaturationIndex] += NewSaturation;
	SaturationTime += DeltaTime;
	if ( SaturationTime >= 1.f / SATURATION_FRACTIONS )
	{
		SaturationTime -= 1.f / SATURATION_FRACTIONS;
		SaturationIndex = (SaturationIndex+1) % SATURATION_FRACTIONS;
		Saturation[SaturationIndex] = NewSaturation * 0.5f;
	}
}

FLOAT FNetClientInfo::GetSaturation()
{
	FLOAT Result = 0;
	for ( INT i=0 ; i<SATURATION_FRACTIONS ; i++ )
		Result += Saturation[i];
	return Result;
}

FNetClientInfo* FXC_ServerProc::GetClient( UNetConnection* InConnection)
{
	if ( InConnection )
	{
		for ( INT i=0 ; i<Clients.Num() ; i++ )
			if ( Clients(i).Connection == InConnection )
				return &Clients(i);
		INT NewItem = Clients.AddItem( FNetClientInfo(InConnection));
		if ( NewItem != INDEX_NONE )
			return &Clients(NewItem);
	}
	return nullptr;
}

// bAlwaysRelevant actors are no longer updated globally
INT FXC_ServerProc::BuildConsiderLists( FMemStack& Mem, FLOAT DeltaSeconds)
{
	guard(FXC_ServerProc::BuildConsiderLists);

	ULevel* Level = Engine->Level();
	check(Level && Level->NetDriver);
	TArray<AActor*>& Actors = Level->Actors;

	INT i;
	ConsiderListSize = 0;
	SpecialConsiderListSize = 0;
	INT ActorListSize = Actors.Num() + 1 - Level->iFirstNetRelevantActor; 
	ConsiderList = new(Mem, ActorListSize + 2) AActor*; //Plus two gives us a nice 2 unit buffer

	// Add LevelInfo - Special case
	if ( Actors(0) && (Actors(0)->RemoteRole!=ROLE_None) )
	{
		Actors(0)->bAlwaysRelevant = true;
		ConsiderList[ConsiderListSize++] = Actors(0);
		UpdateNetTag( Actors(0), DeltaSeconds);
	}

	// Add Net Relevant actors
	for( i=Level->iFirstNetRelevantActor; i<Actors.Num(); i++ ) //Consider all actors for now
	{
		AActor* Actor = Actors(i);
		if ( Actor && !ActorIsNeverRelevant(Actor) ) //Discards more than ROLE_None check
		{
			//NetTag rules: always positive, between 0 and 499
			UpdateNetTag( Actor, DeltaSeconds);

			//Special actors go first in the list, push any other out to last!
			if ( Actor->bRelevantIfOwnerIs || Actor->bRelevantToTeam )
			{
				ConsiderList[ConsiderListSize++] = ConsiderList[SpecialConsiderListSize];
				ConsiderList[SpecialConsiderListSize++] = Actor;
			}
			else if ( Actor->bAlwaysRelevant || !Actor->bNetOptional || (Actor->GetClass()->GetDefaultActor()->LifeSpan - 0.15f < Actor->LifeSpan) )
				ConsiderList[ConsiderListSize++] = Actor;
		}
	}
	return ConsiderListSize;
	unguard;
}

FLOAT FXC_ServerProc::CalcRealTickRate()
{
	FLOAT Result = 0;
	if ( TickTimeStamps.Num() > 1 )
	{
		Result += TickTimeStamps.Last() - TickTimeStamps(0);
		if ( Result != 0.f )
			Result = (float)(TickTimeStamps.Num() - 1) / Result;
	}
	return Result;
}



//======================================================================
//============ ACTOR PRIORITIZER
//
struct FActorPrioritizer
{
	FActorPriority* PriorityArray;
	FActorPriority** PriorityRefs;
	INT PriorityCount;
	INT ExpectedNewChannels;

	UXC_NetConnectionHack* Connection;
	FLOAT ClientUpdateRate;
	FLOAT TimeOffset;
	FLOAT DeltaTime;

	AActor* Viewer;
	FRotator Rotation;
	CFVector4 Location;
	CFVector4 ViewDir;

	FActorPrioritizer( FMemStack& Mem, INT ActorCount)
		: PriorityArray( new(Mem, ActorCount) FActorPriority)
		, PriorityRefs( new(Mem, ActorCount) FActorPriority*)
	{}

	void Setup( UNetConnection* InConnection, FLOAT InClientUpdateRate, FLOAT InDeltaTime)
	{
		PriorityCount = 0;
		ExpectedNewChannels = 0;
		Connection = (UXC_NetConnectionHack*)InConnection;
		ClientUpdateRate = InClientUpdateRate;
		TimeOffset = (FLOAT)(Connection->GetIndex() & 0x0F) * 0.045;
		DeltaTime = InDeltaTime;


		APlayerPawn* Player = Connection->Actor;
		// Get viewer coordinates.
#if __LINUX_X86__
		__asm__ __volatile__("movups  %0,%%xmm0 \n" : : "m"(Player->Location));
		__asm__ __volatile__("movups  %%xmm0,%0  \n" : "=m"(Location));
#else
		Location  = CFVector4( &Player->Location.X);
#endif
		Rotation  = Player->ViewRotation;
		Viewer    = Player;
		Player->eventPlayerCalcView( Viewer, (FVector&)Location, Rotation );
		check(Viewer);

		if ( Connection->TickCount & 1 ) //Happens every 2 frames
		{
			FLOAT TMult = (Connection->TickCount & 2) ? 0.4f : 0.9f; //Pick 0.4 or 0.9 seconds (one frame 0.4, next 0.9 and so on)
#if __LINUX_X86__
			CFVector4 Ahead;
			__asm__ __volatile__("movups  %0,%%xmm2 \n" : : "m"(Viewer->Velocity));
			if ( Viewer->Base )
			{
				__asm__ __volatile__(
					"movups  %0,%%xmm0 \n"
					"addps  %%xmm0,%%xmm2 \n" : : "m"(Viewer->Base->Velocity));
			}
			// X2=NetVelocity, X1=Mult, X0=Location
			__asm__ __volatile(
				"movups         %0,%%xmm0 \n"
				"movss          %1,%%xmm1 \n"
				"shufps  $0,%%xmm1,%%xmm1 \n"
				"mulps      %%xmm2,%%xmm1 \n"
				"addps      %%xmm1,%%xmm0 \n": : "m"(Location), "m"(TMult));
			__asm__ __volatile__("movups  %%xmm0,%0" : "=m"(Ahead));
#else
			CFVector4 NetVelocity( &Viewer->Velocity.X);
			if ( Viewer->Base ) //Add platform/lift velocity to the Ahead calc
				NetVelocity += CFVector4( &Viewer->Base->Velocity.X);
			CFVector4 Ahead = Location + NetVelocity * TMult;
#endif
			if ( Viewer->XLevel->Model->FastLineCheck( *(FVector*)&Ahead, *(FVector*)&Location) )
			{
#if __LINUX_X86__
				__asm__ __volatile__("movups  %0,%%xmm0 \n" : : "m"(Ahead));
				__asm__ __volatile__("movups  %%xmm0,%0  \n" : "=m"(Location));
#else
				Location = Ahead;
#endif
			}
		}
	}

	void AddPriority( AActor* Actor, UActorChannel* Channel, UBOOL SuperRelevancyOverride=0, INT SuperRelevancyValue=0)
	{
		// See what kind of relevancy and priority this actor has
		FActorPriority& Pri = PriorityArray[PriorityCount];
		Pri = FActorPriority( Location, ViewDir, Connection, Channel, Actor);
		if ( SuperRelevancyOverride && (Pri.SuperRelevant >= 0)  )
			Pri.SuperRelevant = SuperRelevancyValue;

		// Add to priority list if can be relevant, otherwise immediately kill off channel
		if ( Pri.SuperRelevant >= SR_CheckVisible )
		{
			PriorityRefs[PriorityCount++] = &Pri;
			if ( !Channel )
				ExpectedNewChannels++;
		}
		else if ( Channel )
			Channel->Close();
	}

	// Returns amount of Super Relevants
	INT SortPriorities()
	{
		INT i;
		//For some reason Sort template is broken in linux
		INT SuperRelevantCount = 0;
		for ( i=0 ; i<PriorityCount ; i++ )
			if ( PriorityRefs[i]->SuperRelevant > 0 )
				Exchange( PriorityRefs[i], PriorityRefs[SuperRelevantCount++]);
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
				Exchange( PriorityRefs[Highest], PriorityRefs[i]);
			}
		}
		return SuperRelevantCount;
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

			if ( Actor->DrawType == DT_Mesh )
			{
				// Loop anim never gets notified
				if ( (Actor->SimAnim.W < 0) && (Abs(Actor->SimAnim.W-OldActor->SimAnim.W) < 2) )
					OldActor->SimAnim.W = Actor->SimAnim.W;
				// Anim frame updated every 4 times
				if ( (Channel->NumReps & 3) && Actor->AnimSequence == OldActor->AnimSequence && Actor->AnimRate == OldActor->AnimRate )
					OldActor->SimAnim.X = Actor->SimAnim.X;
			}
		}
		UClass*& ActorClass = *(UClass**)((BYTE*)Actor + 36);
		UClass* RealClass = ActorClass;
		ActorClass = Channel->ActorClass;
		if ( Actor->bSimulatedPawn )
			ReplicatePawn( Channel);
		else
			Channel->ReplicateActor();
		ActorClass = RealClass;
	}

	UBOOL ShouldPrioritize( AActor* Actor, FLOAT UpdateFrequency)
	{
		if ( UpdateFrequency < ClientUpdateRate )
		{
			FLOAT ActorTime = NetTime(Actor) + TimeOffset;
			if ( appRound( ActorTime * UpdateFrequency) == appRound( (ActorTime+DeltaTime) * UpdateFrequency) )
				return 0;
		}
		return 1;
	}


	//Burst forces actors to be replicated at full rate if not relevant
	//Has to be used with extreme care as it increases check count
	#define BURST_OWNED_COUNT 100
	#define BURST_AR_COUNT 50
	void PrioritizeActors( FXC_ServerProc& ServerProc, FNetClientInfo& Client)
	{
		INT i;

		// Skip sent temporaries (set NetTag to negative)
		TArray<AActor*>& SentTemporaries = *Connection->GetSentTemporaries();
		for ( i=0 ; i<SentTemporaries.Num() ; i++ )
			SentTemporaries(i)->NetTag |= 0x80000000;

		FVector Dir = Rotation.Vector();
		TMap<AActor*,UActorChannel*>& ActorChannels = *Connection->GetActorChannels();
		TArray<UChannel*>& OpenChannels = *Connection->GetOpenChannels();

		// Setup viewtarget cache
		CachedViewTarget = NULL;
		CachedViewTargetChannel = NULL;
		if ( Connection->Actor->ViewTarget && !Connection->Actor->ViewTarget->IsOwnedBy( Connection->Actor) )
		{
			CachedViewTarget = Connection->Actor->ViewTarget;
			CachedViewTargetChannel = ActorChannels.FindRef( CachedViewTarget);
		}

		// Ez mode
		UBOOL bChannelsSaturated = OpenChannels.Num() > 800; //Change later!

		// Prioritize special actors
		APlayerReplicationInfo* PRI = Connection->Actor->PlayerReplicationInfo;
		guard(PrioritizeSpecials);
		for ( i=0 ; i<ServerProc.SpecialConsiderListSize ; i++ ) //Process specials, super branchy code
		{
			AActor* Actor = ServerProc.ConsiderList[i];
			if ( Actor->NetTag >= 0 )
			{
				TimeOffset += 0.023f;
				if ( ShouldPrioritize( Actor, Actor->NetUpdateFrequency) )
				{
					UBOOL SuperRelevancy = SR_AlwaysVisible; //SuperRelevancy override
					UActorChannel* Channel = ActorChannels.FindRef(Actor);

					if ( Actor->bRelevantIfOwnerIs && (!Actor->Owner || !ActorChannels.FindRef(Actor->Owner)) ) //Immediately close channel if owner isn't relevant
					{
						if (Channel)
							Channel->Close();
						continue;
					}

					if ( Actor->bRelevantToTeam && PRI && (!PRI->bIsSpectator || PRI->bWaitingPlayer) ) //Can be combined with above condition
					{
						UByteProperty* TeamProperty = Cast<UByteProperty>(FindScriptVariable(Actor->GetClass(), TEXT("Team"), NULL));
						SuperRelevancy = -1;
						if ( TeamProperty && (*((BYTE*)Actor + TeamProperty->Offset) == PRI->Team)) //Same team
						{
							//Treated as bAlwaysRelevant, can skip updates
							SuperRelevancy = 2;
							if (Actor->CheckRecentChanges() && Channel && Channel->Recent.Num() && !Channel->Dirty.Num() && Actor->NoVariablesToReplicate((AActor*)&Channel->Recent(0)))
							{
								Channel->RelevantTime = Connection->Driver->Time;
								continue;
							}
						}
						else if ( !Channel ) //No channel, don't even bother prioritizing
							continue;
					}
					AddPriority( Actor, Channel, true, SuperRelevancy);
				}
			}
		}
		unguard;

		// Prioritize normal actors (globals and other owned)
		guard(PrioritizeNormal);
		for ( i=ServerProc.SpecialConsiderListSize ; i<ServerProc.ConsiderListSize ; i++ )
		{
			AActor* Actor = ServerProc.ConsiderList[i];
			if ( Actor->NetTag >= 0 )
			{
				UBOOL bOwned = Actor->IsOwnedBy( Connection->Actor);
				if ( !bOwned )
					TimeOffset += 0.023f;
				UActorChannel* Channel = ActorChannels.FindRef(Actor);
				FLOAT UpdateFrequency = (bOwned && !Channel && i<BURST_OWNED_COUNT) ? 200.f //Owned actors are bursted
							: Actor->bAlwaysRelevant ? Actor->NetUpdateFrequency 
							: Actor->UpdateFrequency( Viewer, Dir, *(FVector*)&Location);

				if ( ShouldPrioritize( Actor, UpdateFrequency) )
				{
					if ( Actor->bAlwaysRelevant && Actor->CheckRecentChanges() && Channel && Channel->Recent.Num() && !Channel->Dirty.Num() && Actor->NoVariablesToReplicate( (AActor*)&Channel->Recent(0)) )
						Channel->RelevantTime = Connection->Driver->Time;
					else
					{
						//In case of saturation, visible actors can be lost (owned actors need to be treated carefully)
						UBOOL bForceVisibilityChecks = (bChannelsSaturated && !Actor->bHidden && (Actor != Connection->Actor))
							&& (!bOwned || ((i >= BURST_OWNED_COUNT) && !Actor->bNotRelevantToOwner && !Actor->Inventory));
						AddPriority( Actor, Channel, bForceVisibilityChecks, SR_CheckVisible);
					}
				}
			}
		}
		unguard;

		//SentTemporaries skipped, reset
		for ( i=0 ; i<SentTemporaries.Num() ; i++ )
			SentTemporaries(i)->NetTag &= 0x7FFFFFFF;


		//Count super relevants, sort priorities and early discard of irrelevant channels
		INT SuperRelevantCount = SortPriorities();
		INT DiscardCount = Max( 0, OpenChannels.Num() + ExpectedNewChannels - 923); //Use 100+(0 to FrameRate) channels as 'empty' buffer
		if ( PriorityCount - DiscardCount < SuperRelevantCount ) //Discard less in excess of super relevants
			DiscardCount = PriorityCount - SuperRelevantCount;

		//Close one channel every 0.25 second (or so)
		guard(Discard);
		if ( DiscardCount > 0 )
		{
			INT FrameRate = 1 + appRound(ClientUpdateRate) / 4;
			if ( Connection->TickCount % FrameRate == 0 )
			{
				for ( i=PriorityCount-1 ; i>PriorityCount/2 ; i-- )
				{
					FActorPriority& Pri = *PriorityRefs[i];
					if ( Pri.Channel && (Pri.Actor != Connection->Actor) && (Connection->Driver->Time-Pri.Channel->LastUpdateTime > 1.f) )
					{
						Pri.Channel->Close();
						PriorityRefs[i] = PriorityRefs[--PriorityCount];
						FrameRate = 0;
						break;
					}
				}
				if ( FrameRate ) //If we didn't close a channel, avoid opening a new one
					PriorityCount--;
			}
		}
		unguard;
		
	}

	void ReplicateActors()
	{
		static FPlane EndOffset; //Not thread safe, but 100% exception free
		EndOffset = VRand() * 0.95;

		TArray<UChannel*>& OpenChannels = *Connection->GetOpenChannels();
		UNetDriver* NetDriver = Connection->Driver;

		INT i;
		for ( i=0 ; i<PriorityCount ; i++ )
		{
			UActorChannel* Channel = PriorityRefs[i]->Channel;
			if ( !Channel && (OpenChannels.Num() > 1022) ) //We don't need to perform a check if the list is saturated
				continue;

			AActor* Actor = PriorityRefs[i]->Actor;
			UBOOL IsRelevant = PriorityRefs[i]->SuperRelevant > SR_CheckVisible;
			if ( !IsRelevant && (!Channel || (NetDriver->Time - Channel->RelevantTime > 0.3f)) )
				IsRelevant = ActorIsVisible( Actor, Connection->Actor, Viewer, &Location, *(CFVector4*)&EndOffset);

			if( IsRelevant || (Channel && NetDriver->Time-Channel->RelevantTime < NetDriver->RelevantTimeout) )
			{
				Actor->XLevel->NumPV++;
				if( !Channel )
				{
					UClass* BestClass = Actor->GetClass();
					if ( (Connection->PackageMap->ObjectToIndex(BestClass) != INDEX_NONE
						|| (Actor->bSuperClassRelevancy && ((BestClass=GetNetworkSuperClass(Actor,Connection->PackageMap)) != NULL)))
					&& (Channel=(UActorChannel*)Connection->CreateChannel( CHTYPE_Actor, 1, INDEX_NONE)) != NULL )
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
					}
				}
				if ( Channel )
				{
					if ( !Connection->IsNetReady(0) )
						break;
					if( IsRelevant )
						Channel->RelevantTime = NetDriver->Time + (0.1f + appFrand());
					if ( Channel->IsNetReady(0) )
						ReplicateActor( Channel);
					if ( !Connection->IsNetReady(0) )
						break;
				}
			}
			else if ( Channel && (Actor != Connection->Actor)) //Never close the local player's channel
				Channel->Close();
		}

		//Make sure channels don't go past RelevantTimeout if they don't have to during saturation
		for ( ; i<PriorityCount ; i++ )
		{
			UActorChannel* Channel = PriorityRefs[i]->Channel;
			if ( Channel && (NetDriver->Time-Channel->RelevantTime < NetDriver->RelevantTimeout - 1.1f) )
			{
				AActor* Actor = PriorityRefs[i]->Actor;
				//Reset the relevancy timers if the channels are saturated
				if ( PriorityRefs[i]->SuperRelevant > 0 || ActorIsVisible( Actor, Connection->Actor, Viewer, &Location, *(CFVector4*)&EndOffset) )
					Channel->RelevantTime = NetDriver->Time + (1.1f - NetDriver->RelevantTimeout);
			}
		}
	}

private:
	FActorPrioritizer();
};

//======================================================================
//============ LEVEL HOOK
//
INT UXC_Level::ServerTickClients( FLOAT DeltaSeconds )
{
	guard(UXC_Level::ServerTickClients);

	if ( NetDriver->ClientConnections.Num() == 0 )
		return 0;

	//Fix net driver, do not send keepalive packets on every frame!
	NetDriver->KeepAliveTime = Max( NetDriver->KeepAliveTime, 0.2f);

	DeltaSeconds /= GetLevelInfo()->TimeDilation;
	FLOAT MaxTickRate = Engine->Client ? (1.0f/DeltaSeconds) : Engine->GetMaxTickRate(); //This should become an argument

	FMemMark Mark(GMem);
	FXC_ServerProc* Proc = (FXC_ServerProc*)((UXC_GameEngine*)Engine)->XCGESystems.FindByType( TEXT("ServerProc"));
	check(Proc);
	FActorPrioritizer* Prioritizer = NULL;

	INT Updated=0;
	FLOAT ClientOffset = 0;
	for ( INT i=0 ; i<Proc->Clients.Num() ; i++ )
	{
		FNetClientInfo& Client = Proc->Clients(i);

		// See if connection is valid, we're now updating per a different clients list
		UNetConnection* Conn = Client.Connection;
		if ( UObject::GetIndexedObject(Client.ObjectIndex) != Conn )
			continue;
		check( Conn);
		check( Conn->State==USOCK_Pending || Conn->State==USOCK_Open || Conn->State==USOCK_Closed);

		// Bandwidth and status
		FLOAT Saturation = Client.GetSaturation();
		if ( !Conn->Actor || !Conn->IsNetReady(0) || Conn->State!=USOCK_Open )
			continue;
		if ( Conn->Driver->Time - Conn->LastReceiveTime > 1.5f )
			continue;

		// Artificially limit a Client's update rate
		FLOAT ClientUpdateRate = (Saturation < 0.50f) ? 120.f
								: (Saturation < 0.65f) ? 80.f
								: (Saturation < 0.80f) ? 40.f
								: (Saturation < 0.90f) ? 20.f
								: 10.f;
		if ( (Client.TickRate > 3) && (Client.TickRate < appRound(ClientUpdateRate)) )
			ClientUpdateRate = (FLOAT)Client.TickRate;
		// Spectators should use less resources
		if ( Conn->Actor->PlayerReplicationInfo && Conn->Actor->PlayerReplicationInfo->bIsSpectator )
			ClientUpdateRate *= 0.5;

//		static int Log = 0;
//		if ( Log++ % 64 == 0 )
//			debugf( TEXT("BANDWIDTH: %f, RATE=%f %i"), Saturation, ClientUpdateRate, Client.TickRate);

		if ( TimeInteger( Client.LastRelevancyTime) != TimeInteger( NetDriver->Time) )
		{
			FLOAT ClientTime = TimeFraction(Client.LastRelevancyTime) + ClientOffset;
			FLOAT DriverTime = TimeFraction(NetDriver->Time) + ClientOffset;
			if ( appRound(ClientTime*ClientUpdateRate) == appRound(DriverTime*ClientUpdateRate) )
				continue;
		}
		// Setup Prioritizer on demand
		if ( !Prioritizer )
		{
			INT ActorCount = Proc->BuildConsiderLists( GMem, DeltaSeconds);
			Prioritizer = new( GMem) FActorPrioritizer( GMem, ActorCount);
		}

		// HACK: Manually desaturate a bit
		FLOAT Desaturate = (MaxTickRate*0.5 - ClientUpdateRate) * (1.0f - Saturation);
		if ( Desaturate > 0 )
			Conn->QueuedBytes -= appRound((FLOAT)Conn->CurrentNetSpeed * 0.1f / Desaturate);

		Updated++;
		NetTag++;
		INT OldQueuedBytes = Conn->QueuedBytes;

		Conn->TickCount++;
		FLOAT DeltaRelevancy = NetDriver->Time - Client.LastRelevancyTime;
		Prioritizer->Setup( Conn, Min( MaxTickRate,ClientUpdateRate), DeltaRelevancy);
		Prioritizer->PrioritizeActors( *Proc, Client);
		Prioritizer->ReplicateActors();
		Conn->FlushNet();

		Client.LastRelevancyTime = NetDriver->Time;
		Client.AddSaturation( (FLOAT)(Conn->QueuedBytes - OldQueuedBytes) / (FLOAT)Conn->CurrentNetSpeed, DeltaRelevancy);
		ClientOffset += 0.023f;
	}

	Mark.Pop();
	return Updated;
	unguard;
}


void UXC_Level::TickNetServer( FLOAT DeltaSeconds )
{
	guard(UXC_Level::TickNetServer);

	if ( ! ((UXC_GameEngine*)Engine)->bUseNewRelevancy )
	{
		Super::TickNetServer( DeltaSeconds);
		return;
	}

	// Update window title
//	if( (INT)(TimeSeconds-DeltaSeconds)!=(INT)(TimeSeconds.GetFloat()) )
	if ( TimeInteger( TimeSeconds + DeltaSeconds) != TimeInteger( TimeSeconds) )
		debugf( NAME_Title, LocalizeProgress(TEXT("RunningNet"),TEXT("Engine")), *GetLevelInfo()->Title, *URL.Map, NetDriver->ClientConnections.Num() );

	clock(NetTickCycles);
	INT Updated = ServerTickClients( DeltaSeconds);
	unclock(NetTickCycles);

	// Stats.
	static INT SkipCount = 0;
	static FLOAT AccTickRate = 0;

	if ( Updated )
	{
		SkipCount++;
//		AccTickRate += DeltaSeconds;
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
						FXC_ServerProc* Proc = (FXC_ServerProc*)((UXC_GameEngine*)Engine)->XCGESystems.FindByType( TEXT("ServerProc"));
						AccTickRate = Proc->CalcRealTickRate();
//						AccTickRate = GetLevelInfo()->TimeDilation * (FLOAT)SkipCount / AccTickRate;
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