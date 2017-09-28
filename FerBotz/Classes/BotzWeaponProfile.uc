//=============================================================================
// BotzWeaponProfile.
//
// Hold weapon information, suggest attack and defense style here.
// Hold the pointers at MasterGasterFer, deliver a pointer to a BotZ using this
// weapon and have him use it, pointer is always delivered when BotZ decides
// new pending weapon.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BotzWeaponProfile expands Object;

var() class<Weapon> WeaponClass; //If class == Unreali.Weapon, this is a generic profile, use it to load other profiles
var() string WeaponString; //Use this to avoid class dependency in preset profiles 

//Advantage values go from 0 to 2

/*
var(Movement) const enum EPhysics
{
	PHYS_None,
	PHYS_Walking,
	PHYS_Falling, = 2
	PHYS_Swimming,
	PHYS_Flying, = 4
	PHYS_Rotating,
	PHYS_Projectile, = 6
	PHYS_Rolling,
	PHYS_Interpolating,
	PHYS_MovingBrush,
	PHYS_Spider,
	PHYS_Trailer
} Physics;
*/

//Aim method to use on Botz, just mirroring BotZ here
/*
var enum EAimingFlags
{
	AIM_Navigation,
	AIM_SpecialNavigation,
	AIM_SuspectEnemy,
	AIM_AcquireEnemy,
	AIM_TrackEnemy,
	AIM_PinpointEnemy,
	AIM_CheckOnOther,
	AIM_LookAround,
	AIM_Camping,
	AIM_Sniping
} AimType;
*/

var() bool bAutoDetect; //Auto detection is set for child classes (modded weapons) or weapons
					// where parameters are clear and can be read from properties
var() bool bWeaponAuth; //Weapon has authoritary control over botz behaviour, don't use profile
var() bool bSpecialScript; //Call this profile's SPECIAL SCRIPT to determine weapon usage.
var() bool bTracker, bAltTracker; //Use alternatea aiming method (disables aquisition shot)


var() bool bNoAmmo;
var() bool bInstantFire, bInstantAltFire;
var() float ProjSpeed, ProjAltSpeed;
var() byte ProjPhysics, ProjAltPhysics;
var() name DamageType, AltDamageType; //FUTURO: Implement later!
var() int DegreeError;
var() int MinBulletSelect; //Must scale down selection if ammo below this (defaults to ammo / 10)
var() float CustomRating; //Defaults to AI rating			CODE =
var() float MinRefire; //If 0, don't release fire

var() float PointBlankAdv; //Usage at ranges (< 90)			CODE =
var() float CloseRangeAdv; //Usage at ranges (90 - 250)		CODE =
var() float MidRangeAdv; //Usage at ranges (250 - 550)		CODE =
var() float DistantAdv; //Usage at ranges (550 - 1200)		CODE =
var() float FarAdv; //Usage at far ranges (> 1200)			CODE =

var() float AltChance[5]; //Use alt instead at ranges		CODE =

var() float SameHeightAdv; //Advantage in same height;		CODE = 
var() float LowAdv; //Advantage in low ground;				CODE =
var() float HighAdv; //Advantage in high ground;			CODE =

var() float AmpedAdv; //Prefer if has amplifier				CODE =
var() float WaterAdv; //Water preference					CODE =

var() float SpamFactor; //Advantage for spamming			CODE =
var() float BestHitLoc; //-1 = feet, 1 = head				CODE =
var() float BestHitLocAlt;	//								CODE =
var() float SafeAimDist;

//Strategy control
var() string Strategies[8];
var() float StraA[8], StraB[8]; //Stragy parameters
var() byte FireMode[8]; //0 = normal, 1 = alt, 2 = both, 3 = random, 4 = use altchance, 5 = no fire, 6 or above = use FireControl()
var() string Conditionals[8];
var() float CondA[8], CondB[8], CondC[8]; //Strategy conditions

//********************************************************************************
//**********************************************************Strategy descriptions:
//
// NOTES: TACTICS MUST NOT BE DUPLICATED!
// OTHERWISE, USE SPECIAL CODE FOR SMART FIRE SWITCHING!
//
// =======================================
// NORMAL > fire while doing other task (old BotZ behaviour)
//
// Notes:
// This mode is assumed if other not suitable
// Normal can be disabled with keyword: DISABLENORMAL
//
// =======================================
// DISABLENORMAL > simple fire control every X seconds
//
// StraA = Duration of X (min 0.1)
//
// =======================================
// FLEE > run away, can fire
//
// Notes:
// This mode is used when fleeing is necessary
// Only use as parameter if weapon can potentially kill the user
//
// =======================================
// CHARGE > run towards enemy
// 
// StraA = how close (units distance)
// StraB = strafe factor (0 to 1)
// Other notes:
// Check every second, latent state without enter/leave events
//
// =======================================
// COMBO > execute combo fire tactics
//
// StraA = optimal distance (units, if enemy further, don't execute second fire)
// StraB = this * skill = chance to use strafing
// Other notes:
// Tries firing at a side to avoid direct hit
// Fire mode abandoned if projectile moving away from enemy
//
// =======================================
// LURE > hide at mid/close range and spam at possible appearing enemy
//
// StraA = min distance to lure point
// StraB = (time to wait)
// Other notes:
// Click won't be released when waiting (multiple rockets)
//
// =======================================
// GUNDUEL > strafing ranged fire
//
// StraA = accuracy bonus
// StraB = perception penalty (FRand() < this means ignore SetEnemy)
// Other notes:
// Can dodge jump if skill is high
//
// =======================================
// SNIPER > fire while not moving
//
// StraA = accuracy bonus
// StraB = perception penalty (FRand() < this means ignore SetEnemy)
// Other notes:
// Better than gunduel, but not moving can make it more vulnerable
// Will crouch if enemy has sniper or not at same height
//
// =======================================
// PROJRAIN > fires projectiles above an obstacle
//
// StraA = longest curve influence (0 never, 1 first choice, 0.5 if necessary, 0.2 necessary + not under fire, 0.7 not under fire)
// StraB = force min timer (don't release button)
// Other notes:
// May extend timer if enemy is strong and inmobile
// Curve traces should be done before entering
//
// =======================================
// HOLDBUTTON > holds fire, releases at safe spot
//
// StraA = min timer
// StraB = max timer
// Other notes:
// Can be used by rockets, miniguns and piston
// On state change, button is always released
//
// =======================================
// BACKSTAB > find advantage position, executes quick kill
//
// StraA = mode (0 move firing, 1 charge til position, 2 hit on position)
// StraB = desired distance (the closer to distance, the higher the skill mult)
// Other notes:
// If distance difference is below 100, skill will be twiced
// If from 100 to 1100, it will be scaled down from 2 to 1
//
// =======================================
// USEBAIT > eliminate enemy at distance with high discretion
//
// StraA = 0.3 + accuracy * this (min timer to fire)
// StraB = accuracy addition
// Other notes:
// If approached from close, BotZ will decide to continue fire or fight back
// Skill will be multiplied only if range advantage is above 0.5
//
// =======================================
// BOUNCE > bouncy projectile fire
//
// StraA = max allowed distance
// StraB = max charge timer
// Other notes:
// Bounce point will translate after every timer
// Bounce will only happen if not under fire
//
// =======================================
// SHOWFIRE > if hiding, show up, fire and hide
//
// StraA = max charge time(if 0, will only fire on sight)
// StraB = min refire (upon fire, hide for this time)
// Other notes:
// Don't use with rapid fire weapons
//
// =======================================

//********************************************************************************
//************************************************************Strategy conditions:
//
// =======================================
// ALWAYS > this fire mode always qualifies
// NOENEMY > like always, but checks if enemy doesn't exist

// =======================================
// RUNAWAY > running away from enemy
//
// CondA = aggresiveness mult factor (>0 means trigger runaway for aggressive bots, <0 means trigger for can)
//
// =======================================
// ENEMYSIGHT > basic enemy on sight condition
//
// CondA = min allowed distance
// CondB = max allowed distance
// CondC = max enemies (if > 0)
//
// =======================================
// ENEMYNOSIGHT > enemy out of sight
//
// CondA = min allowed distance
// CondB = max allowed distance
// CondC = ammo percent needed
//
// =======================================
// RAINRANGE > can send projectiles onto enemy out of sight (falling)
//
// CondA = max timer (if projectile doesn't arrive in time, don't fire)
// CondB = 
//
// =======================================
// CANHIDE > can hide from enemy
//
// CondA = min distance
// CondB = max distance
// CondC = defensive factor (this)+ aggresiveness (0 use always, 1 not attacking, 2 not freelancing, 3 never)
//
// =======================================
// TODIST > enemy approaching visible dist, use projectile velocity
//
// CondA = the distance
// CondB = projspeed
// CondC = increment in chance, for adjusting purposes
//
// =======================================
// ENEMYTOOCLOSE > enemy on my face
//
// CondA = distance
// CondB = greater-than-zero: i am stronger
// CondB = lesser-than-zero: i am weaker
// CondB = zero: no strength condition
// CondC = added weight (to ensure multiple enemytooclose can coexist)
//
// =======================================
// CORRIDORAMMO > in corridor, has ammo
//
// CondA = ammo amount
// CondB = time after unseen (0 means not count unseen)
// CondC = safe distance
//

//  CondA = this * ((2 - aggresiveness) + tactics > DEF TACTIC?


native(3555) static final operator(22) Actor Or (Actor A, skip Actor B);
native(3571) static final function float HSize( vector A);


//********************************************************************************
//****************************** INITIALIZATION **********************************
//FUTURO: Default Aggresiveness is calculated from Distance advantage values
//FUTURO: SpamFactor and height advantages influx on a BotZ cleverness
function float SetAggresiveness( Botz B)
{
}

function float SetTactics( Botz B)
{
}

//MasterGaster should init default weapon profiles
//Init 3rd party weapon using Int Definitions
static final function BotzWeaponProfile InitInt( string WeaponString)
{
}


//Class has already been defined, define weapon characteristics here
final function PostInit()
{
	if ( bAutoDetect )
	{
		bInstantFire = WeaponClass.default.bInstantHit;
		bInstantAltFire = WeaponClass.default.bAltInstantHit;
		if ( !bInstantFire && (ProjSpeed == 0) && (WeaponClass.default.ProjectileClass != none) )
		{
			ProjSpeed = WeaponClass.default.ProjectileClass.default.speed;
			ProjPhysics = WeaponClass.default.ProjectileClass.default.Physics;
		}
		if ( !bInstantAltFire && (ProjAltSpeed == 0) && (WeaponClass.default.AltProjectileClass != none) )
		{
			ProjAltSpeed = WeaponClass.default.AltProjectileClass.default.speed;
			ProjAltPhysics = WeaponClass.default.AltProjectileClass.default.Physics;
		}
	}
	
	if ( MinBulletSelect == 0 )
	{
		if ( WeaponClass.default.AmmoName != none )
		{
			MinBulletSelect = WeaponClass.default.AmmoName.default.MaxAmmo / 10 + 1; //Don't select with 0 ammo
		}
		else
			bNoAmmo = true;
	}
}


//********************************************************************************
//**************************** BUILT IN CONDITIONS *******************************

// =======================================
// RUNAWAY > going away from enemy that's chasing me
//
// CondA = aggresiveness mult factor
//
function float ConditionRunningAway( Botz B, int index)
{
	if ( (B.Enemy == none) || (VSize(B.Enemy.Location - B.Location) > 1000) )
		return 0;

	if ( VSize(B.Enemy.Velocity + B.Enemy.Location - B.Location) > VSize(B.Enemy.Location - B.Location) ) //Enemy not going after me
		return 0;

	if ( (B.MoveTarget != none) && (VSize(B.MoveTarget.Location - B.Enemy.Location) > VSize(B.Location - B.Enemy.Location)) )
		return 1.0 + B.Aggresiveness * CondA[index];
	return 0;
}

// =======================================
// TODIST > enemy approaching visible dist, use projectile velocity
//
// CondA = the distance
// CondB = projspeed
// CondC = increment in chance, for adjusting purposes
//
function float ConditionToDist( Botz B, int index)
{
	local vector Result;
	local float fTries , TimeT;
	local int i;

	//EVALUATE SUSPECTED ENEMIES!
	if ( B.Enemy == none )
		return 0;
		
	fTries = (B.Skill + B.TacticalAbility + B.Aggresiveness) * 0.2;
	TimeT = VSize(B.Location - B.Enemy.Location) / CondB[index];

	//No pude resolver esa ecuacion, asi que me acerco mediante una canariada al result
	For ( i=fTries ; i>=0 ; i--) //Iterar 5 veces, tomar en cuenta la velocidad Z
	{
		Result = B.Enemy.Location + (B.Velocity * TimeT);
		fTries = VSize( Result - B.Location) / CondB[index];
		TimeT = (TimeT + fTries) * 0.5;
	}

	fTries = VSize( Result - B.Location);
	
	//Sweet spot, don't miss it
	if ( fTries == fClamp( fTries, CondA[index] * 0.8, CondA[index] * 1.3) )
		return 1.4 + CondC[index] + B.TacticalAbility * 0.05;
	//Some fail, but works
	else if ( fTries == fClamp( fTries, CondA[index] * 0.8 - 90, CondA[index] * 1.3 + 110) )
		return 1.0 + CondC[index] + B.TacticalAbility * 0.05;
	//Flawed
	else if ( fTries == fClamp( fTries, CondA[index] * 0.7 - 120, CondA[index] * 1.3 + 160) )
		return 0.6 + CondC[index] * 0.5 + B.TacticalAbility * 0.05;
	return 0;
}

// ENEMYSIGHT > basic enemy on sight condition
//
// CondA = min allowed distance
// CondB = max allowed distance
// CondC = max enemies (if > 0)
//
function float ConditionEnemySight( Botz B, int index)
{
	local float factor, maxdist;
	local pawn P;
	local int i;
	local bool bEnemyClose;
	
	if ( B.Enemy == none || !B.LineOfSightTo( B.Enemy) )
		return 0;
		
	factor = 1;

	if ( CondB[index] == 0 )		maxdist = 99999;
	else		maxdist = CondB[index];

	if ( CondC[index] == 0 )
	{
		if ( VSize( B.Enemy.Location - B.Location)  < maxdist )
			factor += frand() * 0.5;
		else
			factor -= 0.2 + frand() * 0.5;

		if ( (CondA[index] == 0) || (VSize( B.Enemy.Location - B.Location)  > CondA[index]) )
			factor += frand() * 0.5;
		else
			factor -= 0.2 + frand() * 0.5;

		return factor;
	}
	
	i = -CondC[index];
	bEnemyClose = (CondA[index] >= 0) && (VSize( B.Enemy.Location - B.Location)  < CondA[index]);
	
//	ForEach B.VisibleCollidingActors( class'Pawn', P, maxdist,,true )
	ForEach B.PawnActors( class'Pawn', P, maxdist, B.Location, true)
	{
		if ( !B.SetEnemy( P, true) )
		{
			if ( P.PlayerReplicationInfo != none ) //Must be a valid player to count as ally
				i--;
			continue;
		}
		i++;
		
		if ( (CondA[index] == 0) || (VSize( P.Location - B.Location)  > CondA[index]) )
		{
			factor += 0.1 + frand() * 0.3;
			if ( bEnemyClose && (factor > 1.2) ) //Modify enemy if this condition is likely to win
			{
				B.Enemy = P;
				bEnemyClose = false;
			}
		}
		else
			factor -= 0.1 + frand() * 0.2;
	}

	if ( i > 0 )
		factor -= i * 0.4;
	return factor;
}

// ENEMYNOSIGHT > basic enemy out of sight condition, may induce new enemy on higher skills
//
// CondA = min allowed distance
// CondB = max allowed distance
// CondC = ammo % required
//
function float ConditionEnemyNoSight( Botz B, int index)
{
	local float factor, maxdist;
	local pawn P;
	local int i;
	local bool bEnemyClose;
	
	if ( (B.Enemy == none && (B.Skill < 3)) || (B.Weapon == none) )
		return 0;
	if ( (B.Weapon.AmmoType != none) && (B.Weapon.AmmoType.AmmoAmount < B.Weapon.AmmoType.MaxAmmo * CondC[index] / 100.0) )
		return 0;


	if ( CondB[index] == 0 )		maxdist = 99999;
	else		maxdist = CondB[index];

	if ( B.Enemy != none ) //Absolute
	{
		factor = VSize(B.Enemy.Location - B.Location) + B.Aggresiveness * 20; //Aggressive bots will load more
		if ( (factor > CondA[index]) && (factor > maxdist) && !B.FastTrace(B.Enemy.Location) )
			return 1.5 + FRand() * 0.5; //1.5 to 2.0 upon valid chase
		if ( B.FastTrace(B.Enemy.Location) )
			return 0; //Enemy in sight, move away from this tactic
	}

	factor = 0.10 * B.TacticalAbility;
	maxdist *= 7/B.Skill;
	if ( (B.Weapon.AmmoType != none) && (B.Weapon.AmmoType.AmmoAmount < B.Weapon.AmmoType.MaxAmmo * 50 / 100.0) )
		factor += 0.4; //Full of ammo

	ForEach B.RadiusActors( class'Pawn', P, maxdist)
	{
		if ( B.SetEnemy( P, true) )
			factor += 0.15 + 0.15 * FRand();
		if ( factor > 3 )
			break;
	}
	return factor;
}

// ENEMYTOOCLOSE > enemy on my face
//
// CondA = distance
// CondB = greater-than-zero: i am stronger
// CondB = lesser-than-zero: i am weaker
// CondB = zero: no strength condition
// CondC = added weight (to ensure multiple enemytooclose can coexist)
function float ConditionEnemyTooClose( Botz B, int index)
{
	local float factor;
	local float winfactor;
	local float Dist;
	local Pawn Enemy;
	
	Enemy = B.Enemy;
	if ( Enemy != None && B.Weapon != None )
	{
		Dist = CondA[index];
		if ( CondB[index] < 0 ) //We're evaluating a defensive condition, alter detection radius
			Dist *= 1 - B.Aggresiveness * 0.02;
		if ( (HSize( B.Location - Enemy.Location) < Dist+B.CollisionRadius+Enemy.CollisionRadius) && (Abs(B.Location.Z - Enemy.Location.Z) < Dist+B.CollisionHeight+Enemy.CollisionHeight) )
		{
			if ( CondB[index] == 0 )
				return 2 + CondC[index];

			if ( Enemy.CollisionRadius+Enemy.CollisionHeight > B.CollisionRadius+B.CollisionHeight ) //Enemy is bigger
				winfactor -= Sqrt(Enemy.CollisionRadius+Enemy.CollisionHeight / B.CollisionRadius+B.CollisionHeight);
			winfactor += float(B.Health - Enemy.Health) * 0.001;
			winfactor += B.Aggresiveness * 0.01; //Less aggresive bots tend to not think they'll win
			if ( Enemy.Weapon == None || Enemy.Weapon.bMeleeWeapon ) //Enemy can melee
				winfactor -= 0.2;
			else if ( Enemy.Weapon.bRapidFire || (Enemy.Weapon.AiRating > B.Weapon.AiRating) ) //Enemy weapon is better in this situation
				winfactor -= 0.4;
			else
				winfactor += B.Weapon.AiRating - Enemy.Weapon.AiRating;

			if ( winfactor * CondB[index] > 0 )
				return 2 + CondC[index];
		}
	}
	return B.DistractionLimit - 0.1; //Never trigger this
}



function float SetRating( Botz B, float OldRating, optional Weapon W)
{
	local int i;
	local float DistFactor, HeightFactor, OtherAdv;

	if ( OldRating <= 0 )
		return 0;
		
	i = GetDistanceMode( B);
	if ( i == 0 )
		DistFactor = PointBlankAdv;
	else if ( i == 1 )
		DistFactor = CloseRangeAdv;
	else if ( i == 2 )
		DistFactor = MidRangeAdv;
	else if ( i == 3 )
		DistFactor = DistantAdv;
	else
		DistFactor = FarAdv;

	if ( (i > 0) && (B.Enemy != none) )
	{
		HeightFactor = Normal( B.Enemy.Location - B.Location).Z;
		if ( HeightFactor > 0 ) //Enemy is above me
			HeightFactor = ( 1.0 - HeightFactor) * SameHeightAdv + HeightFactor * LowAdv;
		else //Enemy below
			HeightFactor = ( 1.0 + HeightFactor) * SameHeightAdv - HeightFactor * HighAdv;
	}
	else
		HeightFactor = 1.0;

	OtherAdv = 1;
	if ( B.Physics == PHYS_Swimming )
		OtherAdv *= WaterAdv;
	if ( B.DamageScaling > 2 )
		OtherAdv *= AmpedAdv;

	if ( W != none )
	{
		if ( (W.AmmoType != none) && (W.AmmoType.AmmoAmount < MinBulletSelect) )
			return OldRating * 0.2 + OldRating * DistFactor * HeightFactor * OtherAdv * W.AmmoType.AmmoAmount / MinBulletSelect;
	}
	return OldRating * 0.2 + OldRating * DistFactor * HeightFactor * OtherAdv;

}

//Rating to multiply on weapon choosing
static function float SpecialRating( Botz B)
{
	return 1.0;
}

//Use special fire modes
static function bool CustomizeFire( Botz B)
{
	return false;
}

//Special fire modes for UMode >= 6
function FireControl( Botz B, byte UMode);


//Use this as modifier for launching velocity, useful for weapons with strange firing speeds
static function vector AdjustFire( Botz B)
{
	return vect(0,0,0);
}

//********************************************************************************
//******************************** COMBAT PICKER *********************************

function bool SuggestCombat( Botz B, string LikelyCombat)
{
	local int i, bestFire;
	local float BestStra[2], fStrategies[8];
	local string BestCombat;

	//First we process likely combat
	if ( (LikelyCombat != "") && (B.Enemy != none) && (FRand() < 0.6) )
	{
		for ( i=0 ; (i<8)&&(Strategies[i]!="") ; i++ )
		{
			if ( LikelyCombat == Strategies[i] )
			{
				BestCombat = LikelyCombat;
				BestStra[0] = StraA[i];
				BestStra[1] = StraB[i];
				bestFire = FireMode[i];
				Goto DONT_CHECK;
			}
		}
		i=0;
	}
	
	//Any rating over zero is eligible
	while ( (i<8) && (Strategies[i] != "") )
	{
		if ( Conditionals[i] == "ALWAYS" )
			fStrategies[i] = 1.0;
		else if ( Conditionals[i] == "ENEMYSIGHT" )
			fStrategies[i] = ConditionEnemySight( B, i);
		else if ( Conditionals[i] == "ENEMYNOSIGHT" )
			fStrategies[i] = ConditionEnemyNoSight( B, i);
		else if ( Conditionals[i] == "NOENEMY" )
			fStrategies[i] = 1.0 * int( B.Enemy == none );
		else if ( Conditionals[i] == "TODIST" )
			fstrategies[i] = ConditionToDist( B, i);
		else if ( Conditionals[i] == "RUNAWAY" )
			fStrategies[i] = ConditionRunningAway( B, i);
		else if ( Conditionals[i] == "ENEMYTOOCLOSE" )
			fStrategies[i] = ConditionEnemyTooClose( B, i);
		else if ( Conditionals[i] == "" )
			break;

//		Log("EVAL: "$Strategies[i]$"; RATING "$fStrategies[i]);
		i++;
	}

	while( i >= 0)
	{
		if ( BestStra[0] < fStrategies[i] )
		{
			bestFire = i;
			BestStra[0] = fStrategies[i];
		}
		--i;
	}
	if ( BestStra[0] <= B.DistractionLimit )
		return false;

	BestCombat = Strategies[bestFire];
	BestStra[0] = StraA[bestFire];
	BestStra[1] = StraB[bestFire];
	bestFire = FireMode[bestFire];
	
	DONT_CHECK:
	if ( BestCombat == "" )
	{
		//Change weapon or set weariness...
		B.CombatWeariness = -3;
		B.CurrentTactic = "";
		if ( FRand() < 0.1 )
			B.SwitchToBestWeapon();
		if ( B.IsInState('CombatState') )
			B.ResumeSaved();
		return false;
	}

	//Shared parameters
	B.MoveAgain = 0;
	B.CombatParamA = BestStra[0];
	B.CombatParamB = BestStra[1];
	B.ChargeFireTimer = 0;
	B.ExecuteAgain = 0;

	if ( BestCombat == "DISABLENORMAL" )
	{
		B.CurrentTactic = "DISABLENORMAL";
		SetFixedFire( B, bestFire);
		B.TacticExpiration = fMin(0.1,BestStra[0]);
		return false;
	}
	else if ( BestCombat == "CHARGE" )
	{
		B.ExecuteAgain = 2 + FRand();
		B.CurrentTactic = "CHARGE";
		B.GotoState('CombatState','Charge');
		return true;
	}
	else if ( BestCombat == "HOLDBUTTON" ) //Do nothing, set a timer to reset tactic
	{
		B.CurrentTactic = "HOLDBUTTON";
		if ( B.Accumulator > 0 )
			SetFixedFire( B, bestFire);
		B.TacticExpiration = 20; //Hold charged fire for a long time, tactic expires upon enemy sight anyways
		return false;
	}
	else if ( BestCombat == "LURE" )
	{
		B.ExecuteAgain = 3 + FRand();
		B.CurrentTactic = "LURE";
		B.Accumulator = 2;
		B.ChargeFireTimer = 2;
		B.GotoState('CombatState','Lure');
		return true;
	}
	else if ( BestCombat == "COMBO" )
	{
		B.ExecuteAgain = 5;
		B.Accumulator = 0.8;
		B.CurrentTactic = "COMBO";
		if ( VSize(Normal( B.Velocity) - Normal( B.Enemy.Location - B.Location)) < (0.1 + B.Skill*0.08) )
		{
//			return false; //Combo to be executed during forward run
		}
		Log("Combo selected: "$int(VSize(B.Location-B.Enemy.Location)) );
		B.GotoState('CombatState','Combo');
		return true;
	}

	B.CurrentTactic = "";
	return false;
}


//********************************************************************************
//******************************** WEAPON FIRE ***********************************
function SuggestFire( Botz B, string MyTactic)
{
	local int i, bestFire;

	if ( MyTactic == "" )
	{
		B.bFire = 0;
		B.bAltFire = 0;
		B.ChargeFireTimer = 0;
		return;
	}
	else
	{
		for ( i=0 ; (i<8)&&(Strategies[i]!="") ; i++ )
		{
			if ( MyTactic == Strategies[i] )
			{
				bestFire = FireMode[i];
				Goto SUCCESS;
			}
		}
	}
	return;
	
	SUCCESS:
	if ( MyTactic == "DISABLENORMAL" )
	{
		SetFixedFire( B, bestFire);
		B.Accumulator = 0.1;
		return;
	}
	else if ( MyTactic == "HOLDBUTTON" )
	{
//		Log("HOLDBUTTON SUGGESTED FIRE");
		SetFixedFire( B, bestFire);
		return;
	}
	else if ( MyTactic == "CHARGE" )
	{
		//HACK FIX, REMOVE LATER IN FAVOR OF AIM SYSTEM
		SetFixedFire( B, bestFire, true);
/*		if ( (B.bFire == 0) && B.CanSee(B.Enemy) )
		{
			B.bFire = 1;
			B.Weapon.Fire( 1);
		}*/
		return;
	}
	else if ( MyTactic == "LURE" )
	{
		B.ChargeFireTimer = 2;
		B.Accumulator = 2;
		SetFixedFire( B, bestFire);
		return;
	}

	B.ChargeFireTimer = 0;
	B.Accumulator = 0;
}

//Sets fixed fire mode; subclass here if you want to customize fire choice
function SetFixedFire( Botz B, byte UMode, optional bool bNoLog)
{
	local bool bHadFire;

	if ( UMode >= 6 )
	{
		FireControl( B, UMode);
		return;
	}
	
	if ( CustomizeFire(B) )
		return;
	
	bHadFire = B.bFire > 0;

	B.bFire = 0;
	B.bAltFire = 0;

	if ( UMode == 0)
		B.bFire = 1;
	else if ( UMode == 1 )
		B.bAltFire = 1;
	else if ( UMode == 2 )
	{
		B.bFire = 1;
		B.bAltFire = 1;
	}
	else if ( UMode == 3 )
	{
		if ( Rand(2) == 0 )
			B.bFire = 1;
		else
			B.bAltFire = 1;
	}
	else if ( UMode == 4 )
	{
		if ( FRand() < AltChance[ GetDistanceMode(B) ] )
		{
			B.bAltFire = 1;
			B.bFire = 0;
		}
		else
		{
			B.bFire = 1;
			B.bAltFire = 0;
		}
	}

	if ( !bHadFire && B.bFire == 1 )
		B.Weapon.Fire( 1);
	else if ( B.bAltFire == 1 )
		B.Weapon.AltFire( 1);

	if ( !bNoLog && B.DebugMode )
		Log("FIXED FIRE: "$B.bFire$", "$B.bAltFire$" with UMODE="$UMode);
}

function bool SetupCombo( Botz B)
{
	local Projectile P, aP;
	local vector aVec, Dir;
	local int i;
	local class<Projectile> cP;
	local rotator OldView;

	aVec = ProjectileAim( B, B.Enemy, ProjAltSpeed) + VRand() * B.Enemy.CollisionRadius;
	if ( !B.FastTrace( aVec) || !B.Enemy.FastTrace( aVec) )
	{
		//Second chance!
		i = B.Skill;
		while ( i-- > 0 )
		{
			aVec = VSize(B.Location - B.Enemy.Location) * 0.3 * (VRand() * vect(1,1,0.3) + B.Enemy.Velocity * FRand() * 2 );
			if ( B.FastTrace(aVec) && B.Enemy.FastTrace( aVec) )
				Goto BYPASS;
		}

		return false;
	}
	
BYPASS:
	
	//Wait till ready to aim?
	Dir = Normal( aVec-B.Location);

	cP = B.Weapon.AltProjectileClass;
	if ( (cP != None) && (VSize(B.Location - B.Enemy.Location) < 250) )
		return false;
	
	if ( (cP != None) && (B.Skill > 0.5) )
	{
		ForEach B.CollidingActors( class'Projectile', aP, 50*B.Skill, B.Location+Dir*(50*B.Skill) )
			if ( (aP.Instigator == B) && ClassIsChildOf(aP.Class, cP) && (Normal( aP.Velocity) dot Dir > 0.8) )
			{
				P = aP;
				break;
			}
	}

	if ( P == None )
	{
		OldView = B.ViewRotation;
		B.ViewRotation = rotator( Dir);
		B.Weapon.AltFire( 1);
		P = B.MyMutator.BPS.GetProj(0);
		if ( (P == None) || (P.Instigator != self) )
			return false;
	}

	P.Target = B.Enemy;
	B.AimPoint.PointTarget = B;
	B.AimPoint.AimOther = P;
	B.bFire = 0;
	B.bAltFire = 0;
	Log("COMBO STARTED: "$P);
	return true;
}

function vector ProjectileAim( Botz B, actor Other, float pSpeed)
{
	local vector Result;
	local float fTries , TimeT;
	local int i;

	fTries = (B.Skill + B.TacticalAbility + B.Aggresiveness) * 0.2;
	TimeT = VSize(B.Location - Other.Location) / pSpeed;

	//No pude resolver esa ecuacion, asi que me acerco mediante una canariada al result
	For ( i=fTries ; i>=0 ; i--) //Iterar 5 veces, tomar en cuenta la velocidad Z
	{
		Result = Other.Location + (B.Velocity * TimeT);
		fTries = VSize( Result - B.Location) / pSpeed;
		TimeT = (TimeT + fTries) * 0.5;
	}
	return Result;
}

static function int GetDistanceMode( Botz B)
{
	local float Dist;
	
	if ( B.Enemy == none )
		return 1 + B.AttackDistance;
	
	Dist = VSize( B.Location - B.Enemy.Location);
	if ( Dist < 95 )
		return 0;
	else if ( Dist < 250 )
		return 1;
	else if ( Dist < 550 )
		return 2;
	else if ( Dist < 1200 )
		return 3;
	return 4;
}

//Called during HOLDBUTTON
function bool ShouldReleaseOnSight( Botz B, Actor Other)
{
	return ( B.AimPoint.SightTimer > 0.1 );
}

defaultproperties
{
	WeaponClass=Class'Engine.Weapon'
	bAutoDetect=True
	bInstantFire=True
	ProjPhysics=6
	ProjAltPhysics=6
	DegreeError=0
	PointBlankAdv=1
	CloseRangeAdv=1
	MidRangeAdv=1
	DistantAdv=1
	FarAdv=1
	SameHeightAdv=1
	LowAdv=1
	HighAdv=1
	AmpedAdv=1
	WaterAdv=1
}