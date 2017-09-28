//=============================================================================
// Lift exit type
// Targeted pathing to the lift center i'm aiming at
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_LiftExit expands Botz_NavigBase;

const BFM = class'BotzFunctionManager';
var Mover MyMover;

//Called after botZ decides this is the path to take
//Do some lift handling here?
function bool PostPathEvaluate( botz other)
{
/*	if ( MyMover == none )
		return false;
		
	//Evaluate fall
	if ( BadFall(other) )
	{
		other.SpecialPause = 0.2;
		other.MoveTarget = other;
		return true;
	}
	
	if ( !other.PointReachable(location) )
	{
		//Temporary solution
		if ( (other.Base == MyMover) && !MyMover.bInterpolating  && !MyMover.bDelaying )
		{
			other.MoveTarget = other;
			other.SpecialPause = 0.5;
			other.bTickedJump = true;
		}
		else if ( other.Base == MyMover )
		{
			other.SpecialPause = 0.2;
			other.MoveTarget = other;
		}
		return true;
	}*/
	return false;
}


function Actor SpecialHandling(Pawn Other)
{

	if ( (Other.Base == MyMover) && (MyMover != None) )
	{
		if ( (self.Location.Z < Other.Location.Z + Other.CollisionHeight)
			 && Other.LineOfSightTo(self) )
			return self;
		Other.SpecialGoal = None;
		Other.DesiredRotation = rotator(Location - Other.Location);
		MyMover.HandleDoor(Other);

		if ( (Other.SpecialGoal == MyMover) || (Other.SpecialGoal == None) )
			Other.SpecialGoal = MyMover.myMarker;
		return Other.SpecialGoal;
	}
	return self;
}


function bool BadFall( Pawn Other)
{
	//Evaluate fall
	return (Other.Base == MyMover) && (MyMover.Velocity.Z < 0)
		&& !Region.Zone.bWaterZone
		&& (Location.Z < other.Location.Z)
		&& ((BFM.static.FreeFallVelocity( Location.Z-other.Location.Z, Region.Zone.ZoneGravity.Z) < -750 - other.JumpZ) //Fall too hard
			|| (BFM.static.FreeFallVelocity( Location.Z-other.Location.Z, Region.Zone.ZoneGravity.Z) > MyMover.Velocity.Z) ); //Fall slower than elevator
}


event FinishedPathing()
{
	local Botz_LiftCenter LC;
	local vector CmpPoint;
	local NavigationPoint Best;
	local LiftCenter ULC;
	local Mover M;
	local float Dist, BestDist;

	BestDist = 99999;
	ForEach AllActors (class'Botz_LiftCenter', LC)
	{
		CmpPoint = Location + vector(Rotation) * VSize(LC.Location - Location);
		if ( VSize(LC.Location - CmpPoint) < 180 )
		{
			Dist = VSize(Location - LC.Location);
			if ( Dist < BestDist )
			{
				Best = LC;
				BestDist = Dist;
			}
		}
	}

	if ( Best != none )
	{
		if ( !bOneWayOut )
			AddPathHere( self, Best, true);
		if ( !bOneWayInc )
			AddPathHere( Best, self, true);
		MyMover = Botz_LiftCenter(Best).MyMover;
		return;
	}
	
	//Try a UT LiftCenter now
	ForEach NavigationActors (class'LiftCenter', ULC)
	{
		CmpPoint = Location + vector(Rotation) * VSize(ULC.Location - Location);
		if ( VSize(ULC.Location - CmpPoint) < 180 )
		{
			M = None;
			ForEach AllActors (class'Mover', M, ULC.LiftTag)
				break;
			if ( M == None )
				continue;
			Dist = VSize(Location - ULC.Location);
			if ( Dist < BestDist )
			{
				Best = ULC;
				BestDist = Dist;
			}
		}
	}
	
	if ( Best != none )
	{
		if ( !bOneWayOut )
			AddPathHere( self, Best, true);
		if ( !bOneWayInc )
			AddPathHere( Best, self, true);
		MyMover = LiftCenter(Best).MyLift;
		return;
	}

}




defaultproperties
{
	FriendlyName="Lift Exit"
	MaxDistance=550
	Texture=Texture'BWP_Junction'
	bPushSave=True
	ReservePaths=1
	ReserveUpstreamPaths=1
}