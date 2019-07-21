//=============================================================================
// EventAttractorPath.
//
// Event Chain system's basic attractor
//=============================================================================
class EventAttractorPath expands XC_NavigationPoint;

var NavigationPoint TargetPath;
var EventLink ControlEvent; //This is what we're trying to bypass
var EventLink EnablerEvent; //This is who controls if we should attract
/*
event PostBeginPlay()
{
}*/

event int SpecialCost( Pawn Seeker)
{
	if ( (ControlEvent == None) || ControlEvent.bInProgress || !ControlEvent.bActive
	  || (EnablerEvent == None) || EnablerEvent.bInProgress || !EnablerEvent.bRoot )
		return 10000000;
	return 0;
}

event Actor SpecialHandling( Pawn Other)
{
	if ( (EnablerEvent != None) && (HSize(Other.Location - Location) < 10) && (EnablerEvent.Owner.Brush != None || EnablerEvent.Owner.bCollideActors) )
		return EnablerEvent.Owner;
	Other.SpecialGoal = Other;
	Other.SpecialPause = 1;
	return Other;
}



defaultproperties
{
     bSpecialCost=True
}
