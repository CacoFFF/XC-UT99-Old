//=============================================================================
// EngineTeleportersHandler
//
// This handler will create event links for Engine teleporters.
// Enhanced bot handling will be added as well.
//=============================================================================
class EngineTeleportersHandler expands EventChainHandler;

function InitializeHandler()
{
	local Teleporter T;
		
	ForEach NavigationActors( class'Teleporter', T)
		if ( (T.Class == class'Teleporter') && IsValidTeleporter(T) )
			AddEvent( Spawn(class'EL_Teleporter', T, T.Tag, T.Location));
}


static function bool IsValidTeleporter( Teleporter T)
{
	return (T != None) && T.bCollideActors && (T.Tag != '') && (T.URL != "");
}




/** ================ Script Patcher
 *
 * Creates a proxy for Teleporter.SpecialHandling
 *
 * Allows additional AI directives in case of SpecialHandling being unable
 * to find a reachable trigger.
*/

function ScriptPatcherInit()
{
	if ( Class == class'EngineTeleportersHandler' )
	{
		ReplaceFunction( Class, class'Teleporter', 'SpecialHandling_Original', 'SpecialHandling');
		ReplaceFunction( class'Teleporter', Class, 'SpecialHandling', 'SpecialHandling_Proxy');
	}
}

final function EL_Teleporter GetEventLink( Teleporter T)
{
	local EL_Teleporter EL;
	if ( T != None )
	{
		ForEach DynamicActors( class'EL_Teleporter', EL)
			if ( EL.Owner == T )
				break;
	}
	return EL;
}

final function Actor SpecialHandling_Original( Pawn Other);
function Actor SpecialHandling_Proxy( Pawn Other)
{
	local Actor A, Special;
	
	A = Self;
	Special = SpecialHandling_Original( Other);
	if ( (Special != Self) && Teleporter(Other.RouteCache[1]) != None )
	{
		//Either no TriggerActor, or TriggerActor not reachable
		//TODO: MULTIPLE TELE DESTINATIONS
		RerouteEndPoint( GetEventLink(Teleporter(A)), Teleporter(Other.RouteCache[1]), Other, Special);
	}
	
	//Bot may try to reuse this teleporter as a normal path elsewhere, disable special handling result
	if ( Special != None && Teleporter(Other.RouteCache[1]) == None )
		Special = None;
	return Special;
}


