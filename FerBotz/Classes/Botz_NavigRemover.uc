//=============================================================================
// This node removes all other nodes around it, HARDCODED!
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_NavigRemover expands Botz_NavigBase;


function RemovePaths( Botz_PathLoader Loader)
{
	local NavigationPoint N;

	ForEach Loader.NavigationActors( class'NavigationPoint', N, MaxDistance, Location)
	{
		if ( (Botz_NavigBase(N) != none) || (PathNode(N) == none && BlockedPath(N) == none && InventorySpot(N) == none) )
			continue;
		if ( InventorySpot(N) != none && InventorySpot(N).MarkedItem != none )
			InventorySpot(N).MarkedItem.MyMarker = none;
		LockActor(false,N);
		ClearAllPaths( N, true);
		N.Destroy();
	}
}


event EPathMode IsCandidateTo( Botz_NavigBase Other)
{
	return PM_None;
}

event EPathMode OtherIsCandidate( NavigationPoint Nav)
{
	return PM_None;
}


defaultproperties
{
	FriendlyName="Simple path remover"
	MaxDistance=200
	Texture=Texture'Engine.S_Corpse'
	DrawScale=1
	bLoadSpecial=True
}