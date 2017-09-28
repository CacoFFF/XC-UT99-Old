//=============================================================================
// Global Goal pathnode
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_OneTimeGoal expands Botz_NavigBase;

event FinishedPathing()
{
	SetTimer(0.5, false);
}

event Timer()
{
	//Register this goal?
	if ( MyLoader.MasterG.MyTargeter != none )
		MyLoader.MasterG.MyTargeter.OneTimeGoal( self);
}

defaultproperties
{
	FriendlyName="Goal Once"
	MaxDistance=750
	ExtraCost=0
}