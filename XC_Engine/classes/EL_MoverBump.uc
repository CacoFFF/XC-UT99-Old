class EL_MoverBump expands EventLink;

const EMH = class'EngineMoversHandler';

//Optional AI marker to defer to
function NavigationPoint DeferTo()
{
	if ( (Mover(Owner) != None) && (Mover(Owner).myMarker != None) )
		return Mover(Owner).myMarker;
	return AIMarker;
}

function Update()
{
	// Is this mover still relevant?
	if ( !EMH.static.IsMoverBumpRelevant( Mover(Owner) ) )
		Destroy();
}

//Actor can initiate event chain by interacting with owner
function bool CanFireEvent( Actor Other)
{
	local Mover M;

	M = Mover(Owner);
	return M != None 
		&& ((M.BumpType == BT_AnyBump)
		 || (M.BumpType == BT_PawnBump && Other.bIsPawn && (Other.Mass < 10))
		 || (M.BumpType == BT_PlayerBump && Other.bIsPawn && Pawn(Other).bIsPlayer));
}

function AnalyzedBy( EventLink Other)
{
	local Mover M;
	
	M = Mover(Owner);
	Assert( M != None);
	AnalyzeEvent( M.BumpEvent);
	AnalyzeEvent( M.PlayerBumpEvent);
}

defaultproperties
{
     bRoot=True
     bRootEnabled=True
}
