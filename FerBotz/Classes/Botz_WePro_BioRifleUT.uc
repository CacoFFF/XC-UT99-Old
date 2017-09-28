//=============================================================================
// BotzWeaponProfile.
//
// UT_Biorifle profile
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_WePro_BioRifleUT extends BotzWeaponProfile;

//Advantage values go from 0 to 2

//var() bool bSpecialScript; //Call this profile's SPECIAL SCRIPT to determine weapon usage.


//Increase rating
static function float SpecialRating( Botz B)
{
	return 1.1;
}

//Use special fire modes
static function bool CustomizeFire( Botz B)
{
	local bool bCanSee;

	if ( !B.FastTrace( B.Location + vector(B.Viewrotation) * 100) )
	{
		if ( B.bAltFire > 0 )
			return true;
		B.bAltFire = Rand(2);
		B.bFire = 0;
		return true;
	}

	bCanSee = B.CanSee(B.Enemy);

	if ( !bCanSee && (B.Weapon.AmmoType.AmmoAmount < 14) )
	{
		if ( B.bAltFire == 1 )
			return true; //Don't release if out of ammo

		B.bFire = 0;
		B.bAltFire = 0; //Don't fire if out of ammo
		return true;
	}

	if ( (B.CurrentTactic == "LURE") && bCanSee && (B.bAltFire > 0) )
	{
		B.bFire = 1;
		B.bAltFire = 0;
		return true;
	}
	return false;
}

defaultproperties
{
	WeaponClass=Class'Botpack.UT_Biorifle'
	bTracker=True
	bInstantFire=False
	CustomRating=0.2
	CloseRangeAdv=1.5
	MidRangeAdv=0.8
	DistantAdv=0.1;
	FarAdv=0.0
	HighAdv=1.5
	AmpedAdv=1.2
	WaterAdv=0.5
	SpamFactor=1.6
	BestHitLocAlt=-0.4
	MinRefire=0.3
	Strategies(0)=LURE
	Conditionals(0)=ENEMYSIGHT
	CondA(0)=500
	CondB(0)=1500
	Strategies(1)=CHARGE
	StraA(1)=150
	StraB(1)=0.5
	Conditionals(1)=ENEMYSIGHT
	CondB(1)=600
	Strategies(2)=HOLDBUTTON
	StraA(2)=5
	StraB(2)=10
	FireMode(2)=1
	Conditionals(2)=NOENEMY
	Strategies(3)=PROJRAIN
	StraB(3)=2.5
	FireMode(3)=3
	Conditionals(3)=RAINRANGE
	CondA(3)=3
}