//=============================================================================
// This path type traces thru movers
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_NavigDoor expands Botz_NavigBase;

#exec TEXTURE IMPORT NAME=BWP_Door FILE=..\CompileData\BWP_Door.bmp FLAGS=2

//** This event describes how all paths connect to this, called after IsCandidateTo on NavigBases
event EPathMode OtherIsCandidate( NavigationPoint Nav)
{
	if ( Nav.IsA('LiftCenter') ) //No lift centers
		return PM_None;
	if ( Nav.IsA('SpawnPoint') && (VSize(Nav.Location - Location) > MaxDistance * 0.5) ) //Avoid distant SpawnPoints
		return PM_None;
	if ( PathVisible( Self, Nav, true) )
		return PM_Normal;
	return PM_None;
}

//** This event will set the DoorWay reachflag
event int ModifyFlags( NavigationPoint Dest, int CurFlags)
{
	local Actor A;
	local vector HitLocation, HitNormal;

	if ( (CurFlags & 16) == 0 )
	{
		ForEach TraceActors( class'Actor', A, HitLocation, HitNormal, Dest.Location )
			if ( A.IsA('Mover') )
				return CurFlags | 16;
	}
	return CurFlags;
}

defaultproperties
{
	FriendlyName="Base Door Node"
	MaxDistance=800
	Texture=Texture'BWP_Door'
	bCustomFlags=True
}