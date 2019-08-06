//=============================================================================
// ElevatorReachspecHandler
//
// This handler will create reachspec modifiers on Elevator/LiftCenter duos
//=============================================================================
class ElevatorReachspecHandler expands EventChainHandler;

//Occurs during PostBeginPlay, and these are processed after LiftCenter
function InitializeHandler()
{
	local LiftCenter LC;

	ForEach NavigationActors( class'LiftCenter', LC)
		if ( LC.MyLift != None )
			RegisterElevatorPath( LC, LC.MyLift);
}

event KillCredit( Actor A)
{
	if ( (Mover(A) != None) && (Mover(A).MyMarker != None) )
		RegisterElevatorPath( Mover(A).MyMarker, Mover(A));
}



function RegisterElevatorPath( NavigationPoint Path, Mover Lift)
{
	local ElevatorReachspecModifier Modifier;
	
	if ( Lift.IsA('ElevatorMover')
	|| Lift.IsA('RotatingMover')
	||	( Lift.InitialState != 'TriggerOpenTimed' 
		&& Lift.InitialState != 'BumpOpenTimed' 
		&& Lift.InitialState != 'StandOpenTimed' 
		&& Lift.InitialState != 'TriggerToggle'
		&& Lift.InitialState != 'TriggerControl') )
		return;
	
	Modifier = Spawn( class'ElevatorReachspecModifier', Lift, Lift.Tag, Path.Location + vect(0,0,10) );
	Modifier.Setup( Path, Lift);
}

function Mover FindElevatorForLC( LiftCenter LC)
{
	local Mover M;
	
	if ( LC.LiftTag != '' )
		ForEach AllActors( class'Mover', M, LC.LiftTag)
			break;
	return M;
}