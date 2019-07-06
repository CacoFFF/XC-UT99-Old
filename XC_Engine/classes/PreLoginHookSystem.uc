//=============================================================================
// PreLoginHookSystem
//
// Deprecates old PreLoginHook system for good.
// Now all utils that need to do PreLogin processing must be subclasses of
// PreLoginHookElement and registered in PreLoginHookAddon singleton.
//=============================================================================
class PreLoginHookSystem expands FV_Addons
	abstract;
	
// Only valid in server instances
event PreBeginPlay()
{
	Super.PreBeginPlay();
	if ( !bDeleteMe && (Level.NetMode != NM_DedicatedServer) && (Level.NetMode != NM_ListenServer) )
		Destroy();
}


//****************************** GetAddonInstance
final function PreLoginHookAddon GetAddonInstance()
{
	local PreLoginHookAddon Instance;
	
	ForEach DynamicActors( class'PreLoginHookAddon', Instance)
		break;
	return Instance;
}
