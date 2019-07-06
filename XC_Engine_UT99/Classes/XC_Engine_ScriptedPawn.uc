class XC_Engine_ScriptedPawn expands ScriptedPawn
	abstract;

const SP = class'XC_Engine_ScriptedPawn';
	
var bool bAttitudeQuery;

function Pawn Pawn_PickTarget(out float bestAim, out float bestDist, vector FireDir, vector projStart)
{
	local Pawn P, Best;
	local vector Delta;
	local float Aim, Dist;
	
	ForEach PawnActors( class'Pawn', P, 2000, projStart)
	{
		if ( (P != self) && (P.Health > 0) && P.bProjTarget )
		{
			if ( (PlayerReplicationInfo == None)
				|| (P.PlayerReplicationInfo == None)
				|| (Level.Game.bTeamGame && PlayerReplicationInfo.Team != P.PlayerReplicationInfo.Team) )
			{
				//Additional reject for players
				if ( bIsPlayer && (PlayerReplicationInfo != None) )
				{
					if ( ScriptedPawn(P) != None )
					{
						if ( ScriptedPawn(P).AttitudeToPlayer == ATTITUDE_Friendly )
							continue;
					}
					else if ( StationaryPawn(P) != None )
					{
						if ( StationaryPawn(P).SameTeamAs(PlayerReplicationInfo.Team) )
							continue;
					}
				}
				Delta = P.Location - projStart;
				Aim = Delta dot FireDir;
				if ( Aim > 0 )
				{
					Dist = VSize(Delta);
					Aim /= Dist;
					if ( (Aim > bestAim) && LineOfSightTo(P) )
					{
						Best = P;
						bestAim = Aim;
						bestDist = Dist;
					}
				}
				
			}
		}
	}
	return Best;
}




function Gasbag_PlayRangedAttack()
{
	local vector adjust;

	if ( Target != None )
	{
		adjust.Z = Target.CollisionHeight + 20;
		Acceleration = AccelRate * Normal(Target.Location - Location + adjust);
		if ( HasAnim('Belch') )
			PlayAnim('Belch');
	}
}


function SpawnRightShot();
function Brute_PlayRangedAttack()
{
	//FIXME - if going to ranged attack need to
	//	TweenAnim('StillFire', 0.2);
	//What I need is a tween into time for the PlayAnim()
	// Ns >> What you need is a poke in eye. It is called Sanitizer or Wrapper
	if ( Target != None ) //Maybe...
	{
		if ( (AnimSequence == 'T8') || (VSize(Target.Location - Location) > 230) ) 
		{
			SpawnRightShot(); //Virtual function call, legal as long as target function isn't 'Final'
			if ( HasAnim('StillFire') )
				PlayAnim('StillFire');
		}
		else if ( HasAnim('GutShot') )
			PlayAnim('GutShot');
	}
}



function bool TestDirection( vector dir, out vector pick);
function NaliRabbit_PickDestination()
{
	local vector pick, pickdir, enemyDir;
	local bool success;
	local float XY;

	if ( Enemy != None )
		enemyDir = Enemy.Location - Location;
	pickDir = VRand();
	pickDir.Z = 0;
	if ( (pickDir Dot enemyDir) > 0 )
		pickDir *= -1;
	success = TestDirection(pickdir, pick); //Virtual function call, legal as long as target function isn't 'Final'
	if (!success)
	{
		pickDir = VRand();
		pickDir.Z = 0;
		if ( (pickDir Dot enemyDir) > 0 )
			pickDir *= -1;
		success = TestDirection( pickDir, pick); //Virtual function call, legal as long as target function isn't 'Final'
	}
	if (success)
		Destination = pick;
	else
	{
		Destination = Location;
		GotoState('Evade', 'Turn');
	}
}


function SkaarjBerserker_WhatToDoNext(name LikelyState, name LikelyLabel)
{
	local Pawn aPawn;

	ForEach PawnActors( class'Pawn', aPawn, 500)
	{
		if ( !aPawn.bHidden && (aPawn != Self) && aPawn.bCollideActors && (aPawn.DrawType == DT_Mesh) && (aPawn.Mesh != None) && LineOfSightTo(aPawn) )
			if ( SetEnemy(aPawn) )
			{
				GotoState('Attacking');
				return;
			}
	}
	Super(ScriptedPawn).WhatToDoNext( LikelyState, LikelyLabel);
}

//*****************************************************************************************
// AttitudeToCreature ensures that both monsters agree on how to treat each other
// If a pawn wants to treat as friend or follow me, i'll treat as friend as well
function eAttitude AttitudeToCreature( Pawn Other)
{
	local eAttitude Attitude;
	
	if( Other.Class == Class )
		Attitude = ATTITUDE_Friendly;
	else if ( ClassIsChildOf( Other.Class, class'ScriptedPawn')	&& !SP.default.bAttitudeQuery )
	{
		SP.default.bAttitudeQuery = true;
		Attitude = ScriptedPawn(Other).AttitudeToCreature( self);
		SP.default.bAttitudeQuery = false;
		if ( Attitude > ATTITUDE_Friendly )
			Attitude = ATTITUDE_Friendly;
		else if ( Attitude < ATTITUDE_Ignore )
			Attitude = ATTITUDE_Ignore;
	}
	else
		Attitude = ATTITUDE_Ignore;
	return Attitude;
}


function eAttitude AttitudeTo( Pawn Other)
{
	if ( Other.bIsPlayer && (Other.PlayerReplicationInfo != None) )
	{
		if ( bIsPlayer && Level.Game.bTeamGame && (Team == Other.PlayerReplicationInfo.Team) )
			return ATTITUDE_Friendly;
		else if ( (Intelligence > BRAINS_None) && 
			((AttitudeToPlayer == ATTITUDE_Hate) || (AttitudeToPlayer == ATTITUDE_Threaten) 
				|| (AttitudeToPlayer == ATTITUDE_Fear)) ) //check if afraid 
		{
			if (RelativeStrength(Other) > Aggressiveness)
				AttitudeToPlayer = AttitudeWithFear();
			else if (AttitudeToPlayer == ATTITUDE_Fear)
				AttitudeToPlayer = ATTITUDE_Hate;
		}
		return AttitudeToPlayer;
	}
	else if ( Hated == Other )
	{
		if (RelativeStrength(Other) >= Aggressiveness)
			return AttitudeWithFear();
		else 
			return ATTITUDE_Hate;
	}
	else if ( (TeamTag != '') && (ScriptedPawn(Other) != None) && (TeamTag == ScriptedPawn(Other).TeamTag) )
		return ATTITUDE_Friendly;
	else	
		return AttitudeToCreature(Other); 
}


function bool SetEnemy( Pawn NewEnemy )
{
	local bool result;
	local eAttitude newAttitude, oldAttitude;
	local bool noOldEnemy;
	local float newStrength;

	if ( (NewEnemy == Self) || (NewEnemy == None) || (NewEnemy.Health <= 0) || Level.bStartup )
		return false;
	if ( !bCanWalk && !bCanFly && !NewEnemy.FootRegion.Zone.bWaterZone )
		return false;
	if ( (NewEnemy.PlayerReplicationInfo == None) && (ScriptedPawn(NewEnemy) == None) )
		return false;
	if ( NewEnemy.PlayerReplicationInfo != None && NewEnemy.PlayerReplicationInfo.bIsSpectator )
		return false;

	noOldEnemy = (Enemy == None);
	result = false;
	newAttitude = AttitudeTo(NewEnemy);
	//log ("Attitude to potential enemy is "$newAttitude);
	if ( !noOldEnemy )
	{
		if (Enemy == NewEnemy)
			return true;
		else if ( NewEnemy.bIsPlayer && (NewEnemy.PlayerReplicationInfo != none) && (AlarmTag != '') )
		{
			OldEnemy = Enemy;
			Enemy = NewEnemy;
			result = true;
		} 
		else if ( newAttitude == ATTITUDE_Friendly )
		{
			if ( bIgnoreFriends )
				return false;
			if ( (NewEnemy.Enemy != None) && (NewEnemy.Enemy.Health > 0) && (NewEnemy.Enemy != self) ) 
			{
				if ( NewEnemy.Enemy.bIsPlayer && (NewEnemy.Enemy.PlayerReplicationInfo != None) && (NewEnemy.AttitudeToPlayer < AttitudeToPlayer) )
					AttitudeToPlayer = NewEnemy.AttitudeToPlayer;
				if ( AttitudeTo(NewEnemy.Enemy) < AttitudeTo(Enemy) )
				{
					OldEnemy = Enemy;
					Enemy = NewEnemy.Enemy;
					result = true;
				}
			}
		}
		else 
		{
			oldAttitude = AttitudeTo(Enemy);
			if ( (newAttitude < oldAttitude) || 
				( (newAttitude == oldAttitude) 
					&& ((VSize(NewEnemy.Location - Location) < VSize(Enemy.Location - Location)) 
						|| !LineOfSightTo(Enemy)) ) ) 
			{
				if ( bIsPlayer && Enemy.IsA('PlayerPawn') && !NewEnemy.IsA('PlayerPawn') ) //THIS CODE IS FOR OLD v200 BOT!!!!
				{
					newStrength = relativeStrength(NewEnemy);
					if ( (newStrength < 0.2) && (relativeStrength(Enemy) < FMin(0, newStrength))  
						&& (IsInState('Hunting')) && (Level.TimeSeconds - HuntStartTime < 5) )
						result = false;
					else
					{
						result = true;
						OldEnemy = Enemy;
						Enemy = NewEnemy;
					}
				} 
				else
				{
					result = true;
					OldEnemy = Enemy;
					Enemy = NewEnemy;
				}
			}
		}
	}
	else if ( newAttitude < ATTITUDE_Ignore )
	{
		result = true;
		Enemy = NewEnemy;
	}
	else if ( newAttitude == ATTITUDE_Friendly ) //your enemy is my enemy
	{
		//log("noticed a friend");
		if ( NewEnemy.bIsPlayer && (NewEnemy.PlayerReplicationInfo != None) && (AlarmTag != '') )
		{
			Enemy = NewEnemy;
			result = true;
		} 
		if (bIgnoreFriends)
			return false;

		if ( (NewEnemy.Enemy != None) && (NewEnemy.Enemy.Health > 0) && (NewEnemy.Enemy != self) ) 
		{
			result = true;
			//log("his enemy is my enemy");
			Enemy = NewEnemy.Enemy;
			if ( Enemy.bIsPlayer && (Enemy.PlayerReplicationInfo != None) )
				AttitudeToPlayer = ScriptedPawn(NewEnemy).AttitudeToPlayer;
			else if ( (ScriptedPawn(NewEnemy) != None) && (ScriptedPawn(NewEnemy).Hated == Enemy) )
				Hated = Enemy;
		}
	}

	if ( result )
	{
		//log(class$" has new enemy - "$enemy.class);
		LastSeenPos = Enemy.Location;
		LastSeeingPos = Location;
		EnemyAcquired();
		if ( !bFirstHatePlayer && Enemy.bIsPlayer && (FirstHatePlayerEvent != '') )
			TriggerFirstHate();
	}
	else if ( NewEnemy.bIsPlayer && (NewAttitude < ATTITUDE_Threaten) )
		OldEnemy = NewEnemy;
				
	return result;
}


function bool ScriptedPawn_MeleeDamageTarget(int hitdamage, vector pushdir)
{
	local vector HitLocation, HitNormal, TargetPoint;
	local actor HitActor;

	if ( Target == None && ( Enemy != None  && Enemy.Health > 0 ) )
		Target = Enemy;
	if ( Target != None )
	{
		if ( (VSize(Target.Location - Location) <= MeleeRange * 1.4 + Target.CollisionRadius + CollisionRadius)
			&& ((Physics == PHYS_Flying) || (Physics == PHYS_Swimming) || (Abs(Location.Z - Target.Location.Z) 
				<= FMax(CollisionHeight, Target.CollisionHeight) + 0.5 * FMin(CollisionHeight, Target.CollisionHeight))) )
		{
			HitActor = Trace(HitLocation, HitNormal, Target.Location, Location, false);
			if ( HitActor != None )
				return false;
			Target.TakeDamage(hitdamage, Self,HitLocation, pushdir, 'hacked');
			return true;
		}
	}
	return false;
}

function ScriptedPawn_StartRoaming()
{
	local float oldestRoamTime;
	local ScriptedPawn oldestRoamer, SP;
	local int numRoamers;

	RoamStartTime = Level.TimeSeconds;
	oldestRoamTime = RoamStartTime;

	ForEach PawnActors( class'ScriptedPawn', SP)
		if ( !SP.bIsPlayer && (SP.IsInState('Roaming') || SP.IsInState('Wandering')) )
		{
			numRoamers++;
			if ( (SP.RoamStartTime < oldestRoamTime) || (oldestRoamer == None) )
			{
				oldestRoamer = SP;
				oldestRoamTime = SP.RoamStartTime;
			}
		}

	if ( numRoamers > 100 )
		oldestRoamer.GotoState('Waiting', 'TurnFromWall');
	OrderObject = None;
	OrderTag = '';
	GotoState('Roaming');
}

function StartUp_SetHome()
{
	local HomeBase aHome;

	ForEach NavigationActors( class'HomeBase', aHome)
		if ( aHome.Tag == Tag )
		{
			home = aHome;
			return;
		}
}
