//=============================================================================
// FV_Addons
// UnrealScript addons from XC_Engine, the kind that needs to spawn an actor.
//=============================================================================
class FV_Addons expands XC_Engine_Actor
	abstract;

// Only one addon may be loaded per level
// Only initialize script patcher in saved games
// Override XC_Init if this is an addon element (that doesn't need unique check or init)
event XC_Init()
{
	local Actor A;
	
	ForEach DynamicActors( Class, A) //Compiler bug forcing me to use 'Actor'
		if ( (A.Class == Class) && (A != self) )
		{
			Destroy();
			FV_Addons(A).ScriptPatcherInit();
			return;
		}
		
	AddonCreated();
	ScriptPatcherInit();
}


function AddonCreated();         //Spawn new stuff here
function ScriptPatcherInit();    //Modify code here


defaultproperties
{
	bHidden=True
	RemoteRole=ROLE_None
}
