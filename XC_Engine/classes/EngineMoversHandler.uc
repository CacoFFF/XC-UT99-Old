//=============================================================================
// EngineMoversHandler
//
// This handler will create event links for known Engine movers as well as
// adding additional Bot handling methods.
//=============================================================================
class EngineMoversHandler expands EventChainHandler;


function InitializeHandler()
{
	local Mover M;
		
	ForEach AllActors( class'Mover', M)
	{
		if ( IsKnownState(M) && IsMoverRelevant(M) )
			AddEvent( Spawn(class'EL_Mover', M, M.Tag, M.Location));
		if ( IsMoverBumpRelevant(M) )
			AddEvent( Spawn(class'EL_MoverBump', M, M.Tag, M.Location));
	}
}




static function bool IsKnownState( Mover M)
{
	local name MoverState;
	
	MoverState = M.GetStateName();
	if ( MoverState == '' || MoverState == M.Class.Name )
		MoverState = M.InitialState;
		
	return MoverState == 'BumpOpenTimed'
		|| MoverState == 'BumpButton'
		|| MoverState == 'StandOpenTimed' 
		|| MoverState == 'TriggerPound'
		|| MoverState == 'TriggerControl'
		|| MoverState == 'TriggerToggle'
		|| MoverState == 'TriggerOpenTimed';
}

static function bool IsMoverRelevant( Mover M)
{
	local name MoverState;
	
	if ( M == None )
		return false;
	
	MoverState = M.GetStateName();
	
	if ( M.bTriggerOnceOnly && (MoverState == '' || MoverState == M.Class.Name) && !M.Level.bStartup )
		return false;
	
	if ( MoverState == '' || MoverState == M.Class.Name )
		MoverState = M.InitialState;

	return M.Event != ''
		|| (MoverState != 'BumpOpenTimed'
			&& MoverState != 'BumpButton'
			&& MoverState != 'StandOpenTimed');
}

static function bool IsMoverBumpRelevant( Mover M)
{
	local int EventCount;
	
	if ( M != None )
	{
		EventCount += int((M.BumpEvent != '') && ((M.BumpEvent != M.Tag) || IsUniqueTagged(M)));
		EventCount += int((M.PlayerBumpEvent != '') && ((M.PlayerBumpEvent != M.Tag) || IsUniqueTagged(M)));
	}
	return EventCount > 0;
}

static function bool IsUniqueTagged( Actor Other)
{
	local Actor A;

	if ( A.Tag == '' )
		return false;
	ForEach Other.AllActors( class'Actor', A, Other.Tag)
		if ( (A != Other) && (EventLink(A) == None) )
			return false;
	return true;
}


/** ================ Script Patcher
 *
 * Creates a proxy for Mover.HandleTriggerDoor
 *
 * Allows additional AI directives in case of HandleTriggerDoor failing, including the
 * creation of missing EventLink in order to force this Mover to open.
*/

function ScriptPatcherInit()
{
}


final function bool HandleTriggerDoor_Original( Pawn Other);
function bool HandleTriggerDoor_Proxy( Pawn Other)
{
	local Mover M;
	local Actor A;
	local bool bHandle;
	
	A = self;
	M = Mover(A);
	bHandle = HandleTriggerDoor_Original( Other);
	
	//Case 1: handle with unreachable MoveTarget
	if ( bHandle && (Other.MoveTarget == M.TriggerActor || Other.MoveTarget == M.TriggerActor2) && !Other.ActorReachable(Other.MoveTarget) )
	{
		//Action: establish EventLink then temporarily block reachspecs leading through the mover.
	}
	//Case 2: unable to handle, no trigger actor
	if ( !bHandle && (M.TriggerActor == None) )
	{
		//Action: find trigger, if unreachable create EventLink (as new TriggerActor) then block reacspecs leading through the mover.
	}
	return bHandle;
}



