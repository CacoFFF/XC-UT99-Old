//=============================================================================
// BotzTTarget
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BotzTTarget expands TranslocatorTarget;

var bool bMoveAdjust;
var bool bTeleImpact;
var bool bAvoidErase; //Used to avoid deletion, for now, associate with ImpactLaunch
var bool bImpactLaunch;
var actor PostTarget;

function Throw(Pawn Thrower, float force, vector StartPosition)
{
	local vector dir;
	local float TheForce, hForce;
	local int i;

	if ( DesiredTarget != none )
	{
		if ( (Normal(DesiredTarget.Location - Location).Z > 0.4) || !FastTrace(DesiredTarget.Location) )
			dir = class'BotzFunctionManager'.static.ThrowAt( StartPosition, DesiredTarget.Location + vect(0,0,20), Region.Zone.ZoneGravity.Z, force * 1.05);
		else
			dir = class'BotzFunctionManager'.static.ThrowAt( StartPosition, DesiredTarget.Location, Region.Zone.ZoneGravity.Z, force * 1.05);
		if ( dir != vect(0,0,0) )
		{
			velocity = dir;
			bBounce = true;
			DropFrom( StartPosition);
			return;
		}
		
		dir = DesiredTarget.Location - Location;
		TheForce = VSize(Dir) * 0.2; //Distance can easily reach 800, 2000 on gravity zones; so Force is around 160 and 400 respectively
		hForce = Region.Zone.ZoneGravity.Z / -950.0; //Should be normalized to 1 on normal cases
		TheForce = TheForce * hForce + 15; //Add an extra 15 points
		if ( (VSize(Dir) * hForce ) > 200 ) //Medium distance, increase on 40
			TheForce += 40;
		if ( (VSize(Dir) * hForce ) > 330 ) //Medium-far distance, increase on 80
			TheForce += 80;
		if ( (VSize(Dir) * hForce ) > 700 ) //Distance is large, increase on 200
			TheForce += 200;
		if ( (VSize(Dir) * hForce ) > 1000 ) //Distance is huge, increase on 200
			TheForce += 200;
		dir.Z += TheForce;

		if ( Master.Owner.IsInState('TranslocationChain') || DesiredTarget.bIsPawn ) //Don' fire too much above
			dir += DesiredTarget.Location - Location;

		Velocity = force * Normal(dir) * 1.05; //Set normal throw velocity
		if ( Velocity.Z > 0 )
			Velocity.Z += 6;
		if ( Velocity.Z > force * 0.7 )
			velocity.Z += 10;

		SetCollisionSize(0,0);
		bBounce = true;
		DropFrom(StartPosition);
		return;
	}


	dir = vector(Thrower.ViewRotation);

	Velocity = force * dir + vect(0,0,200);

	dir.Z = dir.Z + 0.35 * (1 - Abs(dir.Z));
	Velocity = FMin(force,  Master.MaxTossForce) * Normal(dir);
	if ( Velocity.Z > 0)
		Velocity .Z += Region.Zone.ZoneGravity.Z / (-50);

	SetCollisionSize(0,0);
	if ( DesiredTarget != none )
		Velocity = class'BotzFunctionManager'.static.AdvancedJump( Location, DesiredTarget.Location, Region.Zone.ZoneGravity.Z, Velocity.Z, 2500, true);

	bBounce = true;
	DropFrom(StartPosition);
}

////////////////////////////////////////////////////////
auto state Pickup
{
	simulated event Landed( vector HitNormal )
	{
		local rotator newRot;

		if ( Master == None || Master.Owner == None )
			return;
		if ( Master.TTarget == None )
			Master.TTarget = self;
		
		if ( bAvoidErase && bImpactLaunch && ( Role == ROLE_Authority ) )
		{
			if ( Master.Owner.IsA('BotZ') )
			{
				BotZ(Master.Owner).SpecialMoveTarget = PostTarget;
				BotZ(Master.Owner).MoveTimer = -1;
				BotZ(Master.Owner).MoveTarget = none;
			}
			else
				Pawn(Master.Owner).MoveTarget = PostTarget;
			Master.Translocate();
			return;
		}

		if ( bTeleImpact && ( Role == ROLE_Authority ) && (DesiredTarget != none) && !DesiredTarget.IsA('Pawn') && (Region.Zone.DamagePerSec <= 0) && FastTrace(DesiredTarget.Location) )
		{
			if ( Master.Owner.IsA('BotZ') )
			{
				BotZ(Master.Owner).SpecialMoveTarget = PostTarget;
				BotZ(Master.Owner).MoveTarget = none;
				BotZ(Master.Owner).MoveTimer = -1;
			}
			else
				Pawn(Master.Owner).MoveTarget = PostTarget;
			Master.Translocate();
			return;
		}
//		SetTimer(2.5, false);
		newRot = Rotation;
		newRot.Pitch = 0;
		newRot.Roll = 0;
		SetRotation(newRot);
		PlayAnim('Open',0.1);
		if ( Role == ROLE_Authority )
		{
			RemoteRole = ROLE_DumbProxy;
			RealLocation = Location;
			if ( Master.Owner.IsA('BotZ') )
			{
//				if ( Pawn(Master.Owner).Weapon == Master )
//					BotZ(Master.Owner).SwitchToBestWeapon();
				LifeSpan = 6;
			}
			Disable('Tick');
		}
	}		

	singular function Touch( Actor Other )
	{
		local bool bMasterTouch;
		local vector NewPos;

		if ( !Other.bIsPawn )
		{
			if ( (Physics == PHYS_Falling) && !Other.IsA('Inventory') && !Other.IsA('Triggers') && !Other.IsA('NavigationPoint') && !Other.IsA('TranslocatorTarget') && !Other.IsA('InfoPoint') )
				HitWall(-1 * Normal(Velocity), Other);
			return;
		}
		bMasterTouch = ( Other == Instigator );
		
		if ( Physics == PHYS_None )
		{
			if ( bMasterTouch )
			{
				PlaySound(Sound'Botpack.Pickups.AmmoPick',,2.0);
				Master.TTarget = None;
				Master.bTTargetOut = false;
				if ( Other.IsA('PlayerPawn') )
					PlayerPawn(Other).ClientWeaponEvent('TouchTarget');
				destroy();
			}
			return;
		}
		if ( bMasterTouch ) 
			return;

		if ( Level.Game.bTeamGame
			&& (Instigator.PlayerReplicationInfo.Team == Pawn(Other).PlayerReplicationInfo.Team) )
			return;

		NewPos = Other.Location;
		NewPos.Z = Location.Z;
		SetLocation(NewPos);
		Velocity = vect(0,0,0);

	}

	simulated function Tick(float DeltaTime)
	{
		if ( Level.bHighDetailMode && (Shadow == None)
			&& (PlayerPawn(Instigator) != None) && (ViewPort(PlayerPawn(Instigator).Player) != None) )
			Shadow = spawn(class'TargetShadow',self,,,rot(16384,0,0));


		if ( Role != ROLE_Authority )
		{
			Disable('Tick');
			return;
		}


		if ( (DesiredTarget == None) || (Master == None) || (Master.Owner == None) )
		{
//			Disable('Tick');
			return;
		}

		//If tickrate == 20, added delta size = 7
		//If Zspeed < 30, added hsize = 20
		if ( (VSize( Location - DesiredTarget.Location) < (20 + 150 * int(bImpactLaunch)  + DeltaTime * 140 ))
		 || (HSize(Location - DesiredTarget.Location) < (Master.Owner.CollisionRadius + 20 * float(bImpactLaunch) + 20 * float(abs(velocity.z) < 45) ) ))
		{
			if ( VSize( Location - DesiredTarget.Location) > 200 )//Just in case
				return; 
			if ( !FastTrace(DesiredTarget.Location) )
				return;	

			Pawn(Master.Owner).StopWaiting();
			Pawn(Master.Owner).MoveTimer = -1;
			Pawn(Master.Owner).Acceleration = vect(0,0,0);
			if ( Master.Owner.IsA('BotZ') )
			{
				BotZ(Master.Owner).SpecialMoveTarget = PostTarget;
				BotZ(Master.Owner).MoveTarget = none;
				if ( bImpactLaunch )
					Botz(Master.Owner).LastTranslocCounter = 0.3;
			}
			else
				Pawn(Master.Owner).MoveTarget = PostTarget;
			if ( Master.TTarget == None )
				Master.TTarget = self;
			Master.Translocate();
			Disable('Tick');
		}
//		if ( (DesiredTarget != none) && bMoveAdjust)
//			Velocity = class'BotzFunctionManager'.static.AdvancedJump( Location, DesiredTarget.Location, Region.Zone.ZoneGravity.Z, Velocity.Z, 2500);

	}

	simulated function HitWall (vector HitNormal, actor Wall)
	{
		if ( bAlreadyHit )
		{
			bBounce = false;
			return;
		}
		bAlreadyHit = ( HitNormal.Z > 0.7 );
		PlaySound(ImpactSound, SLOT_Misc);	  // hit wall sound
		Velocity = 0.3*(( Velocity dot HitNormal ) * HitNormal * (-2.0) + Velocity);   // Reflect off Wall w/damping
		speed = VSize(Velocity);
		
		if ( (Master != None) && (Botz(Master.Owner) != none) && (Master.Owner.IsInState('TranslocationChain') ) )
			Botz(Master.Owner).QueHacerAhora();
	}

	function EndState()
	{
		DesiredTarget = None;

	}
}

simulated function Destroyed()
{
	Super.Destroyed();

	if ( Master != none )
	{
		Master.TTarget = none; //Hard reset
		if ( Botz(Master.Owner) != none )
		{
			Botz(Master.Owner).bAirTransloc = false;
			Botz(Master.Owner).bPendingTransloc = false;
		}
	}
}

simulated function float HSize( vector tested)
{
	tested.z = 0;
	return VSize( tested);
}


defaultproperties
{
}
