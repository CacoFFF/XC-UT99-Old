//=============================================================================
// JumpItemToObjective.
//
// This will force bots to wait here at jump boots until the item has been
// picked up.
//=============================================================================
class JumpItemToObjective expands XC_NavigationPoint;

var InventorySpot Marker;

event int SpecialCost( Pawn Seeker)
{
	if ( Seeker.RouteCache[1] == self )
		Seeker.RouteCache[1] = None;
		
	// We assume the marker is undeletable
	if ( Seeker.JumpZ > Seeker.Default.JumpZ * 1.5 || !AttractsBots(Marker.MarkedItem) ) 
		return 10000000;

	//Predict respawn
	if ( Marker.MarkedItem.bHidden && Marker.MarkedItem.LatentFloat < 20 )
		return 200 * Marker.MarkedItem.LatentFloat;
	
	//Bot can't jump over obstruction, send bot to boots
	return 0; 
}

function Actor SpecialHandling(Pawn Other)
{
	Other.SpecialGoal = Other;
	Other.SpecialPause = 1;
	if ( Marker.MarkedItem != None )
		return Marker.MarkedItem; //This should force bot to wait if trying to go through here
	return Marker;
}

static function bool AttractsBots( Inventory Other)
{
	return UT_JumpBoots(Other) != None || JumpBoots(Other) != None;
}


defaultproperties
{
    bSpecialCost=True
	ExtraCost=10000000
	bCollideWhenPlacing=False
	bPlayerOnly=True
	bStatic=False
	bNoDelete=False
	bGameRelevant=True
}
