//=============================================================================
// EventChainPack
//
// Use this to spawn handlers, useful for registering a single actor in 
// XC_Engine.ini while remaining compliant to the event chain system config.
//=============================================================================
class EventChainPack expands EventChainSystem;

event XC_Init()
{
	local Actor A;
	
	ForEach DynamicActors( Class, A)
		if ( (A.Class == Class) && (A != self) )
		{
			Destroy();
			return;
		}

	if ( class'XC_Engine_Actor_CFG'.default.bEventChainAddon )
		SpawnHandlers();
}

// Spawn event chain handlers here
function SpawnHandlers()
{
	Spawn( class'ElevatorReachspecHandler');
	Spawn( class'EngineTriggersHandler');
	Spawn( class'EngineMoversHandler');
}


