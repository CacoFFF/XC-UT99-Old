//=============================================================================
// EventChainHandler
//
// This handler is responsible for doing whatever is necessary to recognize and
// create event links.
//
// Keeping the handler alive may be useful for mods that spawn actors that may
// be handled by said handler, but mods would need to properly interact with
// said handlers via KillCredit
//=============================================================================
class EventChainHandler expands EventChainSystem;

var EventLink EventList;

event XC_Init()
{
	ScriptPatcherInit();
}

event PostBeginPlay()
{
	InitializeHandler();
}


//========================== Initialization
//
function InitializeHandler();
function ScriptPatcherInit();
event KillCredit( Actor Other ); //Mods can find this handler and attempt to register an actor via this call


//========================== Event Chain
//
final function EventLink AddEvent( EventLink Other)
{
	//TODO //NATIVE?
}

final function EventLink RemoveEvent( EventLink Other)
{
	//TODO //NATIVE?
}

final function EventLink GetEvent( Actor EventOwner)
{
	local EventLink Link;
	
	For ( Link=EventList ; Link!=None ; Link=Link.NextEvent )
		if ( Link.Owner == EventOwner )
			return Link;
	return none;
}
