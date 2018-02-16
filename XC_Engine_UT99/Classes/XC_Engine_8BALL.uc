class XC_Engine_8BALL expands UT_EightBall
	abstract;

	
function Tick( float DeltaTime )
{
	local Pawn P;
	
	P = Pawn(Owner);
	if ( P == None )
		return;
	if ( !P.IsA('PlayerPawn') )
	{
		if ( (P.MoveTarget != P.Target) 
			|| (LockedTarget != None)
			|| (P.Enemy == None)
			|| ( Mover(P.Base) != None )
			|| ((P.Physics == PHYS_Falling) && (P.Velocity.Z < 5))
			|| (P.Target != None && (VSize(P.Location - P.Target.Location) < 400))
			|| !P.CheckFutureSight(0.15) )
			P.bFire = 0;
	}
	if( P.bFire==0 || RocketsLoaded > 5)  // If Fire button down, load up another
		GoToState('FireRockets');
}
