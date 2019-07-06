class PathsEnhancer expands FV_Addons;

var NavigationPoint EndPoint;
var FV_Scout MyScout;

// Single anchor route mapper
native(3538) final function NavigationPoint MapRoutes_SA( Pawn Seeker, NavigationPoint StartAnchors, optional name RouteMapperEvent);

event AddonCreated()
{
	SpawnScout();
	if ( MyScout == None )
		return;
	
	SetupJumpDown();
	SetupJumpBoots();
	
	if ( MyScout != None )
		MyScout.Destroy();
}


function SetupJumpDown()
{
	local int i, j;
	local LiftCenter LC;
	local int iReach;
	local Actor A;
	local NavigationPoint ReachList[16];
	local int ScoutRadius, ScoutHeight, ReachFlags;
	local ReachSpec Spec;
	
	ForEach NavigationActors( class'LiftCenter', LC)
		if ( LC.IsA('JumpSpot') || LC.IsA('TranslocDest') )
		{
			iReach = 0;
			ForEach ConnectedDests( LC, A, i, j) //Last 2 params are unused
				if ( A.IsA('LiftExit') )
					ReachList[iReach++] = NavigationPoint(A);
			For ( i=0   ; i<iReach ; i++ )
			For ( j=i+1 ; j<iReach ; j++ )
			{
				Spec.Distance = VSize( ReachList[i].Location - ReachList[j].Location);
				if ( !IsConnectedTo(ReachList[i], ReachList[j])
				&& MyScout.CheckReachability( ReachList[i], ReachList[j], Spec.CollisionRadius, Spec.CollisionHeight, Spec.ReachFlags) )
				{
					Spec.Start = ReachList[i];
					Spec.End = ReachList[j];
					AddReachSpec( Spec, true);
				}
				if ( !IsConnectedTo(ReachList[j], ReachList[i])
				&& MyScout.CheckReachability( ReachList[j], ReachList[i], Spec.CollisionRadius, Spec.CollisionHeight, Spec.ReachFlags) )
				{
					Spec.Start = ReachList[j];
					Spec.End = ReachList[i];
					AddReachSpec( Spec, true);
				}
			}
		}
}


// Function needs a second pass for when there's more than one jump in the queue
// But that'll require an awful lot of buffering
function SetupJumpBoots()
{
	local JumpSpot JS;
	local InventorySpot IS;
	local NavigationPoint N;
	local Actor A;
	local JumpItemToObjective Attractor;

	local int NewDist;
	local int rIdx, pIdx;
	local int JumpSpots;
	local ReachSpec Spec;


	// Preset JumpSpots
	ForEach NavigationActors( class'JumpSpot', JS)
		if ( JS.Class == class'JumpSpot' )
		{
			JS.bSpecialCost = false;
			JumpSpots++;
		}
	if ( JumpSpots == 0 )
		return;
	
	Spec.CollisionRadius = 100;
	Spec.CollisionHeight = 100;
	Spec.ReachFlags = R_SPECIAL | R_PLAYERONLY;
	
	// Get boot markers
	ForEach NavigationActors( class'InventorySpot', IS)
	{
		if ( !class'JumpItemToObjective'.static.AttractsBots(IS.MarkedItem) ||  IS.Paths[15] >= 0 )
			continue;
		
		Attractor = None;
		MapRoutes_SA( MyScout, IS);
		
		// Get JumpSpots
		ForEach NavigationActors( class'JumpSpot', JS)
		{
			if ( JS.Class != class'JumpSpot'  ||  JS.StartPath == None  ||  JS.prevOrdered == None  ||  JS.VisitedWeight >= 10000000 )
				continue;
				
			// Get exit nodes that require traversing this JumpSpot
			ForEach ConnectedDests( JS, A, rIdx, pIdx)
			{
				N = NavigationPoint(A);
				if ( N != None  &&  N.StartPath != None  &&  N.prevOrdered == JS )
				{
					// Setup attractor
					if ( Attractor == None )
					{
						Attractor = Spawn( class'JumpItemToObjective',,, IS.Location + vect(0,0,10));
						Attractor.Marker = IS;
						LockToNavigationChain( Attractor, true);
						Spec.Start = IS;
						Spec.End = Attractor;
						Spec.Distance = 1;
						AddReachSpec( Spec, true);
					}
					NewDist = N.VisitedWeight - (IS.ExtraCost + N.ExtraCost + 1);
					if ( Attractor.ReservePath( NewDist) )
					{
						Spec.Start = Attractor;
						Spec.End = N;
						Spec.Distance = NewDist;
						AddReachSpec( Spec, true);
					}
				}
			}
		}
	}
	
	// Restore JumpSpots
	ForEach NavigationActors( class'JumpSpot', JS)
		if ( JS.Class == class'JumpSpot' )
			JS.bSpecialCost = true;
}

//*********************************
// *********** Utils
event SetEndpoint()
{
	if ( EndPoint != None )
		EndPoint.bEndPoint = true;
}

function bool IsConnectedTo( NavigationPoint Start, NavigationPoint End)
{
	local int rIdx, pIdx;
	local Actor N;
	
	ForEach ConnectedDests( Start, N, rIdx, pIdx)
		if ( N == End )
			return true;
	return false;
}

function SpawnScout()
{
	local PlayerStart P;
	local NavigationPoint N;
	
	ForEach NavigationActors( class'PlayerStart', P)
	{
		MyScout = Spawn( class'FV_Scout',,,P.Location);
		if ( MyScout != None )
			break;
	}
}