//=============================================================================
// BotzWeaponProfile.
//
// UT_Biorifle profile
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_WePro_BioRifleTEST extends BotzWeaponProfile;

//Advantage values go from 0 to 2

//var() bool bSpecialScript; //Call this profile's SPECIAL SCRIPT to determine weapon usage.


//Increase rating
static function float SpecialRating( Botz B)
{
	if ( (B.Enemy != None) && (B.Enemy.ReducedDamageType == 'Corroded') ) //Slith!!!
		return 1.f - B.ReducedDamagePct;
	return 1.1;
}

//Use special fire modes
static function bool CustomizeFire( Botz B)
{
	local bool bCanSee;

	if ( (B.Enemy != None) && (B.Enemy.ReducedDamageType == 'Corroded') && (FRand() < B.Enemy.ReducedDamagePct) )
	{
		B.bFire = 0;
		B.bAltFire = 0;
		B.SwitchToBestWeapon();
		return true;
	}
	
	if ( !B.FastTrace( B.Location + vector(B.Viewrotation) * 120) )
	{
		if ( B.bAltFire > 0 )
			return true;
		B.bAltFire = Rand(2);
		B.bFire = 0;
		return true;
	}

	bCanSee = (B.Enemy != None) && B.CanSee(B.Enemy);

	if ( !bCanSee && (B.Weapon.AmmoType.AmmoAmount < 13) )
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

//Called during HOLDBUTTON
function bool ShouldReleaseOnSight( Botz B, Actor Other)
{
	if ( !B.FastTrace(B.Location + Vector(B.ViewRotation) * 90 + Vect(0,0,20))  )
		return false;
	if ( (B.Health < 40) || B.AimPoint.bCalcObstructed || (B.PendingWeapon != none) )
		return true;
	if ( (Pawn(Other) != none) && Pawn(Other).Health < 60 )
		return true;
	if ( Trigger(Other) != none )
		return false;
	if ( VSize( B.Location - Other.Location) > 500 ) //Too far
		return false;
	return ( B.AimPoint.SightTimer > 0.2 );
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
	CondB(1)=500
	Strategies(2)=HOLDBUTTON
	StraA(2)=5
	StraB(2)=10
	FireMode(2)=1
	Conditionals(2)=NOENEMY
}