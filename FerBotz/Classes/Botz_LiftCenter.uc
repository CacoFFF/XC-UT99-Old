//=============================================================================
// Lift center type
// Does automatic pathing at short distance for points near the mover's base
// position, requires special pathing for the other positions
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_LiftCenter expands Botz_NavigBase;

#exec TEXTURE IMPORT NAME=BWP_Junction FILE=..\CompileData\BWP_Junction.bmp FLAGS=2

var vector PosOffset;
var rotator RotBase;
var Mover MyMover;

event PostBeginPlay()
{
	local vector HitLocation, HitNormal;
	local Actor A;

	ForEach TraceActors (class'Actor', A, HitLocation, HitNormal, Location - vect(0,0,100) )
	{
		if ( A.IsA('Mover') )
		{
			MyMover = Mover(A);
			break;
		}
	}

	if ( MyMover  != none )
	{
		PosOffset = Location - MyMover.Location;
		RotBase = MyMover.Rotation;
		SetBase( MyMover);
		if ( MyMover.MyMarker == None )
			MyMover.MyMarker = self;
	}
	
	SetTimer( 1 + FRand(), true);
}


event Timer()
{
//FUTURO: MODIFICAR REACHSPEC QUE LLEVA DESDE LIFT EXIT A ESTE NODO
//DE ESTA MANERA DISTRIBUIR CARGA EN LA RUTA
}

//Called after botZ decides this is the path to take
//Do some lift handling here?
function bool PostPathEvaluate( botz other)
{
	SetLocation( MyMover.Location + PosOffset);
	return false;
}



function Actor SpecialHandling(Pawn Other)
{
	local float dist2d;
	local NavigationPoint N, Exit;

	if ( MyMover == None )
		return self;
	if ( Other.Base == MyMover )
	{
/*		if ( (RecommendedTrigger != None) 
		&& (MyMover.SavedTrigger == None)
		&& (Level.TimeSeconds - LastTriggerTime > 5) )
		{
			Other.SpecialGoal = RecommendedTrigger;
			LastTriggerTime = Level.TimeSeconds;
			return RecommendedTrigger;
		}*/
		if ( MyMover.Velocity.Z <= 0 ) //Don't cluster on this actor
			return Other;
		
		return self;
	}

/*	if ( (LiftExit(Other.MoveTarget) != None) 
		&& (LiftExit(Other.MoveTarget).RecommendedTrigger != None)
		&& (LiftExit(Other.MoveTarget).LiftTag == LiftTag)
		&& (Level.TimeSeconds - LiftExit(Other.MoveTarget).LastTriggerTime > 5)
		&& (MyMover.SavedTrigger == None)
		&& (Abs(Other.Location.X - Other.MoveTarget.Location.X) < Other.CollisionRadius)
		&& (Abs(Other.Location.Y - Other.MoveTarget.Location.Y) < Other.CollisionRadius)
		&& (Abs(Other.Location.Z - Other.MoveTarget.Location.Z) < Other.CollisionHeight) )
	{
		LiftExit(Other.MoveTarget).LastTriggerTime = Level.TimeSeconds;
		Other.SpecialGoal = LiftExit(Other.MoveTarget).RecommendedTrigger;
		return LiftExit(Other.MoveTarget).RecommendedTrigger;
	}*/

	SetLocation(MyMover.Location + PosOffset);
	SetBase(MyMover);
	dist2d = square(Location.X - Other.Location.X) + square(Location.Y - Other.Location.Y);
/*	if ( (Location.Z - CollisionHeight - MaxZDiffAdd < Other.Location.Z - Other.CollisionHeight + Other.MaxStepHeight)
		&& (Location.Z - CollisionHeight > Other.Location.Z - Other.CollisionHeight - 1200)
		&& ( dist2D < MaxDist2D * MaxDist2D) )
	{
		return self;
	}*/

	if ( MyMover.BumpType == BT_PlayerBump && !Other.bIsPlayer )
		return None;
	Other.SpecialGoal = None;

	MyMover.HandleDoor(Other);
	MyMover.RecommendedTrigger = None;

	if ( (Other.SpecialGoal == MyMover) || (Other.SpecialGoal == None) )
		Other.SpecialGoal = self;

	return Other.SpecialGoal;
}



defaultproperties
{
	FriendlyName="Lift Center"
	MaxDistance=350
	ExtraCost=400
	Texture=Texture'BWP_Junction'
	ReservePaths=1
	ReserveUpstreamPaths=1
}