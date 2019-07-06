class EL_MoverBump expands EventLink;

const EMH = class'EngineMoversHandler';

function Update()
{
	local Mover M;
	
	// Is this mover still relevant?
	M = Mover(Owner);
	if ( !EMH.static.IsMoverBumpRelevant(M) )
	{
		Destroy();
		return;
	}

	bRoot = true;
	bActive = true;
	bInProgress = false;
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
