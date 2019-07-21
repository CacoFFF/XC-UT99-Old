class XC_Engine_LiftCenter expands LiftCenter;

const XCS = class'XC_EngineStatics';

var vector OffsetDirs[4];


//Auto-connect //TODO: Add to event chain handler
event PreBeginPlay()
{
	local Actor A;
	local LiftExit LE;
	local XC_Engine_Actor XCGEA;
	local vector LOffset, LPoint;
	local int i, Exits;
	local bool bSuccess;

	Super.PreBeginPlay();
	if ( bDeleteMe )
		return;

	XCGEA = XC_Engine_Actor(Owner);
	if ( XCGEA == None )
		ForEach DynamicActors (class'XC_Engine_Actor', XCGEA)
			break;
	if ( XCGEA != None )
	{
		A = Trace( LOffset, LPoint, Location - vect(0,0,78) );
		if ( Mover(A) != None )
		{
			//Give it a tag if necessary
			if ( A.Tag == 'Mover' || A.Tag == '' )
			{
				if ( !XCGEA.TaggedMover( A.Name) )
					A.Tag = A.Name;
				else
					A.SetPropertyText("Tag","XC_Fix_"$A.Name);
				LiftTag = A.Tag;
			}

			LiftTag = A.Tag;
			ForEach NavigationActors ( class'LiftExit', LE)
				if ( LE.LiftTag == LiftTag )
				{
					XCGEA.EzConnectNavigationPoints( Self, LE);
					Exits++;
				}
			
			if ( Exits < 2 )
			{
				LOffset	= Location - A.Location;
				For ( i=0 ; i<Mover(A).NumKeys ; i++ )
				{
					LPoint = Mover(A).BasePos + Mover(A).KeyPos[i] + LOffset;
					ForEach NavigationActors ( class'LiftExit', LE, 300, LPoint, true)
						if ( LE.LiftTag == '' || !XCGEA.TaggedMover(LE.LiftTag) )
						{
							LE.LiftTag = LiftTag;
							XCGEA.EzConnectNavigationPoints( Self, LE);
							Exits++;
						}
				}
			}
			bSuccess = true;
			XCGEA.LockToNavigationChain( Self, true);
		}
	}
	if ( !bSuccess )
		Warn( self @ "failed to find elevator");
	else if ( Exits < 2 )
		Warn( self @ "failed to connect to at least two LiftExit");
}


// Special handling portion using FerBotz AI
// If this returns something, then it'll override SpecialHandling
final function Actor EnhancedHandling( Pawn Other)
{
	local vector StandPosition;
	local NavigationPoint CurrentPath, NextPath;
	local Pawn P;
	local int StandingCount, StandingIdx;

	local bool bHeadedToPawn;

	NextPath = Other.RouteCache[0];
	if ( NextPath == self )
		NextPath = Other.RouteCache[1];
	
	// Lift is moving
	if ( MyLift.bInterpolating || MyLift.bDelaying )
	{
		//And bot is standing in elevator
		if ( (Other.Base != None) && (Other.Base == MyLift || Other.Base.Base == MyLift) )
		{
			//Find standing order
			ForEach PawnActors( class'Pawn', P, 400)
				if ( P.Base != None && (P.Base == MyLift || P.Base.Base == MyLift) )
				{
					if ( P == Other )
						StandingIdx = StandingCount;
					StandingCount++;
				}
				
			StandPosition = AdjustedPosition() + CrowdedOffset(StandingIdx,StandingCount);
			if ( XCS.static.InCylinder( Other.Location-StandPosition, Other.CollisionRadius, Other.CollisionHeight) )
			{
				Other.SpecialPause = 0.5;
				Other.SpecialGoal = Other;
				return Other;
			}
			SetLocation( StandPosition);
			return self;
		}
		//Bot is above elevator
		if ( Other.Location.Z > Location.Z )
		{
			if ( XCS.static.AI_SafeToDropTo( Other, self) )
				return self;
		}
		//Elevator is about to move
		if ( MyLift.bDelaying )
		{
			if ( XCS.static.ToNearestMoverKeyFrame( MyLift, Other.Location) || Other.PointReachable(Location) )
				return self;
		}
		return NearestInboundPathTo( Other);
	}
	
	//Bot is standing on stationary elevator
	if ( (Other.Base != None) && (Other.Base == MyLift || Other.Base.Base == MyLift) )
	{
		if ( (InStr( MyLift.GetStateName(), "Trigger") != -1) && (RecommendedTrigger == None) ) //Triggered lift without marked trigger
		{
			if ( (MyLift.SavedTrigger == None) || MyLift.IsInState('TriggerToggle') )
				return NearestInboundPathTo( Other, true); //Go back to Exit and attempt to trigger the lift
		}
		//Handle?
	}
	
	
	return None;
}

function Actor SpecialHandling( Pawn Other)
{
	local float dist2d;
	local NavigationPoint N;
	local LiftExit Exit;
	local Actor EnhancedOverride;

	local bool bHeadedToPawn;

	if ( MyLift == None )
		return self;

	EnhancedOverride = EnhancedHandling( Other);
	if ( EnhancedOverride != None )
		return EnhancedOverride;
		
	bHeadedToPawn = XCS.static.ToNearestMoverKeyFrame( MyLift, Other.Location);

	// TODO: Review this
	if ( Other.base == MyLift )
	{
		if ( (RecommendedTrigger != None) 
		&& (MyLift.SavedTrigger == None)
		&& (Level.TimeSeconds - LastTriggerTime > 5) )
		{
			Other.SpecialGoal = RecommendedTrigger;
			LastTriggerTime = Level.TimeSeconds;
			return RecommendedTrigger;
		}
		return self;
	}

	// TODO: Review this
	if ( (LiftExit(Other.MoveTarget) != None) 
		&& (LiftExit(Other.MoveTarget).RecommendedTrigger != None)
		&& (LiftExit(Other.MoveTarget).LiftTag == LiftTag)
		&& (Level.TimeSeconds - LiftExit(Other.MoveTarget).LastTriggerTime > 5)
		&& (MyLift.SavedTrigger == None)
		&& (Abs(Other.Location.X - Other.MoveTarget.Location.X) < Other.CollisionRadius)
		&& (Abs(Other.Location.Y - Other.MoveTarget.Location.Y) < Other.CollisionRadius)
		&& (Abs(Other.Location.Z - Other.MoveTarget.Location.Z) < Other.CollisionHeight) )
	{
		LiftExit(Other.MoveTarget).LastTriggerTime = Level.TimeSeconds;
		Other.SpecialGoal = LiftExit(Other.MoveTarget).RecommendedTrigger;
		return LiftExit(Other.MoveTarget).RecommendedTrigger;
	}

	// Mover is stationary at nearest keyframe from seeker
	if ( bHeadedToPawn && !MyLift.bInterpolating && !MyLift.bDelaying )
	{
		return self;
	}
	
	// TODO: Improve this
	SetLocation(MyLift.Location + LiftOffset);
	SetBase(MyLift);
	dist2d = square(Location.X - Other.Location.X) + square(Location.Y - Other.Location.Y);
	if ( (Location.Z - CollisionHeight - MaxZDiffAdd < Other.Location.Z - Other.CollisionHeight + Other.MaxStepHeight)
		&& (Location.Z - CollisionHeight > Other.Location.Z - Other.CollisionHeight - 1200)
		&& ( dist2D < MaxDist2D * MaxDist2D) )
	{
		return self;
	}

	if ( MyLift.BumpType == BT_PlayerBump && !Other.bIsPlayer )
		return None;
	Other.SpecialGoal = None;
		
	// make sure Other is at valid lift exit
	if ( LiftExit(Other.MoveTarget) == None )
	{
		ForEach NavigationActors( class'LiftExit', Exit, Other.CollisionRadius+Other.CollisionHeight, Other.Location)
			if ( Exit.LiftTag == LiftTag )
				break;
		if ( Exit == None )
			return self;
	}

	// TODO: Evaluate this
	MyLift.HandleDoor(Other);
	MyLift.RecommendedTrigger = None;

	if ( (Other.SpecialGoal == MyLift) || (Other.SpecialGoal == None) )
		Other.SpecialGoal = self;

	log("LIFT HANDLE"@Other.SpecialGoal);
	return Other.SpecialGoal;
}


//******************* AdjustedPosition - gets position after offset/rotation transformation
final function vector AdjustedPosition()
{
	return MyLift.Location + (LiftOffset >> (MyLift.Rotation - MyLift.BaseRot));
}

//******************* CrowdedOffset - offsets lift position
final function vector CrowdedOffset( int idx, int total)
{
	if ( total > 1 )
		return class'XC_Engine_LiftCenter'.default.OffsetDirs[idx & 0x03] * float((idx >> 2) * 45 + 25);
	return vect(0,0,0);
}

//**************************** NearestInboundPathTo - get nearest point to Other that leads here, flags not considered
final function NavigationPoint NearestInboundPathTo( Pawn Other, optional bool bRequireReachable)
{
	local int i, ReachFlags, Distance;
	local Actor Start, End;
	local NavigationPoint Nearest;
	local float Dist, BestDist;
	
	BestDist = 99999;
	for ( i=0 ; i<16 && upstreamPaths[i]>=0 ; i++ )
	{
		describeSpec( upstreamPaths[i], Start, End, ReachFlags, Distance);
		if ( (NavigationPoint(Start) != None) && (End == self) )
		{
			Dist = VSize( Other.Location - Start.Location);
			if ( Dist < BestDist && (!bRequireReachable || Other.PointReachable(Start.Location)))
			{
				BestDist = Dist;
				Nearest = NavigationPoint(Start);
			}
		}
	}
	return Nearest;
}



defaultproperties
{
    bGameRelevant=True
    bStatic=False
	bNoDelete=False
	OffsetDirs(0)=(X=1)
	OffsetDirs(1)=(X=-1)
	OffsetDirs(2)=(Y=1)
	OffsetDirs(3)=(Y=-1)
	
}