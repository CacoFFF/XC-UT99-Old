//=============================================================================
// SCF_Disabler
// Used to disable conflicting features from ServerCrashFix
//=============================================================================
class SCF_Disabler expands XC_Engine_Actor
	transient;

//Note: This is the only script event called before GameInfo.Init
event XC_Init()
{
	local Actor A;
	local class<Actor> AC;

	// ServerCrashFix appears to be loaded, find the SCFActor and remove incompatible hooks
	AC = class<Actor>( class'XC_CoreStatics'.static.FindObject( "SCFActor", class'Class'));
	if ( AC != None )
	{
		ForEach AllActors( AC, A)
		{
			A.SetPropertyText("bFixNetDriver","0");
			A.SetPropertyText("bFixExec","0");
			A.SetPropertyText("bFixMalloc","0");
			A.SetPropertyText("bFixHandlers","0");
			Log("Disabling bFixNetDriver, bFixExec, bFixMalloc, bFixHandlers in SCF", 'XC_Engine');
			break;
		}
	}
	Destroy();
}
