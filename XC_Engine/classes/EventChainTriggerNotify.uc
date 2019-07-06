//=============================================================================
// EventChainTriggerNotify
//
// This catches trigger commands and sends notifications to triggerer
//=============================================================================
class EventChainTriggerNotify expands EventChainSystem;

var EventChainTriggerNotify NextNotify;
var EventLink Root;

//Do not filter
event PreBeginPlay()
{
	Root = EventLink( Owner);
	Disable('Tick');
}

event Trigger( Actor Other, Pawn EventInstigator)
{
	Enable('Tick');
}

event Tick( float DeltaTime)
{
	Disable('Tick');
	Root.Update();
}

