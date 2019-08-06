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
		EventCount += int((M.BumpEvent != '') && ((M.BumpEvent != M.Tag) || !IsUniqueTagged(M)));
		EventCount += int((M.PlayerBumpEvent != '') && ((M.PlayerBumpEvent != M.Tag) || !IsUniqueTagged(M)));
	}
	return EventCount > 0;
}

static function bool IsUniqueTagged( Actor Other)
{
	local Actor A;

	if ( Other.Tag == '' )
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
	if ( Class == class'EngineMoversHandler' )
	{
		ReplaceFunction( Class, class'Mover', 'HandleTriggerDoor_Original', 'HandleTriggerDoor');
		ReplaceFunction( class'Mover', Class, 'HandleTriggerDoor', 'HandleTriggerDoor_Proxy');
	}
}

final function EL_Mover GetEventLink( Mover M)
{
	local EL_Mover EL;
	if ( M != None )
	{
		ForEach DynamicActors( class'EL_Mover', EL)
			if ( EL.Owner == M )
				break;
	}
	return EL;
}

final function bool HandleTriggerDoor_Original( Pawn Other);
function bool HandleTriggerDoor_Proxy( Pawn Other)
{
	local Mover M;
	local Actor A;
	local bool bHandle;
	local NavigationPoint OldPath;
	
	
	A = self;
	M = Mover(A);
	OldPath = NavigationPoint(Other.MoveTarget);
	if ( OldPath == None )
		OldPath = Other.RouteCache[0];
	if ( EventModifierPath(OldPath) != None )
		OldPath = EventModifierPath(OldPath).TargetPath;
	bHandle = HandleTriggerDoor_Original( Other);
	
	// I am not a lift
	if ( M.MyMarker == None )
	{
		//Case 1: handle with unreachable MoveTarget (force this one on re-router)
		if ( bHandle && (Other.MoveTarget == M.TriggerActor || Other.MoveTarget == M.TriggerActor2) && !Other.ActorReachable(Other.MoveTarget) )
			RerouteEndPoint( GetEventLink(M), OldPath, Other, Other.MoveTarget);
		//Case 2: unable to handle, find an enabler
		if ( !bHandle && (M.TriggerActor == None) )
			RerouteEndPoint( GetEventLink(M), OldPath, Other);
	}

//	Log( "MOVER"@Other.PlayerReplicationInfo.PlayerName @ bHandle @ OldPath @ Other.MoveTarget);
	return bHandle;
}


