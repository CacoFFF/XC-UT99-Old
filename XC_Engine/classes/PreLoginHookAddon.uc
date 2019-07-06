//=============================================================================
// PreLoginHookAddon
// Singleton that references all PreLoginHookElement actors.
//=============================================================================
class PreLoginHookAddon expands PreLoginHookSystem;

var() PreLoginHookElement PreLoginHooks[16];

function ScriptPatcherInit()
{
	RestoreFunction( class'GameInfo', 'PreLogin');
	RestoreFunction( class'PreLoginHookAddon', 'PreLogin_Original');
	
	ReplaceFunction( class'PreLoginHookAddon', class'GameInfo', 'PreLogin_Original', 'PreLogin'); //Backup the function
	ReplaceFunction( class'GameInfo', class'PreLoginHookAddon', 'PreLogin', 'PreLogin_Hook');
}


function RegisterElement( PreLoginHookElement InElement)
{
	local int i;

	For ( i=0 ; i<ArrayCount(PreLoginHooks) ; i++ )
		if ( PreLoginHooks[i] == InElement )
			return;

	For ( i=0 ; i<ArrayCount(PreLoginHooks) ; i++ )
		if ( PreLoginHooks[i] == none || PreLoginHooks[i].bDeleteMe )
		{
			PreLoginHooks[i] = InElement;
			return;
		}
}

function UnRegisterElement( PreLoginHookElement OutElement)
{
	local int i;
	For ( i=0 ; i<ArrayCount(PreLoginHooks) ; i++ )
		if ( PreLoginHooks[i] == OutElement )
		{
			PreLoginHooks[i] = none;
			return;
		}
}

function PreProcess( string Options, string Address, out string Error, out string FailCode)
{
	local int i;
	For ( i=0 ; i<ArrayCount(PreLoginHooks) ; i++ )
		if ( PreLoginHooks[i] != none && !PreLoginHooks[i].bDeleteMe )
			PreLoginHooks[i].PreLoginHook_PreProcess( Options, Address, Error, FailCode);
}

function PostProcess( string Options, string Address, out string Error, out string FailCode)
{
	local int i;
	For ( i=0 ; i<ArrayCount(PreLoginHooks) ; i++ )
		if ( PreLoginHooks[i] != none && !PreLoginHooks[i].bDeleteMe )
			PreLoginHooks[i].PreLoginHook_PostProcess( Options, Address, Error, FailCode);
}

//*******************************************************************
//    HOOK CODE
//    The following must only be called in GameInfo context
//*******************************************************************

// GameInfo.PreLogin copy/backup
final function PreLogin_Original( string Options, string Address, out string Error, out string FailCode);

// GameInfo.PreLogin replacement
final function PreLogin_Hook( string Options, string Address, out string Error, out string FailCode)
{
	local string InPassword; // Prevent Linux v451 crash
	PreLogin_Internal( Options, Address, Error, FailCode);
}

// GameInfo.PreLogin expansion
final function PreLogin_Internal( string Options, string Address, out string Error, out string FailCode)
{
	local PreLoginHookAddon List;
	
	List = GetAddonInstance();
	List.PreProcess( Options, Address, Error, FailCode);
	if ( Error == "" )
		PreLogin_Original( Options, Address, Error, FailCode);
	if ( Error == "" )
		List.PostProcess( Options, Address, Error, FailCode);
}

