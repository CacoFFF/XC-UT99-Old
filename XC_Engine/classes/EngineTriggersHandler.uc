//=============================================================================
// EngineTriggersHandler
//
// This handler will create event links for known Engine triggers
// NOTE: Doesn't catch bStatic=True triggers
//=============================================================================
class EngineTriggersHandler expands EventChainHandler;


event InitializeHandler()
{
	local Trigger T;
	local Dispatcher D;
	local Counter C;
	local ZoneTrigger Z;
	local RoundRobin R;

		
	ForEach DynamicActors( class'Trigger', T)
		if ( (T.Class == class'Trigger') && (T.Event != '') )
			AddEvent( Spawn(class'EL_Trigger', T, T.Tag, T.Location));
		
	ForEach DynamicActors( class'Dispatcher', D)
		if ( D.Class == class'Dispatcher' )
			AddEvent( Spawn(class'EL_Dispatcher', D, D.Tag, D.Location));
		
	ForEach DynamicActors( class'Counter', C)
		if ( (C.Class == class'Counter') && (C.Event != '') )
			AddEvent( Spawn(class'EL_GenericPropagator', C, C.Tag, C.Location));

	ForEach DynamicActors( class'ZoneTrigger', Z)
		if ( (Z.Class == class'ZoneTrigger') && (Z.Event != '') )
			AddEvent( Spawn(class'EL_Trigger', Z, Z.Tag, Z.Location));
		
	ForEach DynamicActors( class'RoundRobin', R)
		if ( (R.Class == class'RoundRobin') && (R.OutEvents[0] != '') )
			AddEvent( Spawn(class'EL_RoundRobin', R, R.Tag, R.Location));
}

