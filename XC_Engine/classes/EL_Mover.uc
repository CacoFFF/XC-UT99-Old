class EL_Mover expands EventLink;

const EMH = class'EngineMoversHandler';


function Update()
{
	local Mover M;
	
	// Is this mover still relevant?
	M = Mover(Owner);
	if ( !EMH.static.IsMoverRelevant(M) )
	{
		Destroy();
		return;
	}

	bRoot = false;
	bActive = false;
	bInProgress = false;
	if ( !EMH.static.IsKnownState(M) )
		return;

	bRoot = M.IsInState('StandOpenTimed') || M.IsInState('BumpOpenTimed') || M.IsInState('BumpButton') || M.BumpEvent == Tag || M.PlayerBumpEvent == Tag;

	if ( !M.IsInState('StandOpenTimed') && !M.IsInState('BumpOpenTimed') && !M.IsInState('BumpButton') )
	{
		if ( M.IsInState('TriggerOpenTimed') )
			bActive = !M.bDelaying && !M.bInterpolating && !M.KeyNum;
		else if ( M.IsInState('TriggerControl') || M.IsInState('TriggerPound') )
			bActive = !M.bInterpolating && (M.KeyNum + 1 < M.NumKeys);
		else if ( M.IsInState('TriggerToggle') )
			bActive = !M.bInterpolating && !M.bDelaying;
	}
	if ( bRoot )
		bInProgress = M.bDelaying || M.bInterpolating || M.KeyNum > 0;
	else
		bInProgress = !bActive;
	
	if ( M.LatentFloat > 0 ) //Re-enter
		SetTimer( M.LatentFloat + 0.01, false);
}

//Actor can initiate event chain by interacting with owner
function bool CanFireEvent( Actor Other)
{
	local Mover M;

	M = Mover(Owner);
	return M != None 
		&& bRoot
		&& ((M.BumpType == BT_AnyBump)
		 || (M.BumpType == BT_PawnBump && Other.bIsPawn && (Other.Mass < 10))
		 || (M.BumpType == BT_PlayerBump && Other.bIsPawn && Pawn(Other).bIsPlayer));
}

function AnalyzedBy( EventLink Other)
{
	local Mover M;
	
	M = Mover(Owner);
	Assert( M != None);
	AnalyzeEvent( M.Event);
}

event Timer()
{
	Update();
}
