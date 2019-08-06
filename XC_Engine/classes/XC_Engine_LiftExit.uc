class XC_Engine_LiftExit expands LiftExit;

const XCS = class'XC_EngineStatics';

native(3555) static final operator(22) Actor | (Actor A, skip Actor B);

// Special handling portion using FerBotz AI
// If this returns something, then it'll override SpecialHandling
final function Actor EnhancedHandling( Pawn Other)
{
	local bool bInOperation, bReachable, bJumpReachable;
	
	bInOperation = XCS.static.MoverInOperation( MyLift);
	bReachable = Other.PointReachable( Location);
	//TODO: EXPAND WITH NET VELOCITY FOR LIFT-JUMP
	bJumpReachable = XCS.static.Phys_CanJumpTo( Other.Location, Location, Other.Region.Zone.ZoneGravity.Z, Other.default.JumpZ, Other.GroundSpeed)
		&& Other.LineOfSightTo(self);
	if ( IsOnLift( Other) )
	{
		// Force towards self if lift is stationary and at nearest keyframe
		if ( (VSize(MyLift.Velocity) < 1) && XCS.static.ToNearestMoverKeyFrame( MyLift, Location) )
			Goto FORCE_HERE;

		if ( bInOperation )
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
		if ( !bInOperation && (LiftTrigger != '') )
		{
			if ( (Other.RouteCache[0] == MyLift.MyMarker) || (Other.RouteCache[1] == MyLift.MyMarker) ) //Entering lift
				Goto GOTO_TRIGGER;
		}
	}

DO_NOT_HANDLE:
	return none;
CHECK_REACHABLE:
	if ( bReachable || bJumpReachable )
	{
FORCE_HERE:
		return self;
	}
OTHER_WAIT:
	Other.SpecialGoal = MyLift.MyMarker | Other;
	Other.SpecialPause = 0.2;
	return Other.SpecialGoal;
GOTO_TRIGGER:
	Other.SpecialGoal = RecommendedTrigger
		| XCS.static.GetNearestTagged( Other, LiftTrigger, 2000)
		| XCS.static.GetNearestTrigger( Other, MyLift.Tag, 2000);
	if ( NavigationPoint(Other.SpecialGoal) != None )
		return Other.SpecialGoal;
	return Other.SpecialGoal.SpecialHandling( Other);
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

final function Actor GetRecommendedTrigger()
{
	local Actor A, Best;
	local float Dist, BestDist;
	
	if ( (RecommendedTrigger == None) && (LiftTrigger != '') )
	{
		BestDist = 9999;
		ForEach AllActors( class'Actor', A, LiftTrigger)
		{
			Dist = VSize(A.Location - Location);
			if ( Dist < BestDist )
			{
				Best = A;
				BestDist = Dist;
			}
		}
		return Best;
	}
	return RecommendedTrigger;
}

function Actor SpecialHandling(Pawn Other)
{
	local Actor EnhancedOverride; 

//	Log("SpecialHandling "@Name@Level.TimeSeconds);

	EnhancedOverride = EnhancedHandling( Other);
	if ( EnhancedOverride != None )
	{
//		Log("Overriding: "@EnhancedOverride.Name);
		Other.SpecialGoal = EnhancedOverride;
		return EnhancedOverride;
	}

	if ( (Other.Base == MyLift) && (MyLift != None) )
	{
		if ( (self.Location.Z < Other.Location.Z + Other.CollisionHeight)
			&& Other.LineOfSightTo( self)
			&& XCS.static.Phys_CanJumpTo( Other.Location, Location, Other.Region.Zone.ZoneGravity.Z, Other.default.JumpZ, Other.GroundSpeed) )
			return self; //Added Jump check
		Other.SpecialGoal = None;
		Other.DesiredRotation = rotator(Location - Other.Location);
		MyLift.HandleDoor(Other);

		if ( (Other.SpecialGoal == MyLift) || (Other.SpecialGoal == None) )
			Other.SpecialGoal = MyLift.myMarker;
		return Other.SpecialGoal;
	}
	return self;
}

defaultproperties
{
     bStatic=False
	 bNoDelete=False
     bCollideWhenPlacing=False
}
