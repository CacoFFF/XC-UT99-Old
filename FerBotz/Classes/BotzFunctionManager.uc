//=============================================================================
// BotzFunctionManager.
// En vez de incluir todas las funciones en cada entidad que las use, prefiero
// hacer que todas estén en una base general accesable por cualquier 'actor'
// relacionado o no a los botz, esto es útil para reducir lineas innecesarias
// y hacer los scripts más cortos.
// No vendria nada mal pasar unas cuantas cositas a codigo nativo
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BotzFunctionManager expands InfoPoint;

var() class<BotzProjectileStore> defaultBPS;

function Initialize( Botz aBotZ)
{
}

function UnInit()
{
}

//Get a botz's highest rated weapon based on Botz's ThisWeaponOnBest
function Weapon BotzBestWeapon( Botz B)
{
	local float rating;
	local Weapon W;
	local inventory Inv;
	local weapon Best;

	ForEach B.InventoryActorsW( Class'Weapon', W, true)
		B.ThisWeaponOnBest( rating, Best, W );
	return Best;
}

//More expensive function
function Weapon BotzRateWeapons( Botz B, float MinRating, out int RateCount, out int HealthSum)
{
	local float orat, erat;
	local inventory Inv;
	local Weapon Best;

	For ( inv=B.Inventory ; inv!=none ; inv=inv.Inventory )
	{
		if ( Weapon(inv) == none )
		{
			if ( inv.bIsAnArmor)
				HealthSum += inv.Charge;
			continue;
		}

		erat = B.ThisWeaponOnBest( orat, Best, Weapon(inv) );
		if ( erat > MinRating)
			RateCount++;
	}
	return Best;
}


//*******************SafeToDropTo - lower objective is walkable (do Z check first!!)
static function bool SafeToDropTo( Pawn Other, Actor MoveTarget, optional bool bDamageAllowed)
{
	local Actor A;
	local vector Dest, AccumulatedVelocity;
	local float VelocityLimit;
	local int i;
	
	//Need native PointRegion generator!!!
	if ( !MoveTarget.Region.Zone.bWaterZone )
	{
		For ( A=MoveTarget ; (A!=None) && (i++ < 4) ; A=A.Base )
			AccumulatedVelocity += A.Velocity;
		Dest = MoveTarget.Location + AccumulatedVelocity;
			
		//Object going down faster than what player can fall
		if ( (FreeFallVelocity( Dest.Z - Other.Location.Z, Other.Region.Zone.ZoneGravity.Z) > AccumulatedVelocity.Z)
			|| (AccumulatedVelocity.Z >= MoveTarget.Region.Zone.ZoneTerminalVelocity) )
			return false;

		VelocityLimit = Other.Velocity.Z - (750 + Other.JumpZ); //Consider current fall velocity, good for air shortening
		if ( bDamageAllowed )
			VelocityLimit -= Other.Health * 2 / 3;

		//Falling too hard
		if ( FreeFallVelocity( Dest.Z - Other.Location.Z, Other.Region.Zone.ZoneGravity.Z) < VelocityLimit )
			return false;
	}
	return true;
}


//*************SimpleHandleLift - generic lift handling (None = don't handle, just go)
function Actor SimpleHandleLift( Mover Lift, Pawn Other, NavigationPoint CurrentPath)
{
	local Actor A, BestA;
	local vector TargetLoc, V;
	local float F;
	local bool bHeadedToNearest;

	if ( Other.MoveTarget == None )
		return None;
	
	//Find attraction point on top of the lift, can be anything
	A = Lift.MyMarker;
	if ( (Other.MoveTarget.Base != None) && (Other.MoveTarget.Base == Lift || Other.MoveTarget.Base.Base == Lift) )
		A = Other.MoveTarget;
	if ( A != None )	TargetLoc = A.Location;
	else				TargetLoc = Lift.Location + vect(0,0,50);

	//Lift is moving
	if ( Lift.bInterpolating || Lift.bDelaying )
	{
		//And bot is standing in eleveator
		if ( (Other.Base != None) && (Other.Base == Lift || Other.Base.Base == Lift) )
		{
			A = Other.MoveTarget;
			V = Normal(Lift.Velocity);

			if ( (V.Z > 0.7) && (Lift.Velocity.Z > 1) ) //Going up
			{
				if ( Other.Location.Z + Other.CollisionHeight + A.CollisionHeight < A.Location.Z )
					return CurrentPath Or Other; //Target above bot
				if ( HSize(Other.Location - A.Location)/Other.GroundSpeed > (A.Location.Z-Other.Location.Z)/Lift.Velocity.Z )
					return CurrentPath Or Other; //Not reachable before lift hits top
			}
			else if ( (V.Z < -0.7) && SafeToDropTo(Other, A) )
				Goto CHECK_REACHABLE; //Lift going down, worth dropping
			if ( Abs(V.Z) < 0.2 && !NearestMoverKeyFrame( Lift, A.Location, Other.GroundSpeed*0.15) ) 
				Goto CHECK_REACHABLE;			//Z-Estacionario + no dirigiendose al LiftExit designado
			if ( Lift.bDelaying && A.Location.Z > Other.Location.Z+Other.CollisionHeight )
				Goto CHECK_REACHABLE;					//Aun no empezamos a subir
			return CurrentPath Or Other;
		}
	
		//Bot is outside of lift
		V = TargetLoc + Lift.Velocity * (HSize(Other.Location-TargetLoc)/Other.GroundSpeed); //Find future position
		if ( (Lift.Velocity.Z >= 0) && Other.PointReachable(V) ) //Stationary or going up
			return None;
		if ( (Lift.Velocity.Z < 0) && Other.PointReachable(TargetLoc) ) //Going down, prevent UnderLift
		{
			//See if we're taking damage on fall
			if ( (FreeFallVelocity( V.Z-Other.Location.Z, Other.Region.Zone.ZoneGravity.Z) > -750 - Other.JumpZ)
				|| (A != None && A.Region.Zone.bWaterZone) )
				return None; //Safe to drop
		}
		return CurrentPath Or Other;
	}
	
	//Bot is standing on the elevator
	if ( (Other.Base != None) && (Other.Base == Lift || Other.Base.Base == Lift) )
	{
		TargetLoc = Other.MoveTarget.Location;
		bHeadedToNearest = Other.PointReachable( TargetLoc)
						|| (NearestMoverKeyFrame( Lift, TargetLoc) && (Other.Location.Z+Other.CollisionHeight > TargetLoc.Z)); //Bot over 'nearest' keyframe
		if ( InStr( Lift.GetStateName(), "Trigger") != -1 ) //Triggered lift
		{
			if ( (Lift.SavedTrigger == None) || Lift.IsInState('TriggerToggle') )
				Goto FIND_TRIGGER;
		}
		if ( bHeadedToNearest )
		{
			//See if we're taking damage on fall
			if ( (FreeFallVelocity( V.Z-Other.Location.Z, Other.Region.Zone.ZoneGravity.Z) > -750 - Other.JumpZ)
				|| (A != None && A.Region.Zone.bWaterZone) )
				return None; //Safe to drop
		}
		if ( Lift.KeyNum == 0 )
			return Lift; //Jump!
		return CurrentPath Or Other;
	}
	
	//Bot not standing on elevator, and accesible
	bHeadedToNearest = Other.PointReachable( TargetLoc)
					|| (NearestMoverKeyFrame( Lift, Other.Location, Other.GroundSpeed * 0.30) && (Other.Location.Z+Other.CollisionHeight > TargetLoc.Z)) //Bot standing above 'nearest' keyframe
					|| ((CanFallTo(Other,Other.MoveTarget) && Other.FastTrace(TargetLoc)) );

	//Stationary lift can be queried from outside
	if ( bHeadedToNearest )
	{
		//Below bot
		if ( TargetLoc.Z - 200 < Other.Location.Z )
		{
			//Evaluate fall
			if ( (FreeFallVelocity( V.Z-Other.Location.Z, Other.Region.Zone.ZoneGravity.Z) > -750 - Other.JumpZ)
				|| (A != None && A.Region.Zone.bWaterZone) )
				return None; //Safe to drop	
		}
	}
	
	if ( InStr( Lift.GetStateName(), "Trigger") != -1 ) //Triggered lift
	{
		if ( bHeadedToNearest && (Lift.BumpEvent == Lift.Tag || (Other.bIsPlayer && Lift.PlayerBumpEvent == Lift.Tag)) )
			return None; //Lift can self-trigger
		if ( (Lift.SavedTrigger == None) || Lift.IsInState('TriggerToggle') )
			Goto FIND_TRIGGER;
	}
	else if ( bHeadedToNearest ) //Non-triggered lift + reachable
		return None;
	
//Go towards objective if reachable
CHECK_REACHABLE:
	if ( Other.PointReachable( Other.MoveTarget.Location) )
		return None;
	return CurrentPath Or Other;
	
//Finds trigger actor and direct to it if found, otherwise go
FIND_TRIGGER:
	ForEach Other.RadiusActors( class'Actor', A, 800 ) //Should be collidingactors
		if ( A.Event == Lift.Tag )
		{
			if ( (BestA == None) || (VSize(BestA.Location-Other.Location) > VSize(A.Location-Other.Location)) )
				BestA = A;
		}
	if ( (BestA != None) && (BestA.Brush == None) && ActorsTouchingValid(Other,BestA) )
	{
		BestA.UnTouch(Other);
		BestA.Touch(Other);
		return None;
	}
	return BestA;
}

//*************************NearestMoverKeyFrame - DistanceThreshold adds an additional check to make sure elevator is near said target keyframe
static final function bool NearestMoverKeyFrame( Mover M, vector TargetPoint, optional float DistanceThreshold )
{
	local float Dist, BestDist;
	local int i, iNearest;

	//First, find which keyframe is the nearest target
	BestDist = VSize( M.BasePos + M.KeyPos[0] - TargetPoint);
	For ( i=1 ; i<M.NumKeys ; i++ )
	{
		Dist = VSize( M.BasePos + M.KeyPos[i] - TargetPoint);
		if ( Dist < BestDist )
		{
			BestDist = Dist;
			iNearest = i;
		}
	}
	return (M.KeyNum == iNearest) && (DistanceThreshold == 0 || VSize(M.BasePos + M.KeyPos[iNearest] - M.Location) < DistanceThreshold);
}

//***********************NearestNavig - find the nearest navigation point to aVec (excludes whatever's at aVec)
function NavigationPoint NearestNavig( vector aVec, float aDist)
{
	local NavigationPoint N, Best;
	local float fDist;
	
	ForEach NavigationActors ( class'NavigationPoint', N, aDist, aVec )
	{
		fDist = VSize(N.Location - aVec);
		if ( fDist > 30 && fDist < aDist )
		{
			Best = N;
			aDist = fDist;
		}
	}
	return Best;
}


//***********************NearestNavig - find the nearest navigation point to an actor
/*static function NavigationPoint NearestNP( Actor Other)
{
	local NavigationPoint N, Best;
	local float fDist, aDist;
	
	aDist = 500;
	ForEach Other.NavigationActors ( class'NavigationPoint', N, 500, , true)
	{
		fDist = VSize(N.Location - aVec);
		if ( fDist < aDist )
		{
			Best = N;
			aDist = fDist;
		}
	}
	return Best;
}*/


/*
//Analizar plano de apoyo:
// Obtener:  - 2 Vectores normalizado de apoyo ( X, Y, O - centro de apoyo- )
//           - Posible caida de barranco
//           - Posible obstaculo a saltar
static function LinealPlaneDetect( actor DetectFor, vector StartLocation, vector EndLocation, optional Float MinDist, optional Float MaxDifference)
{//Registrar 12 puntos entre los vectores iniciales y comparar plano(s) de apoyo
	local vector HitNormals[12], HitLocations[12];
	local float TotalDist, Factor1, Factor2;
	local vector Current, vX, vY;
	local float fX, fY;
	local int i, j; // Iteradores
	
	TotalDist = VSize( StartLocation - EndLocation);
	if ( (TotalDist < MinDist) || (DetectFor == none) )
		return;

}
*/

//ATENCION!!, formato dual: consumir (+CPU -MEMORIA) TheEnt cualquiera, (-CPU +MEMORIA) TheEnt es BotzMutator
function bool FoundBLP( class<BaseLevelPoint> Sample, actor TheEnt)
{
	local int i;
	local BaseLevelPoint BLP;

	if ( (TheEnt != none) && TheEnt.IsA('BotzMutator') )
		For ( i=0 ; i<96 ; i++ )
			if ( (BotzMutator(TheEnt).GetBLP(i) != none) && classIsChildOf(BotzMutator(TheEnt).GetBLP(i).class, Sample) )
				return True;
	else
		ForEach AllActors(class'BaseLevelPoint', BLP)
			if ( classIsChildOf( BLP.class, Sample) )
				return True;

	return False;
}

//ATENCION!!, formato dual: consumir (+CPU -MEMORIA) SourceEnt cualquiera, (-CPU +MEMORIA) SourceEnt es BotzMutator
//TEAM -1 = no equipo
//bRejectByTeam: rechazar ese BLP en vez de tomarlo
function BaseLevelPoint PickRandomBLP( class<BaseLevelPoint> Sample, actor SourceEnt, int Team, optional bool bRejectByTeam, optional vector TraceFrom, optional bool bLogResults)
{
	local int i, j;
	local BaseLevelPoint BLP, TheList[96];

	if ( bLogResults )
		Log("================== BFM.PickRandomBLP =================");
	i = 0;
	if ( (SourceEnt != none) && SourceEnt.IsA('BotzMutator') )
	{
		if ( bLogResults )
			Log("Source es Mutador");
		For ( j=0 ; j<96 ; j++ )
		{
			if (BotzMutator(SourceEnt).GetBLP(j) == none )
				break;
			if ( !classIsChildOf(BotzMutator(SourceEnt).GetBLP(j).class, Sample) )
			{
				if ( bLogResults )
					Log( SourceEnt.GetItemName(string(BotzMutator(SourceEnt).GetBLP(j)))@"descartado, razón: incompatible");
				continue;
			}
			if ( (TraceFrom != vect(0,0,0)) && !SourceEnt.FastTrace( TraceFrom, BotzMutator(SourceEnt).GetBLP(j).Location ) )
			{
				if ( bLogResults )
					Log( SourceEnt.GetItemName(string(BotzMutator(SourceEnt).GetBLP(j)))@"descartado, razón: no visible");
				continue;
			}
			if ( Team == -1)
			{	TheList[i] = BotzMutator(SourceEnt).GetBLP(j);
				i++;
			}
			else if ( bRejectByTeam )
			{	if ( BotzMutator(SourceEnt).GetBLP(j).Team != Team) 
				{	TheList[i] = BotzMutator(SourceEnt).GetBLP(j);
					i++;	}
				else if ( bLogResults )
					Log( SourceEnt.GetItemName(string(BotzMutator(SourceEnt).GetBLP(j)))@"descartado, razón: pertenece a equipo no deseado");
			}
			else
			{	if (  BotzMutator(SourceEnt).GetBLP(j).Team == Team) 
				{	TheList[i] = BotzMutator(SourceEnt).GetBLP(j);
					i++;	}
				else if ( bLogResults )
					Log( SourceEnt.GetItemName(string(BotzMutator(SourceEnt).GetBLP(j)))@"descartado, razón: no pertenece a equipo deseado");
			}
		}		
	}
	else
	{
		if ( bLogResults )
			Log("Source es"@SourceEnt.GetItemName( string(SourceEnt) ) );
		ForEach AllActors(class'BaseLevelPoint', BLP)
			if ( classIsChildOf( BLP.class, Sample) )
			{
				if ( (TraceFrom != vect(0,0,0)) && !BLP.FastTrace( TraceFrom) )
					continue;
				if ( Team == -1)
				{	TheList[i] = BLP;
					i++;
				}
				else if ( bRejectByTeam )
					if ( int(BLP.Team) != Team )
					{	TheList[i] = BLP;
						i++;
					}
				else
					if ( int(BLP.Team) == Team )
					{	TheList[i] = BLP;
						i++;
					}
			}
	}
	if ( bLogResults )
		For ( j=0 ; j<i ; j++ )
			Log("BFM:"@Sample@"Nº"@(j + 1)@"es"@TheList[j]);
	return TheList[rand(i)];
}

static function bool SetVisibleAndValid( pawn Other)
{
	if ( Other.Mesh == none )
		return false;
	Other.bHidden = False;
	Other.DrawType = DT_Mesh;
	Other.Style = STY_Normal;
	Other.SetCollision( True, True, True);
	Other.bProjTarget = True;
	Other.bCollideWorld = True;
	return True;
}

static function bool SetInvisiblaAndInvalid( pawn Other)
{
	if ( !Other.bIsPlayer )
		return false;
	Other.bHidden = True;
	Other.SetCollision( False, False, False);
	Other.bProjTarget = False;
	Other.bCollideWorld = True;
	return True;
}

//This will return a point we can actually reach, I should globalize this later
function vector SlantStep( vector Origin, float ColRadius, float AddHeight)
{
	local vector Hitloc, HitNorm;
	if ( Trace( Hitloc, HitNorm, Origin - vect(0,0,1) * AddHeight, Origin) == none)
		return Origin;
	HitLoc.Z += AddHeight + ColRadius * (1 - HitNorm.Z);
	return HitLoc;
}
static function vector _SlantStep( Actor A, vector Origin, float ColRadius, float AddHeight)
{
	local vector Hitloc, HitNorm;
	if ( A.Trace( Hitloc, HitNorm, Origin - vect(0,0,1) * AddHeight, Origin) == none)
		return Origin;
	HitLoc.Z += AddHeight + ColRadius * (1 - HitNorm.Z);
	return HitLoc;
}

static function BOOL CanFallTo(pawn Botz, actor JumpDest)
{	local float FallTime;
	local float FallDist;
	local float RunTime;
	local float HDist;
	local float HVel;
	local vector testa, Hitloc, HitNorm;


	if ( (Botz == none) || (JumpDest == none))
		return false;

//Utilizar version alternativa, las caidas no son para tocar un objeto por su punto 0,
//sino que para aterrizar justo en su zona media
	testa = _SlantStep( JumpDest, JumpDest.Location, Botz.CollisionRadius, Botz.CollisionHeight * 2); //Ugly

	FallDist = Botz.Location.Z - testa.Z;
	if ( FallDist * Botz.Region.Zone.ZoneGravity.Z > 0 ) //Negative means can fall
		return false;
	FallTime = sqrt( Abs(FallDist * 2 / Botz.Region.Zone.ZoneGravity.Z) );

	HDist = HSize(testa - Botz.Location);
	RunTime = HDist / Botz.GroundSpeed;

	return RunTime <= FallTime;
}

static function float FreeFallVelocity( float FallDelta, float ZGrav) //Both should have same sign
{
	local float Time;
	
	if ( FallDelta*ZGrav <= 0 ) 
		return 0;
	Time = Sqrt( (FallDelta * 2 / ZGrav) );
	return ZGrav * Time;
}

//********************FallTime - Always considers lowest discriminant (highest arrival time)
static function float FallTime( float FallDelta, float ZGrav, optional float InitialVelZ)
{
	local float disc;

	disc = InitialVelZ*InitialVelZ - 4 * (-FallDelta) * (ZGrav * 0.5); //b^2 - 4*c*a
	if ( disc < 0 )
		return -1;
	return (-InitialVelZ - Sqrt(disc)) / ZGrav;
}

static function BOOL CanFlyTo( vector Origin, vector Dest, float Gravity, float JumpZ, float MaxSpeed, optional actor TraceActor)
{
	local float HighestPoint;	//Si altura supera punto mas alto, salto no posible
	local float DeltaTa, DeltaTb, DeltaT;
	local float DeltaY, disc;
	local float HDist, HVel;

	if ( Gravity >= -0.1 )	return False;

	DeltaY = Dest.Z - Origin.Z;
	disc = JumpZ*JumpZ - 4 * (-DeltaY) * (Gravity * 0.5); //b^2 - 4*c*a
	if ( disc < 0 ) //No hay solucion, no llego tan alto
		return false;

	disc = sqrt(disc);

	//Para salto con caida
	DeltaT = (-JumpZ - disc) / Gravity; //b - disc    /  2*a

	HDist = HSize(Origin - Dest);
	HVel = HDist / DeltaT;
	if ( HVel > MaxSpeed * 1.02)
		return false; //I require a higher horizontal speed

	if ( TraceActor != none ) //Implementar aca el salto con checkeo de obstaculos?
		return TraceActor.FastTrace( Origin);

	return True;
}

static function vector AdvancedJump( vector Origin, vector Dest, float Gravity, float JumpZ, float MaxSpeed, optional bool bSuperAccel)
{
	local float DeltaTa, DeltaTb, DeltaT;
	local float DeltaY, disc;
	local float HDist, HVel;
	local vector Result;

	DeltaY = Dest.Z - Origin.Z;

	disc = JumpZ*JumpZ - 4 * (-DeltaY) * (Gravity * 0.5); //b^2 - 4*c*a
	if ( disc < 0 ) //Evitar un caso 0
	{
		HVel = MaxSpeed;
		Goto END;
	}
	disc = sqrt(disc);

	if ( bSuperAccel ) //Para salto de lleno
	{
		DeltaT = (-JumpZ + disc) / Gravity; //b - disc    /  2*a
		HDist = HSize(Origin - Dest);
		HVel = HDist / DeltaT;
		if ( HVel <= MaxSpeed * 1.05 )
			Goto END;
	}

	//Para salto con caida
	DeltaT = (-JumpZ - disc) / Gravity; //b - disc    /  2*a

// ******************************
	HDist = HSize(Origin - Dest);
	HVel = fMin( HDist/DeltaT, MaxSpeed);

END:
	Result = Normal((Dest - Origin) * vect(1,1,0) ) * HVel;
	Result.Z = JumpZ;

	return Result;
}


//No deberia llamar esta funcion sin antes comprobar que puedo llegar con CanFlyTo()
static function BOOL JumpCollision( pawn Other, vector Start, vector End, float Gravity,float zVel, optional float zExtent, optional int Steps)
{
	local float totalTime, alpha;
	local vector aVel, thisLoc, nextLoc;
	local int i;

	if ( Other == none)
		return false;
	if ( Steps == 0)
		Steps = 4;
	
	//Note: steps means Points to check before end point
	//if steps == 1, only one simple trace will be done
	aVel = AdvancedJump( Start, End, Gravity, zVel, 999999.0, false); //Delta is 0 here
	totalTime = HSize(Start-End) / HSize(aVel); //alpha es la seccion del tiempo que tarda en llegar

//	Log("Speed is X="$aVel.X$"; Y="$aVel.Y$"; Z="$aVel.Z);

	thisLoc = Start;

	For ( i=0 ; i<Steps ; i++ )
	{
		alpha = totalTime / float(Steps);
		alpha *= float(i+1);
		NextLoc.X = Start.X + aVel.X * alpha; //MRU
		NextLoc.Y = Start.Y + aVel.Y * alpha; //MRU
		NextLoc.Z = Start.Z + zVel * alpha + Gravity * 0.5 * square(alpha); //MRUA
//		Log("Point nº "$i+1$" is X="$NextLoc.X$"; Y="$NextLoc.Y$"; Z="$NextLoc.Z$"; Alpha="$alpha);

		if ( zExtent > 0)
		{
			if ( !Other.FastTrace( NextLoc + VectZ(zExtent*0.5), thisLoc - VectZ(zExtent*0.5) ) )
				return false;
		}
		else if ( !Other.FastTrace( NextLoc, thisLoc) )
			return false;
		thisLoc = NextLoc;
	}
	return true;
}

//Location of bot above destination if floating at max speed, accel taken into account?
static function vector SuperFlyLocation( Pawn Other, vector Land)
{
	local float AddedTime, BaseTime, t;
	local vector aVec;

	aVec = HNormal( Land - Other.Location);
	AddedTime = (((Other.Velocity dot aVec) - Other.AirSpeed) / (Other.AccelRate * Other.AirSpeed)) * -1;
	BaseTime = HSize( Land - Other.Location) / Other.AirSpeed;
	t = AddedTime + BaseTime;

	aVec = Land;
	aVec.Z = Other.Location.Z + (Other.Velocity.Z * t + Other.Region.Zone.ZoneGravity.Z * square(t) / 2);

	if ( Botz(Other).DebugMode && (FRand() < 0.08) )
		Log("SFL: "$AddedTime @ BaseTime @ (aVec-Land).Z );

	return aVec;
}

static function vector ThrowAt( vector Origin, vector Dest, float Gravity, float Velocity, optional bool bAltCurve)
{
	local float aTang, bTang;
	local float Yf, Disc;
	local float Xf, HVel;
	local vector Result;
	
	Yf = Dest.Z - Origin.Z;
	Xf = HSize( Origin - Dest);
	
	Gravity *= -1; //Tamos asumiendo aca, por las dudas...
	
	Disc = 1 - ((2 * Gravity * Yf) / square(Velocity));
//	Log( "Discriminant is "$Disc );
	
	Disc -= (square(Gravity) * (Xf**1.9)) / (square(Velocity) * square(Velocity));

//	Log( "Discriminant is "$Disc );
	
	if ( Disc < 0 )
			return vect(0,0,0); //No chance
	
	bTang = square(Velocity) / (Gravity * Xf);
	aTang = bTang * (1 + sqrt(Disc) ); //Aim up
	bTang *= 1 - sqrt(Disc); //Aim down

//	Log( "Tangents are: "$aTang$", "$bTang );

	if ( Gravity < 0 ) //Gravity pulls me upwards
		bAltCurve = !bAltCurve;

	if ( bAltCurve )
		Result = Normal( (Dest - Origin) * vect(1,1,0) ) + (vect(0,0,1) * aTang);
	else
		Result = Normal( (Dest - Origin) * vect(1,1,0) ) + (vect(0,0,1) * bTang);
	return Normal( Result) * Velocity;
}

static function BOOL CompareRotation(rotator A, rotator B, int Tolerance, bool NoPitch)
{
	A = ValidateRotation(A - B);
	return ( (abs(A.Yaw) < Tolerance) && ( NoPitch || (abs(A.Pitch) < Tolerance)) );
}



static function rotator ValidateRotation( rotator TestRot)
{
	TestRot.Pitch = TestRot.Pitch & 65535;
	if ( TestRot.Pitch > 32768 )
		TestRot.Pitch -= 65536;
	TestRot.Yaw = TestRot.Yaw & 65535;
	if ( TestRot.Yaw > 32768 )
		TestRot.Yaw -= 65536;
	return TestRot;
}




static function vector VectZ( float Height)
{	local vector NewV; NewV.Z = Height; return NewV;	}



static function INT IRango(int Min, int Max, int Valor, optional bool Invert)
{	if (Min == Max)
		return Min;
	if (Min > Max)
	{	if (Invert) return Max;
		else return Min;
	}
	if ( Valor < Min )
		Valor = Min;
	else if (Valor > Max)
		Valor = Max;
	return Valor;
}




static function FLOAT FRango(float Min, float Max, float Valor)
{	if (Min == Max)
		return Min;
	if (Min > Max)
		return Max;
	if ( Valor < Min )
		Valor = Min;
	else if (Valor > Max)
		Valor = Max;
	return Valor;
}




static function VECTOR SetPointByRotation(rotator TheRotation, vector TheOrigin, optional int Dist)
{	local vector ExtensionV;
	if (Dist == 0)
		Dist = 2000;
	ExtensionV = ( Vector(TheRotation) * Dist );
	return ( ExtensionV + TheOrigin );
}



static function FLOAT ParaNormal(float TotalPerc, float Valor, optional bool bCanExceed)
{	if ( (Valor > TotalPerc) && !bCanExceed)
		Valor = TotalPerc;
	return (Valor / TotalPerc);
}


//*******************ActorsTouchingValid - sees if both actors are touching 
static function BOOL ActorsTouchingValid( Actor A, Actor B)
{
	local vector V;
	if ( A == None || B == none || !A.bCollideActors || !B.bCollideActors )
		return false;
	V = A.Location - B.Location;
	return (HSize(V) < A.CollisionRadius+B.CollisionRadius) && (Abs(V.Z) < A.CollisionHeight+B.CollisionHeight);
}

static function BOOL InRadiusEntity(actor BaseEnt, actor TheEnt)
{	local float Float1;
	if (TheEnt == none || BaseEnt == none)
		return false;
	Float1 = HSize(TheEnt.Location - BaseEnt.Location);
	if ( (Float1 <= BaseEnt.CollisionRadius) && ( abs(BaseEnt.Location.Z - TheEnt.Location.Z) <= BaseEnt.CollisionHeight) )
		return True;
	return False;
}

static function BOOL ISpotCorrection( Botz B, InventorySpot I)
{
	if ( I == none || I.MarkedItem == none || !I.MarkedItem.IsInState('Pickup') )
		return false;
	if ( VSize( I.Location - B.Location) < 200 )
	{
		if (HSize( I.Location - I.MarkedItem.Location) > (B.CollisionRadius + I.MarkedItem.CollisionRadius))
			return true;
	}
	return (InRadiusEntity( B, I) && B.RouteCache[1] == none);
}

static function ReplaceText(out string Text, string Replace, string With)
{
	local int i;
	local string Input;
		
	Input = Text;
	Text = "";
	i = InStr(Input, Replace);
	while(i != -1)
	{	
		Text = Text $ Left(Input, i) $ With;
		Input = Mid(Input, i + Len(Replace));	
		i = InStr(Input, Replace);
	}
	Text = Text $ Input;
}

function FindMonsters( Botz B)
{
	local ScriptedPawn P, BestP;
	local float Dist, BestDist;

	BestDist = 15000 - B.Punteria * 2000;
	ForEach B.PawnActors (class'ScriptedPawn', P, BestDist, B.Location)
		if ( (P.Health > 0) && (P.AttitudeToPlayer != ATTITUDE_Follow) && (P.AttitudeToPlayer != ATTITUDE_Friendly) )
		{
			Dist = VSize( B.Location - P.Location);
			if ( (Dist < BestDist) && B.FastTrace(P.Location) )
			{
				BestP = P;
				BestDist = Dist;
			}
		}
	if ( BestP != none )
		B.SetEnemy( BestP);
}

//Can be slow, call every FEW times
function ScanEnemies( Botz B)
{
	local Pawn P, bestP;
	local float norm, BestNorm;
	local float aDist;
	local vector vNorm;

	BestNorm = 0.55 - B.TacticalAbility * 0.01 - B.Skill * 0.01;   // sqrt(2) with small ability to detect offscreen enemies
	aDist = 12000 + B.Skill * 1000 - B.Punteria * 1100; 
	vNorm = vector(B.ViewRotation);
	ForEach B.PawnActors (class'Pawn', P, aDist, B.Location)
		if ( B.SetEnemy(P,true) )
		{
			norm = Normal(P.Location - B.Location) dot vNorm;
			if ( (norm > BestNorm) && (B.FastTrace(P.Location) || B.FastTrace(P.Location + vect(0,0,15)) ) )
			{
				BestP = P;
				BestNorm = norm;
			}
		}
	B.Enemy = BestP;
}

static function string ByDelimiter( string Str, string Delimiter, optional int Skip)
{
	local int i;

	AGAIN:
	i = InStr( Str, Delimiter);
	if ( i < 0 )
	{
		if ( Skip == 0 )
			return Str;
		return "";
	}
	else
	{
		if ( Skip == 0 )
			return Left( Str, i);
		Str = Mid( Str, i + Len(Delimiter) );
		Skip--;
		Goto AGAIN;
	}
}

//Dir is orthogonalized with WallNormal, so we can trace without hitting said Wall
//It then becomes the end point of the wall
//WallNormal will be updated as well
//Returns none if no wall end found, level or actor if found
static function Actor FindWallEnd( Actor Tracer, vector Origin, out vector WallNormal, out vector Dir, float StepDistance, optional int StepCount, optional vector MultNormal)
{
	local vector HitLocation, HitNormal, aVec;
	local Actor A;
	local float DistToWall;
	local bool bNoReturn;
	
	if ( StepCount == 0 )		StepCount = 20;

	ForEach Tracer.TraceActors (class'Actor', A, HitLocation, HitNormal, Origin - WallNormal * 200, Origin)
		if ( A == A.Level || A.Brush != none )
		{
			DistToWall = VSize( Origin - HitLocation);
			aVec = Origin;
			if ( WallNormal != HitNormal )
			{
//				Log("Error: mismatching normals"@ WallNormal @ HitNormal);
				WallNormal = HitNormal;
			}
			break;
		}
	if ( DistToWall == 0 ) //No wall end
	{
//		Log("No wall end");
		Dir = Origin - WallNormal * 200;
		return none;
	}
	//orthogonalize vectors with special criterias
	if ( MultNormal == vect(0,0,0) )
		MultNormal = WallNormal;
	else
	{
		Dir *= MultNormal;
		MultNormal = Normal(WallNormal * MultNormal);
	}
	Dir = Normal(Dir - MultNormal * (Dir dot MultNormal));

	While ( StepCount > 0 )
	{
		ForEach Tracer.TraceActors (class'Actor', A, HitLocation, HitNormal, aVec + Dir * StepDistance, aVec )
			if ( IsSolid(A) && (A != Tracer) ) //PREMATURE HIT
			{
				Dir = HitLocation + HitNormal * StepDistance;
				WallNormal = HitNormal;
//				Log("Premature Hit on step -"$StepCount@A);
				return A;
			}
		aVec += Dir * StepDistance;
		ForEach Tracer.TraceActors (class'Actor', A, HitLocation, HitNormal, aVec - WallNormal * 200, aVec )
			if ( IsSolid(A) && (A != Tracer) )
			{
				if ( abs(VSize(HitLocation - aVec) - DistToWall) < 2 )
				{
					bNoReturn = true;
					break;
				}
				if ( (VSize(HitLocation - aVec) - DistToWall > 30) )
				{
					WallNormal = Dir;
					Dir = aVec + Dir * StepDistance;
//					Log("Open wall on step -"$StepCount@A);
					return None;
				}

				WallNormal = HitNormal;
				Dir = aVec + Dir * DistToWall * (WallNormal dot Dir);
//				Log("Wall ended at step -"$StepCount@A);
				return None;
			}
		if ( !bNoReturn )
		{	WallNormal = Dir;
			Dir = aVec + Dir * (DistToWall - StepDistance);
//			Log("Open wall on step -"$StepCount @ Dir);
			return None;
		}
		bNoReturn = false;
		StepCount--;
	}
	Dir = aVec;
}


//Returns actor or level if hit something, none if we could make a small turn around the cylinder
static function Actor AroundCylinder( Actor Tracer, Actor Cylinder, actor Dest, vector Origin, out vector WallNormal, out vector Dir, float CylDist)
{
	local vector HitLocation, HitNormal, aVec;
	local Actor A;

	if ( WallNormal dot Dir != 0 ) //orthogonalize vectors
		Dir = Dir - WallNormal * (Dir dot WallNormal);
	Dir = Normal( Dir);
	CylDist = fMax( CylDist, 20.0);

	aVec = Origin + Dir * 0.5 * (CylDist + Cylinder.CollisionRadius) - Cylinder.Location;
	aVec = Normal(aVec) * (Cylinder.CollisionRadius + CylDist) + Cylinder.Location;
	ForEach Tracer.TraceActors (class'Actor', A, HitLocation, HitNormal, aVec, Origin)
		if ( IsSolid(A) )
		{
			Dir = HitLocation + HitNormal * CylDist;
			WallNormal = HitNormal;
			return A;
		}
		
	WallNormal = HNormal( aVec - Cylinder.Location);
	Dir = aVec;
	ForEach Tracer.TraceActors( class'Actor', A, HitLocation, HitNormal, Dest.Location, aVec)
	{
		if ( A == Dest )
			return None;
		if ( IsSolid( A) )
			return A;
	}
	return None;
}

static function bool IsSolid( actor Other)
{
	return (Other == Other.Level) || Other.bBlockActors || Other.bBlockPlayers || Other.IsA('Mover');
}

defaultproperties
{
}
