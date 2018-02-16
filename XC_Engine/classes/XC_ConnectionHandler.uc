//=============================================================================
// XC_ConnectionHandler.
// Version 1, internal betatesting at UnrealKillers servers.
// - Initial release.
// Version 2, publicly released on XC_GameEngine version 13
// - Can now query the TCPNetDriver multiple times per frame.
//
// This actor can operate independantly of XC_GameEngine
// You may specify as ServerActor and spawn it in your server to use this
// anti DoS protection that mostly consists of fake players and connection
// attempt overflow at the game port (default: 7777)
//=============================================================================
class XC_ConnectionHandler expands Actor
	native
	config(XC_Engine);

var() config float DatalessTimeout; //Timeout for dataless connections in normal conditions
var() config float CriticalTimeout; //Timeout for dataless connections in critical conditions
var() config int CriticalConnCount; //Amount of dataless connections needed to trigger critical mode
var() config int ExtraTCPQueries; //Extra TCPNetDriver queries per frame


//native /*3554*/ final iterator function AllConnections( out NetConnection Connection);

//Do not mutate, prevent stupid config values
event PreBeginPlay()
{
	local XC_ConnectionHandler Other;
	ForEach AllActors (class'XC_ConnectionHandler', Other)
		if ( Other != self )
		{
			Destroy();
			return;
		}
	if ( DatalessTimeout < 2 )
		DatalessTimeout = 5;
	if ( CriticalConnCount < 2 )
		CriticalConnCount = 10;
	SaveConfig();
	Tag='EndGame';
}

event Trigger( Actor Other, Pawn EventInstigator)
{
	SaveConfig();
}

defaultproperties
{
     DatalessTimeout=5
     CriticalTimeout=2
     CriticalConnCount=10
     ExtraTCPQueries=2
     bHidden=True
     bAlwaysTick=True
}
