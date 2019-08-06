class EL_InventoryToucher expands EL_GenericToucher;

function Update()
{
	Super.Update();
	if ( !bDeleteMe )
	{
		bRootEnabled = Owner.IsInState('Pickup');
		bInProgress = Owner.IsInState('Sleeping');
		if ( !bRootEnabled && !bInProgress ) //Something not right (item in player's hands?)
			Destroy();
		else if ( bInProgress )
			SetTimer( Owner.LatentFloat + 0.01, false);
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
	return bRootEnabled && (Pawn(Other) != None) && Pawn(Other).bIsPlayer && (Pawn(Other).Health > 0);
}
