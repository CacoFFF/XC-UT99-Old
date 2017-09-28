//=============================================================================
// Simple high transloc dest (allows bots to jump down on opposite direction)
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_SimpleTDest expands Botz_JumpNode;

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
	FriendlyName="Simple high Translocator dest"
	MaxDistance=700
	Texture=Texture'FerBotz.Botz_Scope'
	bSpecialCost=true
}