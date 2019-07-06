//=============================================================================
// XC_NavigationPoint
// XC_Engine extended navigation point
//=============================================================================
class XC_NavigationPoint expands NavigationPoint;

#exec Texture Import File=Textures\S_Pickup_G.pcx Name=S_Pickup_G Mips=Off Flags=2

native(3553) final iterator function DynamicActors( class<Actor> BaseClass, out actor Actor, optional name MatchTag );

//TODO: AUTO PATH USING SCOUT!!!

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


event Destroyed()
{
	local XC_Engine_Actor XCGEA;
	
	ForEach DynamicActors( class'XC_Engine_Actor', XCGEA)
		break;
	Log("Destroying"@Name@XCGEA);
	if ( XCGEA != None )
	{
		XCGEA.ResetReachSpec( XCGEA.DummyReachSpec);
		XCGEA.CompactPathList( self);
		while ( Paths[0] != -1 )
		{
			Log("Destroying reachspec"@Paths[0]);
			XCGEA.SetReachSpec( XCGEA.DummyReachSpec, Paths[0], true);
		}
		while ( PrunedPaths[0] != -1 )
			XCGEA.SetReachSpec( XCGEA.DummyReachSpec, PrunedPaths[0], true);
		while ( UpstreamPaths[0] != -1 )
			XCGEA.SetReachSpec( XCGEA.DummyReachSpec, UpstreamPaths[0], true);
		XCGEA.LockToNavigationChain( Self, false);
	}
}





defaultproperties
{
     bStatic=False
     bNoDelete=False
     bCollideWhenPlacing=False
     bCollideWorld=False
     Texture=Texture'S_Pickup_G'
}