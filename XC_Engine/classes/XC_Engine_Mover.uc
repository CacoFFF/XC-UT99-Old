class XC_Engine_Mover expands Mover;

function TC_Trigger( actor Other, pawn EventInstigator )
{
	numTriggerEvents++;
	SavedTrigger = Other;
	Instigator = EventInstigator;
	if ( SavedTrigger != None )
		SavedTrigger.BeginEvent();
	if ( numTriggerEvents == 1 ) //Prevent multiple interpolation starts
		GotoState( 'TriggerControl', 'Open' );
}



//======== InterpolateTo Original backup - begin ==========//
//
// Stores Mover.InterpolateTo original code here
//
final function InterpolateTo_Org( byte NewKeyNum, float Seconds )
{
}
//======== InterpolateTo Original backup - end ==========//


//======== InterpolateTo hack - begin ==========//
//
// Hacked version of Mover.InterpolateTo
// Fixes the 'Seconds' parameter so that movers don't badly
// desync in net games
// 
final function InterpolateTo_MPFix( byte NewKeyNum, float Seconds )
{
	Seconds = int(100.0 * FMax(0.01, (1.0 / FMax(Seconds, 0.005))));
	Seconds = 1.0 / (Seconds * 0.01);
	InterpolateTo_Org( NewKeyNum, Seconds);
}
//======== InterpolateTo hack - end ==========//
