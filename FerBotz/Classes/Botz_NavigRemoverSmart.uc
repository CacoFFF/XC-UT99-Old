//=============================================================================
// This node removes all other nodes around it, HARDCODED!
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_NavigRemoverSmart expands Botz_NavigRemover;


function RemovePaths( Botz_PathLoader Loader)
{
	local InventorySpot IS;
	local PathNode P;
	local int Pass;

	//Pass 1, remove reduntant inventory spots
	ForEach Loader.NavigationActors( class'InventorySpot', IS, MaxDistance, Location)
		if ( InventorySpotEvaluate(IS) )
		{
//			Log("INVENTORYSPOT EVALUATE: "$IS.Name);
			if ( IS.MarkedItem != none )
				IS.MarkedItem.MyMarker = none;
			LockActor(false,IS);
			ClearAllPaths( IS, true);
			IS.Destroy();
		}
	
	//3 Passes
	For ( Pass=0 ; Pass<3 ; Pass++ )
	{
		ForEach Loader.NavigationActors( class'PathNode', P, MaxDistance, Location)
		{
			if ( (P.Paths[1] == -1) || (P.Tag != 'PathNode') ) //Endpoint or tagged node
				continue;
			
			if ( PathNearOthers(P) || ClusterFuck(P) || TracedRoute(P) )
			{
				LockActor(false,P);
				ClearAllPaths( P, true);
				P.Destroy();
			}
		}
	}
}

function bool InventorySpotEvaluate( InventorySpot Eval)
{
	local InventorySpot IS;

	if ( Eval.MarkedItem == None )
	{
		ForEach NavigationActors( class'InventorySpot', IS, 80, Eval.Location, true)
			if ( (IS.MarkedItem == None) && (IS != Eval) )
				return true;
	}
	else
	{
		ForEach NavigationActors( class'InventorySpot', IS, 80, Eval.Location, true)
			if ( (IS != Eval) && (IS.MarkedItem != None) && (Eval.MarkedItem.Class == IS.MarkedItem.Class) )
				return true;
	}
}

function bool PathNearOthers( NavigationPoint N)
{
	local Actor End;
	local int rIdx, pIdx;
	local InventorySpot IS;
	
	//Spot nearby IS
	ForEach ConnectedDests( N, End, rIdx, pIdx)
		if ( (InventorySpot(End) != None) || (PlayerStart(End) != None) || (LiftExit(End) != None) )
		{
			if ( (VSize(N.Location - End.Location) < 40) && (IsConnectedTo( NavigationPoint(End), N) != -1) )
			{
//				Log("NEAR"@Caps(End.Class.Name)$": "$N.Name);
				return true;
			}
			IS = InventorySpot(End);
		}
		
	if ( IS == None )
		return false;
		
	ForEach ConnectedDests( N, End, rIdx, pIdx)
		if ( (InventorySpot(End) == None) && (IsConnectedTo( NavigationPoint(End), IS, true) == -1) )
			return false;
//	Log("NEAR INVENTORY: "$N.Name);
	return true;
}

function bool ClusterFuck( NavigationPoint N)
{
	local NavigationPoint Nav;
	local int Matrix[9];
	local int XC, YC;
	local float Factor;
	
	Factor = 1/500;
	
	ForEach NavigationActors( class'NavigationPoint', Nav, 500, N.Location, true)
	{
		if ( (Nav == N) || (Nav.UpstreamPaths[1] == -1) ) //End points shouldn't count as clusterfuck factors
			continue;
		XC = Clamp( (500+N.Location.X-Nav.Location.X) * Factor, 0, 2);
		YC = Clamp( (500+N.Location.Y-Nav.Location.Y) * Factor, 0, 2);
		Matrix[ XC + YC*3]++;
	}
	
	YC = 0;
	For ( XC=0 ; XC<9 ; XC++ )
		YC += int(Matrix[XC] > 1);
	YC += Matrix[4]; //Center paths weigh a lot!
	if ( YC >= 5 )
	{
//		Log("CLUSTERFUCK: "$N.Name);
		return true;
	}
}

function bool TracedRoute( NavigationPoint N)
{
	local Actor End;
	local int rIdx, pIdx;
	local NavigationPoint Nav[4], NN;
	local int Count, i, j;

	if ( N.Paths[4] != -1 ) //Evaluate nodes with 4 or less connections
		return false;
		
	ForEach ConnectedDests( N, End, rIdx, pIdx)
	{
		NN = NavigationPoint( End);
		if ( NN!=None && Count < 4 )
			Nav[Count++] = NN;
	}
	
	//See that these 4 nodes interconnect
	while ( Count-- > 0 )
	{
		For ( i=0 ; i<Count ; i++ )
			if ( (IsConnectedTo(Nav[i], Nav[Count], true) == -1) || (IsConnectedTo(Nav[Count], Nav[i], true) == -1) )
				return false;
	}
//	Log("TRACED ROUTE: "$N.Name);
	return true;
}



defaultproperties
{
	FriendlyName="Smart path remover"
	MaxDistance=3000
	Texture=Texture'Engine.S_Corpse'
	DrawScale=2
	bLoadSpecial=True
}