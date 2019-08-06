class XC_Engine_LiftCenter expands LiftCenter;

const XCS = class'XC_EngineStatics';

var vector OffsetDirs[4];

native(3555) static final operator(22) Actor | (Actor A, skip Actor B);


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
static final function Actor EnhancedHandling( Pawn Other, Mover Lift, optional NavigationPoint Marker)
{
	local vector StandPosition;
	local NavigationPoint CurrentPath, NextPath;
	local Pawn P;
	local int StandingCount, StandingIdx;
	local Actor Best;

	local bool bLocalKeyframe, bBasedOnLift, bTriggered, bHandleNow;

	if ( Marker == None )
		Marker = Lift.myMarker;
	if ( Marker == None )
		return None;

	Other.SpecialGoal = None;
	Other.SpecialPause = 0;
	CurrentPath = XCS.static.GetCurrentPath( Other);
	NextPath = Other.RouteCache[0];
	if ( (NextPath == Marker) && (CurrentPath == Marker) )
		NextPath = Other.RouteCache[1];
	
	// Lift is moving
	if ( XCS.static.MoverInOperation( Lift) )
	{
		//And bot is standing in elevator
		if ( (Other.Base != None) && (Other.Base == Lift || Other.Base.Base == Lift) )
		{
			//Find standing order
			ForEach Other.PawnActors( class'Pawn', P, 400)
				if ( P.Base != None && (P.Base == Lift || P.Base.Base == Lift) )
				{
					if ( P == Other )
						StandingIdx = StandingCount;
					StandingCount++;
				}
				
			Other.SpecialGoal = class'LiftMarkerOffset'.static.Setup( Marker, Other, CrowdedOffset(StandingIdx,StandingCount));
			if ( XCS.static.InCylinder( Other.Location-Other.SpecialGoal.Location, Other.CollisionRadius * 0.5, Other.CollisionHeight) )
			{
				Other.SpecialPause = 0.5;
				Other.SpecialGoal = Other;
				return Other;
			}
			return Other.SpecialGoal;
		}
		//Bot is above elevator
		if ( Other.Location.Z > Marker.Location.Z )
		{
			if ( XCS.static.AI_SafeToDropTo( Other, Marker) )
				return Marker;
		}
		//Elevator is about to move
		if ( !Lift.bInterpolating )
		{
			if ( XCS.static.ToNearestMoverKeyFrame( Lift, Other.Location) || Other.PointReachable(Marker.Location) )
				return Marker;
		}
		Other.SpecialGoal = NearestInboundPathTo( Other, Marker);
		if ( Other.SpecialGoal == CurrentPath )
			Other.SpecialPause = 0.3;
		return Other.SpecialGoal;
	}
	
	//Stationary elevator
	if ( (Other.Base != None) && (Other.Base == Lift || Other.Base.Base == Lift) )
	{
		bLocalKeyframe = true;
		bBasedOnLift = true;
	}
	else if ( Other.Base != None )
	{
		bLocalKeyframe = XCS.static.ToNearestMoverKeyFrame( Lift, Other.Location);
	}
	bTriggered = InStr( Lift.GetStateName(), "Trigger") != -1;
	
	//Lift is accesible
	if ( bLocalKeyframe )
	{
		if ( bTriggered ) 
			Goto FIND_TRIGGER;
		else
		{
			if ( !bBasedOnLift ) 
				return Marker; //Enter lift now
		}
	}
	//Lift is inaccesible
	else
	{
		if ( bTriggered ) 
			Goto CHECK_BEFORE_TRIGGER;
	}
	Goto DO_NOT_OVERRIDE;
	
CHECK_BEFORE_TRIGGER:
	if ( ((Other.Location.Z < Marker.Location.Z + 100) || XCS.static.AI_SafeToDropTo( Other, Marker))
		&& Other.PointReachable( Marker.Location) )
		return Marker;

FIND_TRIGGER:
	//Mapper wanted to force these triggers
	if ( LiftExit(CurrentPath) != None )
	{
		Best = LiftExit(CurrentPath).RecommendedTrigger
			| XCS.static.GetNearestTagged( Other, LiftExit(CurrentPath).LiftTrigger, 2000, true)
			| XCS.static.GetNearestTagged( Other, LiftExit(CurrentPath).LiftTrigger, 2000);
		bHandleNow = (Best != None);
	}
	else if ( LiftCenter(CurrentPath) != None )
	{
		Best = Best | LiftCenter(CurrentPath).RecommendedTrigger
			| XCS.static.GetNearestTagged( Other, LiftCenter(CurrentPath).LiftTrigger, 2000, true)
			| XCS.static.GetNearestTagged( Other, LiftCenter(CurrentPath).LiftTrigger, 2000);
	}
	//Generic find nearest trigger
	Best = Best | XCS.static.GetNearestTrigger( Other, Lift.Tag, 1500, true);
	if ( Best != None )
	{
		if ( Best.bCollideActors && (Best.Brush == None) && XCS.static.ActorsTouchingValid(Other,Best) )
		{
			Best.UnTouch(Other);
			Best.Touch(Other);
			return None;
		}
		bHandleNow = bHandleNow || (NextPath == None) || !Other.PointReachable(NextPath.Location);
		if ( bHandleNow )
		{
			Other.SpecialGoal = Best.SpecialHandling(Other) | Best;
			if ( Other.SpecialGoal == Other )
				Other.SpecialPause = fMax( 0.3, Other.SpecialPause);
			return Other.SpecialGoal;
		}
		else 
			return Marker;
	}

	//No trigger - leave lift if in it.
	if ( bBasedOnLift && (CurrentPath == Marker) && ((Lift.SavedTrigger == None) || Lift.IsInState('TriggerToggle')) )
		return NearestInboundPathTo( Other, Marker, true); //Go back to Exit and attempt to trigger the lift
DO_NOT_OVERRIDE:
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
		
//	Log("SpecialHandling "@Name@Level.TimeSeconds);
		
	Move( AdjustedPosition() - Location);
	
	EnhancedOverride = EnhancedHandling( Other, MyLift, self);
	if ( EnhancedOverride != None )
	{
//		Log("Overriding: "@EnhancedOverride.Name);
		Other.SpecialGoal = EnhancedOverride;
		return EnhancedOverride;
	}
		
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

//************************** CrowdedOffset - offsets lift position
static final function vector CrowdedOffset( int idx, int total)
{
	if ( total > 1 )
		return class'XC_Engine_LiftCenter'.default.OffsetDirs[idx & 0x03] * float((idx >> 2) * 45 + 25);
	return vect(0,0,0);
}

//*********************************** NearestInboundPathTo - get nearest point to Other that leads to N, flags not considered
static final function NavigationPoint NearestInboundPathTo( Pawn Other, NavigationPoint N, optional bool bRequireReachable)
{
	local int i, ReachFlags, Distance;
	local Actor Start, End;
	local NavigationPoint Nearest;
	local float Dist, BestDist;
	
	BestDist = 99999;
	for ( i=0 ; i<16 && N.upstreamPaths[i]>=0 ; i++ )
	{
		N.describeSpec( N.upstreamPaths[i], Start, End, ReachFlags, Distance);
		if ( (NavigationPoint(Start) != None) && (End == N) )
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
	bCollideWhenPlacing=False
	OffsetDirs(0)=(X=1)
	OffsetDirs(1)=(X=-1)
	OffsetDirs(2)=(Y=1)
	OffsetDirs(3)=(Y=-1)
}