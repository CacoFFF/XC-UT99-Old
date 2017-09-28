//=============================================================================
// DirectLinkType Transloc dest
// Targeted pathing to the Nav i'm aiming at
// Rejects all normal pathing, will take nearest flat for start point
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_DirectTDest expands Botz_DirectLink;

#exec TEXTURE IMPORT NAME=BWP_DirectT FILE=..\CompileData\BWP_DirectT.bmp FLAGS=2

//Called after botZ decides this is the path to take
function bool PostPathEvaluate( botz other)
{
	if ( !other.PointReachable(Location) && SpecialCost(Other) < 500 )
	{
		Other.TranslocateToTarget(self);
		return true;
	}
	return false;
}

event int SpecialCost(Pawn Seeker)
{
	if ( Botz(Seeker) != none && Botz(Seeker).bCanTranslocate )
//	if ( Seeker.GetPropertyText("bCanTranslocate") ~= "True" )
		return 150;

	return 100000000;
}

function QueuedForNavigation( Botz Other, byte Slot)
{
	if ( Other.bCanTranslocate && (Other.Weapon != Other.MyTranslocator) && ((Other.Enemy == none) || (VSize(Other.Enemy.Location - Other.Location) > 200)) )
	{
		if ( (Slot < 2) || (VSize( Other.Location - Location) < Other.GroundSpeed) )
		{
			Other.PendingWeapon = Other.MyTranslocator;
			Other.Weapon.PutDown();
		}
	}
}

defaultproperties
{
	FriendlyName="Direct Transloc dest"
	MaxDistance=600
	Texture=Texture'BWP_DirectT'
	bPushSave=True
	bDirectConnect=True
	bSpecialCost=True
}
