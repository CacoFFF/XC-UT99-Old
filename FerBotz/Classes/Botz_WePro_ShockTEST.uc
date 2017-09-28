//=============================================================================
// BotzWeaponProfile.
//
// Flak Cannon test profile
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_WePro_ShockTEST extends BotzWeaponProfile;

//Advantage values go from 0 to 2

//var() bool bSpecialScript; //Call this profile's SPECIAL SCRIPT to determine weapon usage.


//Tweak LURE fire behaviour
function FireControl( Botz B, byte UMode)
{
	local Pawn Enemy;
	local bool bView;
	
	B.bFire = 0;
	B.bAltFire = 0;
	Enemy = B.Enemy;
	if ( UMode == 6 && (Enemy != None) )
	{
		//Push back an enemy once, fat monsters shouldn't be shot with alt-balls
		bView = B.LineOfSightTo(Enemy);
		if ( Enemy.CollisionRadius > 60 || HSize(Enemy.Location-B.Location)+B.CollisionRadius+Enemy.CollisionRadius < B.Punteria*15+RandRange( 100, 200) )
		{
			if ( bView )
			{
			NORMALFIRE:
				B.ChargeFireTimer = -1; //Nominal
				B.Accumulator = MinRefire;
				B.Weapon.Fire( 1);
			}
		}
		else
		{
			if ( bView && FRand() < 0.8 )
			{
				B.ChargeFireTimer = -1; //Nominal
				B.Accumulator = MinRefire;
				B.Weapon.AltFire( 1);
			}
			else
			{
				if ( (VSize(Enemy.Velocity*0.2+B.Location-Enemy.Location) > 550) && SetupCombo(B) ) //Try to combo an incoming enemy
				{
					B.ExecuteAgain = 1;
					B.Accumulator = 0.6;
					B.CurrentTactic = "COMBO";
					B.GotoState('CombatState','Combo');
				}
				else if ( bView )
					Goto NORMALFIRE;
			}
		}
	}
}

//Decrease rating
static function float SpecialRating( Botz B)
{
	return 1.0 - B.Aggresiveness * 0.1;
}

//Called during HOLDBUTTON
//This is a custom fire control used to tell the bot to spam
function bool ShouldReleaseOnSight( Botz B, Actor Other)
{
	return true;
}

//Custom version!!
function bool SetupCombo( Botz B)
{
	local ShockProj S;

	if ( FRand() * 15 < (B.Skill + B.TacticalAbility - B.Punteria) )
	{
		ForEach B.Enemy.VisibleCollidingActors (class'ShockProj', S, 150 + B.Skill*5 + B.TacticalAbility*2)
		{
			if ( S.Instigator != B.Enemy )
				break;
		}
	}

	if ( S == none )	
		return Super.SetupCombo( B);


	S.Target = B.Enemy;
	B.AimPoint.PointTarget = B;
	B.AimPoint.AimOther = S;
	B.bFire = 0;
	B.bAltFire = 0;
	return true;
}

//FireMode = 6 means FireControl()

defaultproperties
{
	WeaponClass=Class'Botpack.ShockRifle'
	bTracker=False
	bInstantFire=True
	PointBlankAdv=0.6
	CloseRangeAdv=1.0
	MidRangeAdv=1
	DistantAdv=1
	FarAdv=1
	HighAdv=0.8
	SameHeightAdv=1.1
	LowAdv=0.4
	AmpedAdv=1.2
	WaterAdv=0.8
	SpamFactor=0.2
	MinRefire=0.1
	AltChance(0)=0.2
	AltChance(1)=0.8
	AltChance(2)=0.4
	AltChance(3)=0.1
	Strategies(0)=COMBO
	StraA(0)=100
	Conditionals(0)=TODIST
	CondA(0)=530
	CondB(0)=1000
	CondC(0)=0.2
	Strategies(1)=LURE
	FireMode(1)=6
	Conditionals(1)=ENEMYTOOCLOSE
	CondA(1)=130
	CondB(1)=-1
	CondC(1)=0.05
}