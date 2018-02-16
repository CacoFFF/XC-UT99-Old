//Edit various PlayerPawn functions

//************************************
//Precached variables go here

static INT NAMES_PlayerPawn_Funcs = 0;
static FName NAME_PP_CanSpectate;
static FName NAME_PP_BecomeViewTarget;

//************************************
//Definitions, classes and events go here

struct APlayerPawn_Dummy : public APlayerPawn
{
	// UTPG --
	INT LoginAttempts;		// How many login attempts we've made
	UBOOL bLoginDisabled;	// no longer able to login even if correct password
	FLOAT NextLoginTime;	// Time at which game will accept another attempt to login

	// All received from GameInfo
	FLOAT ViewDelay;		// Seconds between each viewplayer()/viewplayernum()
	FLOAT TauntDelay;		// Seconds between taunts
	FLOAT SpeechDelay;		// Seconds between chat messages

	FLOAT LastView;			// Used to track last view
	FLOAT LastTaunt;		// Used to track last taunt
	FLOAT LastSpeech;		// Used to track last chat message

	UBOOL bCyclingView;		// Used to allow ViewClass to disregard LastView

	FLOAT MinFOV;			// Enforced MinFOV for this server
	FLOAT MaxFOV;			// Enforced MaxFOV for this server

	INT MaxNameChanges;		// Max number of time a player can change their name in the game
	INT NameChanges;		// Used to track name changes

	void ViewClass( UClass* aClass, UBOOL bQuiet=0);
	DECLARE_FUNCTION( execViewClass);
};

//************************************
//Utilitary/common methods used by natives

static UBOOL GameCanSpectate( AGameInfo* Game, APawn* Viewer, AActor* ViewTarget)
{
	if ( !Game )
		return 0;
	INT Params[3];
	Params[0] = (INT) Viewer;
	Params[1] = (INT) ViewTarget;
	Params[2] = 0; //Return value
	UFunction* CanSpectate = Game->FindFunction( NAME_PP_CanSpectate);
	if ( CanSpectate )
		Game->ProcessEvent( CanSpectate, Params);
	return Params[2];
}

static void ActorBecomeViewTarget( AActor* Other)
{
	if ( !Other )
		return;
	UFunction* BecomeViewTarget = Other->FindFunction(NAME_PP_BecomeViewTarget);
	if ( BecomeViewTarget )
		Other->ProcessEvent( BecomeViewTarget, NULL);
}

static FString GetBestName( AActor* Other)
{
	if ( !Other )
		return FString(0);
	APawn* P = Cast<APawn>(Other);
	if ( P && P->PlayerReplicationInfo && P->PlayerReplicationInfo->PlayerName.Len() )
		return P->PlayerReplicationInfo->PlayerName;
	return Other->GetName();
}

void APlayerPawn_Dummy::ViewClass( UClass* aClass, UBOOL bQuiet )
{
	guard( ViewClass);
	if ( !Level || !XLevel || !aClass || (Level->Game && !Level->Game->bCanViewOthers) )
		return;
	
	if ( XCGE_Defaults->b451Setup && !bCyclingView )
	{
		if ( (ViewDelay > 0.0f) && (Level->TimeSeconds - LastView < ViewDelay) )
			return;
		LastView = Level->TimeSeconds;
	}

	//This optimizes the following loop
	if ( ViewTarget && !ViewTarget->IsA(aClass) )
		ViewTarget = NULL;
	
	AActor* First = NULL;
	UBOOL bFound = 0;
	INT i=0;
	for ( ; i<XLevel->Actors.Num() ; i++ )
	{
		AActor* Other = XLevel->Actors(i);
		if ( Other && !Other->bDeleteMe && Other->IsA( aClass) )
		{
			if ( !First && (Other != this) && ((bAdmin && !Level->Game) || GameCanSpectate(Level->Game, this, Other))  )
			{
				First = Other;
				if ( (bFound == 2) || !ViewTarget ) //No need to keep querying
					break;
				bFound = 1;
			}
			if ( Other == ViewTarget )
			{
				First = NULL;
				bFound = 2;
			}
		}
	}
	if ( First )
	{
		if ( !bQuiet )
			eventClientMessage( ViewingFrom + GetBestName(First), NAME_Event, 1);
	}
	else if ( !bQuiet )
	{
		if ( bFound )
			eventClientMessage( ViewingFrom + OwnCamera, NAME_Event, 1);
		else
			eventClientMessage( FailedView, NAME_Event, 1);
	}
	ViewTarget = First;

	bBehindView = (ViewTarget != NULL);
	if ( bBehindView )
		ActorBecomeViewTarget(ViewTarget);
	unguard;
}


//************************************
//Natives go here

/**
- Native functions are designed to retrieve parameters from the higher stack
- ProcessEvent creates a new stack with pre-stored locals and passes it 
  incorrectly because it's not designed to be used on native functions.
- Therefore variables don't come from code, but from pre-stored locals.
*/	

void APlayerPawn_Dummy::execViewClass( FFrame& Stack, RESULT_DECL)
{
	guard(execViewclass);

	//Register subnames
	if ( !NAMES_PlayerPawn_Funcs )
	{
		NAMES_PlayerPawn_Funcs = 1;
		NAME_PP_CanSpectate			= FName(TEXT("CanSpectate"), FNAME_Intrinsic);
		NAME_PP_BecomeViewTarget	= FName(TEXT("BecomeViewTarget"), FNAME_Intrinsic);
	}
	
	//Classify our node's execution stack
	UFunction* F = Cast<UFunction>(Stack.Node);
	
	//Called via ProcessEvent >>> Native to Script
	if ( F && F->Func == (Native)&APlayerPawn_Dummy::execViewClass )
	{
		UClass**	ActorClassRef	= (UClass**)	(Stack.Locals + 0);
		UBOOL*		bQuietRef		= (UBOOL*)		(Stack.Locals + 4);
		ViewClass( *ActorClassRef, *bQuietRef);
		return;
	}
	
	//Called via ProcessInternal >>> Script to Native
	P_GET_OBJECT( UClass, ActorClass);
	P_GET_UBOOL_OPTX( bQuiet, 0);
	P_FINISH;
	ViewClass( ActorClass, bQuiet);
	unguard;
}

//
// Manually register this native function so it gets associated with XC_Engine_PlayerPawn
//
#if _MSC_VER
	extern "C" DLL_EXPORT Native intAXC_Engine_PlayerPawnexecViewClass = (Native)&APlayerPawn_Dummy::execViewClass;
#else
	extern "C" DLL_EXPORT { Native intAXC_Engine_PlayerPawnexecViewClass = (Native)&APlayerPawn_Dummy::execViewClass; }
#endif
//		static BYTE cls##func##Temp = GRegisterNative( num, int##cls##func );


