class XC_Engine_LiftExit expands LiftExit;

const XCS = class'XC_EngineStatics';

native(3571) static final function float HSize( vector A);

// Special handling portion using FerBotz AI
// If this returns something, then it'll override SpecialHandling
final function Actor EnhancedHandling( Pawn Other)
{
	if ( IsOnLift( Other) )
	{
		// Force towards self if lift is stationary and at nearest keyframe
		if ( (VSize(MyLift.Velocity) < 1) && XCS.static.ToNearestMoverKeyFrame( MyLift, Location) )
			Goto FORCE_HERE;

		if ( MyLift.bInterpolating || MyLift.bDelaying )
		{
			if ( Abs(Normal( MyLift.Velocity).Z) > 0.7 ) //Vertical trajectory
			{
				if ( MyLift.Velocity.Z > 1 ) //Up
				{
					if ( Other.Location.Z + Other.CollisionHeight + CollisionHeight < Location.Z )
					{
						// TODO: LIFT-JUMP
						Goto OTHER_WAIT; //I am above bot
					}
					if ( HSize(Other.Location - Location)/Other.GroundSpeed > (Location.Z-Other.Location.Z)/MyLift.Velocity.Z )
						Goto OTHER_WAIT; //Not reachable before lift hits top
				}
				else if ( MyLift.Velocity.Z < -1 ) //Down
				{
					if ( XCS.static.AI_SafeToDropTo( Other, self) )
						Goto CHECK_REACHABLE; //Lift going down, worth dropping
				}
			}
			else if ( !XCS.static.ToNearestMoverKeyFrame( MyLift, Location, Other.GroundSpeed*0.15) )
				Goto CHECK_REACHABLE; //Z-Stationary + not heading to destination keyframe
			Goto OTHER_WAIT;
		}
			
		if ( MyLift.bDelaying && Location.Z > Other.Location.Z+Other.CollisionHeight )
			Goto CHECK_REACHABLE; //Not going up yet
	}
	else if ( MyLift != None )
	{
		if ( !MyLift.bInterpolating && !MyLift.bDelaying && (RecommendedTrigger != None) )
		{
			if ( (Other.RouteCache[0] == MyLift.MyMarker) || (Other.RouteCache[1] == MyLift.MyMarker) ) //Entering lift
				Goto GOTO_TRIGGER;
		}
	}

DO_NOT_HANDLE:
	return none;
CHECK_REACHABLE:
	if ( Other.PointReachable( Location) )
	{
FORCE_HERE:
		return self;
	}
OTHER_WAIT:
	Other.SpecialGoal = Other;
	Other.SpecialPause = 0.2;
	return Other;
GOTO_TRIGGER:
	return RecommendedTrigger; //TODO: FIND BY TAG
}

final function bool IsOnLift( Pawn Other)
{
	local Actor A;
	local int ReachSpecIdx, PathArrayIdx;

	if ( MyLift != None )
	{
		if ( Other.Base != None && (Other.Base == MyLift || Other.Base.Base == MyLift) )
			return true;
		//Iterate over connected paths
	}
	return false;
}

function Actor SpecialHandling(Pawn Other)
{
	local Actor EnhancedOverride; 
	
	EnhancedOverride = EnhancedHandling( Other);
	if ( EnhancedOverride != None )
		return EnhancedOverride;

	if ( (Other.Base == MyLift) && (MyLift != None) )
	{
		if ( (self.Location.Z < Other.Location.Z + Other.CollisionHeight)
			 && Other.LineOfSightTo(self) )
			return self;
		Other.SpecialGoal = None;
		Other.DesiredRotation = rotator(Location - Other.Location);
		MyLift.HandleDoor(Other);

		if ( (Other.SpecialGoal == MyLift) || (Other.SpecialGoal == None) )
			Other.SpecialGoal = MyLift.myMarker;
		return Other.SpecialGoal;
	}
	return self;
}
