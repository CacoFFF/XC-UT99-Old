//=============================================================================
// BotzWeaponProfile.
//
// Impact hammer profile
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_WePro_Piston extends BotzWeaponProfile;

//Advantage values go from 0 to 2

//var() bool bSpecialScript; //Call this profile's SPECIAL SCRIPT to determine weapon usage.


//Increase rating
static function float SpecialRating( Botz B)
{
	return 2.0;
}

//Called during HOLDBUTTON
function bool ShouldReleaseOnSight( Botz B, Actor Other)
{
	B.CurrentTactic = ""; //Force Charge to check fire on every tick
	B.Accumulator = 0;
	B.ExecuteAgain = 0;
	return false;
}

//Use special fire modes
static function bool CustomizeFire( Botz B)
{
	local vector HitLocation, HitNormal;
	local float SafeDist;

	if ( (B.Enemy != none) && (B.bFire > 0)  && (VSize(B.Location - B.Enemy.Location) < (15*B.Skill - B.Enemy.CollisionRadius) ) )
	{
		if ( PlayerPawn(B.Enemy) != none && FRand() < 0.9 ) //Let players have some space
			return true;
		HitLocation = B.Enemy.Location;
		if ( (HitLocation.Z + B.Enemy.CollisionHeight) < (B.Location.Z + 10) )
			HitLocation.Z += B.Enemy.CollisionHeight * 0.8;
		else if ( (HitLocation.Z - B.Enemy.CollisionHeight) < (B.Location.Z + 10) )
			HitLocation.Z -= B.Enemy.CollisionHeight;
		else
			HitLocation.Z = B.Location.Z + 10;
		HitLocation += Normal( (B.Location - HitLocation) * vect(1,1,0)) * B.Enemy.CollisionRadius;
		if ( VSize( HitLocation - B.Location) > 89 )
			return true;
		B.bFire = 0;
		B.bAltFire = 0;
		B.ViewRotation = rotator(HitLocation - (B.Location+vect(0,0,10)));
		if ( Bot(B.Enemy) != none )
			B.Weapon.Tick( 0.0);
		return true;
	}

	SafeDist = 125;
	if ( B.AimPoint.PointTarget != none )
		SafeDist = FMax(VSize(B.AimPoint.Location - (B.Location + vect(0,0,15))) * 0.5, 125);
	
	if ( !B.FastTrace(B.Location + vector(B.Viewrotation) * SafeDist) )
	{
		if ( B.bFire > 0 )
			B.bFire = 1;
		B.bAltFire = 0;
		return true; //Do not release fire
	}

	if ( !B.Weapon.IsInState('Firing') && B.Enemy == none )
	{
		B.bFire = 0;
		return true;
	}
	if ( B.CurrentTactic == "CHARGE" )
	{
		if ( B.bFire == 0 )
		{
			B.bFire = 1;
			B.Weapon.Fire(1);
		}
		return true;
	}
	return false;
}

defaultproperties
{
	WeaponClass=Class'Botpack.ImpactHammer'
	bTracker=True
	bInstantFire=True
	bInstantAltFire=True
	CustomRating=0.2
	PointBlankAdv=2.2
	CloseRangeAdv=1.5
	MidRangeAdv=1
	DistantAdv=0.2;
	FarAdv=0.0
	SameHeightAdv=1.1
	LowAdv=0.2
	HighAdv=1
	AmpedAdv=0.6
	WaterAdv=0.6
	SpamFactor=2
	Strategies(0)=DISABLENORMAL
	FireMode(0)=5
	Conditionals(0)=ALWAYS
	Strategies(1)=CHARGE
	StraA(1)=50
	StraB(1)=0.2
	Conditionals(1)=ENEMYSIGHT
	CondB(1)=3000
	Strategies(2)=HOLDBUTTON
	StraA(2)=5
	StraB(2)=10
	Conditionals(2)=NOENEMY
}