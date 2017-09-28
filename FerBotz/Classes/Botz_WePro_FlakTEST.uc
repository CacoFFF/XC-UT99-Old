//=============================================================================
// BotzWeaponProfile.
//
// Flak Cannon test profile
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_WePro_FlakTEST extends BotzWeaponProfile;

//Advantage values go from 0 to 2

//var() bool bSpecialScript; //Call this profile's SPECIAL SCRIPT to determine weapon usage.

//Use special fire modes
static function bool CustomizeFire( Botz B)
{
	local bool bCanSee;

	bCanSee = B.CanSee(B.Enemy);

	if ( !bCanSee && !B.FastTrace( B.Location + vector(B.Viewrotation) * 150) )
	{
		B.bAltFire = 0;
		B.bFire = 0;
		return true;
	}

	if ( !bCanSee && (B.CurrentTactic == "LURE") )
	{
		B.bFire = 0;
		B.bAltFire = 0;
		return true;
	}
	return false;
}

//Increase rating
static function float SpecialRating( Botz B)
{
	return 1 + B.Aggresiveness * 0.2;
}


defaultproperties
{
	WeaponClass=Class'Botpack.UT_FlakCannon'
	bTracker=False
	bInstantFire=False
	PointBlankAdv=1.5
	CloseRangeAdv=1.4
	MidRangeAdv=1
	DistantAdv=0.5
	FarAdv=0.2
	HighAdv=1.5
	AmpedAdv=1.2
	WaterAdv=0.5
	SpamFactor=0.2
	BestHitLocAlt=-0.4
	MinRefire=0.1
	AltChance(1)=0.5
	AltChance(2)=0.6
	Strategies(0)=LURE
	Conditionals(0)=ENEMYSIGHT
	CondA(0)=0
	CondB(0)=400
	Strategies(1)=CHARGE
	StraA(1)=200
	StraB(1)=0.7
	Conditionals(1)=ENEMYSIGHT
	CondA(1)=400
	CondB(1)=1200
}