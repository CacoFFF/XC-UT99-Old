//=============================================================================
// DirectLinkType Piston launch
// Targeted pathing to the Nav i'm aiming at
// Rejects all normal pathing, will take nearest flat for start point
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_DirectPistonTrans expands Botz_DirectLink;

#exec TEXTURE IMPORT NAME=BWP_DirectPT FILE=..\CompileData\BWP_DirectPT.bmp FLAGS=2

//Called after botZ decides this is the path to take
function bool PostPathEvaluate( botz Other)
{
	if ( !Other.PointReachable(Location) && SpecialCost(Other) < 500 )
	{
		if ( Other.bHasImpactHammer && Other.bCanTranslocate )
		{
			if ( (Other.MyTranslocator.TTarget != none) && (Other.MyTranslocator.TTarget.Physics == PHYS_Falling) && BotzTTarget(Other.MyTranslocator.TTarget).bImpactLaunch )
				return true;
			Other.bShouldDuck = Other.EnemyAimingAt( Other);
			Other.FinalMoveTarget = self;
			Other.GotoState('ImpactMode','TranslocLaunch');
			return true;
		}
	}
	return false;
}

event int SpecialCost(Pawn Seeker)
{
	if ( (Seeker.Skill > 3) && (Botz(Seeker) != none) && Botz(Seeker).bCanTranslocate && Botz(Seeker).bHasImpactHammer)
//	if ( Seeker.GetPropertyText("bCanTranslocate") ~= "True" )
		return 150;

	return 100000000;
}

function QueuedForNavigation( Botz Other, byte Slot)
{
	if ( Other.bCanTranslocate && (Other.Weapon != Other.MyTranslocator) && ((Other.Enemy == none) || (VSize(Other.Enemy.Location - Other.Location) > 600)) )
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
	FriendlyName="Direct Piston Launch"
	MaxDistance=600
	Texture=Texture'BWP_DirectPT'
	bPushSave=True
	bDirectConnect=True
	bSpecialCost=True
}
