//=============================================================================
// AimOffsetPoint. 
// Punto movible que simula Monstruosamente la vista humana
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================

class AimOffsetPoint expands InfoPoint;

var() float LifeTime;

var float	LastSeenTime;	//Apuntar hacia donde se fue algun enemigo
var float	SniperCounter;	//Apuntar un tiempo (depende de habilidad) antes de disparar (en bAimAtPoint)
var float	SightTimer;	//Tiempo desde q enemigo fue detectado
var pawn 	PointTarget;	//Usado para notificar al bot y relocalizarse
var pawn	AimGuy;			//Desgraciado al que el bot le esta apuntando
var actor	AimOther;		//Apuntar aqui si bAimAtPoint = true
var vector 	TargetOffset;	//Error en la vista, modificado por la punteria
var vector	TrackVector;
var vector	AdjustedTrack;	//Reseteado cada (2-0.4)sec con extension de (5-70): La Punteria
var vector	PointSpot;		//Punto de Point-Target en bAimAtPoint
var vector	CurrentPoint;	//FUTURO: Movimiento humano de la mira al mirar otro objeto

var bool DebugRotate;
var rotator RealBotRotation;//Sistema pensado para bots de HL de los que no pude lograr

var bool	bSafeShot;		//FUTURO: Disparar con metralletas aun adquiriando enemigo
var bool	bComboPaused;	//Esperar la bola de plasma para Liquidar al enemigo
var bool	bCanShoot;		//Para saber si debo disparar, o hacer combos y otras cosas
var bool	bAimAtPoint;	//Botz apuntando por razones especiales (sniper de larga distancia)
var bool	bProcessExtra;	//Enemigo es procesado despues de mi, apuntar con un tick de antelacion
var bool	bCalcObstructed;	//Mira calculada obstruida

event PostBeginPlay()
{
	SetTimer(0.55, True);
}

event Timer()
{
	TargetOffset = VRand();
}

function CheckEnemy()
{
	if (BotZ(Owner).Enemy == none && !bAimAtPoint)
	{
		PointTarget = none;
		AimGuy = none;
		return;
	}

	if ( (Botz(Owner).Enemy != none) && (BotZ(Owner).LineOfSightTo( BotZ(Owner).Enemy) || Owner.FastTrace(BotZ(Owner).Enemy.Location) ) )
	{
		PointTarget = BotZ(Owner).Enemy;
		LastSeenTime = Level.TimeSeconds;
		AimGuy = none;
		return;
	}

	if ( bAimAtPoint )
	{
		PointTarget = Botz(Owner);
		return;
	}

	if ( (Botz(Owner).Enemy != none ) && (Level.TimeSeconds - 4 > LastSeenTime) && (SniperWeapon(Botz(Owner)) ) ) //Fix for sniping
	{
		Botz(Owner).Enemy = none;
		return;
	}

	if (Level.TimeSeconds - 2 > LastSeenTime)
	{
		PointTarget = none;
		return;
	}



}

final function FLOAT ParaNormal(float TotalPerc, float Valor)
{
	if (Valor > TotalPerc)
		Valor = TotalPerc;

	return (Valor / TotalPerc);
}

function float CalculateHeight()
{
	local Botz B;
	local float Error;
	local vector Start;

	B = Botz(Owner);
	if (B.Weapon == none)
		return 0;

	Start = Location;
	Start.Z += Pawn(Owner).BaseEyeHeight * 0.8;

	Error = ParaNormal(49152, abs(B.ViewRotation.Pitch) ) * 70; //Error feo del rifle de UT
	if ( Pawn(Owner).BaseEyeHeight == 0 ) //Crouching
		Error -= 25;

	if (B.Weapon.IsA('Rifle') || B.Weapon.IsA('RazorJack') )
		return (PointTarget.CollisionHeight * 0.9);
	else if (B.Weapon.IsA('SniperRifle'))
		return ((PointTarget.CollisionHeight * 0.9) - Error);

	if ( B.Weapon.IsA('UT_EightBall') || B.Weapon.IsA('EightBall') )
	{
		Error = fMin( 60, PointTarget.CollisionHeight*0.9);
		if ( FastTrace( PointTarget.Location - vect(0,0,1)*Error, Start) )
			return (ParaNormal(4, B.Skill) * Error) * -1.0;
	}

	if ( B.Weapon.IsA('Ripper') )
	{
		if (B.bFire == 1)
			return (ParaNormal(4, B.Skill) * PointTarget.CollisionHeight);
		else
			return (ParaNormal(4, B.Skill) * PointTarget.CollisionHeight * -0.8);
	}

	if ( B.Weapon.IsA('UT_Biorifle') )
		return VSize( B.Location - PointTarget.Location) * 0.2 - 30;

	return 0.0;
}

function BOOL SniperWeapon( Pawn Other)
{
	local int i;

	if ( Other.Weapon == none )
		return False;

	if ( Botz(Owner).MyMutator == none )
		return False;

	For ( i=0 ; i<24 ; i++ )
		if ( Botz(Owner).MyMutator.MasterG.SniperWeapons[i] == Other.Weapon.Class )
			return True;
	if ( Other.Weapon.IsA('SniperRifle') || Other.Weapon.IsA('Rifle') )
		return True;	//Default
	return False;
}

function FireAway( vector FireAt, optional float fEyeOffset)
{
	local rotator TheRotator;
	local vector EyeOffset;
	if ( Botz(Owner).Weapon == none )
		return;
	if ( fEyeOffset == 0)
		EyeOffset.Z = Botz(Owner).EyeHeight;
	else
		EyeOffset.Z = fEyeOffset;
	if ( Botz(Owner).Weapon.IsA('SniperRifle') )
		FireAt.Z -= ParaNormal(49152, abs(Botz(Owner).ViewRotation.Pitch) ) * 70; //Error feo del rifle de UT
	TheRotator = rotator(FireAt - (Owner.Location + EyeOffset) );

	Botz(Owner).bFire = 1;
	Botz(Owner).bAltFire = 0;
	Botz(Owner).Weapon.Fire(1.0);
	Botz(Owner).bFire = 0;
}

event Tick(float Delta)
{
	local float DistanceFactor;
	local float WeaponFactor;
	local vector Normality;
	local vector Vectus;
	local rotator TheRot;
	local vector Vectality;
	local bool bSuccess;

	if (Delta == 0.0)	//Debug calls
	{
		if ( PointTarget != none ) 	//Apuntar antes de disparar
		return; //Llamado por Tick() del botz antes de disparar
	}

	if ( (AimOther != None) && AimOther.bDeleteMe )
		AimOther = None;
	
	//Freeze timer, weapon profile related
	if ( Botz(Owner).bKeepEnemy )
		LastSeenTime += Delta;

	CheckEnemy();
	Owner.Target = PointTarget;
	if ( Owner.Target == none )
		Owner.Target = Owner;
	if (PointTarget == none)
	{
		SetLocation(Owner.Location);
		SightTimer = 0;
		return;
	}

	if ( PointTarget == Botz(Owner) )
	{
		if ( (AimGuy != none) && (AimGuy.Health > 0) )
		{
			Vectality = Owner.Location + vect(0,0,1) * Botz(Owner).EyeHeight;
			SniperCounter -= Delta / (1 + VSize(AimGuy.Velocity) / 250) ;
			Vectus.Z = AimGuy.CollisionHeight + 2;
			bSuccess = False;
			While ( Vectus.Z > (AimGuy.CollisionHeight * -1) )
			{
				Vectus.Z -= Max(7, AimGuy.CollisionHeight / 10);
				if (FastTrace(Vectality, AimGuy.Location + Vectus ) )
				{
					bSuccess = True;
					break;
				}
			}
			Vectus.Z -= 30;
			SetLocation( AimGuy.Location + Vectus);
			if (!bSuccess || !SniperWeapon(Botz(Owner)) )
				bAimAtPoint = False;
			if ( SniperCounter <= 0 )
			{
				TargetOffset = vect(0,0,0);
				FireAway(AimGuy.Location + Vectus);
				Botz(Owner).SetEnemy( AimGuy);
			}
			return;
		}
		else if ( AimOther != none )
		{
			vectus = AimOther.Location - vect(0,0,1) * BotZ(Owner).BaseEyeHeight;
			if ( AimOther.IsA('TranslocatorTarget') )
				vectus.z += 15;
			SetLocation( vectus );
			return;
		}
		AimGuy = none;
		SetLocation( PointSpot);
		return;
	}


//HACK FOR ROTATION FIX
	if ( true )
	{
		Pawn(Owner).FaceTarget = self;
		Pawn(Owner).Focus = Location;
		Pawn(Owner).DesiredRotation = rotator(Location - Owner.Location);
	}

	//Don't move if lost target, fire just in case...
	if ( Level.TimeSeconds != LastSeenTime )
	{
		//Instead, stay in sight or reposition to allow view
		if ( Trace( Vectus, Normality, Owner.Location + vect(0,0,1) * Pawn(Owner).EyeHeight) == Level )
		{
			Vectality = Location + Normal( Owner.Location - Location) * 30 + Normality * 32;
			if ( FastTrace( Vectality, Owner.Location) )
				SetLocation( Vectality);
		}
			
		return;
	}

	Vectus.Z = CalculateHeight() - 20;
	SightTimer += Delta * float(PointTarget.Visibility) / 160.0;
	if ( Botz(Owner).Weapon != none)
	{
		if ( (PointTarget.Physics == PHYS_None) && (PointTarget.Base == None || PointTarget.Base.Velocity == vect(0,0,0)) )
		{}
		else if ( (PointTarget.bTicked != bTicked) || (Botz(Owner).Weapon.bTicked != bTicked) ) //Place myself one tick ahead if enemy is going to be processed, or if weapon was processed already
			Vectus += (PointTarget.Location - PointTarget.OldLocation);
		DistanceFactor = 5 + ( VSize(Owner.Location - PointTarget.Location) / 400);
		WeaponFactor = 20;
		Normality = Normal(Owner.Location - Owner.OldLocation);
		Vectality = BotCalculate( PointTarget, Botz(Owner).Weapon, bool(Botz(Owner).bAltFire), Delta);
		SetLocation(		PointTarget.Location +
								Vectus		+
						TargetOffset * DistanceFactor * (1 + Botz(Owner).Punteria)   +
						Normality * WeaponFactor	+
						Vectality );
		if ( Botz(Owner).SafeAimDist > 0 )
			AdjustToSafeLoc( Botz(Owner).SafeAimDist );
	}
//	return; //THIS RETURN IS A TEST...

	TheRot = Botz(Owner).BFM.ValidateRotation(BotZ(Owner).ViewRotation);
	if (TheRot.Pitch > 4000)
		TheRot.Pitch = 4000;
	else if (TheRot.Pitch < -4000)
		TheRot.Pitch = -4000;

	Owner.SetRotation(TheRot);
}

function AdjustToSafeLoc( float Safe)
{
	local vector HitLocation, HitNormal;
	local float aDist;
	local actor HitActor;

	HitActor = Owner.Trace( HitLocation, HitNormal, Location, Owner.Location + vect(0,0,0.9) * Botz(Owner).EyeHeight );
	if ( (HitLocation == vect(0,0,0)) || (VSize(HitLocation - Owner.Location) > Safe) )
		return;
	if ( HitActor.bIsPawn && Botz(Owner).SetEnemy( Pawn(HitActor), true) )  //KAMIKAZE AGAINST ENEMY!
		return;
		
	Safe = VSize(HitLocation - Owner.Location);
	aDist = VSize(Location - Owner.Location) / Safe;
	if ( (PointTarget != none) && (VSize(PointTarget.Location - HitLocation) < VSize(Owner.Location - HitLocation)) ) //A dangerous shot is very intended
		SetLocation( Location + HitNormal * Safe * aDist * 0.3);
	else
		SetLocation( Location + HitNormal * Safe * aDist * 0.6);

}

function vector BotCalculate( actor TheEnemy, weapon TheWeapon, bool bAlt, float Delta)
{
	local bool bTrace;
	local float Distance;
	local class<Projectile> TheProj;
	local vector Result, RealVelocity;
	local float Scale;
	local float TimeT, newTime;
	local float FixedSpeed;
	local int i;

	if ( (TheWeapon == none) )
		return vect(0,0,0);
	if ( (TheWeapon.AltProjectileClass == none) && bAlt)
		return vect(0,0,0);
	if ( (TheWeapon.ProjectileClass == none) && !bAlt)
		return vect(0,0,0);
	if ( (TheEnemy.Physics == PHYS_None) && (TheEnemy.Base == None || TheEnemy.Base.Velocity == vect(0,0,0)) )
		return vect(0,0,0);

	if (bAlt)
		TheProj = TheWeapon.AltProjectileClass;
	else
		TheProj = TheWeapon.ProjectileClass;

	if ( TheProj.Default.speed <= 20 )
		return vect(0,0,0);

	RealVelocity = (TheEnemy.Location - TheEnemy.OldLocation) / Delta;
	if ( TheEnemy.Base == none)
		RealVelocity.Z *= 0.3;
	Scale = 1;
	Distance = VSize(Owner.Location - TheEnemy.Location);
	FixedSpeed = TheProj.Default.Speed;
	TimeT = Distance / FixedSpeed;
	newTime = TimeT;

	//No pude resolver esa ecuacion, asi que me acerco mediante una canariada al result
	For ( i=4 ; i>=0 ; i--) //Iterar 5 veces, tomar en cuenta la velocidad Z
	{
		Result = TheEnemy.Location + (RealVelocity * TimeT);
		newTime = VSize( Result - Owner.Location) / FixedSpeed;
		TimeT = (TimeT + newTime) * 0.5;
	}

	RealVelocity = Result - TheEnemy.Location; //Saving up space
	bCalcObstructed = false;
	while ( Scale > 0 )
	{
		if ( !FastTrace( TheEnemy.Location + RealVelocity*Scale, Owner.Location + vect(0,0,1) * Pawn(Owner).BaseEyeHeight ) )
		{
			Scale -= 0.04;
			bCalcObstructed = true;
		}
		else
			return RealVelocity*Scale;
	}
	return vect(0,0,0);
}

event Destroyed()
{
	if ( Botz(Owner) != none )
		Botz(Owner).AimPoint = none;
}


defaultproperties
{
     Texture=Texture'Engine.S_Weapon'
     bGameRelevant=True
}
