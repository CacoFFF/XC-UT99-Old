//=============================================================================
// InventoryHoldSpot.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class InventoryHoldSpot expands BaseLevelPoint;

var Inventory ItemProtegido;
var InventorySpot PresetPoint;

event PostBeginPlay()
{
	SetTimer(0.5, False);
}

function Timer()
{
	if (ItemProtegido == none)
		Destroy();
}

defaultproperties
{
}
