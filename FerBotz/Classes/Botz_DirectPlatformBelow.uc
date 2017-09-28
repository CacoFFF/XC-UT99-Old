//=============================================================================
// PlatformBelow direct link
// Connects to a waypoint, to be used on top of bridges/platforms that move
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_DirectPlatformBelow expands Botz_DirectLink;

#exec TEXTURE IMPORT NAME=BWP_DirectPlatformBelow FILE=..\CompileData\BWP_DirectPlatformBelow.bmp FLAGS=2

event FinishedPathing()
{
	Super.FinishedPathing();
	SetTimer( 1 + FRand(), true);
}

event Timer()
{
	local vector HitLocation, HitNormal;
	if ( CollideTrace( HitLocation, HitNormal, Location - vect(0,0,70)) != None )
		ExtraCost = 0;
	else
		ExtraCost = 10000000;
}

defaultproperties
{
	FriendlyName="Direct Link"
	MaxDistance=600
	Texture=Texture'BWP_Direct'
	bPushSave=True
	bDirectConnect=True
}
