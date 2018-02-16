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
