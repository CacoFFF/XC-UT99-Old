//=============================================================================
// PreLoginHookElement
//
// Singleton that processes one kind of PreLogin hook.
// Keep in mind that Error/FailCode may be already set in any of the calls.
//
// Save game support yet to be tested
//=============================================================================
class PreLoginHookElement expands PreLoginHookSystem
	abstract;

var PreLoginHookAddon Master; // If this isn't set, then initialization failed!

event XC_Init();

function PreLoginHook_PreProcess // Called before PreLogin
(
	string Options,
	string Address,
	out string Error,
	out string FailCode
);

function PreLoginHook_PostProcess // Called after PreLogin (only if passes PreLogin)
(
	string Options,
	string Address,
	out string Error,
	out string FailCode
);


// You should NOT override PreBeginPlay, use PostBeginPlay instead
event PreBeginPlay()
{
	Super.PreBeginPlay();
	if ( !bDeleteMe )
	{
		Master = GetAddonInstance();
		if ( Master == none )
			Destroy();
		else
			Master.RegisterElement( self);
	}
}

event Destroyed()
{
	Super.Destroyed();
	Master.UnRegisterElement( self);
}