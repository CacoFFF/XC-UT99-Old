//=============================================================================
// XC_NavigationPoint
// XC_Engine extended navigation point
//=============================================================================
class XC_NavigationPoint expands NavigationPoint;

#exec Texture Import File=Textures\S_Pickup_G.pcx Name=S_Pickup_G Mips=Off Flags=2

function bool ReservePath( optional int MinDistance)
{
	local int i, Highest;
	local int HighestDistance;
	local Actor Start, End;
	local int ReachFlags, Distance;
	local XC_Engine_Actor XCGEA;

	if ( Paths[15] < 0 )
		return true;
		
	ForEach DynamicActors( class'XC_Engine_Actor', XCGEA) break;
	if ( XCGEA == None )
		return false;
	
	XCGEA.CompactPathList( self);
	if ( Paths[15] < 0 )
		return true;
	
	XCGEA.GetReachSpec( XCGEA.DummyReachSpec, Paths[15]);
	if ( XCGEA.DummyReachSpec.Distance < MinDistance )
		return false;

	XCGEA.ResetReachSpec( XCGEA.DummyReachSpec);
	XCGEA.SetReachSpec( XCGEA.DummyReachSpec, Paths[15], true); //Automatic unlink
	return true;
}


// Post route mapping, finds cost to reaching this path (also checks adjacents in case this is blocked)
static function int LowestReachableWeight( NavigationPoint N)
{
	local int i;
	local int Best;
	local Actor Start, End;
	local int ReachFlags, Distance;
	
	Best = GetWeight(N);
	For ( i=0 ; i<16 && N.upstreamPaths[i] >= 0 ; i++ )
	{
		N.describeSpec( N.upstreamPaths[i], Start, End, ReachFlags, Distance);
		if ( NavigationPoint( Start) != None )
			Best = Min( GetWeight(NavigationPoint(Start)) + Distance, Best);
	}
	return Best;
}

static function int GetWeight( NavigationPoint N)
{
	if ( N.StartPath == None )
		return 10000000;
	return N.VisitedWeight;
}



defaultproperties
{
     bStatic=False
     bNoDelete=False
     bCollideWhenPlacing=False
     bCollideWorld=False
     Texture=Texture'S_Pickup_G'
}