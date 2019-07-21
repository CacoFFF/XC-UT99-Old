//=============================================================================
// ACE_Disabler
// Used to disable ACE on Unreal 1 games.
//=============================================================================
class ACE_Disabler expands XC_Engine_Actor
	transient;

//Note: This is the only script event called before GameInfo.Init
event XC_Init()
{
	local Actor A;
	
	ForEach DynamicActors( class'Actor', A)
		if ( A.IsA('IACECommon') || A.IsA('ACEM_Actor') )
		{
			Log( "Removing"@A.Name@", not supposed to run on gametype"@Level.Game.Class, 'XC_Engine');
			A.Destroy();
		}
	Destroy();
}
