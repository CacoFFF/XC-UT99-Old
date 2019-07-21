//=============================================================================
// EngineInventoryHandler
//
// This handler will create event links for inventory items that trigger an
// event upon being touched.
//=============================================================================
class EngineInventoryHandler expands EventChainHandler;

function InitializeHandler()
{
	local Inventory Inv;
		
	ForEach DynamicActors( class'Inventory', Inv)
	{
		if ( Inv.Event != '' )
			AddEvent( Spawn(class'EL_InventoryToucher', Inv, Inv.Tag, Inv.Location));
	}
}