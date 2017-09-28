//=============================================================================
// BotzWeaponProfile.
//
// Flak Cannon test profile
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_WePro_RocketTEST extends BotzWeaponProfile;


//var() bool bSpecialScript; //Call this profile's SPECIAL SCRIPT to determine weapon usage.

//Use special fire modes
static function bool CustomizeFire( Botz B)
{
	local vector HitLocation, HitNormal;
	local float SafeDist;
	
	SafeDist = 1000;
	if ( B.AimPoint.PointTarget != none )
		SafeDist = FMax(VSize(B.AimPoint.Location - B.Location) * 0.5, 200);
	
	if ( !B.FastTrace(B.Location + vector(B.Viewrotation) * SafeDist) )
	{
		B.bFire = 0;
		return true; //Do not fire
	}

	B.Trace( HitLocation, HitNormal, B.Location + Vector(B.ViewRotation) * 250);
	if ( HitLocation != vect(0,0,0) )
	{
		B.CombatParamA += 1;
		if ( B.CombatParamB > 0 )
			B.CombatParamB += 1.2;
		if ( (Normal( B.AimPoint.Location - B.Location).Z > 0.18) && ( VSize(B.AimPoint.Location - B.Location) < 1500 ) && !B.FastTrace(B.AimPoint.PointTarget.Location - Vect(0,0,25) ) )
		{
			B.bFire = 0;
			b.bAltFire = 1;
		}
	}
	return false;
}

//Called during HOLDBUTTON
function bool ShouldReleaseOnSight( Botz B, Actor Other)
{
	if ( (B.Health < 40) || B.AimPoint.bCalcObstructed )
		return true;
	if ( (Pawn(Other) != none) && Pawn(Other).Health < 80 )
		return true;
	if ( Trigger(Other) != none )
		return true;
	if ( !B.FastTrace(B.Location + Vector(B.ViewRotation) * 200 + Vect(0,0,20))  )
		return false;
	if ( VSize( Vector(Other.Rotation) + Normal(B.Location - Other.Location)) < 1.0 ) //Not aiming at me
		return false;
	return ( B.AimPoint.SightTimer > 0.1 );
}

defaultproperties
{
	WeaponClass=Class'Botpack.UT_EightBall'
	bTracker=False
	bInstantFire=False
	PointBlankAdv=0.2
	CloseRangeAdv=0.9
	MidRangeAdv=1.2
	DistantAdv=0.8
	FarAdv=0.6
	LowAdv=0.2
	SameHeightAdv=1.1
	HighAdv=1.5
	AmpedAdv=1.1
	WaterAdv=0.3
	SpamFactor=0.5
	BestHitLocAlt=-0.4
	SafeAimDist=240
	MinRefire=0.1
	AltChance(0)=0.9
	AltChance(1)=0.3
	AltChance(2)=0.2
	Strategies(0)=LURE
	Conditionals(0)=RUNAWAY
	StraA(0)=250
	StraB(0)=0.5
	CondA(0)=2.0
	FireMode(0)=4
	Strategies(1)=HOLDBUTTON
	Conditionals(1)=ENEMYNOSIGHT
	StraA(1)=0.6
	StraB(1)=4
	CondA(1)=200
	CondB(1)=2500
	CondC(1)=23.0
	Strategies(2)=CHARGE
	StraA(2)=400
	StraB(2)=1
	Conditionals(2)=ENEMYSIGHT
	CondA(2)=400
	CondB(2)=2500
	Strategies(3)=LURE
	Conditionals(3)=ENEMYTOOCLOSE
	CondA(3)=70
	CondB(3)=0
	CondC(3)=0.05

}