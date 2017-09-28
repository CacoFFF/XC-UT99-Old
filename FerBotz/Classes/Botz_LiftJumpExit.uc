//=============================================================================
// Lift exit type
// Targeted pathing to the lift center i'm aiming at
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_LiftJumpExit expands Botz_LiftExit;

//Called after botZ decides this is the path to take
//Do some lift handling here?
function bool PostPathEvaluate( Botz Other)
{
	if ( MyMover == none )
		return false;
	if ( Other.Base == MyMover ) //Unreachable always assumed
	{
		//Let Botz handle this mover first
		if ( !MyMover.bInterpolating  && !MyMover.bDelaying )
			return False;
		if ( Other.BFM.CanFlyTo( Other.Location, Location, Region.Zone.ZoneGravity.Z, Other.JumpZ + MyMover.Velocity.Z, Other.AirSpeed) )
		{
			Log("LiftJump NOW");
			Other.HighJump( self, true);
			return true;
		}
		Other.SpecialPause = 0.1;
		Other.MoveTarget = Other;
		return true;
	}
	return false;
}

event int SpecialCost(Pawn Seeker)
{
	if ( Botz(Seeker) == None )
		return 10000000;
	return 0;
}



defaultproperties
{
	bSpecialCost=True
	FriendlyName="Lift Jump Exit"
}