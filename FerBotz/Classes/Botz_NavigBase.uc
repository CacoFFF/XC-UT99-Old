//=============================================================================
// The extended navigation point
// Native branch class only, rename this file if compiled in normal mode
// This actor should automatically become bNoDelete after being spawned
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_NavigBase expands NavigationPoint
	native;

#exec TEXTURE IMPORT NAME=BWP_Normal FILE=..\CompileData\BWP_Normal.bmp FLAGS=2
const R_SPECIAL = 0x00000020;

var float MaxDistance; //Maximum hook distance, used by automatic pather, setting to 0 ignores all pathing
var bool bPushSave;
var bool bOneWayInc; //Limits Incoming paths
var bool bOneWayOut; //Limits Outgoing paths
var bool bFlying; //Used to force special reachspec creation
var bool bHighPath; //This path is a high node, don't start walk-only connections here (only fall)
var bool bCustomFlags; //Call ModifyFlags() event here on USCRIPT when the reachflags are being set
var bool bDirectConnect; //Dynamic Player will display the hook target
var bool bNeverPrune; //This node is dynamic, do not prune paths
var bool bFinishedPathing; //Just finished it's own pathing loops, set before FinishedPathing
var bool bLoadSpecial; //During special process of Botz_PathLoader
var int ReservePaths; //Reserve this amount of slots (during native path node detection)
var int ReserveUpstreamPaths; //Reserve this amount of slots
var string FriendlyName;
var Botz_PathLoader MyLoader;

enum EPathMode
{
	PM_None, //Don't path
	PM_Normal, //Do normal processing
	PM_Forced //Force this path!
};


//XC_Engine
native(3541) final iterator function NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint P, optional float Distance, optional vector VOrigin, optional bool bVisible);
native(3554) static final function iterator ConnectedDests( NavigationPoint Start, out Actor End, out int ReachSpecIdx, out int PathArrayIdx);
native(3570) static final function vector HNormal( vector A);
native(3571) static final function float HSize( vector A);


event PostBeginPlay()
{
	bHighPath = !FastLowCheck( Self, Location);
}

//Called after botZ decides this is the path to take
function bool PostPathEvaluate( botz other);
function QueuedForNavigation( Botz Other, byte Slot);

function bool PathVisible( NavigationPoint Start, NavigationPoint End, optional bool IgnoreMovers)
{
	local Actor A;
	local vector HitLocation, HitNormal;
	
	ForEach TraceActors (class'Actor', A, HitLocation, HitNormal, End.Location, Start.Location)
	{
		if ( A == Level )
			return false;
		if ( A.IsA('BlockMonsters') )
			A.SetCollision(false,false,false);
		if ( A.IsA('BlockAll') )
			return false;
		if ( !IgnoreMovers && Mover(A) != none )
			return false;
	}
	return true;
}


//***************************ResetScriptRunaway - reset the iterator and recursion counters
native static final function ResetScriptRunaway();

//********************LockActor - Safely sets bNoDelete and hooks to navigation point list
native final function LockActor( bool bLock, optional NavigationPoint Other); 

//************************CreateReachSpec - Inserts a reachspec into memory, returns it's index
native final function int CreateReachSpec();

//********************PathCandidates - Runs an automatic path build routine in runtime
native final function PathCandidates();

//************************ExistingPath - returns index of reachspec if already exists, -1 for no reachspec
native final function int ExistingPath( actor Dest);

//*************************EditReachSpec - Runtime setting of a reachspec, useful for placeable teleporters (siege)
native final function bool EditReachSpec( int ReachSpec, actor Start, actor End, optional float CollisionHeight, optional float CollisionRadius, optional bool bTele);

//************************UnusedReachSpec - Returns a reachspec with no start and end (dynamic reachspec), -1 for failure
native final function int UnusedReachSpec();

//********************PruneReachSpec - Moves any reachspec into prunes and automatically set Paths/UpstreamPaths/PrunedPaths (-1 is safe param)
native final function PruneReachSpec( int rIdx);

//*******************************IsConnectedTo - Fast connection check, can include pruned paths
native static final function int IsConnectedTo( NavigationPoint N, NavigationPoint Other, optional bool bIncPruned);

//***************************ClearAllPaths - Makes a navigation point safe to delete, can restore paths that were pruned over this node
native static final function ClearAllPaths( NavigationPoint Other, optional bool bRestorePrunes);

//*******************************Find unused slot in array
native static final function int FreePathSlot( NavigationPoint N);
native static final function int FreeUpstreamSlot( NavigationPoint N);


//** This event will alter the ReachFlags between self and Dest
// If Dest is self then this is an incoming reachspec
event int ModifyFlags( NavigationPoint Dest, int CurFlags)
{
	return CurFlags;
}

//** This event describes how a custom navig-base should connect
// Forced prevents OtherIsCandidate from being called, so pair it with a Trace if necessary
event EPathMode IsCandidateTo( Botz_NavigBase Other)
{
	return PM_Normal;
}

//** This event describes how all paths connect to this, called after IsCandidateTo on NavigBases
event EPathMode OtherIsCandidate( NavigationPoint Nav)
{
	if ( Nav.IsA('LiftCenter') ) //No lift centers
		return PM_None;
	if ( Nav.IsA('SpawnPoint') && (VSize(Nav.Location - Location) > MaxDistance * 0.5) ) //Avoid distant SpawnPoints
		return PM_None;
	if ( PathVisible( Self, Nav) )
		return PM_Normal;
	return PM_None;
}



//** Called after selection routine decides pathing is possible
//** This function is called a second time with reversed End-Start if we're connecting to a non-NavigBase point
//** bOneWay only works for non-forced paths!
event AddPathHere( NavigationPoint Start, NavigationPoint End, bool bForce, optional bool bOneWay)
{
	local int WlkCost;
	local int aReach, aSlot, uSlot, Reach, Dist, i, j;
	local actor A, B;
	local vector aDir, eDir;
	local NavigationPoint N;

	//Custom prune check, avoid creating paths from legacy navigation points to here
	if ( (FreePathSlot(self) < 0) || (FreeUpstreamSlot( End) < 0) ||  MyLoader.IsPruned( Start, End) )
	{
//		if ( Start.IsA('Botz_NavigBase') && End.IsA('Botz_NavigBase') )
//			Log("PRE PATH CHECK APPLIED");
		return;
	}

	//Fix this in DLL!!!!
	if ( !Start.IsA('Botz_NavigBase') || !End.IsA('Botz_NavigBase') )
		bOneWay = true;
	
	//General purpose pruner
	if ( !bForce && (Botz_NavigBase(Start) == None || !Botz_NavigBase(Start).bNeverPrune) ) //See if this is a likely prune dest, discard before expensive checks
	{
		ForEach NavigationActors ( class'NavigationPoint', N, fMin(MaxDistance,VSize(Start.Location-End.Location) ),, true)
			if ( !N.bSpecialCost && ConsiderPruning( Start, N, End) )
			{
				MyLoader.AddPrune( Start, End);
				return;
			}
		WlkCost = WalkableCost( Start, End);
//		LOG("WALKABLE COST="$WLKCOST$" FROM "$START@"TO"@END);
	}

	if ( bForce )
		WlkCost = 1;


	if ( WlkCost == 0 || WlkCost == 1 )
	{
		aReach = UnusedReachSpec();
		if ( aReach < 0 )
			aReach = CreateReachSpec();
		if ( bForce )
			EditReachSpec( aReach, Start, End, 60, 40, true);
		else
			EditReachSpec( aReach, Start, End);
		aSlot = FreePathSlot( Start);
		uSlot = FreeUpstreamSlot( End);
		if ( aSlot < 0 || uSlot < 0 )
		{
			EditReachSpec( aReach, none, none);
			Log("REACHSPECS FULL");
			return;
		}
		Start.Paths[aSlot] = aReach;
		End.UpstreamPaths[uSlot] = aReach;
		
		if ( !bOneWay && (WlkCost == 0) ) //2 way normal path
		{
			if ( Botz_NavigBase(End) == none )
				AddPathHere( End, Start, false, true); //Set forced flag, we alreay got a good check
			else if ( !Botz_NavigBase(End).bFinishedPathing && (VSize(Location - End.Location) <= Botz_NavigBase(End).MaxDistance) ) //Respect target node's distance setting
				AddPathHere( End, Start, false, true); //Set forced flag, we alreay got a good check
		}
	}
}

//** Called when this path has already iterated, do post reachspec treatment here
event FinishedPathing()
{
	local int i, j, k, rIdx;
	local int ReachFlags, Distance;
	local Actor O, S, E;
	
	i = FreeUpstreamSlot( self);
	k = FreePathSlot( self);
	while ( --i >= 0 ) //Analyze first half
	{
		describeSpec( UpstreamPaths[i], S, O, ReachFlags, Distance);
		if ( ((ReachFlags & R_SPECIAL) == 0) && (Distance > 1) ) //This is not a special connection
		{
			For ( j=k-1 ; j>=0 ; j-- ) //Analyze second half
			{
				describeSpec( Paths[j], O, E, ReachFlags, Distance);
				if ( ((ReachFlags & R_SPECIAL) == 0) && (Distance > 1) && ConsiderPruning(NavigationPoint(S),Self,NavigationPoint(E)) ) //This is also not a special connection
					PruneReachSpec( IsConnectedTo( NavigationPoint(S), NavigationPoint(E) ));
			}
		}
	}
	ResetScriptRunaway();
}


//Return description:
//2: no connection
//1: must jump hole or obstacle
//0: Fully walkable
//Visibility check assumed
function int WalkableCost( NavigationPoint Start, NavigationPoint End)
{
	local vector HitLocation, HitNormal;;
	local float SteepDistance, LastZHit;
	local vector SteepStart, SteepEnd;
	local bool bHasHoles; //Must jump!
	local bool bDownfall; //There's a fall, never return 0
	local float AlphaRoute, AlphaInc;
	local vector CurV, LowV, Trajectory;
	local int RealSteps, curSteps, i;
	local bool bCurSteep;
	local float jZ;
	local bool bStartHigh, bEndHigh;

	if ( Start.Region.Zone.bWaterZone && End.Region.Zone.bWaterZone )
		return 0;

	jZ = class'Botz'.default.JumpZ * fMin(1.18, Level.Game.PlayerJumpZScaling());

	Trajectory = End.Location - Start.Location;
	AlphaRoute = HSize(Trajectory);
	LowV = Start.Location;
	bStartHigh = IsHighPath( Start);
	bEndHigh = IsHighPath( End);
	if ( !bStartHigh ) //Expand start anchor
		LowV += HNormal(Trajectory) * 12;
	CurV = End.Location;
	if ( !bEndHigh ) //Expand end anchor
		CurV -= HNormal(Trajectory) * 12;
	if ( Start.Region.Zone.bWaterZone ) //Facilitate water exit
	{
		MyLoader.SetLocation( Start.Location);
		while ( (MyLoader.Location.Z < End.Location.Z) && MyLoader.Region.Zone.bWaterZone && (MyLoader.Region.ZoneNumber != 0) && (i++<15) )
			MyLoader.Move( Normal(Trajectory)*5 + Trajectory*0.1 );
		i = 0;
		LowV = MyLoader.Location;
		LowV.Z += 10;
	}
		
	if ( Class'BotzFunctionManager'.static.CanFlyTo( LowV, CurV, Start.Region.Zone.ZoneGravity.Z, jZ, class'Botz'.default.GroundSpeed) ) //Jumpable lol
		return 1;
	else if ( AlphaRoute < Trajectory.Z ) //Unjumpable
	{
//		Log("FAIL ON PASS 1");
		return 2;
	}
	else if ( bStartHigh || bEndHigh )
		return 2;

	RealSteps = AlphaRoute / 8; //Horizontal steps every 8 units or so
	AlphaInc = VSize(Trajectory) / RealSteps;

	if ( RealSteps <= 1 ) //Paths' horizontal uber close
	{
		AlphaRoute = VSize(Trajectory);
		if ( AlphaRoute < 60 )
			return 0;
		else if ( Start.Location.Z > End.Location.Z )
			return 1;
//		Log("FAIL ON PASS 2");
		return 2;
	}

	i=1;
	AlphaRoute = AlphaInc;
	Trajectory = Normal(Trajectory);
	CollideTrace( LowV, HitNormal, Start.Location - vect(0,0,300), Start.Location, true);

	THIS_ALPHA: //Iterator
	if ( i >= RealSteps )
	{
		if ( bCurSteep )
		{
			SteepStart.Z += 39;
			if ( !Class'BotzFunctionManager'.static.CanFlyTo( SteepStart, End.Location, End.Region.Zone.ZoneGravity.Z, jZ, class'Botz'.default.GroundSpeed) )
			{
//				Log("FAIL ON PASS 3");
				return 2;
			}
			return 1;
		}


		if ( !bHasHoles )
			return int(bDownfall);
		return 1;
	}

	CurV = Start.Location + Trajectory * AlphaRoute;

	if ( CollideTrace( HitLocation, HitNormal, CurV - vect(0,0,300), CurV, true) == none )
	{
		if ( !bCurSteep )
		{
			SteepStart = LowV;
			bCurSteep = true;
			bDownfall = true;
		}
	}
	else
	{
		if ( !bCurSteep )
		{
			if ( (HitLocation.Z - LowV.Z > 40) && //Path's suddenly gained altitude...
				!Class'BotzFunctionManager'.static.CanFlyTo( LowV, HitLocation, Start.Region.Zone.ZoneGravity.Z, jZ, class'Botz'.default.GroundSpeed) ) //Can't jump over it
				return 2;
			if ( HitNormal.Z < 0.7070 ) //was 0.7854, was 0.7732
			{
				SteepStart = LowV;
				bCurSteep = true;
				bDownfall = true;
			}
			else if ( !bDownfall && (HitLocation.Z - LowV.Z < -40) && //Path's suddenly lost altitude
				!Class'BotzFunctionManager'.static.CanFlyTo( HitLocation, LowV, Start.Region.Zone.ZoneGravity.Z, jZ, class'Botz'.default.GroundSpeed) )
				bDownfall = true;
		}
		else
		{
			if ( abs( HitLocation.Z - SteepStart.Z) <  HSize(SteepStart - HitLocation) * 0.8 )
			{
				SteepEnd = HitLocation;
				if ( !Class'BotzFunctionManager'.static.CanFlyTo( SteepStart, SteepEnd, Start.Region.Zone.ZoneGravity.Z, jZ, class'Botz'.default.GroundSpeed) )
				{
//					Log("FAIL ON PASS 4");
					return 2;
				}
				bCurSteep = false;
				bHasHoles = true;
			}
		}

		LowV = HitLocation;
	}
	i++;
	AlphaRoute += AlphaInc;
	Goto THIS_ALPHA;
}

static function bool IsHighPath( Actor N)
{
	if ( N.IsA('Botz_NavigBase') )
		return Botz_NavigBase(N).bHighPath;
	return !FastLowCheck( N, N.Location);
}

//**************************CollideTrace - Sees if trace hits a solid, HitLocation=End, HitNormal=Dir if no hit.
native final function Actor CollideTrace( out vector HitLocation, out vector HitNormal, vector End, optional vector Start, optional bool bOnlyStatic);


static function bool FastLowCheck( Actor A, vector Start)
{
	local vector HitLocation, HitNormal;
	local actor tempActor;

	ForEach A.TraceActors ( class'Actor', tempActor, HitLocation, HitNormal, Start - vect(0,0,100), Start)
	{
		if ( ((tempActor.bStatic || tempActor.bNoDelete) && (tempActor.bBlockActors || tempActor.bBlockPlayers)) || (tempActor == A.Level) )
			return true;
	}
	return false;
}


//Complex pruner
function bool ConsiderPruning( NavigationPoint Start, NavigationPoint ExistingPath, NavigationPoint NewPath)
{
	local vector Dir, Dir2;
	local int i, Reach, Dist;
	local Actor A,B;
	
	//Distance check, if new path is inbetween never prune
	if ( VSize( Start.Location - NewPath.Location) < VSize(Start.Location - ExistingPath.Location) )
		return false;
	//See that a connection actually exists between Start and ExistingPath (prunes included)
	i = IsConnectedTo( Start, ExistingPath, true);
	if ( i < 0 )
		return false;
	//Do not prune special paths
	describeSpec( i, A, B, Reach, Dist);
	if ( ((Reach & R_SPECIAL) != 0) || (Dist<1) )
		return false;
		
	//Two of the paths in the set are very nearby to each other (start-existing-new)
	if ( HSize( Start.Location - ExistingPath.Location) < 20 && Abs(Start.Location.Z - ExistingPath.Location.Z) < 30 )
		return true;
	if ( HSize( ExistingPath.Location - NewPath.Location) < 20 && Abs(ExistingPath.Location.Z - NewPath.Location.Z) < 30 )
		return true;
	
	//Extended cone check - direction 1
	Dir = Normal( (ExistingPath.Location - Start.Location) * vect(1,1,0.5) );
	Dir2 = Normal( (NewPath.Location - ExistingPath.Location) * vect(1,1,0.5) - Dir * 100 );
	if ( Dir dot Dir2 > 0.82 )
		return true;

	Dir = Normal( (ExistingPath.Location - NewPath.Location) * vect(1,1,0.5) );
	Dir2 = Normal( (Start.Location - ExistingPath.Location) * vect(1,1,0.5) - Dir * 100 );
	if ( Dir dot Dir2 > 0.82 )
		return true;
}


event Destroyed()
{
	local int i;

	if ( bNoDelete || bStatic )
		return;
		
//Clear reachspecs and indices
	ClearAllPaths( self);
/*	For ( i=0 ; i<16 ; i++ )
	{
		//Clear outgoing
		if ( Paths[i] != -1 )
			EditReachSpec( Paths[i], none, none, 1, 1);
		if ( PrunedPaths[i] != -1 )
			EditReachSpec( PrunedPaths[i], none, none, 1, 1);

		//Clear incoming
	}*/
}

defaultproperties
{
	FriendlyName="Base Waypoint"
	bStatic=False
	bNoDelete=False
	MaxDistance=200
	Texture=Texture'FerBotz.BWP_Normal'
	bCollideWhenPlacing=false
	Style=3
	SpriteProjForward=4
	DrawScale=0.5
}