class EL_InventoryToucher expands EL_GenericToucher;

function Update()
{
	Super.Update();
	if ( !bDeleteMe )
	{
		bRoot = Owner.IsInState('Pickup');
		bActive = true;
		bInProgress = Owner.IsInState('Sleeping');
		if ( !bRoot && !bInProgress ) //Something not right (item in player's hands?)
			Destroy();
	}
}

function NavigationPoint DeferTo()
{
	if ( (Inventory(Owner) != None) && (Inventory(Owner).myMarker != None) )
		return Inventory(Owner).myMarker;
	return AIMarker;
}

//Actor can initiate event chain by interacting with owner
function bool CanFireEvent( Actor Other)
{
	return bRoot && (Pawn(Other) != None) && Pawn(Other).bIsPlayer && (Pawn(Other).Health > 0);
}
