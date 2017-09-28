//=============================================================================
// Botz.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz expands BotzClientPawn
	config(BotzDefault);

const MaxSkill = 7.0;
const MaxAccuracy = 0.0;
const MinAccuracy = 5.0;
const MinTactical = 0.0;
const MaxTactical = 5.0;
//const BFM = class'BotzFunctionManager';
const AngleFactor = 182.044444444444444444444444444;


var BotzFunctionManager BFM;
var bool bSpawnedByUser; //Do not remove this botz
var bool bIgnoredByMutator; //Invisible to BotzMutator
var bool bNative; //Native Botz
var int iIndex; //Internal index for mutator control

var(Pawn) string DefaultSkinName;

var(Orders) name SubOrders;
var(Orders) actor SubOrderObject;
var(Orders) travel name Orders;
var(Orders)	actor OrderObject;
var travel string OObjectName;
var name SavedState;
var name SavedLabel;
// var name PostMoveLabel;  //No todos los label de movimiento son iguales
var name OldSubOrders;
var actor OldSubOrderObject;
var name ForceState, ForceLabel; //Intervencion externa
var float MinDesiredDelta; //Avoid FPS from falling below the limit (60 on viewport, 20 on server)

var config bool bHumanMove;	//Set bAdvanced tactics if set and enemy in sight
var() vector FireOffset;     // Basic Fire offset. //BORRAR
var() class<Weapon> ArmaFavorita;
var() bool Suicida;//Tema de distancias, numeros 0 y 1 son armas inferiores(ej: pistola)
var() float Punteria, TacticalAbility, TrackingAbility, Aggresiveness; //AGG is -1 to 1

//Multi-Camping Variables
var() int AvgCampTime; //Config
var float CampTime;

//Deprecate camp stuff below
var() float CampChance; //Config
var int MaxCampTime;
var int iCampTime; //Contador interno
var Actor ProximoCamp;
var bool bDoesCamp; //Determinado Por QueHacerAhora() usando camp-chance
var bool bCamping;
var bool bSniping;
var bool bWeaponCamp;
var bool bDebugLog;
var actor LastAmbushSpot;
var Ambushpoint AmbushSpot;
var(SinglePlayerBot) Ambushpoint PuntoDeCamping;

//Defending Variables
var bool bMultiDefense;		//Definido por 'InitialStand' para determinar si DOS o mas BOTZ defienden en este punto (solo si hay pocos puntos de defensa para los BOTZ que defienden)
var FortStandard MyDefenseFort;

//Evaluacion De Objetivos
var float LastObjectiveCheck;
var float LastMsgTime;
var Actor GameTarget;
var Actor GameTargetAlt;
var Actor DefenseTarget; //FUTURO: IMPLEMENTAR ESTO
var actor ObjetivoPrimario; //Para DOM(PuntoDeControl mas cercano), Para DM(ItemPrincipal) 
var actor ObjetivoSecundario; //DOM(PuntoDeControl que acabo de dejar, DM(ItemSecundario)
var actor MiBase; //CTF: mi bandera, DM: zona donde mejor le va(matando, no muriendo) FUTURO
var actor FinalMoveTarget; //StrafeFacing hacia el item; Translocator launch
var actor SpecialMoveTarget; //Usado durante movimiento no latente
var name BadEvent; //Evento malo, para chequeo rapido de Trigger
var bool bMustChange;
var bool bShouldDuck;
var BotzMutator MyMutator;
var BotzFollowTrail theTrail;
var MasterGasterFer MasterEntity;
var Botz_BaddingSpot MyBads;
var int BadCount;
var FlightProfileBase FlightProfiles[8], CurFlight;
var int iFlight;
var float LastAnimFrame;

//Evaluacion de Nivel
var float CurDelta;
var ControlPoint ControlPointList[64];
var int iCP;
var bool bCpEv;
var bool bGeneralCheck;	//Checkeo general: 1 cada 2 cuadros
						//Utilizado para detectar proyectiles (FUTURO: DETECTAR OTRAS COSAS)
						//Consumiendo menos procesador por bot
						//Se utiliza en Tick(), y si es verdadero, se llevan a cabo los chequeos

//Patrol-Order
var bool bPatrolUp; //Para resumir patrulla luego de haber hecho algo especial
var actor PatrolStops[16]; //Patrol stops no se borran con otra orden
var int CurrentPatrol;

//Evaluacion de caminos
var Translocator MyTranslocator;
var bool bHasTranslocator;
var bool bHasImpactHammer;
var bool bFlagCarrier;
var bool bPendingTransloc;
var bool bCanTranslocate;
var NavigationPoint LastNode;
var NavigationPoint StartAnchor; //Used during pathfinding

var float RespawnTime; /*Si muere de forma vergonzosa, tarda mucho en aparecer; si muere normalmente, un tiempo normal y si tienen su bandera, aparece rapido*/
var InfoPoint CampPoint,MySniperPoint,PingPongPoint,MyHoldSpot;
var AimOffsetPoint AimPoint;
var PlayerPawn JugadorSimulado;//Detecta un jugador y lo imita en los estados iniciales
var bool bHasToJump;
var bool SharingSpots;							//FUTURO
var bool CriticalSituation; // Situación crítica, reaparecer rapido y apurarse en ataques.
var bool bSuperAccel;
var bool bUnstateMove;
var bool bScriptedMove;
var F_HoldPosition SharedSpots[8];				//FUTURO
//SUSTITUIDA POR UN FUNCTION BOOL
var	name NextAnim;//used in states with multiple animations//BORRAR SI NO NECESARIO

//Translocalización
var float LastTranslocCounter;
var float NoDeleteTranslocs;
var bool bAirTransloc;
var bool bHadTTarget;

//Combate simple
var enum EAttackDistance
{
	AD_Cercana,
	AD_Media,
	AD_Larga,
} AttackDistance;
var vector BestDodgeLocation;
var Projectile DangerM;

var float Accumulator;
var name OldMessageType;
var int OldMessageID;
var bool bTurnControl;
var bool bWasWaiting;
var() bool DebugMode;
var() bool DebugSoft;
var() bool DebugPath;
var actor ImpactTarget;
var float TiempoDeVida;
var bool bGameStarted;
var bool bTickedJump;
var bool bTickedSuperJump;
var float Precaucion;
var config bool bSuperAim;

//Perfiles de armas
var BotzWeaponProfile WeaponProfile;
var Actor MyCombo; //Keep track of combo projectile
var float ExecuteAgain; //Check for conditionals
var string CurrentTactic; //Avoid leaving a chained tactic
var float MoveAgain; //Movement checker
var float CombatParamA, CombatParamB;
var int CombatInt; //Special parameter in state code
var bool bKeepEnemy;
var bool bCombatBool; //Special parameter in state code
var float CombatWeariness; //Once it reaches 5 abandon combat; when negative don't combat
var float ChargeFireTimer; //Combined with accumulator, sets a fire timer
var float TacticExpiration; //Manual expiration timer for non state, each combat treats this differently!
var float DistractionLimit;
var float DodgeAgain;
var float SafeAimDist; //Avoid walls when aiming

//Chat'n'Radio
var bool bCoverAdv;
var float ChatCounter, RadioCounter;

//Lista de acciones del bot (Para el futuro tickmove y update accel)
// MAL, Para ultrabotz!
enum EMainActionList
{
	MAL_None,
	MAL_Attacking,
	MAL_Defending,
	MAL_Following,
	MAL_Freelancing,
	MAL_Holding,
	MAL_CarryingFlag,
	MAL_InitialStand,
};
enum ESecondaryActions
{
	SA_Hunting,
	SA_None,
	SA_Sniping,
	SA_Supporting,
	SA_Covering,
};
var EMainActionList FrontActions; 	//For TickMove and events
var ESecondaryActions SideActions; //For Special Team Cooperating, not yet implemented

//Trigger External variables: lidiar con Botz sin union de scripts
var string PlayerNamez;
var name PlayerOrderz;
var string TriggerCommand;
var string TheClassZ;


static final preoperator  bool  !  ( Object O )
{
	return O == None;
}

//====================
// XC_Core / XC_Engine
//====================

native(640) static final function int Array_Length_Int( out array<int> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_Int( out array<int> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_Int( out array<int> Ar, int Offset, optional int Count );


native(3540) final iterator function PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional Pawn StartAt);
native(3541) final iterator function NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint P, optional float Distance, optional vector VOrigin, optional bool bVisible);
native(3542) final iterator function InventoryActors( class<Inventory> InvClass, out Inventory Inv, optional bool bSubclasses, optional Actor StartFrom); 
native(3542) final iterator function InventoryActorsW( class<Weapon> Weapon, out Weapon W, optional bool bSubclasses, optional Actor StartFrom);  //Hack for weapon finding
native(3552) final iterator function CollidingActors( class<actor> BaseClass, out actor Actor, float Radius, optional vector Loc);
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );
native(3554) static final function iterator ConnectedDests( NavigationPoint Start, out Actor End, out int ReachSpecIdx, out int PathArrayIdx);
native(3555) static final operator(22) Actor Or (Actor A, skip Actor B);
native(3555) static final operator(22) Object Or (Object A, skip Object B);
native(3570) static final function vector HNormal( vector A);
native(3571) static final function float HSize( vector A);
native(3572) static final function float InvSqrt( float C);

//**************************CollideTrace - Sees if trace hits a solid, HitLocation=End, HitNormal=Dir if no hit.
// Code really resides on Botz_NavigBase class, this is a redirection
native final function Actor CollideTrace( out vector HitLocation, out vector HitNormal, vector End, optional vector Start, optional bool bOnlyStatic);

//********************************* Route mapper
//All the navigation network is mapped 
// Candidate flags:
//	bEndPoint=True			- Mark the candidate as endpoint
//	VisitedWeight			- Added weight to an endpoint
//	bestPathWeight			- Total weight of the route (const)
//	return value			- True=Propagate route, False=Stop here
//	** What false is returned, this path can be checked again if a shorter route leads to it

//In order to mark a NavigationPoint as endpoint, set the candidate's bEndPoint=True
//Prior to evaluation SpecialCost/ExtraCost is applied on the node
//VisitedWeight is the added weight to an endpoint

//Available tags: ExtraTag, OtherTag (prioritize OtherTag)


//Modifiers:
// 0x0001:	no R_WALK routes
// 0x0002:	no R_FLY routes
// 0x0004:	no R_SWIM routes
// 0x0008:	no R_JUMP routes
// 0x0010:	no R_DOOR routes
// 0x0020:	no R_SPECIAL routes
// 0x0040:	no R_PLAYERONLY routes
// 0x0080:	soft-reset (VisitedWeight, prevOrdered) instead of hard-reset (+ cost, nextOrdered)

// When calling MapRoutes a 'hard-reset' will occur and all paths will be ready to be mapped
// PostHardResetEvent allows the user to modify NavigationPoint's cost inbetween a hard-reset and the mapping

// If you intend to change the StartAnchor after already having mapped the network,
// perform a soft-reset to avoid calculating path 'Cost' again
native final function MapRoutes( NavigationPoint StartAnchor, optional int MinWidth, optional int MinHeight, optional int Modifiers, optional name PostHardResetEvent);
native final function NavigationPoint BuildRouteCache( NavigationPoint EndPoint, out NavigationPoint CacheList[16] );

// Increase cost of navigation points post MapRouts hard-reset
event GlobalModifyCost()
{
	if ( MasterEntity != None )
		MasterEntity.AdjustCostFor( Self);
	CostBads();
}
event CostBads()
{
	local Botz_BaddingSpot B;

	For ( B=MyBads ; B!=none ; B=B.NextSpot )
		B.ApplyBadding();
	if ( PlayerReplicationInfo.Team < 4 )
		For ( B=MasterEntity.TeamBads[PlayerReplicationInfo.Team] ; B!=none ; B=B.NextSpot )
			B.ApplyBadding();
}

function TeamChat( name ChatType, optional PlayerReplicationInfo PRI1, optional PlayerReplicationInfo PRI2, optional string ForceChat);

function WhatToDoNext(name LikelyState, name LikelyLabel) /* CERTIFICADO: COMPATIBILIDAD */
{
	QueHacerAhora();
}
function Trigger( actor Other, pawn EventInstigator ) /* CERTIFICADO: COMPATIBILIDAD */
{
	local Pawn P, EART;

	if ( TriggerCommand == "SETVISUALPROPS" )
	{
		SetVisualProps();
		TriggerCommand = "";
		TheClassZ = "";
	}
	if ( (PlayerNamez != "") && (PlayerOrderz != '') )
	{
		ForEach AllActors (class'Pawn', P)
			if ( (P.PlayerReplicationInfo != none) && (P.PlayerReplicationInfo.PlayerName ~= PlayerNamez) )
			{	EART = P;	break;	}
		SetOrders( PlayerOrderZ, EART);
		PlayerOrderZ = '';
		PlayerNamez = "";
	}

	if ( (Other == Self) || (Health <= 0) )
		return;

	SetEnemy(EventInstigator);
}

event Touch( Actor Other )
{
	if ( Other == none )
		return;
	if ( (Inventory(Other) != None) && (GetMoveTarget() == Other) )
		StopMoving(true);
	if ( (ControlPoint(Other) != none) && !Other.bHidden )
	{
		SpecialMoveTarget = none;
		SendTeamMessage(None, 'OTHER', 11, 15);
		return;
	}
	if ( Kicker(Other) != none )
		TouchedBooster( Other);
	else if ( Other.IsA('swJumpPad') && (Teleporter(Other).URL != "") )
		TouchedBooster( Other);
}

//Modify pathfinding based on added cost
function BaddingPaths( pawn Sentinel)	/* CERTIFICADO: MEJORA */ //No ir por un camino vigilado la próxima
{
	local float AddedBads;
	local bool bCamper;
	local Botz_BaddingSpot aBad;

	if ( (Sentinel == none) || (BadCount > 8) )
		return;

	if ( Sentinel == self )
	{
		aBad = MasterEntity.GetFreeBad();
		aBad.Setup( self, none, Destination, 800, 100);
		return;
	}

	if ( Sentinel.Weapon != none) //Evaluar arma asesina
	{
		if (Sentinel.Weapon.bInstantHit)
			AddedBads += 100;
		AddedBads += fMin(Sentinel.Weapon.AiRating * 100, 150);
		AddedBads *= fMin(Sentinel.DamageScaling, 2);
	}
	if ( Sentinel.Acceleration == vect(0,0,0) ) //Camper
	{
		AddedBads += 100;
		bCamper = true;
	}
	AddedBads += fMin(Sentinel.Health, 200);	//Mayor si asesino es fuerte
	AddedBads += fMin(Abs(Health), 200);	//Mayor si fue un golpe mortal (ej: HeadShot)
	AddedBads += fMin(VSize( Sentinel.Location - Location) / 30, 300);

	//Avoid this spot
	aBad = MasterEntity.GetFreeBad();
	aBad.Setup( self, Sentinel, Location, AddedBads, 60);
	if ( bCamper ) //Notify whole team as well
	{
		aBad.ScanDist *= 2;
		aBad = MasterEntity.GetFreeBad( PlayerReplicationInfo.Team);
		aBad.Setup( none, Sentinel, Location, AddedBads / 2, 160);
		aBad.bDieWithTarget = true;
		aBad.ScanDist *= 0.9;
	}
	else if ( Sentinel.Health > 1000 ) //Bigass mofo, avoid him
	{
		aBad = MasterEntity.GetFreeBad( PlayerReplicationInfo.Team);
		aBad.Setup( none, Sentinel, Sentinel.Location, AddedBads, 60);
		aBad.bDieWithTarget = true;
		aBad.bMoveToTarget = true;
		aBad.ScanDist *= 1.2;
	}
	else
	{
		aBad = MasterEntity.GetFreeBad( PlayerReplicationInfo.Team);
		aBad.Setup( none, Sentinel, Sentinel.Location, AddedBads / 2, 30);
		aBad.bMoveToTarget = true;
		aBad.ScanDist *= 0.7;
	}
}

function BOOL CanSideMove()	/* CERTIFICADO: MEJORA */ //Side-Move, movimiento especial hacia un lado para evitar paredes
{			// Especialmente usado en following
	if ( Physics != PHYS_Walking )
		return False;	//por ahora
	if ( GetStateName() != 'Following' )
		return False;	//por ahora

	return True;
}

function bool EludeWallBetween( actor TargetSpot, optional int MaxSteps)
{
	local vector EndPoint, EndNormal, HitLocation, HitNormal;
	local float aDist, bDist;
	local vector aPos[16], bPos[16], InitialPoint, InitialNormal;
	local actor aResult, A, B;
	local int i, j, k;

	if ( TargetSpot == none )
		return false;
	MaxSteps = Max( MaxSteps, 1);
	B = CollideTrace( HitLocation, HitNormal, TargetSpot.Location);
	if ( B == none || B == TargetSpot)
		return false;
	InitialPoint = HitLocation + HitNormal * CollisionRadius * 1.8;
	InitialNormal = HitNormal;

	//FORWARD MODE!
	aResult = B;
	EndNormal = InitialNormal;
	EndPoint = TargetSpot.Location - Location;
	HitLocation = InitialPoint;
	while ( i < MaxSteps )
	{
		if ( aResult != Level && aResult.Brush == none ) //THIS IS A CYLINDER
		{
			A = BFM.AroundCylinder( self, aResult, TargetSpot, HitLocation, EndNormal, EndPoint, CollisionRadius * 1.8);
			aPos[j++] = EndPoint;
			if ( A == none ) //No hit, finish validation
				Goto F_SUCCESS;
			aResult = A;
			HitLocation = EndPoint;
		}
		else
		{
			A = BFM.FindWallEnd( self, HitLocation, EndNormal, EndPoint, 25, 25, vect(1,1,0));
			aPos[j++] = EndPoint + EndNormal * 5;
			if ( A == none )
				aResult = CollideTrace( HitLocation, HitNormal, TargetSpot.Location, EndPoint);
			else
			{
				aResult = A;
				HitNormal = EndNormal;
				HitLocation = EndPoint - HitNormal * 25;
			}
			if ( aResult == none || aResult == TargetSpot )
				Goto F_SUCCESS;
			HitLocation += HitNormal * CollisionRadius * 1.8;
			EndNormal = HitNormal;
		}
		EndPoint = TargetSpot.Location - HitLocation;
		i++;
	}
	j = 0; //FAILURE
	if ( false )
	{	F_SUCCESS:
		aDist = VSize( Location - aPos[0] );
		For ( i=1 ; i<j ; i++ )
			aDist += VSize( aPos[i-1] - aPos[i]);
		aDist += VSize( aPos[j-1] - TargetSpot.Location);
	}

	i=0;
	//BACKWARD MODE!
	aResult = B;
	EndNormal = InitialNormal;
	EndPoint = Location - TargetSpot.Location;
	HitLocation = InitialPoint;
	while ( i < MaxSteps )
	{
		if ( aResult != Level && aResult.Brush == none ) //THIS IS A CYLINDER
		{
			A = BFM.AroundCylinder( self, aResult, TargetSpot, HitLocation, EndNormal, EndPoint, CollisionRadius * 1.8);
			bPos[k++] = EndPoint;
			if ( A == none ) //No hit, finish validation
				Goto B_SUCCESS;
			aResult = A;
			HitLocation = EndPoint;
		}
		else
		{
			A = BFM.FindWallEnd( self, HitLocation, EndNormal, EndPoint, 25, 25, vect(1,1,0));
			bPos[k++] = EndPoint + EndNormal * 5;
			aResult = CollideTrace( HitLocation, HitNormal, TargetSpot.Location, EndPoint);
			if ( aResult == none || aResult == TargetSpot )
				Goto B_SUCCESS;
			HitLocation += HitNormal * CollisionRadius * 1.8;
			EndNormal = HitNormal;
		}
		EndPoint = TargetSpot.Location - HitLocation;
		i++;
	}
	k = 0; //FAILURE
	if ( false )
	{	B_SUCCESS:
		bDist = VSize( Location - bPos[0] );
		For ( i=1 ; i<k ; i++ )
			bDist += VSize( bPos[i-1] - bPos[i]);
		bDist += VSize( bPos[k-1] - TargetSpot.Location);
	}

	if ( j<=0 && k<=0 )
		return false;
	if ( k<=0 || ((j>0) && (aDist < bDist)) )
	{
		MasterEntity.TempDest().Setup( self, TargetSpot, 3 + j * 1.5, aPos[j-1]);
		For ( i=j-1 ; i>0 ; i-- )
			MasterEntity.TempDest().Setup( self, SpecialMoveTarget, 3 + i * 1.5, aPos[i-1]);
	}
	else
	{
		MasterEntity.TempDest().Setup( self, TargetSpot, 3 + j * 1.5, bPos[k-1]);
		For ( i=k-1 ; i>0 ; i-- )
			MasterEntity.TempDest().Setup( self, SpecialMoveTarget, 3 + i * 1.5, bPos[i-1]);
	}
	return true;
}

function ResetAimTarget() /* CERTIFICADO: AFINADO */
{
	local bool First;
	local actor A;

	if (AimPoint == none)
	{
		AimPoint = spawn(class'AimOffsetPoint', self);
		return;
	}

	ForEach AllActors (class'Actor', A)
	{
		if (First && A.bIsPawn )
		{
			AimPoint.Destroy();
			AimPoint = spawn(class'AimOffsetPoint', self);
			break;
		}
		if ( A == AimPoint )
			First = True;
	}
}
function QueHacerAhora() /* CERTIFICADO: BASE */ //ACA SE DECIDEN LOS ESTADOS, PRIMERO LOS DEFINO
{
	local Name CustomState;
	local ImpactHammer IH;
	
	if ((Health <= 0) && !bGameStarted)
		return;

	if ( !bGameStarted && bHidden )
		BFM.SetVisibleAndValid( self);
	
	bUnstateMove = false;
	bScriptedMove = false;
	SpecialMoveTarget = none;
	ResetAimTarget();
	if ( BotReplicationInfo(PlayerReplicationInfo) != none )
		BotReplicationInfo(PlayerReplicationInfo).RealOrders = Orders;

	if (Health <= 0)
	{
		if ( !IsInState('Dead') )
			GotoState('Dead');
		return;
	}


	CurrentTactic = "";
	bDoesCamp = (FRand() < CampChance);
	iCampTime = (-5 - (7 / (CampChance + 0.1)));
	MaxCampTime = (AvgCampTime * RandRange(0.8, 1.2));
	
	MyTranslocator = Translocator(FindInventoryType(class'Translocator'));
	bHasTranslocator = (MyTranslocator != None);
	ForEach InventoryActors (class'ImpactHammer', IH, true)
		break;
	bHasImpactHammer = IH != None;
	bCanTranslocate = (bHasTranslocator && (PlayerReplicationInfo.HasFlag == none) );
	if ( !bAirTransloc )
		SwitchToBestWeapon();

	Enable('Tick');
	LifeSignal(1.0);

	bGameStarted = True;

	if (FrontActions == MAL_CarryingFlag)
	{
		DistractionLimit = 1.5;
		if ( Health < 80 )
			DistractionLimit += 0.2;
		GotoState('Attacking');
		return;
	}

	DistractionLimit = 0.8;
	if ( Health < 80 )
		DistractionLimit += 0.2;
	if ( (Pawn(OrderObject) != None) && (StationaryPawn(OrderObject) == None) )
		DistractionLimit -= 0.2;
	

	CustomState = MasterEntity.MyTargeter.ModifyState( self);
	if ( CustomState != '' )
		GotoState( CustomState);
	else if ( Level.Game.bTeamGame )
	{
		ORDER_AGAIN:
		if ( SubOrders == 'GetOurFlag' && (SubOrderObject != none) ) //Overrides orders
			GotoState('Following');
		else if ( (Orders == 'Follow') || (Orders == 'FollowZ') )
			GotoState('Following');
		else if (Orders == 'Attack' || Orders == 'sgAttack' )
			GotoState('Attacking');
		else if ( (Orders == 'Hold') || (Orders == 'Patrol') )
			GotoState('Holding');
		else if (Orders == 'Defend')
			GotoState('Defending','Moving');
		else
		{
			if (Orders == '')
			{
				Orders = MasterEntity.MyTargeter.InitialOrders( self);
				if ( Orders != '' )
					Goto ORDER_AGAIN;
				if ( BotReplicationInfo(PlayerReplicationInfo) != none )
					BotReplicationInfo(PlayerReplicationInfo).RealOrders = Orders;
			}
			if ( InStr(Caps(string(Level.Game)), "DOMINATION") == -1 )
				GotoState('Freelancing');
			else
				GotoState('DominationFree');
			if (Orders == '')
			{
				Orders = 'FreeLance';
				if ( BotReplicationInfo(PlayerReplicationInfo) != none )
					BotReplicationInfo(PlayerReplicationInfo).RealOrders = 'Freelance';
			}
		}
	}
	else
	{
		GotoState('Freelancing');
		Orders = 'Freelance';
	}
}

function float AdjustDesireFor(Inventory Inv) /* CERTIFICADO: AFINADO */
{
	local float Tmp;
	local Weapon AlreadyHas;

	if ( Weapon(Inv) != none )
	{
		Tmp = 1;
		if ( Level.Game.bTeamGame )
		{
			AlreadyHas = Weapon(FindInventoryType( Inv.Class));
			if ( AlreadyHas != none && (AlreadyHas.AmmoType == none || AlreadyHas.AmmoType.AmmoAmount >= AlreadyHas.AmmoType.MaxAmmo) )
				return -1000;
			if ( CheckPotential() )
				return -0.2;
			if ( (!Inv.bHeldItem || Inv.bTossedOut) && Weapon(Inv).bWeaponStay )
				Tmp = 0.2;
		}
		if ( ArmaFavorita != none )
		{
			if ( Inv.Class == ArmaFavorita )
				return Tmp * 0.5;
			if ( ClassIsChildOf( Inv.Class, ArmaFavorita) )
				return Tmp * 0.3;
		}
		if ( (Weapon != none) && (Weapon.AmmoName == Inv.class) && (Weapon.AmmoType.AmmoAmount < Weapon.AmmoType.MaxAmmo * 0.2) )
			return 0.2;
		return 0;
	}

	if ( inv.IsA('JumpBoots') || inv.IsA('UT_JumpBoots') )
		return 0.1;

	if (inv.IsA('Health') || inv.IsA('TournamentHealth'))
		return fClamp( (Default.Health - Health) * 0.01, 0, 1);

	if (inv.IsA('SCUBAGear') && (Physics == PHYS_Swimming) )
		return 0.1;

	return 0;
}

function SetRotationRate() /* CERTIFICADO: AFINADO */
{
	local float Dist;

	if (Target != none && Target.IsA('InfoPoint'))
	{
		Dist = VSize(Target.Location - Location);
		RotationRate.Yaw = (10000 + 600000 / (Dist /20));
	}
	else
		RotationRate.Yaw = 30000;
}
function SeePlayer(Actor SeenPlayer)
{
	NextState = GetStateName();
	SetEnemy(Pawn(SeenPlayer));
}

function bool SetEnemy( Pawn NewEnemy, optional bool bOnlyCheck )
{
	local bool result;

	bKeepEnemy = bKeepEnemy && (Enemy != None) && (Enemy.Health > 0);
	if ( bKeepEnemy )
		return (NewEnemy == Enemy);
	
	if ( !bGameStarted || (NewEnemy == none) || (NewEnemy == self) || (NewEnemy.Health <= 0) || !NewEnemy.bCollideActors ) //Intangible enemies shouldn't be targeted
		return False;

	if ( (MasterEntity.MyTargeter != none) && MasterEntity.MyTargeter.ModifyBehaviour(self, NewEnemy, bOnlyCheck) )
		return (NewEnemy != none);

	if ( (NewEnemy.Enemy != self) && (NewEnemy.IsA('Spectator') || NewEnemy.IsA('FlockPawn') || NewEnemy.IsA('FlockMasterPawn')))
		return False;

	if ( NewEnemy.IsA('ScriptedPawn') )
	{
		if ( NewEnemy.AttitudeToPlayer == ATTITUDE_Friendly  )
			return False;
	}
	else if (Level.Game.bTeamGame)
	{
		if ( NewEnemy.bIsPlayer && (NewEnemy.PlayerReplicationInfo != None) && (NewEnemy.PlayerReplicationInfo.Team == PlayerReplicationInfo.Team) )
			return False;
		if ( NewEnemy.IsA('StationaryPawn') && StationaryPawn(NewEnemy).SameTeamAs(PlayerReplicationInfo.Team) )
			return False;
	}
	return bOnlyCheck || (NewEnemy == Enemy) || ElegirEnemigo( NewEnemy);
}

function bool ElegirEnemigo( pawn Other)
{
	local float Factys;
	local pawn P;

	if ( (Enemy != none ) && FastTrace( Enemy.Location) )
	{
		Factys = (VSize( Enemy.Location - Location) - VSize( Other.Location - Location)) / 10;
		Factys += ( Other.Health - Enemy.Health);
		if ( Factys < 0 )
			return False;
			//Darsela al que este cerca y tenga menos vida =)
	}

	Enemy = Other;
	return True;
}

event PreBeginPlay()
{
	local Mutator M;
	local string aS;

	
	//Require mutator
	For ( M=Level.Game.BaseMutator ; M!=none ; M=M.NextMutator )
	if (M.IsA('BotzMutator') )
	{
		MyMutator = BotzMutator(M);
		break;
	}
	if ( MyMutator == None )
	{
		Destroy();
		return;
	}
	
	if ( Level.Game.IsA('SiegeGI') )
	{
		aS = string(Level.Game.Class);
		aS = Left(aS, InStr(aS,".") );
		PlayerReplicationInfoClass = Class<PlayerReplicationInfo>( DynamicLoadObject(aS$".sgPRI", class'class') );
		if ( PlayerReplicationInfoClass == none )
			PlayerReplicationInfoClass = Class'BotReplicationInfo';
	}

	Super.PreBeginPlay();

	if ( Level.Game.IsA('LastManStanding') )
		PlayerReplicationInfo.Score = LastManStanding(Level.Game).Lives;
	PlayerReplicationInfo.bIsABot = True;
	PlayerReplicationInfo.PlayerID = Level.Game.CurrentID++;
	PlayerReplicationInfo.PlayerName = "BotZ"$string(PlayerReplicationInfo.PlayerID);
	
	if ( MyMutator.SmartCTF_hack != none )
		Spawn( MyMutator.SmartCTF_hack, PlayerReplicationInfo);

	ForEach DynamicActors (class'BotzFunctionManager', BFM)
		break;

	if ( BFM == none )
	{
		BFM = Spawn( class<BotzFunctionManager>(MyMutator.BFM Or class'BotZFunctionManager'), none,'BFM',vect(0,0,0));
		BFM.Initialize(self);
	}
	ResetAimTarget();
}

function BecomeViewTarget()
{
	bViewTarget = True;
}
//****************************************************************
// INTELIGENCIA ARTIFICIAL CREADA POR MI *************************
//****************************************************************
event PostBeginPlay()
{
	local pawn aPawn;
	local PlayerPawn SimPlayer;
	local float TickRate;
	local DeathMatchPlus DMP;

	Super.PostBeginPlay();

	bHasToJump = True;
	CriticalSituation = False;
	bTurnControl = False;
	AvgCampTime = 4;
	EvaluarPuntosDeControl();
	if ( Level.NetMode == NM_Standalone || Level.NetMode == NM_ListenServer )
		MinDesiredDelta = 1.0 / 59.0;
	else
		MinDesiredDelta = 1.0 / 19.5;

//	if ( Level.NetMode != NM_DedicatedServer ) MOVE TO FERBOTZ_CL_5
//		Shadow = Spawn(class'PlayerShadow',self);

	ForEach DynamicActors (class'MasterGasterFer',MasterEntity)
		break;
	if (MasterEntity == none)
		MasterEntity = spawn(class'MasterGasterFer');
	WeaponProfile = MasterEntity.WProfiles[0];

	ForEach PawnActors (class'PlayerPawn', SimPlayer)	break;
	if ( SimPlayer != none )	bAutoActivate = SimPlayer.bAutoActivate;
	else						bAutoActivate = Level.Game.IsA('DeathMatchPlus');
	
	//Game-specific hacks
	if ( Level.Game.IsA('JailBreak') )
		JailBreakHack();
	bViewTarget = true;
	if ( Level.Game.IsA('DeathMatchPlus'))
	{
		DMP = DeathMatchPlus(Level.Game);
		if ( DMP.bGameEnded )
			InitialState = 'GameEnded';
		else if ( DMP.bRequireReady && (DMP.CountDown > 0) )
			InitialState = 'WaitForStart';
//		else if ( Level.NetMode == NM_DedicatedServer && (Min(DeathMatchPlus(Level.Game).countdown,DeathMatchPlus(Level.Game).NetWait-DeathMatchPlus(Level.Game).ElapsedTime) > 1) )
//			GotoState('WaitForStart');
		else if ( (SimPlayer != None) && (SimPlayer.Physics == PHYS_Flying || SimPlayer.Physics == PHYS_None) )
			InitialState = 'WaitForStart';
		else
			InitialState = 'Dead';
	}
	else
		InitialState = 'Dead';
}

//Specific hack fixes for specific games... starting with JailBreak
function JailBreakHack()
{
	Spawn( class<ReplicationInfo>( DynamicLoadObject("Jailbreak.JBPRI",class'class') ), self);
}


state Attacking
{
	function BeginState()
	{
		SavedState = 'Attacking';
		ProximoCamp = none;
		LastObjectiveCheck = Level.TimeSeconds;
	}
	event EndState()
	{
	}

	function bool CheckPotential( optional int MinHealth)
	{
		if ( MinHealth == 0 )
			MinHealth = 40;
		return Global.CheckPotential( MinHealth);
	}
	function FindMyFlag()
	{
		local FlagBase N;

		MoveTarget = none;
		ForEach NavigationActors (class'FlagBase', N)
			if ( N.Team == PlayerReplicationInfo.Team )
			{
				MoveTarget = N;
				break;
			}
	}
	function ElegirDestino()
	{
		local float MinDistraction;
		local Actor InvPath;
		local NavigationPoint N;

		SpecialMoveTarget = none;
		if ( PlayerReplicationInfo.HasFlag != none)
		{
			FindMyFlag();
			if ( (MoveTarget != none) && (GameTarget != MoveTarget) )
			{
				GameTarget = MoveTarget;
				SendTeamMessage(None, 'OTHER', 2, 10);
			}
			return;
		}

		if ( (GameTarget != None) && GameTarget.bDeleteMe )
			GameTarget = None;
		
		GameTarget = MasterEntity.MyTargeter.SuggestAttack( self);
		LastObjectiveCheck = Level.TimeSeconds;
		MoveTarget = GameTarget;
		FinalMoveTarget = GameTarget;

		//If bot is ready to attack, set MinDistraction to a high value
		if ( CheckPotential() && (GameTarget != None) )
			MinDistraction = 1 - Precaucion * 0.35;
			
		//Allow bot to grab nearby items
		if ( MinDistraction < 0.9 )
			InvPath = BestInventoryPath( MinDistraction);
		else
			Precaucion += 0.01; //Slightly make bot more prone to go after items again
		if ( InvPath != None )
		{
			MoveTarget = InvPath;
			FinalMoveTarget = InvPath;
			if ( GameTarget != None )
				Precaucion -= 0.03; //Prevent Bot from forever going after items
		}



		if ( (FinalMoveTarget == none) || !LineOfSightTo(FinalMoveTarget) )
			FinalMoveTarget = PickRemoteInventory( true);

			
//		if ( InventorySpot(Caca) == none)
			PickLocalInventory(230,0);
	}

Begin:
	SavedLabel = 'Begin';
	Sleep(0.001);
Moving:
	SavedLabel = 'Moving';
	ElegirDestino();
	
	//Camping!
	if ( CampTime > 0 )
	{
	}

	if ( MoveTarget != none )
		SearchAPath( MoveTarget);
	PostPathEvaluate();
	if ( GetMoveTarget() == none)
	{
		Sleep(0.1);
		GotoState('Wander','Begin');
	}
	ScriptMoveToward( GetMoveTarget(), FinalMoveTarget);
	Sleep(0.1);
	while ( ScriptMovePoll() )
		Sleep(0.0);
	Goto('Moving');
Wait:
	SavedLabel = 'Wait';
	Sleep(0.001);
	if ( DebugMode )
		Log("Attack: Wait");
	StopMoving();
	LifeSignal(3);
	FinishAnim();
	Sleep(1);
	Goto('Moving');
UnStateMove:
	Sleep(0.01);
	if ( CanLeaveUnstate() )
		Goto( SavedLabel);
	UpdateUnstate();
	Goto('UnStateMove');
}

state() Defending
{
	function BeginState()
	{
		SavedState = 'Defending';
//		ProximoCamp = none;
	}
	event EndState ()
	{
		if ( (Health < 1) || (Orders != 'Defend') )
			ProximoCamp = none;
	}
	function bool CheckCampDistance()
	{
		local float Dist;

		Dist = VSize(ProximoCamp.Location - Location);
		if (Dist < 50.0)
			return True;
		else
			return False;
	}
	function bool CanPickProbableInv()
	{
		MoveTarget = none;
		PickLocalInventory(220, 0);

		return ((MoveTarget != none) && MoveTarget.IsA('Inventory'));
	}	
	function ElegirDestino()
	{
		local float Mierda;
		local actor Caca;

		Caca = BestInventoryPath( Mierda);

		if (Caca != none)
		{
			MoveTarget = Caca;
			Destination = MoveTarget.Location;
			FinalMoveTarget = PickRemoteInventory( true);
		}
	}
	function actor FindDefensePointFor(actor DefenseObject, name CodeSign)
	{
		local navigationpoint N;
		local FerDefensePoint Suck;
		local Actor ListDef[64];
		local DefensePoint R;
		local int i;
		local bool bOverride;

		i = 0;
		if (CodeSign == 'CTF')
		{//Check de prioridad //Inutil =(
			ForEach NavigationActors (class'DefensePoint', R)
				if ( (R.Team == PlayerReplicationInfo.Team) && !R.Taken)
					ListDef[i++] = R;

			ForEach DynamicActors (class'FerDefensePoint',Suck)
				if (Suck.Team == PlayerReplicationInfo.Team)
				{
					bOverride = false;
					if ( Suck.bJumpBoot && (JumpZ > 500) && (Region.Zone.ZoneGravity.Z > -649))
						bOverride = true;
					else if ( Suck.bTransloc && bHasTranslocator )
						bOverride = true;

					if ( (Suck.bJumpBoot || Suck.bTransloc) && !bOverride)
						continue;
					ListDef[i++] = Suck;
					if (Suck.DoubleChance)
						ListDef[i++] = Suck;
				}
			if ( i > 0 )
				return ListDef[Rand(i)];
		}
		else if (CodeSign == 'AS')
		{
			ForEach NavigationActors (class'DefensePoint', R)
				if ( (R.Team == PlayerReplicationInfo.Team) && (i < 63) )
				{
					ListDef[i++] = R;
					if ( R.FortTag == DefenseObject.Tag )
						ListDef[i++] = R;
				}
			MyDefenseFort = FortStandard(DefenseObject);
			if ( i > 0 )
				return ListDef[Rand(i)];
		}

		return MasterEntity.MyTargeter.SelectGuardPointFor( Self, DefenseObject) or DefenseObject;
	}
	function bool FortDestroyed()
	{
		if (!Level.Game.IsA('Assault'))
			return false;		//No Fort
		return (MyDefenseFort == none);
	}
	function LookForDefensePoint()
	{
		local int i;
		local NavigationPoint AmbushList[24];
		local FortStandard ASForts[6];
		local CTFFlag NewFFlag;
		local actor Best;
		local int iMax;
		local NavigationPoint N; 
		local FortStandard F;
		local int FortPriorMax;
		local AmbushPoint A;

		i = 0;

		if (ProximoCamp == none)
		{
			if (Level.Game.IsA('Assault')) //ASALTO
			{
				FortPriorMax = -1;
				ForEach AllActors (class'FortStandard', F) //Buscar Mas Alta Prioridad
					if (F.DefensePriority > FortPriorMax)
						FortPriorMax = F.DefensePriority;

				if (FortPriorMax < 0)
				{
					Log("Error: "$PlayerReplicationInfo.PlayerName$" couldn't find FortStandard to defend, start Freelancing");
					SetOrders('Freelance',self,true);
					return;
				}
				ForEach AllActors (class'FortStandard', F) //Elegir a los mas prioritarios
					if (F.DefensePriority == FortPriorMax && (i < 6) ) //al azar
						ASForts[i++] = F;

				iMax = Rand(i);

				Best = ASForts[iMax];
				ProximoCamp = FindDefensePointFor( Best, 'AS');
			}
			else if (Level.Game.IsA('CTFGame')) //CTF
			{
				if ((MiBase != none) && (MiBase.IsA('CTFFlag')) && (CTFFlag(MiBase).Team == PlayerReplicationInfo.Team))
					ProximoCamp = FindDefensePointFor(MiBase, 'CTF');
				else
					ForEach AllActors (class'CTFFlag', NewFFlag)
						if (NewFFlag.Team == PlayerReplicationInfo.Team)
						{
							MiBase = NewFFlag;
							Break;
						}
			}
			else		//Camp en un AmbushSpot
			{
				ForEach NavigationActors (class'AmbushPoint', A)
				{
					if (Level.Game.bTeamGame)
					{
						if (!N.Taken)
							AmbushList[i++] = N;
					}
					else
						AmbushList[i++] = N;
				}
				ProximoCamp = AmbushList[Rand(i)];
			}
		}

		if ( ProximoCamp == self )
		{
			ElegirDestino();
			return;
		}

		MoveTarget = ProximoCamp;
		FinalMoveTarget = MoveTarget;
	}
Begin:
Moving:
	SavedLabel = 'Moving';
	AimPoint.bAimAtPoint = False;
	if (CheckPotential(70))
	{
		if (FortDestroyed())
			ProximoCamp = none;
		LookForDefensePoint();
	}
	else
		ElegirDestino();
	PickLocalInventory(220, 0.15);
	if ( MoveTarget != none)
	{
		SearchAPath(MoveTarget);
		PostPathEvaluate();
	}
	if (MoveTarget == none)
	{
		if ( FRand() < 0.2 )
			GotoState('Wander','Begin');
		Sleep(0.5);
		Goto('Moving');
	}
	if ( ProximoCamp == self )
	{
		sleep(0.001);
		Goto('Moving');
	}
	if ((ProximoCamp != none) && CheckCampDistance() && CheckPotential(65) )
		Goto('StartDefending');

	ScriptMoveToward( GetMoveTarget(), /*FinalMoveTarget*/ None);
	Sleep(0.1);
	while ( ScriptMovePoll() )
		Sleep(0.0);
	Goto('Moving');
StartDefending:
	iCampTime = 0;
	if (FRand() < 0.05);
		SendTeamMessage(PlayerReplicationInfo, 'OTHER', 9, 1.2);
	if ( Weapon == MyTranslocator )
		SwitchToBestWeapon();
	if (ProximoCamp.IsA('Ambushpoint') && AmbushPoint(ProximoCamp).bSniping)
		GetWeapon(class'SniperRifle');
	if (ProximoCamp.IsA('FerDefensePoint') && FerDefensePoint(ProximoCamp).Sniping )
		GetWeapon(class'SniperRifle');
//	Goto('DefenseInProgress');
DefenseInProgress:
	Sleep(0.001);
	StopMoving();
	iCampTime++;
	bTurnControl = false;
	FinalMoveTarget = FindRandomDest();
	if ( FinalMoveTarget != none )
		Focus = FinalMoveTarget.Location;
	LifeSignal(2.0);
	FinalMoveTarget = none;
	if ( BFM.FoundBLP( class'F_EnemySniperSpot', MyMutator) )	//SNIPERSPOTFOUND
	{
		FinalMoveTarget = BFM.PickRandomBLP( class'F_EnemySniperSpot', MyMutator, PlayerReplicationInfo.Team, True, Location + VectZ(EyeHeight) );
		if ( FinalMoveTarget != none )
		{
			if ( Enemy == none )
				AimPoint.bAimAtPoint = True;
			AimPoint.PointSpot = FinalMoveTarget.Location;
			if ( Enemy == none )
				LocateEnemy( rotator( FinalMoveTarget.Location - Location), 650);
			DesiredRotation = rotator( FinalMoveTarget.Location - Location);
		}
	}
	if ( FinalMoveTarget == none )
	{
		if (FRand() > 0.85)
			if (NeedToTurn( Focus ) )
			{
				PlayTurning();
				TurnTo( Focus );
				bTurnControl = True;
			}
		else
			if (DoesNeedToTurn(ProximoCamp.Rotation))
			{
				PlayTurning();
				TurnTo( SetPointByRotation( ProximoCamp.Rotation, Location) );
				bTurnControl = true;
			}
	}
	if (bTurnControl)
		Sleep(0.8);
	else
		Sleep(1.1);
	bTurnControl = false;
	Disable('AnimEnd');
	if ( !CheckPotential(65) )
		Goto('Moving');
	if (FortDestroyed())
	{
		ProximoCamp = none;
		Goto('Moving');
	}
	if (CanPickProbableInv())
	{	Goto('CampMovement');
		AimPoint.bAimAtPoint = False;
	}
	if (!CheckCampDistance())
	{	Goto('ReturnMoving');
		AimPoint.bAimAtPoint = False;
	}
	if (iCampTime > MaxCampTime)
	{	ProximoCamp = none;
		QueHacerAhora();
		AimPoint.bAimAtPoint = False;
	}
	else
		Goto('DefenseInProgress');
CampMovement:
	SavedLabel = 'CampMovement';
	Sleep(0.001);
	SearchAPath(MoveTarget);
	LifeSignal(2.1);
	SavedLabel = 'PostCamp';
	MoveToward(MoveTarget);
	PostCamp:
	Sleep(0.25);
	if (CanPickProbableInv())
		Goto('CampMovement');
	Goto('ReturnMoving');
ReturnMoving:
	SavedLabel = 'ReturnMoving';
	Sleep(0.001);
	if (CheckCampDistance())
	{
		Goto('DefenseInProgress');
	}
	MoveTarget = ProximoCamp;
	SearchAPath(MoveTarget);
	PostPathEvaluate();
	MoveToward(MoveTarget);
	Goto('ReturnMoving');
UnStateMove:
	Sleep(0.01);
	if ( CanLeaveUnstate() )
		Goto( SavedLabel);
	UpdateUnstate();
	Goto('UnStateMove');
}

state DodgeProj	//******** ESQUIVAR MISILES (DURA UN MOVIMIENTO, FINALMENTE QueHacerAhora()
{
	event BeginState()
	{
		SavedLabel = '';
	}
	event Tick( float DeltaTime)	//Informar cambios de puntos de huida
	{
		Global.Tick( DeltaTime);
		if ( (VSize( Destination - BestDodgeLocation) > 5) && (VSize(Acceleration) > 20) )
		{	//Modificar movimiento para multi-dodging
			Destination = BestDodgeLocation;
			MoveTimer += 0.3;
		}
	}
StandDodge:
	LifeSignal(1.5);
	StrafeFacing(BestDodgeLocation, FaceTarget);
	if ( DangerM != none )
		SetEnemy(DangerM.Instigator);
	DangerM = none;
	BestDodgeLocation = vect(0,0,0);
	LifeSignal(0.8);
	Sleep(0.5);	//Multi-Move-Dodging
	if ( (DangerM != none) && (BestDodgeLocation != vect(0,0,0) ) )
		Goto('StandDodge');
	ResumeSaved();
	sleep(0.01);
RunDodge:
	LifeSignal( 1.8);
	StrafeFacing( BestDodgeLocation, MoveTarget);
	if ( (Enemy == none) && ( VSize(DangerM.Instigator.Location - Location) < 1200 ) )
		SetEnemy( DangerM.Instigator);	//Eliminar al disparador despues de lograr eludir el proyectil
	DangerM = none;
	BestDodgeLocation = vect(0,0,0);
	LifeSignal(1.4);
	MoveToward( FaceTarget);
	Sleep(0.01);
	ResumeSaved();
UnStateMove:
	Sleep(0.01);
	if ( CanLeaveUnstate() )
	{
		ResumeSaved();
		Stop;
	}
	UpdateUnstate();
	Goto('UnStateMove');
}

state Following//******************	FOLLOWING.
{
	function BeginState()
	{
		SavedState = 'Following';
		if ( (Orders == 'Follow') || (Orders == 'FollowZ'))
		{
			GameTarget = OrderObject;
			if ( TheTrail == none )
			{
				theTrail = OrderObject.Spawn( class'BotzFollowTrail', OrderObject);
				theTrail.Follower = self;
			}
		}
		if ( (SubOrders == 'GetOurFlag') && (SubOrderObject != none) ) //Overrides orders
			GameTarget = CTFFlag(SubOrderObject).Position();

	}
	event EndState() { Disable('AnimEnd'); }
	function MayFall()
	{
		if ( (MoveTarget == GameTarget) && (GameTarget.Physics == PHYS_Falling) )
			GotoState('Following','Waiting');
		bCanJump = True;
		Global.MayFall();
	}
	event Tick( float DeltaTime)
	{
		local vector HitNormal, HitLocation, aVec;
		local actor aTarget;

		if ( GameTarget == none )
			Goto EndFunc;
		aTarget = MoveTarget Or SpecialMoveTarget;
		if ( bGeneralCheck && (FRand() < 0.3) && (theTrail Or GameTarget == aTarget) && !FastTrace(aTarget.Location) )
		{
			if ( aTarget == TheTrail )
			{
				SetMoveTarget( GameTarget);
				if ( FastTrace( GameTarget.Location) );
					Goto EndFunc;
			}
			if ( EludeWallBetween( GameTarget, 3) )
				Goto EndFunc;
		}
		
		if ( GameTarget.bIsPawn && (HSize( GameTarget.Location - Location) < CollisionRadius * 3.5) && (GetMoveTarget() == GameTarget) && (VSize( Acceleration) > 100) && (GameTarget.Base != none) && !GameTarget.Base.IsA('Mover')  )
			StopMoving();
		EndFunc:
		Global.Tick( DeltaTime);
	}
	//Back off
	event Bump( actor Other)
	{
		if ( (Other == GameTarget) && ( (MoveTarget == none) || (!MoveTarget.IsA('Inventory') && !MoveTarget.IsA('InventorySpot') ) ) )
			MasterEntity.TempDest().Setup( Self, Self, 1, SelectBackOffDest() ).LockToGround().PauseAfter(0.5);
		Global.Bump(Other);
	}
	function vector SelectBackOffDest()
	{
		local vector Diff;

		Diff = (Location - GameTarget.Location) * (1.25 + FRand() * FRand());
		Destination = Location + Diff;
		return Destination;
	}
	function bool VerifyOrderGiver()
	{
		if ( Orders == 'Follow' || Orders == 'FollowZ' )
			GameTarget = OrderObject; //Override
		if ( GameTarget == None || GameTarget.bDeleteMe )
		{
			Orders = 'FreeLance';
			QueHacerAhora();
			return false;
		}
		return true;
	}
	event AnimEnd()
	{
		if ( (Orders == 'FollowZ') && (VSize(Location - OrderObject.Location) > 2000) && (OrderObject.Physics != PHYS_Falling) )
			if ( (HSize(theTrail.Location - OrderObject.Location) > (CollisionRadius + OrderObject.CollisionRadius) ) && !theTrail.FastTrace( theTrail.Location - VectZ(OrderObject.CollisionHeight * 1.5) ) )
			{
				SetCollision( False, False, False);
				SetLocation(theTrail.Location);
				SetCollision( True, True, True);
			}
	}
Begin:
CheckTarget:
	SavedLabel = '';
	if ( !VerifyOrderGiver() )
		Stop;
	MoveTarget = GameTarget;
	if ( MoveTarget.bIsPawn && (theTrail != none) && (VSize(theTrail.Location - GameTarget.Location) < 270) )
		MoveTarget = theTrail;
	PickLocalInventory(260,0);
	if ( MoveTarget == none )
	{
		if ( FRand() < 0.1 )
			QueHacerAhora();
		Sleep(0.2);
		Goto('CheckTarget');
	}
	SearchAPath(MoveTarget);
	if ( theTrail != none )
	{
		if (Orders == 'FollowZ')
			theTrail.bEnable = True;
		else if ( (MoveTarget != theTrail) || (VSize(Location - OrderObject.Location) > 550) || !FastTrace(theTrail.Location) )
			theTrail.bEnable = False;
		else
			theTrail.bEnable = True;
	}
	PostPathEvaluate();
	if (MoveTarget == none)
		Goto('Waiting');
	if ( (MoveTarget == GameTarget) || (MoveTarget == theTrail) )
	{
		if ( (GameTarget.Base != none) && GameTarget.Base.IsA('Mover') && (Base != GameTarget.Base) )
			Goto('Moving');
		if ( (VSize(GameTarget.Acceleration) > 50) && (VSize(GameTarget.Location - Location) >= 50) )
			Goto('Moving');
		if ( MoveTarget.bIsPawn && (VSize(GameTarget.Location - Location) <= 180) )
			Goto('Waiting');
	}
Moving:
	SavedLabel = 'Moving';
	Disable('AnimEnd');
	LifeSignal(2);
	SavedLabel = 'PostMove';
	if (VSize(GameTarget.Location - Location) >= 200)
		MoveToward(MoveTarget);
	else
	{	if ( MoveTarget == GameTarget) Goto('Waiting');
		else
				MoveToward(MoveTarget);
	}
	PostMove:
	if (MoveTarget == none)
		sleep(0.001);
	else if ( HSize(MoveTarget.Location - Location) < 3 )
		sleep(0.01);
	else if ( (Base != none) && Base.IsA('Mover') && MoveTarget.IsA('LiftCenter') )
		sleep(0.2);
	Goto('CheckTarget');
Waiting:
	SavedLabel = '';
	Enable('AnimEnd');
	StopMoving();
	LifeSignal(1.4);
	Sleep(0.47);
	Disable('AnimEnd');
	Goto('CheckTarget');
UnStateMove:
	Sleep(0.01);
	if ( CanLeaveUnstate() )
		Goto( SavedLabel);
	UpdateUnstate();
	Goto('UnStateMove');
}
state() WaitForStart//***************************SE ESPERA EL COMIENZO
{
ignores SeePlayer, EnemyNotVisible, HearNoise, Died, Bump, Trigger, HitWall, HeadZoneChange, FootZoneChange, ZoneChange, Falling, WarnTarget, LongFall, PainTimer, QueHacerAhora, WhatToDoNext, Tick;

	event Beginstate()
	{
		HidePlayer();
		SetPhysics(PHYS_None);
	}
	
	event EndState()
	{
//		Assert( DeathMatchPlus(Level.Game) == None || !DeathMatchPlus(Level.Game).bRequireReady || (DeathMatchPlus(Level.Game).CountDown <= 0) ) ;
	}
	
	function TakeDamage( int Damage, Pawn instigatedBy, Vector hitlocation, 
							Vector momentum, name damageType)
	{
		if ( !bHidden )
			Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
	}
	function ReStartPlayer() //Manually issued by DeathMatchPlus
	{
		bHasToJump = false;
		bTickedJump = false;
		GameTarget = none;
		if ( DebugMode )
			Log("RestartPlayer() called");
		if( bHidden && Level.Game.RestartPlayer(self) )
		{
			StopMoving();
			GotoState('InitialStand','Start');
		}
		else if ( Health > 0 )
		{
			Level.Game.AddDefaultInventory(self);
			GotoState('InitialStand','Start');
		}
		else if ( !IsInState('GameEnded') )
			GotoState('Dead', 'TryAgain');
	}
Begin:
	Sleep(0.2 + FRand() );
	if ( DeathMatchPlus(Level.Game) != none )
	{
		if ( DeathMatchPlus(Level.Game).bGameEnded || (DeathMatchPlus(Level.Game).bRequireReady && (DeathMatchPlus(Level.Game).CountDown > 0)) )
			Goto('Begin');
	}
	GotoState('Dead','Go');
}

state Dying
{
	function BeginState()
	{
		GotoState('Dead');
	}
}

state() Dead//***********************ESTÁ MUERTO, REAPARECER
{
ignores SeePlayer, EnemyNotVisible, HearNoise, Died, Bump, Trigger, HitWall, HeadZoneChange, FootZoneChange, ZoneChange, Falling, WarnTarget, LongFall, PainTimer;

	function ReStartPlayer()
	{
		bHasToJump = false;
		bTickedJump = false;
		GameTarget = none;
		if ( DebugMode )
			Log("RestartPlayer() called");
		if( bHidden && Level.Game.RestartPlayer(self) )
		{
//			Velocity = vect(0,0,0);
			StopMoving();
//			SetPhysics(PHYS_Falling);
//			Level.Game.AddDefaultInventory(self);
			GotoState('InitialStand','Start');
		}
		else if ( Health > 0 )
		{
			Level.Game.AddDefaultInventory(self);
			GotoState('InitialStand','Start');
		}
		else if ( !IsInState('GameEnded') )
			GotoState('Dead', 'TryAgain');
	}
	
	function TakeDamage( int Damage, Pawn instigatedBy, Vector hitlocation, 
							Vector momentum, name damageType)
	{
		if ( !bHidden )
			Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
	}
	
	function BeginState()
	{
		Disable('Tick');
		Disable('BaseChange');
		SetTimer(0, false);
		Enemy = None;
		StopMoving();
		MoveTarget = none;
		Weapon = none; //TESTA
		ProximoCamp = none;
		if ( bSniping && (AmbushSpot != None) )
			AmbushSpot.taken = false;
		AmbushSpot = none;
		bSniping = false;
		Precaucion = 3 * FRand() * FRand();
		if ( DebugMode )
			Log("Enter state: DEAD");
	}
	function EndState()
	{
		if ( DebugMode )
			Log("Left state: DEAD");
	}

Begin:
	Sleep(0.001);
	if ( Level.Game.bGameEnded )
		GotoState('GameEnded');
	else
		Goto('TryAgain');
	LifeSignal(0.5);
	Sleep(0.2);
	if ( !bHidden )
		SpawnCarcass();
TryAgain:
	Sleep(0.001);
	if ( !bHidden )
		HidePlayer();
	if ( !Level.Game.IsA('JailBreak') ) //Another hack
	{
		LifeSignal(1.0 + RespawnTime);
		Sleep(0.25 + RespawnTime);
		RespawnTime = 0;
	}
	ReStartPlayer();
	Goto('TryAgain');
WaitingForStart:
	Sleep(0.001);
	bHidden = true;
Go:
	Sleep(0.001);
	bHidden = True;
	LifeSignal(1);
	ReStartPlayer();
}

state() InitialStand//****************** PEQUEÑA DEMORA, A LO HUMANO
{
ignores landed;
	function BeginState()
	{
		if ( DebugMode )
			Log("Enter state: INITIALSTAND");
		Velocity.X = 0;
		Velocity.Y = 0;
		if ( Mesh == None || MySimulated == None )
		{
			MySimulated = class<PlayerPawn>(MySimulated Or Class'TBoss');
			SetVisualProps();
		}
		bCoverAdv = False;
		UpdateProfile( Weapon);
	}
Begin:
Start:
	if ( AimPoint == none )
		Disable('UpdateEyeHeight');
	DesiredRotation = ViewRotation;
	SetCollision(True,True,True);
	if ( !Region.Zone.bWaterZone )
		SetPhysics(PHYS_Falling);
	else
		SetPhysics(PHYS_Swimming);
	bHidden = False;
	LifeSignal(1.7);
	StopMoving();
	SpecialMoveTarget = none;
	if ( DebugMode )
		Log(Self$" post spawned");
	Enable('Tick');
	Enable('BaseChange');
	if ( !Level.Game.IsA('JailBreak') )
		Sleep(1.5 - (Skill / 7));
	bCanJump = true;
	bHasToJump = True;
	Enable('UpdateEyeHeight');
	QueHacerAhora();
UnStateMove:
	Goto('Start');
}

state() DominationFree //============================= FREELANCING SECUNDARIO
{
	event BeginState()
	{
		if (DebugMode && (SavedState != 'DominationFree'))
			log(PlayerReplicationInfo.PlayerName@"entered Domination-Free");
		SavedState = 'DominationFree';
		if ( Precaucion > 1.1 )
			Precaucion *= 0.9;
	}
	event EndState()
	{
		if (DebugMode)
			log(PlayerReplicationInfo.PlayerName@"exited Domination-Free");
	}
	function bool FriendlyCP(ControlPoint DesiredCP)
	{
		if (DesiredCP == none)		return False;
		if (DesiredCP.ControllingTeam == none)			return False;
		if (DesiredCP.ControllingTeam.TeamIndex != PlayerReplicationInfo.Team)
			return False;
		return True;
	}
	function ElegirDestino()
	{
		local controlpoint P;
		local float Mierda;
		
		ForEach NavigationActors (class'ControlPoint', P)
			if ( !FriendlyCP( P) )
				if ( (VSize(P.Location - Location) < 300 && FastTrace(P.Location)) || ActorReachable(P) )
				{
					MoveTarget = P;
					return;
				}

		MoveTarget = none;
		P = ControlPoint(ObjetivoPrimario);


		if (P == none)
		{
			if (DebugMode)
				log(PlayerReplicationInfo.PlayerName@"no tiene Objetivo, busca otro");
			SelectControlPoint();
		}
		if ( !CheckPotential(50) )
		{
			MoveTarget = BestInventoryPath(Mierda);
			return;
		}

		if (ProximoCamp == none)
		{
			MoveTarget = P;
			return;
		}

		if ( FriendlyCP(P) )
			MoveTarget = ProximoCamp;
		else		
			MoveTarget = P;
	}

//=====================================================================================
//==ESTA VA A SER UNA FUNCION COMPLICADA DEBIDO A LA CANTIDAD DE RAZON HUMANA REQUERIDA
	function ControlPoint SelectControlPoint()
	{
		local ControlPoint Closest;
		local float ClosestDist;
		local float Dist;
		local int i, winner;
		local TeamGamePlus DOM;

		if ( LogicaDeCP() )
		{
			ProximoCamp = none;
			BalancearDefensa();
			FindDefensePointFor( ObjetivoPrimario, Orders);
			if (DebugMode)
				log(PlayerReplicationInfo.PlayerName@"defenderá el punto"@ControlPoint(ObjetivoPrimario).PointName);
			return ControlPoint(ObjetivoPrimario);
		}
		else if (DebugMode)
			log(PlayerReplicationInfo.PlayerName@" ataca por logica");

		ClosestDist = 80000;//Paso Inicial: Buscar Al Mas cercano bajo control enemigo
		//Aplicar peso de punto de control a dist, atacando a los ocupados por el equipo ganador

	
		DOM = TeamGamePlus(Level.Game);
		While( winner < 4) //Sanity checks to avoid accessed none warnings
		{	if ( DOM.Teams[winner] == none )
				winner++;
			else
				break;
		}
	
		For ( i=0 ; i<4 ; i++ )
		{
			if ( i==PlayerReplicationInfo.Team)
				continue;
			if ( (DOM.Teams[i] != none) && (DOM.Teams[i].Score > DOM.Teams[winner].Score) )
				winner = i;
		} //Get the winner (or closest) team to prioritize attack

		CostJumpSpots(false);
		For (i=0; i<iCP; i++)
		{
			if ( !FriendlyCP(ControlPointList[i]) &&  (FindPathToward(ControlPointList[i],,false) != none) )
			{
				Dist = VSize(ControlPointList[i].Location - Location);
				if ( (ControlPointList[i].ControllingTeam != none) && (ControlPointList[i].ControllingTeam.TeamIndex == winner) )
					Dist *= 0.6;
				if (Dist < ClosestDist)
				{
					ClosestDist = Dist;
					Closest = ControlPointList[i];
				}
			}
		}
		CostJumpSpots(true);

		if (Closest != none)
		{
			ProximoCamp = none;
			ObjetivoPrimario = Closest;
			FindDefensePointFor( ObjetivoPrimario, Orders);
			if (DebugMode)
				Log(PlayerReplicationInfo.PlayerName@"atacando a "$Closest.PointName);
		}
		else
			BalancearDefensa();
		bMustChange = false;
		return ControlPoint(ObjetivoPrimario);

	}

	function BalancearDefensa()
	{
		local int Integer1;			//CP mios, luego, CP mios menos defendidos
		local int Integer2;			//Defensas en mi punto, Array CP's menos defendidos
		local int Integer3[8];		//Defesas por CP's (relacionado con CpB)
		local int Integer4;			//Array CP's mios, minimo de defensas, distancia en Int
		local int i;				//Iterador
		local float Float1;			//Distancias;
		local ControlPoint CpA[8];	//CP's menos defendidos
		local ControlPoint CpB[8];	//CP's mios
		local ControlPoint CpC;		//CP mejor

		Integer4 = 0;
		i = 0;


		/* Localizar puntos nuestros */
		For ( i=0 ; i<iCP ; i++)
		{
			if (FriendlyCP(ControlPointList[i]))
			{
				CpB[Integer4] = ControlPointList[i];
				Integer4++;
		}	}

		Integer1 = Integer4;
		Integer4 = 20;


		/* Contar los defensas de cada punto mio y ver el numero mínimo */
		For ( i=0 ; i<Integer1 ; i++ )
		{
			Integer3[i] = GetDefenderCount(
						CpB[i],
						500,
						PlayerReplicationInfo.Team );
			Integer4 = IRango( Integer3[i], Integer4, Integer3[i] , true);
		}


		/* Revisar si cuido algun punto de control y si tiene pocos defensas */
		if ( DefendingPoint(ObjetivoPrimario, self, 500) )
		{
			Integer2 = GetDefenderCount(
						CpB[i],
						500,
						PlayerReplicationInfo.Team );
			if ( ++Integer4 >= Integer2 )
			{
				if (DebugMode)
					log(PlayerReplicationInfo.PlayerName@"stays dafending");
				return;
			}
		}


		/* Localizar a los menos defendidos */
		Integer2 = 0;
		For ( i=0 ; i<Integer1 ; i++ )
		{
			if ( Integer3[i] <= Integer4 )
			{
				CpA[Integer2] = CpB[i];
				Integer2++;
		}	}

		Integer1 = Integer2;

		Integer4 = 20000;
		/* Localizar al mas cercano */
		For ( i=0 ; i<Integer1 ; i++ )
		{
			Float1 = VSize(CpA[i].Location - Location);
			if (Float1 < Integer4)
			{
				CpC = CpA[i];
				Integer4 = Float1;
			}
		}
		ObjetivoPrimario = CpC;
		if (DebugMode)
				log("Proximo punto de defensa de"@PlayerReplicationInfo.PlayerName@"es"@CpC.PointName);
		ProximoCamp = none;

	}

	function bool LogicaDeCP()
	{
		local int EnemyP, MyP, ThisEnemyP;
		local int i;
		local float MyScore;
		local float EnemyScore;
		local int Rourke;
		local TeamGamePlus DOM;

		EnemyP = 0;		MyP = 0;		ThisEnemyP = 0;
		For (i=0; i<iCP; i++)
		{
			if ( FriendlyCP(ControlPointList[i]) )
				MyP++;
			else
				EnemyP++;
		}
		DOM = TeamGamePlus(Level.Game);
		MyScore = DOM.Teams[PlayerReplicationInfo.Team].Score;
		Rourke = PlayerReplicationInfo.Team;

		if (MyP == 0)
			return False; //Attack
		if (EnemyP == 0)
			return True;  //Defend
		if ( (FRand() < 0.7) && (MyP >= EnemyP) && (DOM.GoalTeamScore > 0.5))
			return True;  //Attack, un bot ambicioso

		EnemyScore = 0;
		For (i=0; i<4; i++) //Find Closest 'enemy team' Score
		{
			if (i == PlayerReplicationInfo.Team)
				continue;
			if ( (DOM.Teams[i] != none) && (DOM.Teams[i].Score > EnemyScore) )
			{
				EnemyScore = DOM.Teams[i].Score;
				Rourke = i;
			}
		}

		For (i=0; i<iCP; i++)
		{
			if ( FriendlyCP(ControlPointList[i]) )
				ThisEnemyP++;
		}

		if ( (DOM.GoalTeamScore > 20) &&
( ((DOM.GoalTeamScore - EnemyScore) / ThisEnemyP) > ((DOM.GoalTeamScore - MyScore) / MyP)))
			return True;  //Defend, I think i can win if it keeps like it

		return False;
	}
	function RoamDest()
	{
		local float DDD;
		MoveTarget = BestInventoryPath(DDD);
	}
	function bool CheckCampDistance()
	{
		local float Dist;

		if (ProximoCamp == none)
			return False;

		Dist = VSize(ProximoCamp.Location - Location);
		return (Dist < 110.0);
	}
	function actor FindDefensepointFor( actor DefenseObject, name CodeSign)
	{
		local NavigationPoint N;
		local actor PointList[16]; //Puntos de defensa probables
		local int i;
		local AmbushPoint A;

		i = 0;
		ForEach NavigationActors (class'AmbushPoint', A)
		{
			if ( (VSize(N.Location - DefenseObject.Location) < 500) || FastTrace(N.Location,DefenseObject.Location) )
				PointList[i++] = N;
		}//Agregar otros hold Spots

		if (PointList[0] == none)
			ProximoCamp = DefenseObject;
		else
			ProximoCamp = PointList[ IRango(0, (i - 1), Rand(i) )];

	}
	function bool CanPickProbableInv()
	{
		MoveTarget = none;
		PickLocalInventory(200, 0);

		return ((MoveTarget != none) && MoveTarget.IsA('Inventory'));
	}	
Begin:
BuscarDestino:
	SavedLabel = '';
	ElegirDestino();
	PickLocalInventory(240, 0);
	if (MoveTarget == none)
		Goto('Roam');
	SearchAPath(MoveTarget);
	PostPathEvaluate();
	if (MoveTarget == none)
	{
		StopMoving();
		GotoState('Wander');
	}
	Goto('Moving');
Moving:
	Destination = MoveTarget.Location;
	LifeSignal( HSize(Destination - Location) / GroundSpeed + 0.5);
	SavedLabel = 'PostMove';
	if (LineOfSightTo(FaceTarget) )
	{
		FaceTarget = FinalMoveTarget;
		StrafeFacing(Destination,FaceTarget);
	}
	else
	{
		FaceTarget = None;
		MoveToward(MoveTarget);
	}
	PostMove:
	if (MoveTarget.IsA('ControlPoint'))
	{
			if (DebugMode)
				Log("Alcanzé el punto "$ControlPoint(ObjetivoPrimario).PointName);
			SelectControlPoint();
	}
	if (CheckCampDistance() )
	{
		if ( HSize(location - MoveTarget.location) < 40 )
		{
			LifeSignal( 1);
			MoveTo( NearSpot( MoveTarget.Location, 100) );
		}
		iCampTime = -5;
		if (Proximocamp.bDirectional) Goto('AmbushCamp');
		else Goto('NormalCamp');
	}
	if (MoveTarget == none)
		sleep(0.001);
	else if ( HSize(MoveTarget.Location - Location) < 4 )
		sleep(0.015);
	else if ( (Base != none) && Base.IsA('Mover') && MoveTarget.IsA('LiftCenter') )
		sleep(0.2);
	Goto('BuscarDestino');
Roam:
	if (DebugMode)
		Log("Roam:");
	RoamDest();
	if ( MoveTarget == none )
	{
		StopMoving();
		GotoState('Wander');
	}
	LifeSignal( 2.2);
	SavedLabel = 'PostRoam';
	MoveToward(MoveTarget);
	PostRoam:
	if ( HSize(MoveTarget.Location - Location) < 5 )
		sleep(0.001);
	Goto('BuscarDestino');
NormalCamp:
	StopMoving();
	if (CanPickProbableInv())
		Goto('CampMovement');
	Focus = (FindRandomDest() ).Location;
	if (NeedToTurn( Focus) )
	{
		bTurnControl = True;
		PlayTurning();
		TurnTo( Focus );
	}
	iCampTime += 2;
	LifeSignal(2.3);
	if (bTurnControl)
	{
		Sleep(1.5);
		bTurnControl = False;
	}
	else
		Sleep(2);
	if (!FriendlyCP(ControlPoint(ObjetivoPrimario) ))
		Goto('BuscarDestino');
	if (!CheckCampDistance())
		Goto('ReturnMoving');
	if (iCampTime > MaxCampTime)
	{
		SelectControlPoint();
		ElegirDestino();
	}
	else
		Goto('NormalCamp');
AmbushCamp:
	StopMoving();
	Sleep(0.001);
	TweenToWaiting(0.15);
	if (FRand() > 0.85)
		if (NeedToTurn((FindRandomDest()).Location))
		{
			PlayTurning();
			bTurnControl = True;
			LifeSignal(1);
			TurnTo(SetPointByRotation(DesiredRotation, Location));
		}
	else
		if (DoesNeedToTurn(ProximoCamp.Rotation))
		{
			PlayTurning();
			bTurnControl = True;
			LifeSignal(1);
			TurnTo(SetPointByRotation(DesiredRotation, Location));
		}
	iCampTime++;
	LifeSignal(1.5);
	if (bTurnControl)
		Sleep(0.8);
	if (!FriendlyCP(ControlPoint(ObjetivoPrimario) ))
		Goto('BuscarDestino');
	if (CanPickProbableInv())
		Goto('CampMovement');
	if (!CheckCampDistance())
		Goto('ReturnMoving');
	if (iCampTime > MaxCampTime)
	{
		SelectControlPoint();
		ElegirDestino();
	}
	else
		Goto('AmbushCamp');
ReturnMoving:
	Sleep(0.001);
	if (CheckCampDistance())
	{
		if (ProximoCamp.bDirectional)
			Goto('AmbushCamp');
		else
			Goto('NormalCamp');
	}
	SearchAPath(ProximoCamp);
	MoveToward(MoveTarget);
	LifeSignal(2.6);
	Goto('ReturnMoving');
CampMovement:
	Sleep(0.001);
	SearchAPath(MoveTarget);
	LifeSignal(2.5);
	MoveToward(MoveTarget);
	Sleep(0.3);
	if (CanPickProbableInv())
		Goto('CampMovement');
	Goto('ReturnMoving');
UnStateMove:
	Sleep(0.01);
	if ( CanLeaveUnstate() )
		Goto( SavedLabel);
	UpdateUnstate();
	Goto('UnStateMove');
}

state() Freelancing // ****************************	FREELANCING
{
	event BeginState()
	{
		DistractionLimit -= 0.3;
		SavedState = 'Freelancing';
	}
	event EndState()
	{
		DistractionLimit += 0.3;
	}
	
	function ElegirDestino()
	{
		local float Mierda;
		local actor Caca;
		local ControlPoint CP;
		local Inventory AttT;

		Caca = BestInventoryPath(Mierda);

		if ( CheckPotential( 25 + Precaucion * 10) )
		{
			if ( (ObjetivoPrimario != none) && ObjetivoPrimario.IsA('ControlPoint') )
			{
				if ( FriendlyCP( ControlPoint( ObjetivoPrimario ) ) )
					ObjetivoPrimario = none;
				else
					CP = ControlPoint( ObjetivoPrimario);
			}
			if (CP == none)
				ForEach AllActors (class'ControlPoint', CP)
					if ( !FriendlyCP( CP) )
						if ( VSize(CP.Location - Location) < 600 || FastTrace(CP.Location) )
						{
							ObjetivoPrimario = CP;
							Caca = CP;
							break;
						}
			else
				Caca = CP;
		}
		if ( Caca == none )
			Caca = GameTarget;

		if (Caca != none)
		{
			MoveTarget = Caca;
			FinalMoveTarget = PickRemoteInventory( true);
		}
		PickLocalInventory(220, 0);
	}
	function bool FriendlyCP(ControlPoint DesiredCP)
	{
		if (DesiredCP.ControllingTeam == none)
			return False;
		if (DesiredCP.ControllingTeam.TeamIndex != PlayerReplicationInfo.Team)
			return False;

		return True;
	}
	function FindCampSpot()
	{
		local int i;
		local NavigationPoint AmbushList[24];
		local int iMax;
		local NavigationPoint N; 
		local float Fyt;
		local AmbushPoint A;

		i = 0;
		Fyt = FRand();

		if ( Level.Game.IsA('MissionTeamGame'))
			return;

		if (ProximoCamp == none)
		{
			if (FRand() < 0.3) //Camp sobre un item
			{
				if (Fyt < 0.50 && (PickInventoryForCamping(class'Weapon') != none) )
					AddCampPointFor(ProximoCamp);
				else if (Fyt < 0.80 && (PickInventoryForCamping(class'TournamentPickup') != none))
					AddCampPointFor(ProximoCamp);
				else if (Fyt < 1.00 && (PickInventoryForCamping(class'TournamentHealth') != none))
					AddCampPointFor(ProximoCamp);
				else
				{
					PickInventoryForCamping(class'Inventory');
					AddCampPointFor(ProximoCamp);
				}
			}
			else //Camp en un AmbushSpot
			{
				ForEach NavigationActors (class'AmbushPoint', A)
				{
					if (Level.Game.bTeamGame)
					{	if (!N.Taken)
							AmbushList[i++] = N;	}
					else
						AmbushList[i++] = N;
				}
				iMax = Rand(i);
				ProximoCamp = AmbushList[iMax];
			}
		}

		MoveTarget = ProximoCamp;
		if ( ProximoCamp != none )
			Destination = ProximoCamp.Location;
		FinalMoveTarget = MoveTarget;
	}

	function MayFall()
	{
		bCanJump = True;
		Global.MayFall();
	}
	function bool CheckCampDistance()
	{
		local float Dist;

		Dist = VSize(ProximoCamp.Location - Location);
		if (Dist < 90.0)
			return True;
		else
			return False;
	}

Begin:
Moving:
	SavedLabel = 'Moving';
	ElegirDestino();
	if (bDoesCamp)
	{
		if (iCampTime < 0)
			iCampTime++;
		else
			FindCampSpot();
	}
	if (MoveTarget == none)
	{
		Sleep(0.3);
		Goto('Moving');
	}
	SearchAPath(MoveTarget);
	PostPathEvaluate();
	if ( GetMoveTarget() == none)
	{
		StopMoving();
		LifeSignal(1);
		Sleep(0.8);
		GotoState('Wander'); //Temporario
	}
	if (ProximoCamp != none && CheckCampDistance() )
		Goto('BeginCamp');

	if ((ProximoCamp != none) && (GetMoveTarget() == ProximoCamp))
	{
		Destination = (ProximoCamp.Location + VRand() * 40);
		Destination.Z = ProximoCamp.Location.Z;
		MoveTo(Destination);
		Goto('BeginCamp');
	}
	ScriptMoveToward( GetMoveTarget(), FinalMoveTarget);
	Sleep(0.1);
	while ( ScriptMovePoll() )
		Sleep(0.0);
	Goto('Moving');
BeginCamp:
	SavedLabel = '';
	Sleep(0.001);
	iCampTime = 0;
	SavedState = 'Camping';
	if (ProximoCamp.IsA('InventoryHoldSpot') || ProximoCamp.IsA('Inventory'))
		GotoState('Camping','WeaponCamp');
	else
		GotoState('Camping','NormalCamp');
}

//*********************************** Camping, usado por Freelancing y Defending 
//*********************************** Defending tiene su propio camp...
state() Camping
{
	function bool CanPickProbableInv()
	{
		MoveTarget = none;
		PickLocalInventory(190, 0);

		return ((MoveTarget != none) && MoveTarget.IsA('Inventory'));
	}	
	event EndState()
	{
		SavedLabel = '';
	}
	function bool CheckCampDistance()
	{
		local float Dist;

		Dist = VSize(ProximoCamp.Location - Location);
		if (Dist < 90.0)
			return True;
		else
			return False;
	}
WeaponCamp:
	Sleep(0.001);
	bWeaponCamp = True;
	StopMoving();
	if (CanPickProbableInv())
		Goto('CampMovement');
	TweenToWaiting(0.15);
	FaceTarget = FindRandomDest();
	LifeSignal(0.5);
	if (NeedToTurn(FaceTarget.Location))
	{
		PlayTurning();
		bTurnControl = true;
		TurnToward(FaceTarget);
	}
	iCampTime += 2;
	LifeSignal(2.3);
	if (!bTurnControl)
		Sleep(0.3);
	Sleep(1.7);
	bTurnControl = False;
	if (!CheckCampDistance())
		Goto('ReturnMoving');
	if (iCampTime > MaxCampTime)
	{	ProximoCamp = none;
		QueHacerAhora();
	}
	else
		Goto('WeaponCamp');
NormalCamp:
	Sleep(0.001);
	bWeaponCamp = False;
	StopMoving();
	TweenToWaiting(0.15);
	if (FRand() > 0.85)
		if (NeedToTurn((FindRandomDest()).Location))
		{
			PlayTurning();
			bTurnControl = True;
			LifeSignal(1);
			TurnTo(SetPointByRotation(DesiredRotation, Location));
		}
	else
		if (DoesNeedToTurn(ProximoCamp.Rotation))
		{
			PlayTurning();
			bTurnControl = True;
			LifeSignal(1);
			TurnTo(SetPointByRotation(DesiredRotation, Location));
		}
	iCampTime++;
	LifeSignal(1.5);
	if (bTurnControl)
		Sleep(0.7);
	else
		Sleep(1.15);
	if (CanPickProbableInv())
		Goto('CampMovement');
	if (!CheckCampDistance())
		Goto('ReturnMoving');
	if (iCampTime > MaxCampTime)
	{	ProximoCamp = none;
		QueHacerAhora();
	}
	else
		Goto('NormalCamp');
CampMovement:
	SavedLabel = 'CampMovement';
	Sleep(0.001);
	SearchAPath(MoveTarget);
	LifeSignal(2.5);
	if (bWeaponCamp)
		StrafeFacing(MoveTarget.Location, FaceTarget);
	else
		MoveToward(MoveTarget);
	Sleep(0.3);
	if (CanPickProbableInv())
		Goto('CampMovement');
	Goto('ReturnMoving');
ReturnMoving:
	SavedLabel = 'ReturnMoving';
	Sleep(0.001);
	if (CheckCampDistance())
	{
		if (bWeaponCamp)
			Goto('WeaponCamp');
		else
			Goto('NormalCamp');
	}
	SearchAPath(ProximoCamp);
	LifeSignal(2.6);
	if (bWeaponCamp)
		StrafeFacing(MoveTarget.Location, FaceTarget);
	else
		MoveToward(MoveTarget);
	Goto('ReturnMoving');
UnStateMove:
	Sleep(0.01);
	if ( CanLeaveUnstate() )
		Goto( SavedLabel);
	UpdateUnstate();
	Goto('UnStateMove');
}


/*States
state Sniping			FUTURO: MUY CERCA, si ve un franco muy lejos y esta distraido, fajarlo de un tiro
						Parte de si está implementado en defending y holding
state Hunting

state Translocating		En creación //DESECHADO

state Patrullando
	comentario extra: De esta manera puedo hacer que el Botz se rija con 3 estados únicos:
		InValido, Dead, Moving;	siendo el Moving el que maneja TODO el movimiento...

state Teledirigiendo

state FightAttack		Disparar mientras ataca

state NormalFight		Pelea Basica

state Picador			Disparar a picar a las paredes, ultra defensivo //Uso de infopoints

state DefensiveFight	Mi Estilo

state CagonEye			Huyendo(herido, cagon)
*/

//******************************     HOLD THIS POSITION!
//******************************     AND PATROL
state Holding
{
	function BeginState()
	{
		Disable('AnimEnd');
		SavedState = 'Holding';
		GameTarget = none;
		if ((Orders == 'Hold')&&(!OrderObject.IsA('F_HoldPosition'))&&(MyHoldSpot != none ))
			OrderObject = MyHoldSpot;	//Temporario
		else if ( (Orders == 'Patrol') )
			OrderObject = SetPatrolStop();
		GotoState('Holding','Begin');
		if ( DebugMode )
			Log(" HOLDING: BeginState()");
	}
	event EndState()
	{
		AimPoint.bAimAtPoint = False;
		if ( DebugMode )
			Log(" HOLDING: EndState");
	}
	function Actor SetPatrolStop()
	{
		local float BestDist, Dist;
		local int i;
		local actor Best;

		BestDist = 99999;
		if ( OrderObject == none ) //Pick Nearest
			For (i=0;i<16;i++)
			{	if ( PatrolStops[i] != none )
				{	Dist = VSize( PatrolStops[i].Location - Location);
					if ( Dist < BestDist )
					{	BestDist = Dist;
						Best = PatrolStops[i];
						CurrentPatrol = i;
						bPatrolUp = bool( Rand(2) ); //Si o no, 50 y 50
					}
				}
				else
					break;
			}
		else if ( VSize( OrderObject.Location - Location) < 100 )
		{
			if ( bPatrolUp )
			{	if ( (CurrentPatrol < 15) && (PatrolStops[CurrentPatrol + 1] != none) ) //Subir si se cumple
				{
					if ( PatrolStops[++CurrentPatrol] == none )
						bPatrolUp = False;
					return PatrolStops[CurrentPatrol];
				}
				else if ( CurrentPatrol > 0 )	//Bajar si hay al menos dos
				{
					bPatrolUp = False;
					return PatrolStops[--CurrentPatrol];
				}
				else
				{
					bPatrolUp = false;
					return PatrolStops[0]; //Si no se da lo anterior, obviamente se trata de cero y solo ese punto
				}
			}
			else // Patrol Down
			{
				if ( CurrentPatrol > 0 )	//Bajar si hay al menos dos
				{
					bPatrolUp = (--CurrentPatrol == 0);
					return PatrolStops[CurrentPatrol];
				}
				else
				{
					bPatrolUp = true;
					return PatrolStops[0]; //Si no se da lo anterior, obviamente se trata de cero y solo ese punto
				}
			}
		}
		return Best; //In the end, for safety
	}
	function ElegirDestino()
	{
		local float Mierda;
		local Inventory FavW;

/*
		FavW = FindInventoryType( ArmaFavorita);
		if ( FavW == none )
			FavW = PickNearestItem( ArmaFavorita);
		else if ( FavW.IsA('Weapon') && (Weapon(FavW).AmmoType.AmmoAmount < Weapon(FavW).AmmoType.MaxAmmo * 0.10) )
			FavW = PickNearestItem( Weapon(FavW).AmmoName );
		else
			FavW = none;
*/
		if ( (Orders == 'Patrol') && (OrderObject == none) )
			OrderObject = SetPatrolStop();

		if ( CheckPotential() )
			MoveTarget = OrderObject;
		else
			MoveTarget = BestInventoryPath(Mierda);
		PickLocalInventory(240,0);
	}
	function bool CheckHoldDistance()
	{
		local float Dist;

		if ( OrderObject == none )
		{
			OrderObject = SetPatrolStop();
			return false;
		}
		Dist = VSize( OrderObject.Location - Location);
		if ( (OrderObject.IsA('F_HoldPosition')) && (Dist <= F_HoldPosition(OrderObject).Extension) )
			return True;
		else if ( (OrderObject != none) && InRadiusEntity(OrderObject) )
			return True;
	}
	event AnimEnd()
	{
	}
Begin:
	SavedLabel = '';
	ElegirDestino();
Moving:
	if ( MoveTarget == none )
	{
		sleep(0.01);
		Goto('Begin');
	}
	SearchAPath(MoveTarget);
	PostPathEvaluate();
	if (MoveTarget == none)
	{
		bDoesCamp = true;
		MaxCampTime = 4;
		GotoState('Freelancing','Moving');
		Stop;
	}	
	SavedLabel = 'PostMove';
	MoveToward(Movetarget);
	PostMove:
	if (MoveTarget == OrderObject)
	{
		Destination = (OrderObject.Location + VRand() * 40);
		Destination.Z = OrderObject.Location.Z;
		LifeSignal(0.2);
		MoveTo(Destination);
	}
	if ( (Base != none) && Base.IsA('Mover') && MoveTarget.IsA('LiftCenter') )
		sleep(0.2);
	if ( CheckHoldDistance() )
	{
		if ( (F_HoldPosition(OrderObject) != None) && (Level.TimeSeconds-F_HoldPosition(OrderObject).LastMsgTime > 60 * Level.TimeDilation) )
		{
			SendTeamMessage(PlayerReplicationInfo, 'OTHER', 9, 1.2);
			F_HoldPosition(OrderObject).LastMsgTime = Level.TimeSeconds;
		}
		SwitchToBestWeapon();
		if ( ClassIsChildOf( ArmaFavorita, class'Sniperrifle') )
			GetWeapon( ArmaFavorita);
		Goto('Hold');
	}
	Goto('Begin');
Hold:
	SavedLabel = '';
	Enable('AnimEnd');
	if ( Enemy == none )
		AimPoint.bAimAtPoint = True;
	AimPoint.PointSpot = SetPointByRotation( OrderObject.Rotation, Location);
	if ( Enemy == none )
		LocateEnemy( OrderObject.Rotation, 800);
	Acceleration = vect(0,0,0);
	DesiredRotation = OrderObject.Rotation;
	LifeSignal(1.3);
	Sleep(1);
	Disable('AnimEnd');
	if ( (Orders == 'Patrol') && ((Enemy == none) || !FastTrace(Enemy.Location)) && (AimPoint.AimGuy == none)  )
	{
		LifeSignal(1.3);
		Sleep(1);
		OrderObject = SetPatrolStop();
	}
	if ( DebugMode && (Orders == 'Patrol') && (OrderObject == none) )
		Log(" HOLDING: PostHold, SetPatrolStop() = none");
	MoveTarget = none;
	PickLocalInventory( 500, 0.5 + (Health - 100.0) * 0.005 );
	if ( (MoveTarget != none) && (FRand() < 0.5) )
		Goto('Moving');
	if ( CheckHoldDistance() )
		Goto('Hold');
	AimPoint.bAimAtPoint = False;
	Goto('Begin');
UnStateMove:
	Sleep(0.01);
	if ( CanLeaveUnstate() )
		Goto( SavedLabel);
	UpdateUnstate();
	Goto('UnStateMove');
}

//		CheckHoldSpots()    SPOTS COMPARTIDOS, ETC      TRABAJO FUTURO




state GameEnded
{
ignores SeePlayer, EnemyNotVisible, HearNoise, TakeDamage, Died, Bump, Trigger, HitWall, HeadZoneChange, FootZoneChange, ZoneChange, Falling, WarnTarget, PainTimer;

	function SpecialFire()
	{
	}
	function TryToDuck(vector duckDir, bool bReversed)
	{
	}
	function SetFall()
	{
	}
	function LongFall()
	{
	}
	function Killed(pawn Killer, pawn Other, name damageType)
	{
	}

	function BeginState()
	{
		Disable('Tick');
		Enemy = none;
		AnimRate = 0.0;
		bFire = 0;
		bAltFire = 0;
		SimAnim.Y = 0;
		SetCollision(false,false,false);
		SetPhysics(PHYS_None);
		StopMoving();
	}
}


function TweenToWalking(float tweentime)
	{
		if ( Physics == PHYS_Swimming )
		{
			if ( (vector(Rotation) Dot Acceleration) > 0 )
				TweenToSwimming(tweentime);
			else
				TweenToWaiting(tweentime);
		}
		
		BaseEyeHeight = Default.BaseEyeHeight;
		if (Weapon == None)
			DummyTweenAnim('Walk', tweentime);
		else if ( Weapon.bPointing ) 
		{
			if (Weapon.Mass < 20)
				DummyTweenAnim('WalkSMFR', tweentime);
			else
				DummyTweenAnim('WalkLGFR', tweentime);
		}
		else
		{
			if (Weapon.Mass < 20)
				DummyTweenAnim('WalkSM', tweentime);
			else
				DummyTweenAnim('WalkLG', tweentime);
		} 
	}

function PlayRangedAttack()
{
	TweenToWaiting(0.11);
}

function PlayMovingAttack()
{
}

function PlayOutOfWater()
{
	PlayDuck();
}

function PlayWalking()
{
	if ( Physics == PHYS_Swimming )
	{
		if ( (vector(Rotation) Dot Acceleration) > 0 )
			PlaySwimming();
		else
			PlayWaiting();
		return;
	}

	BaseEyeHeight = Default.BaseEyeHeight;
	if (Weapon == None)
		LoopAnim('Walk');
	else if ( Weapon.bPointing ) 
	{
		if (Weapon.Mass < 20)
			LoopAnim('WalkSMFR');
		else
			LoopAnim('WalkLGFR');
	}
	else
	{
		if (Weapon.Mass < 20)
			LoopAnim('WalkSM');
		else
			LoopAnim('WalkLG');
	}
}



function TweenToWaiting(float tweentime)
{
	if ( Physics == PHYS_Swimming )
	{
		BaseEyeHeight = 0.7 * Default.BaseEyeHeight;
		if ( (Weapon == None) || (Weapon.Mass < 20) )
			TweenAnim('TreadSM', tweentime);
		else
			TweenAnim('TreadLG', tweentime);
	}
	else
	{
		BaseEyeHeight = Default.BaseEyeHeight;
//		if ( Enemy != None )
//			ViewRotation = Rotator(Enemy.Location - Location);
//		else
//		{
//			if ( GetAnimGroup(AnimSequence) == 'Waiting' )
//				return;
//			ViewRotation.Pitch = 0;
//		}
		ViewRotation.Pitch = ViewRotation.Pitch & 65535;
		If ( (ViewRotation.Pitch > RotationRate.Pitch) 
			&& (ViewRotation.Pitch < 65536 - RotationRate.Pitch) )
		{
			If (ViewRotation.Pitch < 32768) 
			{
				if ( (Weapon == None) || (Weapon.Mass < 20) )
					TweenAnim('AimUpSm', 0.3);
				else
					TweenAnim('AimUpLg', 0.3);
			}
			else
			{
				if ( (Weapon == None) || (Weapon.Mass < 20) )
					TweenAnim('AimDnSm', 0.3);
				else
					TweenAnim('AimDnLg', 0.3);
			}
		}
		else if ( (Weapon == None) || (Weapon.Mass < 20) )
			TweenAnim('StillSMFR', tweentime);
		else
			TweenAnim('StillFRRP', tweentime);
	}
}


//FUTURO: play anims from corresponding mesh
function PlayDying(name DamageType, vector HitLoc)
{
	BaseEyeHeight = Default.BaseEyeHeight;
	PlayDyingSound();
		
	if ( (InStr( String(Mesh), "SGirl") != -1) || (InStr( String(Mesh), "FCommando") != -1) )
	{
		PlayDyingF( DamageType, HitLoc);
		return;
	}
		
	if ( (DamageType == 'Suicided') )
	{
		PlayAnim('Dead8',, 0.1);
		return;
	}

	// check for head hit
	if ( (DamageType == 'Decapitated') && !Level.Game.bVeryLowGore )
	{
		PlayDecap();
		return;
	}

	if ( FRand() < 0.15 )
	{
		PlayAnim('Dead2',,0.1);
		return;
	}

	// check for big hit
	if ( (Velocity.Z > 250) && (FRand() < 0.75) )
	{
		if ( FRand() < 0.5 )
			PlayAnim('Dead1',,0.1);
		else
			PlayAnim('Dead11',, 0.1);
		return;
	}

	// check for repeater death
	if ( (Health > -10) && ((DamageType == 'shot') || (DamageType == 'zapped')) )
	{
		PlayAnim('Dead9',, 0.1);
		return;
	}
		
	if ( (HitLoc.Z - Location.Z > 0.7 * CollisionHeight) && !Level.Game.bVeryLowGore )
	{
		if ( FRand() < 0.5 )
			PlayDecap();
		else
			PlayAnim('Dead7',, 0.1);
		return;
	}
	
	if ( Region.Zone.bWaterZone || (FRand() < 0.5) ) //then hit in front or back
		PlayAnim('Dead3',, 0.1);
	else
		PlayAnim('Dead8',, 0.1);
}

function PlayDecap()
{
	local carcass carc;

	PlayAnim('Dead4',, 0.1);
	if ( Level.NetMode != NM_Client )
	{
		carc = Spawn(class 'UT_HeadMale',,, Location + CollisionHeight * vect(0,0,0.8), Rotation + rot(3000,0,16384) );
		if (carc != None)
		{
			carc.Initfor(self);
			carc.Velocity = Velocity + VSize(Velocity) * VRand();
			carc.Velocity.Z = FMax(carc.Velocity.Z, Velocity.Z);
		}
	}
}


function PlayDyingF(name DamageType, vector HitLoc)
{
	local carcass carc;

	BaseEyeHeight = Default.BaseEyeHeight;
	PlayDyingSound();
			
	if ( DamageType == 'Suicided' )
	{
		PlayAnim('Dead3',, 0.1);
		return;
	}

	// check for head hit
	if ( (DamageType == 'Decapitated') && !class'GameInfo'.Default.bVeryLowGore )
	{
		PlayDecapF();
		return;
	}

	if ( FRand() < 0.15 )
	{
		PlayAnim('Dead7',,0.1);
		return;
	}

	// check for big hit
	if ( (Velocity.Z > 250) && (FRand() < 0.75) )
	{
		if ( (HitLoc.Z < Location.Z) && !class'GameInfo'.Default.bVeryLowGore && (FRand() < 0.6) )
		{
			PlayAnim('Dead5',,0.05);
			if ( Level.NetMode != NM_Client )
			{
				carc = Spawn(class 'UT_FemaleFoot',,, Location - CollisionHeight * vect(0,0,0.5));
				if (carc != None)
				{
					carc.Initfor(self);
					carc.Velocity = Velocity + VSize(Velocity) * VRand();
					carc.Velocity.Z = FMax(carc.Velocity.Z, Velocity.Z);
				}
			}
		}
		else
			PlayAnim('Dead2',, 0.1);
		return;
	}

	// check for repeater death
	if ( (Health > -10) && ((DamageType == 'shot') || (DamageType == 'zapped')) )
	{
		PlayAnim('Dead9',, 0.1);
		return;
	}
		
	if ( (HitLoc.Z - Location.Z > 0.7 * CollisionHeight) && !class'GameInfo'.Default.bVeryLowGore )
	{
		if ( FRand() < 0.5 )
			PlayDecap();
		else
			PlayAnim('Dead3',, 0.1);
		return;
	}
	
	//then hit in front or back	
	if ( FRand() < 0.5 ) 
		PlayAnim('Dead4',, 0.1);
	else
		PlayAnim('Dead1',, 0.1);
}

function PlayDecapF()
{
	local carcass carc;

	PlayAnim('Dead6',, 0.1);
	if ( Level.NetMode != NM_Client )
	{
		carc = Spawn(class 'UT_HeadFemale',,, Location + CollisionHeight * vect(0,0,0.8), Rotation + rot(3000,0,16384) );
		if (carc != None)
		{
			carc.Initfor(self);
			carc.Velocity = Velocity + VSize(Velocity) * VRand();
			carc.Velocity.Z = FMax(carc.Velocity.Z, Velocity.Z);
		}
	}
}


function PlayHeadHit(float tweentime)
{
	if ( (AnimSequence == 'HeadHit') || (AnimSequence == 'Dead7') )
		TweenAnim('GutHit', tweentime);
	else if ( FRand() < 0.6 )
		TweenAnim('HeadHit', tweentime);
	else
		TweenAnim('Dead7', tweentime);
}

function PlayLeftHit(float tweentime)
{
	if ( (AnimSequence == 'LeftHit') || (AnimSequence == 'Dead9') )
		TweenAnim('GutHit', tweentime);
	else if ( FRand() < 0.6 )
		TweenAnim('LeftHit', tweentime);
	else 
		TweenAnim('Dead9', tweentime);
}

function PlayRightHit(float tweentime)
{
	if ( (AnimSequence == 'RightHit') || (AnimSequence == 'Dead1') )
		TweenAnim('GutHit', tweentime);
	else if ( FRand() < 0.6 )
		TweenAnim('RightHit', tweentime);
	else
		TweenAnim('Dead1', tweentime);
}

function PlayFlip()
{
	PlayAnim('Flip', 1.35 * FMax(0.35, Region.Zone.ZoneGravity.Z/Region.Zone.Default.ZoneGravity.Z), 0.06);
}

//******************************************************
//OTRAS FUNCIONES DE BOT********************************
//******************************************************
function inventory PickNearestItem( class<Inventory> Sample)
{
	local inventory Inv, BestInv;
	local float NewWeight, BestWeight;

	BestWeight = 5000;
	foreach visiblecollidingactors( class'Inventory', Inv, 5000,,true)
		if ( (Inv.IsInState('PickUp')) && (Inv.Physics != PHYS_Falling) && (Inv.Class == Sample) )
		{
			NewWeight = VSize(Inv.Location - Location);
			if ( NewWeight > 1 )
			{
				if ( NewWeight < BestWeight )
				{
					BestWeight = NewWeight;
					BestInv = Inv;
				}
			}
		}
	return BestInv;
}

function PickLocalInventory(float MaxDist, float MinDistraction)
{
	local inventory Inv, BestInv;
	local float NewWeight, BestWeight;
	local actor BestPath, ItemOfInterest;
	local bool bCanReach;
	local NavigationPoint N;
	local actor NewTarget;

	foreach visiblecollidingactors(class'Inventory', Inv, MaxDist,,true)
		if ( (Inv.IsInState('PickUp')) && (Inv.Physics != PHYS_Falling) && ( (Inv.Location.Z - Inv.CollisionHeight) < (Location.Z + CollisionHeight) ) && ( (Inv.Location.Z < Location.Z) || CanReachInv(Inv)) )
		{
			NewWeight = inv.BotDesireability(self);
			if ( (NewWeight > MinDistraction) 
				 || (Inv.bHeldItem && Inv.IsA('Weapon') && (VSize(Inv.Location - Location) < 0.6 * MaxDist)) )
			{
				if ( ArmaFavorita != none )
				{
					if ( ClassIsChildOf(inv.Class, ArmaFavorita) )
						NewWeight += 0.5;
					if ( ClassIsChildOf(inv.Class, ArmaFavorita.Default.AmmoName ) )
						NewWeight += 0.1;
				}

				NewWeight = NewWeight/VSize(Inv.Location - Location);
				if ( NewWeight > BestWeight )
				{
					BestWeight = NewWeight;
					BestInv = Inv;
				}
			}
		}

	NewTarget = BestInv;
	if ( (BestInv != none) && (BestInv.MyMarker != none) && ( HSize(BestInv.Location - BestInv.MyMarker.Location) < (CollisionRadius + BestInv.CollisionRadius) - 8) && ActorReachable(BestInv.MyMarker) )
		NewTarget = BestInv.MyMarker;
	else
		NewTarget = BestInv;

	if ( MasterEntity.MyTargeter != none )
		ItemOfInterest = MasterEntity.MyTargeter.OldItemOfInterest( self);

	if ( NewTarget != none )
	{
		if ( NewTarget.IsA('TournamentHealth') || NewTarget.IsA('Health') )
			return;
		if ( (InventorySpot(NewTarget) != none) )
		{
			if ( TournamentHealth(InventorySpot(NewTarget).MarkedItem) != none )
				return;
			if ( Health(InventorySpot(NewTarget).MarkedItem) != none )
				return;
		}
	}

	NewTarget = NewTarget Or ItemOfInterest;
	if ( NewTarget != none)
		SetMoveTarget(NewTarget);
}

function WarnTarget(Pawn shooter, float projSpeed, vector FireDir)
{
	local float DistRight, DistLeft, TheDist;
	local bool bShouldJump;
	local bool bNoLeft, bLeft;
	local vector OldAimLocation, X, Y, Z;
	local actor aTarget;

	if ( (Physics != PHYS_Walking) || (Enemy == none) )
		return;

	if ( (FRand() < (0.8 - (Skill / 3)) && (VSize(Velocity) > 150) ) )
		return;

	if ( ( (Shooter != enemy) && (Skill < 4)) || (IsInState('Attacking') && FRand() < 0.4) || ( IsInState('Following') && (VSize(OrderObject.Location - Location) > 900) ) )
		return;

	//FUTURO: aplicar movimiento ofensivo aqui

	TheDist = fClamp( GroundSpeed * RandRange(0.3, 1.2), 120, 340 );
	GetAxes( rotator(shooter.Location - Location), X, Y, Z);
	if ( !TraceToDir( Y, DistLeft, TheDist) )
		bNoLeft = true;
	if ( !TraceToDir( -Y, DistRight, TheDist) && bNoLeft)
		return;	//FUTURO: pasar a movimiento leve a un costado miantras corre

	if ( !bNoLeft && ( (FRand() < 0.5) || !TraceToDir( -Y, DistRight, TheDist)) )
		bLeft = True;

	if ( bLeft )
		Destination = Location + Y * DistLeft;
	else
		Destination = Location - Y * DistRight;

	aTarget = MoveTarget Or SpecialMoveTarget;
	if ( F_TempDest(aTarget) != none )
		aTarget.SetLocation( Destination);
	else
		aTarget = MasterEntity.TempDest().Setup( self, aTarget, 4, Destination);

	if ( (FRand() < 0.7) && (TheDist > 230) && !FastTrace( Destination + vect(0,0,100), Destination) )	//O sea: chance 70%, distancia mayor a 230 y si hay un piso donde caer
	{
		SetBase(none);
		SetPhysics(PHYS_Falling);
		bHasToJump = True;
		ProcessTickJump();
		if ( F_TempDest(aTarget) != none )
		{
			aTarget.SetLocation( AimPoint.Location);
			aTarget.SetTimer(0.5, false);
		}
		PlayDodge( !bLeft);
	}
}

function Actor PickRemoteInventory( optional bool bVisible)
{
	local float ThePrior, TempPrior;
	local Inventory Inv, Best;

	ThePrior = -0.5;
	ForEach DynamicActors( class'Inventory', Inv)
		if ( Inv.IsInState('PickUp'))
		{
			TempPrior = Inv.BotDesireability(self);
			TempPrior -= (VSize(Inv.Location - Location) / 1000);
			if ( (TempPrior > ThePrior) && (!bVisible || LineOfSightTo(Inv)) )
			{
				ThePrior = TempPrior;
				Best = Inv;
			}
		}
	if ( Best != None  )
		return Best.MyMarker Or Best;
	return None;
}

function SetOrders(name NewOrders, Pawn OrderGiver, optional bool bNoAck)
{
	local Pawn P;
	local Bot B;
	local int i;

	if ( bSniping && (NewOrders != 'Defend') )
		bSniping = false;
	if ( !bNoAck && (OrderGiver != None) )
		SendTeamMessage(OrderGiver.PlayerReplicationInfo, 'ACK', Rand(class<ChallengeVoicePack>(PlayerReplicationInfo.VoiceType).Default.NumAcks), 5);

	if ( BotReplicationInfo(PlayerReplicationInfo) != none )
		BotReplicationInfo(PlayerReplicationInfo).SetRealOrderGiver(OrderGiver);
	PlayerReplicationInfo.SetPropertyText( "RealOrders", string(NewOrders) );
	if ( theTrail != none )
		theTrail.Destroy();

	Orders = NewOrders;
	if ( !bNoAck && (HoldSpot(OrderObject) != None) )
	{
		OrderObject.Destroy();
		OrderObject = None;
	}
	if ( Orders == 'Hold' )
	{
		OrderObject = OrderGiver.Spawn(class'F_HoldPosition',self,,OrderGiver.Location,
							OrderGiver.ViewRotation);
		MyHoldSpot = F_HoldPosition(OrderObject);
	}
	else if ( (Orders == 'Follow') || (Orders == 'FollowZ') )
	{
		OrderObject = OrderGiver;
		OObjectName = OrderGiver.PlayerReplicationInfo.PlayerName;
		theTrail = Spawn( class'BotzFollowTrail', none);
		theTrail.Follower = self;
		thetrail.SetOwner(none); //Trail will decide its follower (Reason: error with chat orders)
	}
	else if ( Orders == 'NewPatrol' )
	{
		For ( i=0 ; i<16 ; i++ )
			if ( PatrolStops[i] != none )
			{	PatrolStops[i].Destroy();
				PatrolStops[i] = none;
			}
		PatrolStops[0] = OrderGiver.Spawn(class'F_HoldPosition',self,,OrderGiver.Location,
							OrderGiver.ViewRotation);
		CurrentPatrol = 0;
		Orders = 'Patrol';
	}
	else if ( Orders == 'AddPatrol' )
	{
		For ( i=0 ; i<16 ; i++ )
		{	if (PatrolStops[i] == none)
				break;
		}
		if ( i < 16 )
			PatrolStops[i] = OrderGiver.Spawn(class'F_HoldPosition',self,,OrderGiver.Location,
							OrderGiver.ViewRotation);
		Orders = 'Patrol';
	}

	if ( BotReplicationInfo(PlayerReplicationInfo) != none )
		BotReplicationInfo(PlayerReplicationInfo).OrderObject = OrderObject;

	if ( (Health > 0) && (!IsInState('InitialStand')) && (!IsInState('WaitForStart')) && (!IsInState('BeginGame')) )
		QueHacerAhora();
}
function SetSubOrders(name NewSubOrder, optional actor NewSubOrderObject)//Futuro, CASI
{
	if ( NewSubOrder == 'GetOurFlag' )
	{
		if ( SubOrders != 'GetOurFlag' )
		{	OldSubOrders = SubOrders;
			OldSubOrderObject = SubOrderObject;
		}
	}
	else
	{
		OldSubOrders = '';
		OldSubOrderObject = none;
	}
	SubOrders = NewSubOrder;
	SubOrderObject = NewSubOrderObject;
	if ( (Health > 0) && (!IsInState('InitialStand')) && (!IsInState('WaitForStart')) && (!IsInState('BeginGame')) )
		QueHacerAhora();	
}

function Killed(pawn Killer, pawn Other, name damageType)
{
	local Pawn aPawn;

	if ( Killer == self )
	{
		MasterEntity.MyTargeter.EnemyKilled( self, Other);
		Other.Health = FMin(Other.Health, -11); // don't let other do stagger death
	}

	if ( Health <= 0 )
		return;

	if ( CarcassType == none )
		CarcassType = Default.CarcassType;

	if ( Enemy == Other )
	{
		bFire = 0;
		bAltFire = 0;
		Enemy = None;
		AimPoint.bAimAtPoint = False;
		if (Killer == self)
		{
			ForEach PawnActors (class'Pawn', aPawn, 1600)
				if ( aPawn.bIsPlayer && aPawn.bCollideActors 
					&& CanSee(aPawn) && SetEnemy(aPawn) )
				{
					QueHacerAhora();
					return;
				}

			if (FRand() < 0.85)
			{
				if ( Level.NetMode == NM_StandAlone )
					SendGlobalMessage(none, 'TAUNT', Rand(class<ChallengeVoicePack>(PlayerReplicationInfo.VoiceType).Default.NumTaunts), 0.5);
				else if ( FRand() < 0.1 )
					SendGlobalMessage(none, 'TAUNT', Rand(class<ChallengeVoicePack>(PlayerReplicationInfo.VoiceType).Default.NumTaunts), 0.5);
			}
		}
		else 
			QueHacerAhora();
	}
	else if ( Level.Game.bTeamGame && Other.bIsPlayer && (Other.PlayerReplicationInfo != none)
			&& (Other.PlayerReplicationInfo.Team == PlayerReplicationInfo.Team) )
	{
		if ( Other == Self )
			return;
		else
		{	//Sorry, you got in my way
			if ( Killer == self )
				TeamChat('KilledFriend', Other.PlayerReplicationInfo);
			else if ( (Enemy == none) && (LineOfSightTo(Killer) || FRand() < Skill/7) ) //Suppress the sniper
				SetEnemy(Killer);
		}
	}
}	

function Carcass SpawnCarcass()
{
	local carcass carc;

	carc = Spawn(CarcassType);
	if ( carc != None )
		carc.Initfor(self);

	return carc;
}

function HearNoise(float Loudness, Actor NoiseMaker)
{
	if ( NoiseMaker.Instigator != None )
	{
		SetEnemy(NoiseMaker.Instigator);
		if ( (NoiseMaker.Instigator == Enemy) && (AimPoint.PointTarget != None) )
			AimPoint.SightTimer += Loudness * 0.2;
	}
}

function Died(pawn Killer, name damageType, vector HitLocation)
{
	local pawn OtherPawn;
	local actor A;

	if ( Level.Game.BaseMutator.PreventDeath(self, Killer, damageType, HitLocation) )
	{
		Health = max(Health, 1); //mutator should set this higher
		return;
	}

	ForEach PawnActors( class'Pawn', OtherPawn)
		OtherPawn.Killed(Killer, self, damageType);
	if ( CarriedDecoration != None )
		DropDecoration();
	WeaponProfile = MasterEntity.WProfiles[0];
	level.game.Killed(Killer, self, damageType);
	if( Event != '' )
		foreach AllActors( class 'Actor', A, Event )
			A.Trigger( Self, Killer );
	Level.Game.DiscardInventory(self);
	Velocity.Z *= 1.3;
	PlayDying(DamageType, HitLocation);
	if ( Gibbed(damageType) )
	{
		SpawnGibbedCarcass();
		if ( bIsPlayer )
			HidePlayer();
		else
			Destroy();
	}
	else
		SpawnCarcass();

	if ( CurFlight != none )
	{
		Log("Botz "@PlayerReplicationInfo.PlayerName@"died in flight");
		CurFlight.ForceEndFlight( self);
		Log("Botz "@PlayerReplicationInfo.PlayerName@"out of flight");
		bDebugLog = true;
	}

	if ( Level.Game.bGameEnded )
		return;
	BaddingPaths( Pawn( Killer Or self) );

	if (damagetype == 'RedeemerDeath')
		RespawnTime = 2.5;
	else if (damagetype == 'Decapitated')
		RespawnTime = 4;
	else
		RespawnTime = 1.5;
	if (CriticalSituation)// despues la cambio por un Function Bool que es más práctico
		RespawnTime = 0.1;
	LifeSignal( 5);
	GotoState('Dead');
}
function bool Gibbed( name damageType)
{
	if ( (damageType == 'decapitated') || (damageType == 'shot') )
		return false; 	
	return ( (Health < -80) || ((Health < -40) && (FRand() < 0.6)) );
}


function PlayHit(float Damage, vector HitLocation, name damageType, vector Momentum)
{
	local float rnd;
	local Bubble1 bub;
	local bool bOptionalTakeHit;
	local vector BloodOffset, Mo;

	if (Damage > 1) //spawn some blood
	{
		if (damageType == 'Drowned')
		{
			bub = spawn(class 'Bubble1',,, Location 
				+ 0.7 * CollisionRadius * vector(ViewRotation) + 0.3 * BaseEyeHeight * vect(0,0,1));
			if (bub != None)
				bub.DrawScale = FRand()*0.06+0.04; 
		}
		else if ( damageType != 'Corroded' )
		{
			BloodOffset = 0.2 * CollisionRadius * Normal(HitLocation - Location);
			BloodOffset.Z = BloodOffset.Z * 0.5;
			if ( (!Level.bDropDetail || (FRand() < 0.67))
				&& ((DamageType == 'shot') || (DamageType == 'decapitated') || (DamageType == 'shredded')) )
			{
				Mo = Momentum;
				if ( Mo.Z > 0 )
					Mo.Z *= 0.5;
				spawn(class 'UT_BloodHit',self,,hitLocation + BloodOffset, rotator(Mo));
			}
			else
				spawn(class 'UT_BloodBurst',self,,hitLocation + BloodOffset);
		}
	}	

	PlayTakeHitSound(Damage, damageType, 2);
	if ( ((Weapon == None) || !Weapon.bPointing)
		 && (GetAnimGroup(AnimSequence) != 'Dodge') 
		&& (bOptionalTakeHit || (Momentum.Z > 140) 
			 || (Damage * FRand() > (0.17 + 0.04 * skill) * Health)) ) 
	{
		PlayHitAnim(HitLocation, Damage);
	}
}

function PlayDeathHit(float Damage, vector HitLocation, name damageType, vector Momentum)
{
	local Bubble1 bub;
	local UT_BloodBurst b;
	local vector Mo;

	if ( Region.Zone.bDestructive && (Region.Zone.ExitActor != None) )
		Spawn(Region.Zone.ExitActor);
	if (HeadRegion.Zone.bWaterZone)
	{
		bub = spawn(class 'Bubble1',,, Location 
			+ 0.3 * CollisionRadius * vector(Rotation) + 0.8 * BaseEyeHeight * vect(0,0,1));
		if (bub != None)
			bub.DrawScale = FRand()*0.08+0.03; 
		bub = spawn(class 'Bubble1',,, Location 
			+ 0.2 * CollisionRadius * VRand() + 0.7 * BaseEyeHeight * vect(0,0,1));
		if (bub != None)
			bub.DrawScale = FRand()*0.08+0.03; 
		bub = spawn(class 'Bubble1',,, Location 
			+ 0.3 * CollisionRadius * VRand() + 0.6 * BaseEyeHeight * vect(0,0,1));
		if (bub != None)
			bub.DrawScale = FRand()*0.08+0.03; 
	}
	if ( (DamageType == 'shot') || (DamageType == 'decapitated') )
	{
		Mo = Momentum;
		if ( Mo.Z > 0 )
			Mo.Z *= 0.5;
		spawn(class 'UT_BloodHit',self,,hitLocation, rotator(Mo));
	}
	else if ( (damageType != 'Burned') && (damageType != 'Corroded') 
		 && (damageType != 'Drowned') && (damageType != 'Fell') )
		b = spawn(class 'UT_BloodBurst',self,'', hitLocation);
}

function PlayHitAnim(vector HitLocation, float Damage)
{
	PlayTakeHit(0.08, hitLocation, Damage); 
} 

function bool CheckPotential(optional int MaxHealth)
{
	local int HealthSum, RateCount;
	local Inventory Inv;
	local bool PotenciaEnFuego;
	local weapon Best, Last;
	local float rating, orat;

	PotenciaEnFuego = False;
	HealthSum = Health;
	if ( Inventory == None )
		return false;

	Best = BFM.BotzRateWeapons( self, 0.4 + Precaucion * 0.09, RateCount, HealthSum);
//	if ( DebugMode )
//		Log("CHECKPOTENTIAL: Prec="$Precaucion$", Rated="$RateCount$", Health="$HealthSum$", Best="$Best.GetItemName(string(Best)) );

	if ( Precaucion <= 0 )
		return true;
	if ( (Best == none) || (RateCount < Precaucion * 0.9 - 0.5) )
		return False;

	if ((!Best.IsA('Enforcer')) 		&&
		(!Best.IsA('AutoMag')) 			&&
		(!Best.IsA('ImpactHammer')) 	&&
		(!Best.IsA('ChainSaw')) 		&& 
		(!Best.IsA('DispersionPistol')) )
		PotenciaEnFuego = True;

	if (MaxHealth == 0)
		MaxHealth = 40 + 15 * Precaucion;
	return ( (HealthSum > MaxHealth) && PotenciaEnFuego );
}

function UnderLift(Mover M)
{
	local NavigationPoint N;
	local LiftExit LE;

	// find nearest lift exit and go for that
	if ( (MoveTarget != None) && MoveTarget.IsA('LiftCenter') )
		ForEach NavigationActors ( class'LiftExit', LE)
			if ( (LE.LiftTag == M.Tag) && ActorReachable(N) )
			{
				MoveTarget = LE;
				return;
			}
}
function SendTeamMessage(PlayerReplicationInfo Recipient, name MessageType, byte MessageID, float Wait)
{
	//log(self@"Send message"@MessageType@MessageID@"at"@Level.TimeSeconds);
	if ( (MessageType == OldMessageType) && (MessageID == OldMessageID)
		&& (Level.TimeSeconds - OldMessageTime < Wait) )
		return;

	//log("Passed filter");
	OldMessageID = MessageID;
	OldMessageType = MessageType;

	SendVoiceMessage(PlayerReplicationInfo, Recipient, MessageType, MessageID, 'TEAM');
	LastMsgTime = Level.TimeSeconds;
}

function SendGlobalMessage(PlayerReplicationInfo Recipient, name MessageType, byte MessageID, float Wait)
{

	//log("Fuck that filter, HAHAHAHA");
	OldMessageID = MessageID;
	OldMessageType = MessageType;

	SendVoiceMessage(PlayerReplicationInfo, Recipient, MessageType, MessageID, 'GLOBAL');
}
function BotVoiceMessage(name messagetype, byte messageID, Pawn Sender)
{
	if ( !Level.Game.bTeamGame || (Sender.PlayerReplicationInfo.Team != PlayerReplicationInfo.Team) )
		return;

	if ( messagetype == 'ORDER' )
		SetOrders(class'ChallengeTeamHUD'.default.OrderNames[messageID], Sender);
}
function ZoneChange(ZoneInfo newZone)
{
	local vector jumpDir;

	if ( newZone.bWaterZone )
	{
		RotationRate.Yaw = 200000;
		if (!bCanSwim)
			MoveTimer = -1.0;
		else if (Physics != PHYS_Swimming)
		{
			if (Physics != PHYS_Falling)
				PlayDive(); 
			setPhysics(PHYS_Swimming);
		}
	}
	else if (Physics == PHYS_Swimming)
	{
		RotationRate.Yaw = 50000;
		if ( bCanFly )
			 SetPhysics(PHYS_Flying); 
		else
		{ 
			SetPhysics(PHYS_Falling);
			if ( bCanWalk && (Abs(Acceleration.X) + Abs(Acceleration.Y) > 0)
				&& (Destination.Z >= Location.Z) 
				&& CheckWaterJump(jumpDir) )
				JumpOutOfWater(jumpDir);
			else
				PlayInAir();
		}
	}
}

function JumpOutOfWater(vector jumpDir)
{
	Falling();
	Velocity = jumpDir * WaterSpeed;
	Acceleration = jumpDir * AccelRate;
	velocity.Z = 380; //set here so physics uses this for remainder of tick
	PlayOutOfWater();
	bUpAndOut = true;
}
function SpawnGibbedCarcass()
{
	local carcass carc;

	carc = Spawn(CarcassType);
	if ( carc != None )
	{
		carc.Initfor(self);
		carc.ChunkUp(-1 * Health);
	}
}
function SetMovementPhysics()
{
	if (Physics == PHYS_Falling)
		return;
	if ( Region.Zone.bWaterZone )
		SetPhysics(PHYS_Swimming);
	else
		SetPhysics(PHYS_Walking); 
}
function bool NeedToTurn(vector targ)
{
	local int YawErr;

	DesiredRotation = Rotator(targ - location);
	DesiredRotation.Yaw = DesiredRotation.Yaw & 65535;
	YawErr = (DesiredRotation.Yaw - (Rotation.Yaw & 65535)) & 65535;
	if ( (YawErr < 4000) || (YawErr > 61535) )
		return false;

	return true;
}
function bool DoesNeedToTurn(rotator targ)
{
	local int YawErr;

	DesiredRotation = targ;
	DesiredRotation.Yaw = DesiredRotation.Yaw & 65535;
	YawErr = (DesiredRotation.Yaw - (Rotation.Yaw & 65535)) & 65535;
	if ( (YawErr < 4000) || (YawErr > 61535) )
		return false;

	return true;
}


function eAttitude AttitudeTo(Pawn Other)
{
	local byte result;

	if ( Level.Game.bTeamGame && (PlayerReplicationInfo.Team == Other.PlayerReplicationInfo.Team) )
		return ATTITUDE_Friendly; //teammate

	return ATTITUDE_Hate;
}

//Fire weapon according to profile
function bool ProfileFire( float Delta, optional bool bIsInCombat)
{
	local float fTest;
	local vector aVec;
	
	if ( WeaponProfile.name == 'BaseBotzWeaponProfile' || WeaponProfile.bWeaponAuth )
		return false;
	if ( (CurFlight != none) && CurFlight.bOwnsFire )
		return false;
	//Execute FireWeapon() instead

	if ( CurrentTactic == "DISABLENORMAL" )
	{
		if ( ((TacticExpiration-=Delta) < 0) || Enemy == None )
		{
			CurrentTactic = "";
			return false;
		}
		return true;
	}
	else if ( CurrentTactic == "HOLDBUTTON" )
	{
		if ( (Enemy != none) && CanSee(Enemy) && WeaponProfile.ShouldReleaseOnSight( self, Enemy) )
		{
			CurrentTactic = ""; //Switch away from hold button spam mode
//			Log("ENEMY SEEN RELEASE");
			return false;
		}
		if ( (Accumulator > 0) && (Accumulator - Delta < 0) )
		{
			ExecuteAgain = WeaponProfile.MinRefire;
		}
		else if ( Accumulator <= 0 )
		{
			if ( ExecuteAgain > 0 )
			{
				ExecuteAgain -= Delta;
				HaltFiring();
				return true;
			}
			if ( CombatParamB > 0 )
				Accumulator = RandRange( CombatParamA, CombatParamB);
			else
				Accumulator = CombatParamA;
//			Log("NEW ACCUMULATOR = "$Accumulator);
			WeaponProfile.SuggestFire( self, "HOLDBUTTON");
		}
		return true;
	}
	else if ( CurrentTactic == "COMBO" )
	{
		bKeepEnemy = true;
		AimPoint.PointTarget = self;
		if ( (AimPoint.AimOther == none) || AimPoint.AimOther.bDeleteMe || (AimPoint.AimOther.Target == none) )
		{
			if ( (Accumulator > 0) && (ExecuteAgain > 0) ) //Try until we can fire
			{
				if ( (Enemy != None) && WeaponProfile.SetupCombo(self) )
					Accumulator = 0; //Instantly decide to shoot newly acquired projectile?
				else
					return true;
			}
			else
				Goto DISCARD_COMBO;
		}

		//Is weapon ready to fire?
		if ( Weapon.IsInState('Idle') )
		{
			aVec = AimPoint.AimOther.Location - AimPoint.AimOther.Target.Location;
			fTest = VSize( aVec ) - (Enemy.CollisionRadius+AimPoint.AimOther.CollisionRadius);
			if ( fTest < 50 )
				Goto SHOOT_COMBO;
			else if ( AimPoint.AimOther.Velocity Dot Normal(aVec) < 0 )
			{
				if ( fTest < 170 )
					Goto SHOOT_COMBO;
				else
					Goto DISCARD_COMBO;
			}
		}
		return true;
	//Accumulator is already zero at this stage
	SHOOT_COMBO:
		Log("TRY SHOOT COMBO");
		ViewRotation = Rotator( AimPoint.AimOther.Location - (Location + vect(0,0,0.8) * BaseEyeHeight ) );
		bFire = 0;
		bAltFire = 0;
		Weapon.Fire(1);
		bKeepEnemy = AimPoint.AimOther.bDeleteMe;
		if ( AimPoint.AimOther.bDeleteMe )
		{
	DISCARD_COMBO:
			Log("DISCARD COMBO");
			AimPoint.PointTarget = None;
			AimPoint.AimOther = None;
			bFire = 0;
			bKeepEnemy = false;
			CurrentTactic = "";
		}
		StopWaiting();
		return true;
	}

	//Generic profilefire
	if ( ChargeFireTimer > 0 )
	{
		//Release both fires, set negative charge fire
		if ( (Accumulator >= 0) && (Accumulator - Delta < 0) )
		{
			if ( WeaponProfile.MinRefire > 0 )
				HaltFiring();
			ChargeFireTimer = -WeaponProfile.MinRefire;
			Accumulator = WeaponProfile.MinRefire;
			if ( DebugSoft )
				Log("PROFILEFIRE: ENTERING REFIRE MODE");
			return true;
		}
		else
			return true;
	}
	else if ( ChargeFireTimer < 0 )
	{
		if ( Accumulator <= 0 )
		{
			if ( DebugSoft )
				Log("PROFILEFIRE: WEAPON PROFILE SUGGESTING FIRE");
			WeaponProfile.SuggestFire( self, CurrentTactic);
			return true;
		}
	}



	return false;
}

function FireWeapon()//COMO TELEDIRIGIR REDEEMER!:ROTATOR(MY_REED.LOCATION - ENEMY.LOCATION)
{
	local float AltChance; //SNIPER RIFLE ALWAYS CHANCE 0
	local bool bCanAttack, bOverrideAttack;
	local float Decision;
	local int DaAlt;
	local vector HitLocation, HitNormal;
	local actor aTracing;

	if ( Weapon == none )
		return;
	if ( (CurFlight != none) && CurFlight.bOwnsFire )
		return;
		

	//Wtf is going on here?
	if ( CurrentTactic == "DISABLENORMAL" )
		return;

	bCanAttack = false;
	Decision = (Level.TimeSeconds*0.25)%1.0;
	AltChance = 2; //Inicial, despues cambiado, si no cambia => el arma es inapropiada.

	if (Weapon.IsA('DispersionPistol') )
		AltChance = 0.5;
	else if ( Weapon.IsA('BetrayerIG') )
	{
		bOverrideAttack = true;
		if ( Enemy.PlayerReplicationInfo != none && Enemy.PlayerReplicationInfo.Team == PlayerReplicationInfo.Team )
			AltChance = 1;
		else
			AltChance = 0;
	}
	else if (AttackDistance == AD_Cercana)
	{
		if ( (Weapon.IsA('ChainSaw')) || (Weapon.IsA('ImpactHammer')) )
			AltChance = 0;
		else if ( (Weapon.IsA('Enforcer')) || (Weapon.IsA('Automag')) || (Weapon.IsA('Stinger')) )
			AltChance = 0.3;
		else if ( (Weapon.IsA('UT_BioRifle')) || (Weapon.IsA('GESBioRifle')) || (Weapon.IsA('Razorjack')) )
			AltChance = 0;
		else if ((Weapon.IsA('ShockRifle')) || (Weapon.IsA('ASMD')))
			AltChance = 0.7;
		else if ((Weapon.IsA('PulseGun'))||(Weapon.IsA('Minigun2'))||(Weapon.IsA('Minigun')));
			AltChance = 1;
		if ((Weapon.IsA('UT_EightBall')) || (Weapon.IsA('EightBall')))
			AltChance = 0.3;
		else if (Weapon.IsA('Ripper'))
			AltChance = 0.4; //Redefinir en caso de tirar a picar, FUTURO
		else if ((Weapon.IsA('UT_FlakCannon')) || (Weapon.IsA('FlakCannon')))
			AltChance = 0.17;
		if (Weapon.IsA('CARifle') || Weapon.IsA('GrenadeLauncher') || Weapon.IsA('RocketLaucher') )
			AltChance = 0;
	}
	else if (AttackDistance == AD_Media)
	{
		if ((Weapon.IsA('Enforcer'))	||		(Weapon.IsA('Automag'))	|| 			(Weapon.IsA('ShockRifle'))	||		(Weapon.IsA('ASMD'))		||
			(Weapon.IsA('PulseGun'))	||		(Weapon.IsA('Stinger'))	||
			(Weapon.IsA('UT_EightBall'))||		(Weapon.IsA('EightBall'))	||
			(Weapon.IsA('Ripper'))		||		(Weapon.IsA('UT_FlakCannon'))	|| 			(Weapon.IsA('FlakCannon'))	)
			AltChance = 0;
		else if	((Weapon.IsA('Minigun2')) ||	(Weapon.IsA('Minigun')))
			AltChance = 1;
		if (Weapon.IsA('CARifle') || Weapon.IsA('GrenadeLauncher') || Weapon.IsA('RocketLaucher') )
			AltChance = 0;
	}
	else
	{
		if ((Weapon.IsA('Enforcer'))	||		(Weapon.IsA('Automag'))	|| 			(Weapon.IsA('ShockRifle'))	||		(Weapon.IsA('ASMD'))		||
			(Weapon.IsA('PulseGun'))	||		(Weapon.IsA('UT_EightBall'))||
			(Weapon.IsA('EightBall'))	)
			AltChance = 0;
		else if	((Weapon.IsA('Minigun2')) ||	(Weapon.IsA('Minigun')))
			AltChance = 0;
		if (Weapon.IsA('GrenadeLauncher') || Weapon.IsA('RocketLaucher') )
			AltChance = 0;
		else if (Weapon.IsA('CARifle') )
			AltChance = 0.1;
	}

	if ((Weapon.IsA('SniperRifle'))||(Weapon.IsA('Rifle'))||(Weapon.IsA('SuperShockRifle')))
		AltChance = 0;
	if ( Weapon.IsA('UT_BioRifle') || Weapon.IsA('GESBioRifle') )
		AltChance = 0.2;

	if ((Weapon.IsA('WarHeadLauncher')) && Suicida)
		AltChance = 0; //AGREGAR: SI W=REED Y AD_LEJANA, ALT = 0.75; GOTO(TELEDIRIGIR)
	if ((Weapon.IsA('WarHeadLauncher')) && (AttackDistance == AD_Larga))
		AltChance = 0;


	if ( (Weapon.AmmoType != None) && (Weapon.AmmoType.AmmoAmount > 0) )
		bCanAttack = true;

	if ( AltChance > 1.90 )
	{
		Weapon.RateSelf( DaAlt );
		AltChance = float(DaAlt);
	}

	if ( (Weapon == MyTranslocator) && (Enemy != none) )
	{
		bFire = 0; //Translocator fire is hardcoded
		bAltFire = 0;
		NoDeleteTranslocs = 0.3; //Just in case

		if ( VSize(Enemy.Location - Location) > 1500 )
		{
			SwitchToBestWeapon();
			return;
		}

		if ( MyTranslocator.TTarget == none )
		{
			BotzTranslocateToTarget( Enemy, false, false);
			MyTranslocator.TTarget.LifeSpan = 1.5;
			return;
		}
		else if ( MyTranslocator.TTarget.LifeSpan > 1.5 )
			MyTranslocator.TTarget.LifeSpan = 1.5;
		return;
	}


	aTracing = Trace( HitLocation, HitNormal, vector(ViewRotation) * 65 + Location + vect(0,0,1) * BaseEyeHeight,  Location + vect(0,0,1) * BaseEyeHeight);
	if ( AimPoint.PointTarget != none && (AimPoint.SightTimer < 0.05 + (7-Skill) * 0.1 + Punteria * 0.1) )
		bCanAttack = false;
	else if ( aTracing == Level )
		bCanAttack = (Weapon.bInstantHit || !Weapon.bSplashDamage);
	else if ( bOverrideAttack )
		bCanAttack = true;
	else if ( (Pawn(aTracing) != none) && (Pawn(aTracing).PlayerReplicationInfo != none) && (Pawn(aTracing).PlayerReplicationInfo.Team == PlayerReplicationInfo.Team ) )
		bCanAttack = false;

	PlayFiring();
	if (bCanAttack && (Decision <= 1.2))
	{
		if ( Decision <= AltChance )
		{
			bFire = 0;
			bAltFire = 1;
			Weapon.AltFire(1.0);
		}
		else if (Weapon.IsA('UT_EightBall') )
		{
			if (Accumulator < 0)
			{
				bFire = 0;
				bAltFire = 0;
				Weapon.Fire(1.0);
				bFire = 1;
				Weapon.Fire(1.0);
				Accumulator = RandRange( 0.2, 3);
			}
			else
				bFire = 1;
		}
		else
		{
			if ( bFire != 1) 
			{
				bFire = 1;
				bAltFire = 0;
				Weapon.Fire(1.0);
			}
		}
	}
	else if (FRand() < 0.04)
		SwitchToBestWeapon();
//REDEFINIR TODO, DISPARAR CON RESPECTO AL TIPO Y DIST' DEL ARMA
}
function HaltFiring()
{
	bFire = 0;
	bAltFire = 0;
	if ( (Weapon != None) && (Weapon.AmmoType != None) && (Weapon.AmmoType.AmmoAmount <= 0) && (Weapon.AnimRate == 0) 
		&& (Weapon.IsInState('NormalFire') || Weapon.IsInState('AltFiring')) )
	{
		if ( (PendingWeapon != None) && (PendingWeapon != Weapon) )
		{
			Weapon.bChangeWeapon = true;
			Weapon.Finish();
		}
		else
			Weapon.GotoState('Idle');
	}
	
//	Accumulator = 0.2;
}


//Only overrides anchor if found one
function bool LocateStartAnchor( optional bool bUnreachableAllowed)
{
	local float BestWeight, Weight, ZModify;
	local NavigationPoint N, NewAnchor;
	local vector StartSearch, AdjustedLocation; //Ajust location of paths when considering reachability

	BestWeight = -1;

	//Falling
	if ( (Physics == PHYS_Falling) && (NewAnchor == None) )
	{
		StartSearch = Location + Velocity * vect(0.5,0.5,0.1);
		if ( !FastTrace(StartSearch) )
			StartSearch = Location;
		ForEach NavigationActors( class'NavigationPoint', N, 2000, StartSearch, true)
		{
			AdjustedLocation = BFM.SuperFlyLocation( Self, N.Location);
			//High paths are reachable even if barely touched
			if ( ((Region.Zone.ZoneGravity.Z <= 0) && (AdjustedLocation.Z > N.Location.Z - CollisionHeight * int(class'Botz_NavigBase'.static.IsHighPath(N))))
				|| ((Region.Zone.ZoneGravity.Z > 0) && (AdjustedLocation.Z < N.Location.Z + CollisionHeight)) )
			{
				Weight = 2
						+ int(N.Region.Zone.bWaterZone)
						+ int(N.Region.Zone.DamagePerSec <= 0)
						- HSize(N.Location-StartSearch) * 0.001; //Can substract up to 2
			}
			else
				Weight = -1;
			if ( Weight > BestWeight )
			{
				NewAnchor = N;
				BestWeight = Weight;
			}
		}
	}
	
	
	//Generic
	if ( NewAnchor == None )
	{
		ForEach NavigationActors ( class'NavigationPoint', N, 2000)
		{
			Weight = 2 + int(FastTrace(N.Location)) - VSize(Location - N.Location) * 0.001;
			if ( (Weight > BestWeight) && (bUnreachableAllowed || PointReachable(N.Location)) )
			{
				NewAnchor = N;
				BestWeight = Weight;
			}
		}
	}

	//Water (if generic fails)
	if ( Region.Zone.bWaterZone && (NewAnchor == None) )
	{
		ForEach NavigationActors( class'NavigationPoint', N, 6000,, true)
			if ( N.Region.Zone.bWaterZone )
			{
				Weight = 6 - VSize(Location - N.Location) * 0.001;
				if ( (Weight > BestWeight) && (bUnreachableAllowed || PointReachable(N.Location)) )
				{
					NewAnchor = N;
					BestWeight = Weight;
				}
			}
	}
	
	if ( NewAnchor != None )
	{
		StartAnchor = NewAnchor;
		return true;
	}
}

//AnchorStatus: 0=initial search, 1=found, 2=failure
//Very useful to chain multiple searches on the same bot
//RESET TO ZERO AFTER TICK OR IF NEW BOT IS SEARCHING
function Actor FindPathBotz( Actor PathTarget, out byte AnchorStatus)
{
	local Actor PTarget; //Do not override global MoveTarget
	local int BestWeight;
	local int Dist;
	local NavigationPoint N, EndPoint;
	
	//Rewrite flying navigation to use manual paths
	if ( (Physics != PHYS_Swimming || FastTrace(PathTarget.Location)) && PointReachable(PathTarget.Location) )
		return PathTarget;
	if ( PathTarget.bCollideActors && !PathTarget.bBlockActors && CanReachInv(PathTarget) )
		return PathTarget;
	
	if ( AnchorStatus == 1 )
	{
		if ( StartAnchor == None )
		{
			AnchorStatus = 2;
			return None;
		}
	}
	else
	{
		if ( !LocateStartAnchor( FRand() > VSize(Acceleration)) ) //If bot isn't moving, then we better try unreachable paths for a while
		{
			AnchorStatus = 2;
			return None;
		}
		MapRoutes( StartAnchor, CollisionRadius, CollisionHeight, 0, 'GlobalModifyCost');
	}
	AnchorStatus = 1;

	EndPoint = NavigationPoint(PathTarget);
	if ( (EndPoint != None) && (EndPoint.UpstreamPaths[0] != -1) && (EndPoint.VisitedWeight < 10000000) )
	{
		PTarget = BuildRouteCache( EndPoint, RouteCache) Or EndPoint;
		return PTarget;
	}
	
	//Prioritize shooting down the enemy 
	BestWeight = 10000000;
	if ( (Pawn(PathTarget) != None) && (Weapon != None) && Weapon.bInstantHit && SetEnemy( Pawn(PathTarget), true) )
	{
		ForEach NavigationActors( class'NavigationPoint', N, 8000, PathTarget.Location, true)
			if ( N.VisitedWeight < BestWeight )
			{
				EndPoint = N;
				BestWeight = N.VisitedWeight;
			}
			
		PTarget = BuildRouteCache( EndPoint, RouteCache);
		if ( (EndPoint != None) && InRadiusEntity(EndPoint) )
			Enemy = Pawn(PathTarget);
		return PTarget;
	}

	if ( (Inventory(PathTarget) != None) && (Inventory(PathTarget).MyMarker != None) )
	{
		PTarget = BuildRouteCache( Inventory(PathTarget).MyMarker, RouteCache);
		if ( Inventory(PathTarget).MyMarker.VisitedWeight < 10000000 && PTarget == None )
			Log("ERROR: Found path to"@PathTarget@"but route caching failed"@RouteCache[0] );
		return PTarget;
	}

	ForEach NavigationActors( class'NavigationPoint', N, 2000, PathTarget.Location, true)
		if ( N.VisitedWeight < BestWeight )
		{
			//If N is higher, the better
			Dist = VSize(N.Location - PathTarget.Location) * 4 + (PathTarget.Location.Z - N.Location.Z) / 2;
			if ( N.VisitedWeight + Dist < BestWeight )
			{
				EndPoint = N;
				BestWeight = N.VisitedWeight + Dist;
			}
		}

	PTarget = BuildRouteCache( EndPoint, RouteCache);
	return PTarget;
} 

//bPathAlreadySearched sirve para evitar que se busque camino redundantemente (usado por attacking?)
function SearchAPath(actor PathTarget)
{
	local BaselevelPoint FerP;
	local NavigationPoint N;
	local byte AnchorStatus, ForceTarget;

	SpecialMoveTarget = none;
	MoveTarget = none;
	if ( ForceState != '' && !IsInState(ForceState) )
	{
		if ( ForceLabel == '' )
			GotoState( ForceState);
		else
			GotoState( ForceState, ForceLabel);
		ForceState = '';
		ForceLabel = '';
		return;
	}

	if (PathTarget == none)
	{
		Log("Error: Called SearchAPath without specifying variable 'PathTarget', in State: "$ GetStateName() $"");
		return;
	}
	
	FerP = BaseLevelPoint(PathTarget);
	if (FerP != none) //MOVE THIS CODE TO BaseLevelPoint
	{
		if ( (FerP.ClosestNode != none) && !InRadiusEntity(FerP.ClosestNode) )
			PathTarget = FerP.ClosestNode;
		else if ( ActorReachable(FerP) )
		{
			MoveTarget = FerP;
			return;
		}
		else if (FerP.bJumpBoot && ((JumpZ > 500) || (Region.Zone.ZoneGravity.Z > -649) ))
		{
			HighJump(FerP);
			return;
		}
		else if (FerP.bTransloc && bHasTranslocator)
		{
			TranslocateToTarget(FerP);
			return;
		}
	}
	
	if ( (MasterEntity != None) && (MasterEntity.MyTargeter != None) )
		PathTarget = MasterEntity.MyTargeter.ModifyAttraction( Self, PathTarget, ForceTarget);

	//If game profile wants to force this target, don't do any pathfinding at all
	if ( ForceTarget != 0 )	MoveTarget = PathTarget;
	else					MoveTarget = FindPathBotz( PathTarget, AnchorStatus);

	//PathFinding ultimately failed
	if ( MoveTarget == None )
	{
		//If pathfinding fails, we have this alternative of using the route cache
		if ( RouteCache[0] != None && (VSize(Location - RouteCache[0].Location) < CollisionRadius*2) )
			PopRouteCache( true);
	}
	else
		Destination = MoveTarget.Location;
}

function bool NewFlightRoute( actor Dest)
{
	local NavigationPoint OldCache[16];
	local int i;
	local actor NewMT;

	if ( iFlight <= 0 )
		return false;
	For ( i=0 ; i<16 ; i++ )
		OldCache[i] = RouteCache[i];
	NewMT = FindFlyingPathToward( Dest);
	if ( NewMT == none )
		Goto RESET_CACHE;
	For ( i=0 ; i<16 ; i++ )
		if ( OldCache[i] != RouteCache[i] )
			Goto VALIDATE_FLIGHT;
//	Log("TEST2 ROUTE ERROR"@OldCache[0]@RouteCache[0]@OldCache[1]@RouteCache[1]@OldCache[2]@RouteCache[2]);
	Goto RESET_CACHE;
VALIDATE_FLIGHT:
	For ( i=0 ; i<iFlight ; i++ )
		if ( FlightProfiles[i].ValidateRoute( self) )
		{
			CurFlight = FlightProfiles[i];
			break;
		}
	if ( CurFlight != none )
	{	MoveTarget = NewMT;
		if ( DebugMode )			Log("START FLIGHT USING: "$ string(CurFlight.Name) );
		return true;
	}
RESET_CACHE:
	For ( i=0 ; i<16 ; i++ )
		RouteCache[i] = OldCache[i];
}

function NavigationPoint FindCurrentPath( optional class<NavigationPoint> NClass)
{
	local NavigationPoint N, best;
	local float Dist, BestDist;

	BestDist = CollisionRadius+CollisionHeight;
	ForEach NavigationActors ( NClass, N, BestDist )
	{
		Dist = VSize( Location - N.Location);
		if ( InRadiusEntity(N) )
			Dist *= 0.5;
		if ( Dist < BestDist )
		{
			BestDist = Dist;
			best = N;
		}
	}
	return best;
}

function bool CanHighJump()
{
	return ((JumpZ > 500) || (Region.Zone.ZoneGravity.Z > -800) );
}

//Este codigo no solo activa los LiftCenter especiales
function CostJumpSpots(bool TheCost)
{
	local NavigationPoint N;
	
	if ( MasterEntity != none )
	{
		MasterEntity.CostBase( TheCost);
		if ( bCanTranslocate )
		{
			MasterEntity.CostJump( TheCost);
			MasterEntity.CostTransloc( TheCost);
		}
		else if ( CanHighJump() )
			MasterEntity.CostJump( TheCost);
	}
}




function bool CanReachInv(actor TheInv)//Prototipo
{
	local vector X, aPoint, bPoint, Y, Z;
	local vector TheNormal;
	local  float TheDist;
	local bool result;

	if ( (Inventory(TheInv) == none) && (FortStandard(TheInv) == none) && (Trigger(TheInv) == none) )
		return False;
	if ( abs(TheInv.Location.Z - Location.Z) > (CollisionHeight + TheInv.CollisionHeight) )
		return False;

	if ( DebugMode )
		Log( "Start: CanReachInv");


//Chequeo 1: ambos puntos perifericos deben poder conectarse
	aPoint = Location + HNormal( TheInv.Location - Location) * CollisionRadius;
	bPoint = TheInv.Location + HNormal( Location - TheInv.Location) * TheInv.CollisionRadius;
	if ( !FastTrace( bPoint, aPoint) )
	{
		GetAxes( Rotator(TheInv.Location - Location), X, Y, Z);
		//Handle Left
		bPoint = TheInv.Location + Normal( Y*3 - X) * TheInv.CollisionRadius;
		if ( FastTrace( bPoint) )
			Goto AP;
			
		//Handle Right
		bPoint = TheInv.Location + Normal( Y*(-3) - X) * TheInv.CollisionRadius;
		if ( FastTrace( bPoint) )
			Goto AP;
		if ( DebugMode )
			Log("CanReachInv failed on"@GetItemName( string(TheInv)) );
		return false;
	}


//Chequeo 2: puedo alcanzar el punto mas cercano que me permita tocar el inv?
	bPoint = TheInv.Location + HNormal( Location - TheInv.Location) * (TheInv.CollisionRadius + CollisionRadius * 0.7);

AP:
	if ( TheInv.Location.Z > (Location.Z + CollisionHeight * 0.7) )
		bPoint.Z -= TheInv.CollisionHeight;

	result = (/*(FRand() < 0.1) ||*/ PointReachable( bPoint));
	if ( result && debugMode )
		Log( "CanReachInv succesful on"@GetItemName( string(TheInv) ) );
	if ( !result && debugMode )
		Log( "CanReachInv unsuccesful on"@GetItemName( string(TheInv) ) );

	return result;
}

function PreSetMovement()
{
	if (JumpZ > 0)
		bCanJump = true;
	bCanWalk = true;
	bCanSwim = true;
	bCanFly = false;
	MinHitWall = -0.2;
	bCanOpenDoors = true;
	bCanDoSpecial = true;
}
event UpdateEyeHeight(float DeltaTime)
{
	local float smooth, bound, TargetYaw, TargetPitch;
	local Pawn P;
	local rotator OldViewRotation, RealViewRotation;
	local vector T;
	local bool bHasMut;
	local mutator TheMut;
	local int i, j;

	if (bHidden )
		return;

	if ( LastTranslocCounter >= 0 )
		LastTranslocCounter -= DeltaTime;

	if ( MyMutator != none )
		bHasMut = True;

	if (bHasMut)
		i = 10;
	else
		i = 7;

	// update viewrotation
	OldViewRotation = ViewRotation;			

	j = 7.0 + Skill * 1.5 + ( 5.0 - Punteria);

//********COMBAT VIEW
	if ( (AimPoint == none) || ((CurFlight != none) && CurFlight.bOwnsAim) )
		Goto AFTERAIMPOINT;

	if ( AimPoint.PointTarget != none )
	{
		RealViewRotation = rotator(AimPoint.Location - Location);
		if ( (DeltaTime < 0.14) && (!bSuperAim || (bFire == 0 && bAltFire == 0)) ) //Ignorar SuperAim si no estoy disparando
		{
			OldViewRotation.Yaw = OldViewRotation.Yaw & 65535;
			OldViewRotation.Pitch = OldViewRotation.Pitch & 65535;
			TargetYaw = float(RealViewRotation.Yaw & 65535);
			if ( Abs(TargetYaw - OldViewRotation.Yaw) > 32768 )
			{
				if ( TargetYaw < OldViewRotation.Yaw )
					TargetYaw += 65536;
				else
					TargetYaw -= 65536;
			}
			TargetYaw = float(OldViewRotation.Yaw) * (1 - j * DeltaTime) + TargetYaw * j * DeltaTime;
			ViewRotation.Yaw = int(TargetYaw);


			TargetPitch = float(RealViewRotation.Pitch & 65535);
			if ( Abs(TargetPitch - OldViewRotation.Pitch) > 32768 )
			{
				if ( TargetPitch < OldViewRotation.Pitch )
					TargetPitch += 65536;
				else
					TargetPitch -= 65536;
			}
			TargetPitch = float(OldViewRotation.Pitch) * (1 - j * DeltaTime) + TargetPitch * j * DeltaTime;
			ViewRotation.Pitch = int(TargetPitch);
		}
		else
			ViewRotation = RealViewRotation;
		DesiredRotation = ViewRotation;
	}
	else if ( (bFire == 0) && (bAltFire == 0) && !bPendingTransloc)
		ViewRotation = Rotation;

	//Why is this?
	if ( DeltaTime == 0.0)
		return;

//***************
	//check if still viewtarget

	if ( ( (Enemy == None) || !LineOfSightTo(Enemy)  || bPendingTransloc) && (AimPoint.AimGuy == none) )
	{
		ViewRotation.Roll = 0;
		if ( DeltaTime < 0.14 )
		{
			OldViewRotation.Yaw = OldViewRotation.Yaw & 65535;
			OldViewRotation.Pitch = OldViewRotation.Pitch & 65535;
			TargetYaw = float(ViewRotation.Yaw & 65535);
			if ( Abs(TargetYaw - OldViewRotation.Yaw) > 32768 )
			{
				if ( TargetYaw < OldViewRotation.Yaw )
					TargetYaw += 65536;
				else
					TargetYaw -= 65536;
			}
			TargetYaw = float(OldViewRotation.Yaw) * (1 - i * DeltaTime) + TargetYaw * i * DeltaTime;
			ViewRotation.Yaw = int(TargetYaw);


			TargetPitch = float(ViewRotation.Pitch & 65535);
			if ( Abs(TargetPitch - OldViewRotation.Pitch) > 32768 )
			{
				if ( TargetPitch < OldViewRotation.Pitch )
					TargetPitch += 65536;
				else
					TargetPitch -= 65536;
			}
			TargetPitch = float(OldViewRotation.Pitch) * (1 - i * DeltaTime) + TargetPitch * i * DeltaTime;
			ViewRotation.Pitch = int(TargetPitch);
			
		}
	}

	AFTERAIMPOINT:

	if ( (Health > 0) && (DeltaTime > 0) )
		AnimationControl();

	smooth = FMin(1.0, 10.0 * DeltaTime/Level.TimeDilation);
	// smooth up/down stairs
	If ( (Physics == PHYS_Walking) && !bJustLanded)
	{
		EyeHeight = (EyeHeight - Location.Z + OldLocation.Z) * (1 - smooth) + BaseEyeHeight * smooth;
		bound = -0.5 * CollisionHeight;
		if (EyeHeight < bound)
			EyeHeight = bound;
		else
		{
			bound = CollisionHeight + FMin(FMax(0.0,(OldLocation.Z - Location.Z)), MaxStepHeight); 
			 if ( EyeHeight > bound )
				EyeHeight = bound;
		}
	}
	else
	{
		smooth = FMax(smooth, 0.35);
		bJustLanded = false;
		EyeHeight = EyeHeight * ( 1 - smooth) + BaseEyeHeight * smooth;
	}
}


//PickItemCamp
function Inventory PickInventoryForCamping(class<Inventory> InvClass)
{
	local actor Inv;
	local int i;
	local int iRand;
	local inventory InvList[64];

	i = 0;

	ForEach AllActors (InvClass, Inv)
	{
		if (Inventory(Inv).MyMarker != none)
		{
			InvList[i] = Inventory(Inv);
			i++;
		}
		if (i >= 64)
			break;
	}

	ProximoCamp = none;
	if (i <= 0)
		return none;

	iRand = Rand(i);
	if (iRand == i)
		iRand--;

	ProximoCamp = InvList[iRand];
	return InvList[iRand];
}
//Crear Puntos De Camping
function AddCampPointFor(actor CampTarget)
{
	local InventoryHoldSpot TheHold;
	local InventoryHoldSpot TempHold;
	local vector Verga;

	if ( CampTarget == none )
		return;
	ForEach AllActors (class'InventoryHoldSpot', TempHold)
		if (TempHold.ItemProtegido == Inventory(CampTarget))
		{
			TheHold = TempHold;
			break;
		}

	if (TheHold == none)
	{
		TheHold = CampTarget.Spawn(class'InventoryHoldSpot');
		Verga = TheHold.Location;
		Verga.Z = TheHold.Location.Z + 20;
		TheHold.SetLocation(Verga);
		TheHold.ItemProtegido = Inventory(CampTarget);
	}

	ProximoCamp = TheHold;
}

//************************************Static States Statetis***********************
//*****************************************************************************
//*********Basicamente, Estados intermedios que no duran mas de 15 seg******
//*************************************************************************
//*************************************************************************
state Wander
{
	function bool FindReachablePath() //Futuro, permitir transloc
	{
		local navigationpoint N, translocAlt;
		local int NumPathsNow;

		For (N=Level.NavigationPointList ; N!=none ; N=N.NextNavigationPoint)
		{
			if ( !InRadiusEntity(N) && !N.IsA('Teleporter') && (PointReachable(N.Location) || (Physics == PHYS_Falling) || (Physics == PHYS_Swimming) ) )
			{
				NumPathsNow++;
				if ( FRand() <= ( 1.0 / float(NumPathsNow)) )
				{	MoveTarget = N;	//Por anti-teletranke
					Destination = N.Location;
				}
			}
		}
		if ( NumPathsNow > 0 )
			return True;
		return False;
	}
	event Tick( float Delta)
	{
		if ( (NoDeleteTranslocs > 0) && (VSize( Location - OldLocation) > 100) )
		{
			if ( Physics == PHYS_Falling)
			{	Velocity.Y = 0;
				Velocity.X = 0;
			}
			StopMoving();
		}
		Global.Tick( Delta);
		//Sort of unstate movement
		if ( (Physics == PHYS_Falling) && (SpecialMoveTarget == None) && (MoveTarget != none) && (MoveTarget.Location.Z > Location.Z) && (HSize(MoveTarget.Location - Location) > 50) && (HSize(Acceleration) < 100) )
			Acceleration = Normal(Acceleration) * GroundSpeed; //Corregir bug: saltar y caer en el propio teletransportador
	//Bajo prueba TEST
	}
	function Vector FindRandomDestination()
	{
		local vector Result;
		local vector Temp;
		local vector Temp2;
		local vector HitLocation;
		local vector HitNormal;
		local int i;

		if ( (Physics == PHYS_Falling) || (Physics == PHYS_Swimming) || (Physics == PHYS_None) )
			return vect(0,0,0);

		SpecialMoveTarget = None;
		Result = vect(0,0,0);
		Do
		{
			i++;
			Temp = ( VRand() * RandRange(100,500) );
			Temp.Z *= 0.3;
			Temp += Location; //Elegir un punto a tal distancia

			Temp2 = Temp;
			Temp2.Z -= 1000;  //Elegir otro mucho mas abajo
			if ( FastTrace(Temp, Temp2) )
				continue;	  //Hay peligro de caida, resetear

			Trace( HitLocation, HitNormal, Temp2, Temp); //Averiguar distancia del punto 
														 //Al piso que hay abajo
			Hitlocation.Z += 50;
			Result = HitLocation;
			if ( i>300)
				break;
		} Until ( PointReachable(Result) )

		return Result;
	}
Begin:
	LifeSignal(3);
	StopMoving();
	Sleep(0.001);
	if ( !FindReachablePath() )
		Destination = FindRandomDestination();
	if ( Destination != vect(0,0,0) ) //No moverse hasta tocar tierra (evita un crash en domination-free)
	{
		if ( (MoveTarget != None) && (MoveTarget.Location == Destination) )
			SwitchToUnstate();
		MoveTo(Destination);
	}
	else
		Sleep(1.0);
	if ( SavedState != '' )
		ResumeSaved();
	else
		QueHacerAhora();
	Sleep(0.02);
UnStateMove:
	LifeSignal(0.2);
	if ( Physics == PHYS_Falling )
	{
		Sleep( 0.05);
		Goto('UnStateMove');
	}
	bHasToJump = True;
	if ( (MoveTarget != none) && ActorReachable(MoveTarget) && !InRadiusEntity(MoveTarget) )
		MoveToward(MoveTarget);
	QueHacerAhora();
}

state ImpactMode
{
ignores seeplayer, hearnoise, warntarget;
//MoveTarget should be preset first
	event BeginState()
	{
		MoveTarget = none;
		SpecialMoveTarget = none;
		MoveTimer = -1;
	}
	event EndState()
	{
		AimPoint.AimOther = none;
		AimPoint.bAimAtPoint = false;
		bPendingTransloc = false;
		bShouldDuck = false;
		FinalMoveTarget = none;
		BaseEyeHeight = Default.BaseEyeHeight;
	}
	event Tick( float Delta)
	{
		if ( (MyTranslocator != none) && (PendingWeapon == MyTranslocator) )
		{
			Enemy = none;
			bFire = 0;
			bAltFire = 0;
		}
		if ( TranslocatorTarget(AimPoint.AimOther) != none )
		{
			Enemy = none;
			bFire = 1;
			bAltFire = 0;
		}
		Global.Tick(Delta);
	}
	event HitWall( vector HitNormal, actor Wall)
	{
		QueHacerAhora();
	}
	function bool FullTranslocCharge() //Is charge good enough to reach my movetarget? if so, launch
	{
		local ImpactHammer Piston;
		local float ChargeSize;
		local vector SimMomentum, SimVel;
		local int i;

		Piston = ImpactHammer( Weapon);
		if ( Piston == none)
			return false;
		if ( (MyTranslocator == none) || (MyTranslocator.TTarget == none) )
			return false;
		if ( FinalMoveTarget == none )
			return false;
		if ( bFire == 0)
		{
			Log("Why is bFire 0?, setting it back to 1");
			bFire = 1;
		}


		if ( MyTranslocator.TTarget.Physics == PHYS_Falling ) //BUG?
			MyTranslocator.Enable('Tick');

		ChargeSize = FMin(Piston.ChargeSize * 1.2, 1.5);

		if ( bShouldDuck )
			SimMomentum = 66000.0 * ChargeSize * Normal(MyTranslocator.TTarget.Location - Location);
		else
			SimMomentum = 66000.0 * ChargeSize * Normal(MyTranslocator.TTarget.Location - (Location+VectZ(BaseEyeHeight)) );
		
		SimVel = SimMomentum/MyTranslocator.TTarget.Mass;
		SimVel.Z = FMax(SimVel.Z, 0.7 * VSize(SimVel));

		SimMomentum = BFM.AdvancedJump( MyTranslocator.TTarget.Location, FinalMoveTarget.Location, Region.Zone.ZoneGravity.Z, SimVel.Z, HSize(SimVel)*1.1);

		if ( (HSize(SimMomentum) > HSize(SimVel)*1.02) && (ChargeSize < 1.5) )
			return false;

		if ( DebugMode && ChargeSize == 1.5)
			Log("Top chargesize was necessary, why? CalculatedVel="$HSize(SimMomentum)$", RawVel="$HSize(SimVel) );

		MyTranslocator.TTarget.SetPhysics( PHYS_Falling);
		MyTranslocator.TTarget.Velocity = SimMomentum;
		MyTranslocator.TTarget.LifeSpan = 15;
		MyTranslocator.TTarget.DesiredTarget = FinalMoveTarget;
		MyTranslocator.TTarget.Enable('Tick');
		BotzTTarget(MyTranslocator.TTarget).bAvoidErase = true;
		BotzTTarget(MyTranslocator.TTarget).bImpactLaunch = true;
		BotzTTarget(MyTranslocator.TTarget).PostTarget = FinalMoveTarget;

		bFire = 0;
		Piston.GotoState('FireBlast');
		Piston.PlayFiring();
		
		if ( DebugMode )	
			Log("Launch success!");

		return true;
	}
	singular event BaseChange()
	{
		if ( Base == Level )
			bAirTransloc = False;
		Super.BaseChange();
		if ( Physics != PHYS_Falling )
			bSuperAccel = false;
	}

ImpactJump:

TranslocLaunch:
	if ( FinalMoveTarget == none)
	{
		sleep(0.01);
		ResumeSaved();
		sleep(0.01);
	}
	PendingWeapon = MyTranslocator;
	if ( (Weapon != none) && (Weapon != MyTranslocator) )
		Weapon.PutDown();
	Destination = Location + normal(FinalMoveTarget.Location - Location) * 150;
	if ( !PointReachable( Destination) )
		AimPoint.AimOther = spawn( class'F_HoldPosition',,, Location - vect(0,0,60) ); //Aim below me
	else
		AimPoint.AimOther = spawn( class'F_HoldPosition',,, Destination - vect(0,0,60) ); //Aim ahead
	AimPoint.AimOther.Disable('Timer');
	AimPoint.AimOther.LifeSpan = 4.5;
	AimPoint.bAimAtPoint = true;
	LifeSignal( 4.0);
	bPendingTransloc = true;
	NoDeleteTranslocs = 3;
	Destination = Location - (HNormal( FinalMoveTarget.Location - Location) * 50);
	MoveTo(Destination);
	ReTGet:
		sleep(0.01); //1 frame
		if ( Weapon != MyTranslocator )
		{
			PendingWeapon = MyTranslocator;
			if ( Weapon != none)
				Weapon.PutDown();
			Goto('ReTGet');
		}
		LifeSignal(2.0); //Don't get stuck
		if (EnemyAimingAt( self) || (VSize(FinalMoveTarget.Location - Location) < 2000) )
		{
			QueHacerAhora();
			sleep(0.01);
		}
	ReTUp:
		sleep(0.01);
		if ( Weapon != MyTranslocator )
		{
			if ( PendingWeapon == MyTranslocator)
				Goto('ReTUp');
			else
				Goto('ReTGet');
		}
		if ( MyTranslocator.bWeaponUp && MyTranslocator.IsInState('Idle') )
		{
/*			if ( MyTranslocator.TTarget != none)
			{
				MyTranslocator.TTarget.Destroy();
				MyTranslocator.TTarget = none;
			}
*/			Weapon.Fire(1.0);
			if ( MyTranslocator.TTarget == none)
				Goto('ReTUp');
			else
				ReplaceTTarget( MyTranslocator.TTarget);
		}
		else
			Goto('ReTUp');
		MyTranslocator.TTarget.LifeSpan = 25;
		MyTranslocator.TTarget.SetCollisionSize(3,3);
		MyTranslocator.TTarget.DesiredTarget = FinalMoveTarget;
		NoDeleteTranslocs = 3;
		GetWeapon(class'BotPack.ImpactHammer');
		LifeSignal(2.6);
		if (EnemyAimingAt( self) )
		{
			QueHacerAhora();
			sleep(0.01);
		}
	ImpTGet:
		sleep(0.01);
		if ( (Weapon == none) || !Weapon.IsA('ImpactHammer') )
		{
			GetWeapon( class'BotPack.ImpactHammer');
			Goto('ImpTGet');
		}
		LifeSignal(2.3);
		NoDeleteTranslocs = 3;
		if (EnemyAimingAt( self) )
		{
			QueHacerAhora();
			sleep(0.01);
		}
	TtoGround:
		sleep(0.01);
		if ( (MyTranslocator.TTarget == none) || !FastTrace(MyTranslocator.TTarget.Location) )
			QueHacerAhora();
		if ( MyTranslocator.TTarget.Physics == PHYS_Falling )
			Goto('TtoGround');
		AimPoint.AimOther = MyTranslocator.TTarget;
		AimPoint.bAimAtPoint = true;
		BotzTTarget(MyTranslocator.TTarget).bTeleImpact = true;
		NoDeleteTranslocs = 3;
		Weapon.Fire(1.0);
		bFire = 1;
		LifeSignal(6);
		if (EnemyAimingAt( self) )
		{
			QueHacerAhora();
			sleep(0.01);
		}
	BeforeLaunch:
		sleep( 0.01);
		BaseEyeHeight = Default.BaseEyeHeight;
		if ( MyTranslocator.TTarget == none)
		{
			ResumeSaved();
			sleep(0.01);
		}
		Destination = MyTranslocator.TTarget.Location + vect(0,0,25) - (HNormal( FinalMoveTarget.Location - MyTranslocator.TTarget.Location) * (60 + float(bShouldDuck) * 5) );
		if ( HSize(Destination - Location) > CollisionRadius )
			MoveTo(Destination);

		if ( bShouldDuck )
			BaseEyeHeight = 0;

		if ( !FastTrace( MyTranslocator.TTarget.Location) )
		{
			if ( ImpactHammer(Weapon) != none )
				Weapon.GotoState('FireBlast');
			ResumeSaved();
			sleep(0.01);
		}

		if ( !FullTranslocCharge() )
		{
			sleep(0.01);
			if ( bShouldDuck )
				BaseEyeHeight = 0;
			if ( !FullTranslocCharge() )
				Goto('BeforeLaunch');
		}
		NoDeleteTranslocs = 7;
		PendingWeapon = MyTranslocator;
		LifeSignal( 2.3);
		sleep( 2.2 - Skill / 7.0);
		if ( (bFire == 1) && ImpactHammer(Weapon) != none )
			Weapon.GotoState('FireBlast');

		if ( EnemyAimingAt(self) )
		{
			LastTranslocCounter = 2.5;
			QueHacerAhora();
		}
		else
			LifeSignal( 2);
}

state TranslocationChain
{
	ignores SeePlayer, WarnTarget;

	event BeginState()
	{
		SpecialMoveTarget = none;
//		Log("Entering TranslocationChain");
	}
	function bool SeekNextPoint( float MinDist, float MaxDist)
	{
		local int i, iMax;
		local vector HitLocation, HitNormal, StartAt, DesignedVec;

		For ( i=15 ; i>=0 ; i-- )
			if ( RouteCache[i] != none )
			{
				iMax = i;
				break;
			}


		if ( (iMax <= 0) || (VSize(RouteCache[iMax].Location - Location) < 120) )
			return false;

		i = iMax;
		MoveTarget = none;
		While (i >= 0)
		{
			if ( RouteCache[i] == none )
			{
				i--;
				continue;
			}

			if ( (VSize( RouteCache[i].Location - Location) < 300) && FastTrace(RouteCache[i].Location) )
			{
				if ( (i!=iMax) && HSize( RouteCache[i].Location - Location) < 70 )
					return false;
				FinalMoveTarget = RouteCache[i];
				return true;
			}

			if ( FastTrace(RouteCache[i].Location) || FastTrace(CeilAt(RouteCache[i].Location, 150)) )
			{
				StartAt = Location + Normal( RouteCache[i].Location - Location) * RandRange( MinDist, MaxDist);
				StartAt = CeilAt( StartAt, 50 + FRand() * 40 );
				if ( !FastTrace(StartAt - vect(0,0,280), StartAt) && FastTrace( StartAt) )
				{
					FinalMoveTarget = InsertBogus( StartAt, 3.5);
					break;
				}
				StartAt = Location + Normal( RouteCache[i].Location - Location) * MaxDist;
				StartAt = CeilAt( StartAt, 50 + FRand() * 40 );
				if ( !FastTrace(StartAt - vect(0,0,280), StartAt) && FastTrace( StartAt) )
				{
					FinalMoveTarget = InsertBogus( StartAt, 3.5);
					break;
				}
				StartAt = Location + Normal( RouteCache[i].Location - Location) * MinDist;
				StartAt = CeilAt( StartAt, 50 + FRand() * 40 );
				if ( !FastTrace(StartAt - vect(0,0,280), StartAt) && FastTrace( StartAt) )
				{
					FinalMoveTarget = InsertBogus( StartAt, 3.5);
					break;
				}
			}
			--i;
		}

		if ( FinalMoveTarget != none )
		{
			if ( BaseLevelPoint(FinalMoveTarget) != none && (HSize(FinalMoveTarget.Location - Location) < 50) )
			{
				FinalMoveTarget = RouteCache[i+1];
				return (FinalMoveTarget != none);
			}
	
			if ( FRand() < 0.4 ) //Remove one element in RouteCache list
				PopRouteCache();

			Acceleration = normal(normal(StartAt - Location) + VRand()) * GroundSpeed;
			//Alter destination
			return true;
		}
		
		return false;

	}
	function vector CeilAt( vector StartAt, float MaxDist)
	{
		local vector hitlocation, hitnormal;

		CollideTrace( hitlocation, hitnormal, StartAt + vect(0,0,1)*MaxDist, StartAt);
		if ( !FastTrace(hitlocation) )
			return StartAt;
		return hitlocation - vect(0,0,40);
	}
	function BaseLevelPoint InsertBogus( vector InsertAt, optional float LifeTime)
	{
		local BaseLevelPoint Bogus;
		if ( LifeTime == 0.0 )
			LifeTime = 2.5;
			
		Bogus = Spawn(class'BaseLevelPoint',,, InsertAt);
		Bogus.LifeSpan = LifeTime;
		return Bogus;
	}
	event Tick( float Delta)
	{
		PendingWeapon = MyTranslocator;
		if ( Weapon == MyTranslocator )
		{
			PendingWeapon = none;
			if ( Weapon.IsInState('DownWeapon') )
				Weapon.GotoState('Idle');
		}
	}

Begin:
	sleep( 0.10);
FireTransloc:
	Sleep( 0.10 + (MaxSkill-Skill) / 15 );
	SwitchToWeapon( MyTranslocator);
	if ( !SeekNextPoint( 320 + TacticalAbility * 2 + Skill * 2, 510 + TacticalAbility * 4 + Skill * 4) )
		Goto('LeaveNow');
	ViewRotation = Rotator( FinalMoveTarget.Location - Location);
	if ( MyTranslocator.TTarget == none)
		BotzTranslocateToTarget( FinalMoveTarget, false, false);
	else
		Goto('LeaveNow');
	if ( MyTranslocator.TTarget == none)
		Goto('FireTransloc');
	MyTranslocator.TTarget.LifeSpan = 3.5;
Waiting:
	Sleep(0.002);
	if ( FinalMoveTarget == none )
	{
		Log("FinalMoveTarget disappeared?");
		Goto('LeaveNow');
	}



	if (MyTranslocator.TTarget == none)
	{
		Acceleration = (vector(viewRotation) + VRand()) * GroundSpeed;
		Velocity = (Velocity + Acceleration*vect(1,1,0)) * 0.5;
		Velocity.Z *= 1.8; //Bot cheat
		FastInAir();

		if ( (FRand() < 0.4) && EnemyAimingAt(self,true) )
			Goto('LeaveNow');

		if ( (FRand() < 0.1) && EnemyAimingAt(self) )
			Goto('LeaveNow');
		
		Goto('FireTransloc');
	}
	else if ( MyTranslocator.TTarget.Physics != PHYS_Falling )
	{
		if ( Physics == PHYS_Falling )
			MyTranslocator.Translocate();
		Goto('LeaveNow');
	}

	Goto('Waiting');
UnStateMove:
	WaitForLanding();
LeaveNow:
	QueHacerAhora();
}


//Ignore game goals and execute a combat movement, override most functions here
state CombatState
{
ignores warntarget, hitwall;

	event BeginState()
	{
		MoveTarget = none;
		SpecialMoveTarget = none;
		FinalMoveTarget = none;
		MoveTimer = -1;
		Destination = vect(0,0,0);
		bKeepEnemy = true;
		Enable('Tick');
		MoveAgain = 0;
//		Log("ENTERED COMBATSTATE");
	}
	event EndState()
	{
		bKeepEnemy = false;
//		Log("LEFT COMBATSTATE");
	}

	singular event BaseChange()
	{
		bHasToJump = false;
		Global.BaseChange();
		bHasToJump = true;
	}

	function bool FindWayTo( optional actor aTarget)
	{
		local actor aTest;

		if ( aTarget == none )
			aTarget = Enemy;
		if ( aTarget == none )
			return false;
			
		aTest = FindPathToward( aTarget);
		if ( (RouteCache[1] != none) && PointReachable(RouteCache[1].Location) )
			aTest = RouteCache[1];
		if ( aTest != none )
		{
			Destination = Normal(aTest.Location - Location) * 2500;
			return true;
		}
		return false;
	}
	
	//Find a proper destination in this time
	//If bTickedJump is set here, JUMP, else, set a dodge
	function vector FindDestTo( vector DesiredDest, float TimeT, optional bool bUseJump)
	{
		local vector HitLocation, HitNormal;
		
		if ( Physics == PHYS_Walking )
		{
			if ( !bUseJump )
				DesiredDest = Normal( DesiredDest * vect(1,1,0)) * GroundSpeed * TimeT;
			else
			{
				if ( (DodgeAgain <= 0) && FastTrace( Location + (HNormal(DesiredDest) * GroundSpeed * 0.30) - vect(0,0,20), Location - vect(0,0,20)) )
				{
					MyCombo = Enemy;
					return Normal( DesiredDest * vect(1,1,0)) * GroundSpeed * 0.30; //Dodge
				}
				DesiredDest = Normal( DesiredDest * vect(1,1,0)) * GroundSpeed * 0.3;
			}
		}
		else		
		{
			bUseJump = false;
			DesiredDest = Normal( DesiredDest) * GroundSpeed * TimeT;
		}

		//NEEDS CODE BEFORE THIS
		CollideTrace( HitLocation, HitNormal, Location + DesiredDest);
		if ( VSize(HitLocation - (Location+DesiredDest) ) > 5 )
			return vect(0,0,0);

		if ( Physics == PHYS_Falling )			DesiredDest.Z = 0;
		if ( bUseJump )			bTickedJump = true;

		return DesiredDest;
	}
	
	//Find proper place to take cover
	function vector TakeCover( actor CoverFrom)
	{
		if ( CoverFrom == none )	return vect(0,0,0);
	}
	
	//Retreat to a safe spot, globalize this function later
	function vector RetreatSpot( actor RetreatFrom)
	{
		local NavigationPoint N, aN[3], thisOne;
		local actor aS, aE;
		local int i[3], iBest[3], k, h; //Best combination so far
		local float best, current[3], cdist; //Add distance difference, add extra 300 if not visible
		
		if ( RetreatFrom == none )	return vect(0,0,0);
		if ( !FastTrace(RetreatFrom.Location) )	return vect(0,0,1); //Special code meaning: already hiding

		N = NavigationPoint(FindPathToward( RetreatFrom));
		if ( N == none ) //Enemy is too close or no paths
			return HNormal( Location - RetreatFrom.Location) * 200 + VRand() * vect(100,100,0);

		cdist = VSize( N.Location - RetreatFrom.Location);
		best = 999999;

		While ( (N.Paths[ i[0] ] > 0) && ( i[0] <16) )
		{
			N.describeSpec( N.Paths[ i[0] ], aS, aE, h, k); 
			aN[0] = NavigationPoint( aE);
			if ( aN[0] != none )
			{
				i[1] = 0;
				current[0] = VSize( aN[0].Location - RetreatFrom.Location) - cdist - VSize(Location - aN[0].Location) * 0.2;
				if ( (VSize(aN[0].Location - Location) < VSize(RetreatFrom.Location - aN[0].Location) ) && !FastTrace(aN[0].Location, RetreatFrom.Location) )
				{
					thisOne = aN[0];
					Goto END_LOOP;
				}
				While ( (aN[0].Paths[ i[1] ] > 0) && ( i[1] <16) )
				{
					aN[0].describeSpec( aN[0].Paths[ i[1] ], aS, aE, h, k);   //Whops!, aN[1] never exists here lol
					aN[1] = NavigationPoint( aE);
					if ( aN[1] != none )
					{
						i[2] = 0;
						current[1] = VSize( aN[1].Location - RetreatFrom.Location) - cdist - VSize(Location - aN[1].Location) * 0.2;
						if ( (VSize(aN[1].Location - Location) < VSize(RetreatFrom.Location - aN[1].Location) ) && !FastTrace(aN[1].Location, RetreatFrom.Location) )
						{
							thisOne = aN[1];
							Goto END_LOOP;
						}
						While ( (aN[1].Paths[ i[2] ] > 0) && ( i[2] <16) )
						{
							aN[1].describeSpec( aN[1].Paths[ i[2] ], aS, aE, h, k); 
							aN[2] = NavigationPoint( aE);
							if ( aN[2] != none )
							{
								current[2] = VSize( aN[2].Location - RetreatFrom.Location) - cdist - VSize(Location - aN[2].Location) * 0.2;
								if ( (VSize(aN[2].Location - Location) < VSize(RetreatFrom.Location - aN[2].Location) ) && !FastTrace(aN[2].Location, RetreatFrom.Location) )
								{
									thisOne = aN[2];
									Goto END_LOOP;
								}
								if ( current[0] + current[1] + current[2] < best )
								{
									best = current[0] + current[1] + current[2];
									iBest[0] = N.Paths[ i[0] ];
									iBest[1] = aN[0].Paths[ i[1] ];
									iBest[2] = aN[1].Paths[ i[2] ];
								}
							}
							++i[2];
						}

					}
					++i[1];
				}
			}
			++i[0];
		}

		//Loop ended without optimal target!
		aN[1].describeSpec( iBest[0], aS, aE, h, k);
		FinalMoveTarget = aE;
		return Normal(aE.Location - Location) * 2500;

		END_LOOP:
		FinalMoveTarget = thisOne;
		return Normal(thisOne.Location - Location) * 2500;
	}
	
	event Tick( float Delta)
	{
		if ( Enemy == none )
		{
			ResumeSaved();
			return;
		}

		MoveAgain -= Delta;
		ExecuteAgain -= Delta;
		if ( ExecuteAgain < -8 ) //Lockdown?
		{
			QueHacerAhora();
			return;
		}
		//Evaluate weapon change and profile update?
		Global.Tick( Delta);
	}

//COMBO FIRE!
Combo:
	if ( (AimPoint.AimOther != None) && !FastTrace(Location+Velocity, AimPoint.AimOther.Location+AimPoint.AimOther.Velocity) )
		StopMoving();
	Sleep(0.8 - Skill*0.1);
	ResumeSaved();
	Stop;
//LURE THE ENEMY
Lure:
	if ( ExecuteAgain <= 0 || (Enemy == none) )
	{
		CurrentTactic = "";
		Goto('Finish');
	}
	if ( MoveAgain <= 0 )
	{
		if ( (Physics == PHYS_Falling) && (bCombatBool) ) //FUTURO, TEST THIS
		{
			Sleep(0.0);
			Goto('Lure');
		}
		bCombatBool = false;
		MoveAgain = ((14 - Skill) - TacticalAbility ) * 0.10;

		if ( !FastTrace( Enemy.Location) )
		{
			if ( Acceleration != vect(0,0,0) )
				DesiredRotation = rotator( Location - OldLocation); //Rotate behind me
			AimPoint.SetLocation( vector(DesiredRotation) * 100);
			Acceleration = vect(0,0,0);
			Sleep(0.0);
//			Log("STAND STILL");
			Goto('Lure');
		}

		if ( FinalMoveTarget == none )
		{
			Destination = RetreatSpot( Enemy);
			if ( FinalMoveTarget != none )
				Goto('ReLure');
			Acceleration = FindDestTo( Destination, MoveAgain, false ) * 500;
			if ( DebugMode )
				Log("NO LURE ZONE");
		}
		else
		{
			ReLure:
			if ( !FindWayTo( FinalMoveTarget) )
				Goto('BadFinish');
			Acceleration = FindDestTo( Destination, MoveAgain, (Skill + TacticalAbility) * FRand() > 2 + 7 * FRand() ) * 500;
//			Log("LURING ENEMY");
			if ( bTickedJump )
			{
				Velocity.Z += Default.JumpZ * fMax(1.0, Level.Game.PlayerJumpZScaling() );
				Acceleration = Normal( Destination) * 2500;
				PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
				PlayInAir();
				SetPhysics( PHYS_Falling);
				bTickedJump = false;
				bCombatBool = true; //In air it means: don't change acceleration if timer hits
			}
			else if ( MyCombo != none )
			{
				MyCombo = none;
				Acceleration = Normal( Destination) * 2500;
				Velocity = HNormal( Destination) * GroundSpeed * 1.4;
				Velocity.Z = 165;
				PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
				PlayInAir();
				SetPhysics( PHYS_Falling);
				bCombatBool = true; //In air it means: don't change acceleration if timer hits
					if ( VSize(HNormal(Destination) - HNormal(vector(Rotation) )) < 0.4 )
						PlayFlip();
					else if ( VSize(HNormal(Destination) - HNormal(vector(Rotation) )) > 1.80 )
						TweenAnim('DodgeB', 0.35);
					else if ( Vector(rotator((Enemy.Location - Location)*vect(1,1,0) ) - rotator(Destination * vect(1,1,0))).Y > 0 )
						PlayDodge( False);
					else
						PlayDodge( True);
			}
			else
			{
				Acceleration = Normal( Destination) * 2500;
			}
		
		}
	}
	Sleep(0.0);
	Goto('Lure');
//CHARGE!
Charge: //CombatParamA = recommended distancem, CombatParamB = strafe factor
	if ( ExecuteAgain <= 0 || (Enemy == none) )
		Goto('Finish');
	if ( MyCombo != none )
		Acceleration = MyCombo.Location - Location;
	if ( MoveAgain <= 0 )
	{
		if ( (Physics == PHYS_Falling) && bCombatBool ) //FUTURO, TEST THIS
		{
			Sleep(0.0);
			Goto('Charge');
		}
		bCombatBool = false;
		MyCombo = none; //Accelerate to this place...

		//Base value goes from 14 to 5
		MoveAgain = ((14 - Skill) - (1 + Aggresiveness)) * 0.06;
		LifeSignal( 2 + MoveAgain );
		if ( !PointReachable(Enemy.Location) )
		{
			if ( !FindWayTo( Enemy) )
				Goto('BadFinish');
			Acceleration = Destination;
		}
		else
		{
			if ( VSize(Location - Enemy.Location) > (CombatParamA * RandRange(1.0, 1.2) ) )
			{
				//Beyond effective range, charge
				//Never stick to a wall, decide if charge or strafe
				//Base charge: enemy not aiming
				//Higher aggesiveness = charge ahead, higher strafe factor = less charge ahead
				if ( !BFM.CompareRotation( Enemy.Rotation, Rotator(Location - Enemy.Location), 5000 + 2000 * Aggresiveness + 2000 * CombatParamB, false) )
				{
					Acceleration = Normal( Enemy.Location - Location) * 2500; //FUTURO, CAMBIAR POR ALGO MAS LIMPIO?
					Sleep( 0.0);
					Goto('Charge');
				}
				//Enemy possibly aiming, skill and tactics determines strafing
				else if ( (Enemy.bFire + Enemy.bAltFire == 0) && (FRand() * Skill > CombatParamB * 5) )
				{
					Acceleration = Normal( Enemy.Location - Location) * 2500; //FUTURO, CAMBIAR POR ALGO MAS LIMPIO?
					Sleep( 0.0);
					Goto('Charge');
				}

				bCombatBool = FRand() < 0.5;
				CombatInt = 0;
			OtherSide:
				if ( bCombatBool )
					Destination = FindDestTo( (Enemy.Location - Location) >> Rot(0,8192,0) , MoveAgain, (16-(Skill+TacticalAbility)) * FRand() < 2);
				else
					Destination = FindDestTo( (Enemy.Location - Location) << Rot(0,8192,0) , MoveAgain, (16-(Skill+TacticalAbility)) * FRand() < 2);

				++CombatInt;
				if ( bTickedJump )
				{
					Velocity.Z += Default.JumpZ * fMax(1.0, Level.Game.PlayerJumpZScaling() );
					Acceleration = Normal( Destination) * 2500;
					PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
					PlayInAir();
					SetPhysics( PHYS_Falling);
					bTickedJump = false;
					bCombatBool = true; //In air it means: don't change acceleration if timer hits
				}
				else if ( MyCombo != none )
				{
					Acceleration = Normal( Destination) * 2500;
					Velocity = HNormal( Destination) * GroundSpeed * 1.4;
					Velocity.Z = 165;
					PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
					PlayInAir();
					SetPhysics( PHYS_Falling);
					bCombatBool = true; //In air it means: don't change acceleration if timer hits
					if ( Vector(rotator((Enemy.Location - Location)*vect(1,1,0) ) - rotator(Destination * vect(1,1,0))).Y > 0 )
						PlayDodge( False);
					else
						PlayDodge( True);
				}
				else if ( Destination != vect(0,0,0) )
				{
					Acceleration = Normal( Destination) * 2500; //Cambiar?
				}
				else
				{
					bCombatBool = !bCombatBool;
					if ( CombatInt > 1 )
					{
						Acceleration = Normal( Enemy.Location - Location) * 2500; //FUTURO, CAMBIAR POR ALGO MAS LIMPIO?
						Sleep( 0.0);
						Goto('Charge');
					}
					Goto('OtherSide');
				}
			}
			else //NOT DONE YET!
			{
				Sleep(0.0); //LAZY SHIT HERE, LURE MODE IF TOO CLOSE LOL
				Acceleration = vect(0,0,0);
				Goto('Lure');
				Log("IMPLEMENT MORE!");
			}
		}
	}
	Sleep(0.0);
	Goto('Charge');
BadFinish:
//	Log("CAN'T CONTINUE COMBAT");
	bCombatBool = false;
	CombatInt = 0;
	CombatWeariness = -5;
	ResumeSaved();
	Sleep(1);
Finish:
	if ( Health < 90 )
		CombatWeariness += 0.2;
	if ( Health < 50 )
		CombatWeariness += 0.2;
	if ( CheckPotential() )
		CombatWeariness -= 0.3;
	if ( (Enemy != none) && (Enemy.Health < 50) )
		CombatWeariness -= 0.1;
	//If i have teammate, continue fighting
	CombatWeariness += 1.0;
	Sleep(0.1);
	if ( (CombatWeariness > 5) || (CombatWeariness < 0) )
	{
		if ( DebugSoft )
			Log("POST-FINISH; WEARY");
		if (CombatWeariness > 0)			CombatWeariness = Aggresiveness - 6;
		CurrentTactic = "";
		if ( SavedState != '' )
			ResumeSaved();
		else
			QueHacerAhora();
		Sleep(1);
	}
	else if ( WeaponProfile.name != 'BotzBaseWeaponProfile' )
	{
		if ( DebugSoft )
			Log("POST-FINISH; NORMAL");
		if ( !WeaponProfile.SuggestCombat( self, CurrentTactic) )
			QueHacerAhora();
		else
		{
			if ( CurrentTactic == "CHARGE" ) Goto('Charge');
			if ( CurrentTactic == "LURE" ) Goto('Lure');
		}			
	}
	else
	{
		if ( DebugSoft )
			Log("POST-FINISH; CHANGEDWEAPON");
		CurrentTactic = "";
		if ( SavedState != '' )
			ResumeSaved();
		else
			QueHacerAhora();
	}
	//Same weapon, ask the profile again?
	//Find another enemy?
}

function UpdateProfile( Weapon thisWeapon)
{
	local int i;

	CurrentTactic = "";
	ChargeFireTimer = 0;
	Accumulator = 0;
	SafeAimDist = 0;

	if ( thisWeapon != None )
	{
		i = MasterEntity.WProfileCount;
		While ( --i > 0 )
		{
			if ( ClassIsChildOf(thisWeapon.class, MasterEntity.WProfiles[i].WeaponClass) )
			{
				WeaponProfile = MasterEntity.WProfiles[i];
				SafeAimDist = WeaponProfile.SafeAimDist;
				return;
			}
		}
	}
	WeaponProfile = MasterEntity.WProfiles[0];
}

/*
function AccelSpeed()
{
	if ( Physics = Phys
}
*/
//FUTURO, set dodge, execute in timer
function SetDodge( rotator TheRot, vector TheAccel, EDodgeDir NewDir)
{
}

//***************************************
//***************************BasicHitWall
//***************************************
	function HitWall(vector HitNormal, actor Wall)
	{
		local actor aTarget;

		if (( Physics == PHYS_Falling) || (Wall == None) )
			return;

		Focus = Destination;
		bHasToJump = False;
		aTarget = MoveTarget Or SpecialMoveTarget;
		if ( Wall.IsA('Mover') && Mover(Wall).HandleDoor(self) )
		{
			if ( SpecialPause > 0 )
				Acceleration = vect(0,0,0);
		}
		else if ( (Physics == PHYS_Walking) && PickWallAdjust())
		{
			if ( Physics == PHYS_Falling )
			{	TweenToFalling();
				PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
			}
			else
				bTickedJump = true;
		}
		else if ( aTarget == none )
		{
			//Just for bug-fixing
		}
		else if ( Physics == PHYS_Walking && (aTarget.Location.Z > Location.Z + 50) && BFM.CanFlyTo( Location, aTarget.Location, Region.Zone.ZoneGravity.Z, JumpZ * 1.01, GroundSpeed * 1.05) )
			bTickedJump = true; 			//Weird low-grav link
		else/* if ( MoveTarget != none )*/
			EludeWallBetween( aTarget, 2);
	}

event Bump( Actor Other)
{
	local Actor aTarget;
	aTarget = MoveTarget Or SpecialMoveTarget;
	if ( IsMoving() && (Physics != PHYS_Falling) && (Other != aTarget) && (F_TempDest(aTarget) == none) )
	{
		if ( VSize(HNormal( Location - OldLocation) - HNormal( Velocity)) > 0.7 ) //Significant obstruction
			EludeWallBetween( MoveTarget Or SpecialMoveTarget, 3);
	}
	Super.Bump(Other);
}

event MayFall()
{
	if ( !bCanJump && bUnstateMove )
	{
		if ( F_TempDest(SpecialMoveTarget) != None )
			F_TempDest(SpecialMoveTarget).ReachedByBot();
		else
			bCanJump = true;
	}
	bCanJump = true;
/*
	SetPhysics(PHYS_Falling);
	if ( (MoveTarget != none) && MoveTarget.bIsPawn)
		Velocity = FAdjustJump(MoveTarget.Location, true, true);
	else
		Velocity = FAdjustJump(Destination, true, true);
	PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
	bTickedJump = True;
*/
}

function HighJump(actor JumpDest, optional bool bBaseSpeed)
{
	local vector Vectus, Vectality;
	local rotator aRot, eRot;

	SpecialMoveTarget = JumpDest;
	MoveTarget = JumpDest;
	if ( bScriptedMove || bUnstateMove )
		MoveTarget = None;
	bHasToJump = False;

	if ( (JumpSpot(JumpDest) != none) && JumpSpot(JumpDest).bAlwaysAccel )
		bSuperAccel = true;

	if ( BFM.CanFlyTo( Location, JumpDest.Location, Region.Zone.ZoneGravity.Z, 260, GroundSpeed * 1.05, JumpDest)  )
	{ //Dodge-This
		Vectus = HNormal( JumpDest.Location - Location);
		Vectality = HNormal( vector(Rotation) );
		if ( VSize( Vectus - Vectality) < 0.4 )
			PlayFlip();
		else if ( VSize( Vectus - Vectality) > 1.85)
			TweenAnim('DodgeB', 0.35);
		else
		{
			aRot = Rotator( Vectus); //Movimiento
			eRot = Rotator( Vectality); //Vista
			Vectus = vector(eRot - aRot);
			if ( Vectus.Y > 0 )
				PlayDodge( False);
			else
				PlayDodge( True);
		}
		Velocity = BFM.AdvancedJump( Location, JumpDest.Location, Region.Zone.ZoneGravity.Z, 260, GroundSpeed * 1.05);
	}
	else
	{
		if ( !bBaseSpeed || (Base == none) )
			Velocity = BFM.AdvancedJump( Location, JumpDest.Location, Region.Zone.ZoneGravity.Z, JumpZ, GroundSpeed * 1.05, bSuperAccel);
		else
			Velocity = BFM.AdvancedJump( Location, JumpDest.Location, Region.Zone.ZoneGravity.Z, JumpZ + Base.Velocity.Z, GroundSpeed * 1.05, bSuperAccel);
		Inventory.OwnerJumped();
	}
	SetPhysics(PHYS_Falling);


	PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
//********** Acabo de saltar, ver si llego, si no puedo, tirar transloc en el aire... WOOOHOOOO
	if ( bCanTranslocate && !BFM.CanFlyTo( Location, JumpDest.Location, Region.Zone.ZoneGravity.Z, JumpZ, GroundSpeed * 1.02) )
	{
		TranslocateToTarget( JumpDest);
		if ( BotzTTarget(MyTranslocator.TTarget) != none ) 
			BotzTTarget(MyTranslocator.TTarget).PostTarget = RouteCache[1];
		bAirTransloc = True;
	}
	DesiredRotation = Rotator(JumpDest.Location - Location);
	PlayInAir();
}

function ProcessTickJump()
{
	local vector Vectus, Vectality, vecter;
	local rotator aRot, eRot;
	local float ZSpeed;

	if ( MoveTarget != None )
		SpecialMoveTarget = MoveTarget;
	if ( bScriptedMove || bUnstateMove )
		MoveTarget = none;
	if ( SpecialMoveTarget == none || (Physics == PHYS_Swimming) )
	{
		if ( DebugPath )
			Log("ProcessTickJump denied");
		return;
	}

	if ( (Physics != PHYS_Walking) && BFM.CanFallTo( self, SpecialMoveTarget) )
	{
		Velocity = FallTo(SpecialMoveTarget);
		Velocity += HNormal( Velocity)*2; //Additional push
		Goto END_TICKJUMP;
	}
	
	//Dodge
	if ( BFM.CanFlyTo( Location, SpecialMoveTarget.Location, Region.Zone.ZoneGravity.Z, 165, GroundSpeed * 1.15)  )
	{
		SetPhysics(PHYS_Falling);
		Vectus = HNormal( SpecialMoveTarget.Location - Location);
		Vectality = HNormal( vector(Rotation) );
		if ( VSize( Vectus - Vectality) < 0.4 )
			PlayFlip();
		else if ( VSize( Vectus - Vectality) > 1.85)
			TweenAnim('DodgeB', 0.35);
		else
		{
			aRot = Rotator( Vectus); //Movimiento
			eRot = Rotator( Vectality); //Vista
			Vectus = vector(eRot - aRot);
			if ( Vectus.Y > 0 )
				PlayDodge( False);
			else
				PlayDodge( True);
		}
		Velocity = BFM.AdvancedJump( Location, SpecialMoveTarget.Location, Region.Zone.ZoneGravity.Z, 165, GroundSpeed * 1.15); //Dodge is faster
		PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
		Goto END_TICKJUMP;
	}

	if ( bTickedSuperJump )
	{
		ZSpeed = JumpZ;
		Inventory.OwnerJumped();
	}
	else
		ZSpeed = Default.JumpZ * Level.Game.PlayerJumpZScaling();
	if ( Mover(Base) != none && Mover(Base).Velocity.Z > 0 )
		ZSpeed += Mover(Base).Velocity.Z;
	//Can jump into target
	if ( BFM.CanFlyTo( Location, SpecialMoveTarget.Location, Region.Zone.ZoneGravity.Z, ZSpeed, GroundSpeed * 1.03) )
	{
		Velocity = BFM.AdvancedJump( Location, SpecialMoveTarget.Location, Region.Zone.ZoneGravity.Z, ZSpeed, GroundSpeed * 1.03);
	}
	//Jump target not directly reachable
	else
	{
		Velocity = HNormal( SpecialMoveTarget.Location - Location) * (GroundSpeed * 1.03);
		Velocity.Z = ZSpeed;
		bSuperAccel = true;
	}
	//FUTURO: AGREGAR CASO DONDE EL BOT PUEDE SALTAR A UNA PLATAFORMA INTERMEDIA!!!

	Acceleration = HNormal( Velocity) * 5; //To make air jump realistic
	PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
	PlayInAir();
	SetPhysics(PHYS_Falling);

	END_TICKJUMP:
	LifeSignal( 0.5 + HSize(Location - SpecialMoveTarget.Location) / HSize( Velocity) );
	bTickedJump = false;
	bTickedSuperJump = false;
}

singular event BaseChange()
{
	if ( Base == Level )
		bAirTransloc = False;
	//No longer walking
	if ( (Base == none) && (MoveTarget Or SpecialMoveTarget != none) )
	{
		if ( bHasToJump && (PendingTouch == none) && !Region.Zone.bWaterZone )
			bTickedJump = true;
		SwitchToUnstate();
	}
	Super.BaseChange();
	if ( Physics != PHYS_Falling )
		bSuperAccel = false;
	if ( DebugMode )
		Log("BASE CHANGE:"@Base@", MoveTarget:"@MoveTarget@", bHasToJump:"@bHasToJump);
}

function TouchedBooster( actor Other)
{
	if ( MoveTarget Or SpecialMoveTarget == none )
		return;
	if ( VSize( (MoveTarget Or SpecialMoveTarget).Location - Other.Location) < (200 + Other.CollisionRadius * 0.2) )
		PopRouteCache(true);
	LifeSignal( 3);
	PlayInAir();
}

function DeleteTranslocators(bool BadOnly)
{
	local TranslocatorTarget T;

	ForEach AllActors (class'TranslocatorTarget',T)
	{
		if (T.Master == MyTranslocator  )
		{
			if ( T.IsA('BotzTTarget') && BotzTTarget(T).bAvoidErase)
				continue;
			if ( T.LifeSpan == 0 )
				T.LifeSpan = 4;
			if (BadOnly && (T.Physics == PHYS_Falling) )
				continue;
			T.Destroy();
		}
	}
}

function TranslocateToTarget(Actor Destn)
{
	local vector Vectus;
	local bool bCombatMove;

	if ( False )
	{
		BotzTranslocateToTarget( Destn, True);
		return;
	}

	Vectus.Z = 100;
	if ( Physics != PHYS_Falling )
		Disable('Tick');
	bPendingTransloc = True;
	DeleteTranslocators(True);
	PendingWeapon = MyTranslocator;
	DesiredRotation = rotator( (Destn.Location - Location) + Vectus);
	ViewRotation = rotator( (Destn.Location - Location) + Vectus);
	if ( Weapon == None )
	{	ChangedWeapon();
		SpecialPause = 0.7;
	}
	else if ( Weapon != PendingWeapon )
	{	Weapon.PutDown();
		SpecialPause = 1.2;
	}
	else
	{
		if ( bAirTransloc )
			NoDeleteTranslocs = 3.0 + VSize( Location - Destn.Location) /1000;
		bAirTransloc = False;
		MyTranslocator.DesiredTarget = Destn;
		MyTranslocator.PlayPostSelect();
		ReplaceTTarget( MyTranslocator.TTarget, true, true);
		SpecialPause = 3.0;
		bCombatMove = True;
	}
	if (MyTranslocator.TTarget != none)
		MyTranslocator.TTarget.Velocity = SetTSpeed( MyTranslocator.TTarget, DestN);
	MoveTarget = Destn;
	if ( bCombatMove && (Enemy != none) && (Physics != PHYS_Falling) )
	{
		NoDeleteTranslocs = 2.0 + VSize( Location - Destn.Location) /1000;
		SpecialPause = 0;
		GotoState('Wander', 'Begin');
	}
}

function vector SetTSpeed(TranslocatorTarget T, actor Dest)
{
	local vector dir;

	if ( True )
	{
		T.Throw( self, MyTranslocator.MaxTossForce, T.Location);
		return T.Velocity;
	}

	dir = vector(ViewRotation);
	if ( T.FastTrace( Dest.Location, Location - VectZ( CollisionHeight)) && (Location.Z > Dest.Location.Z) )
		T.Velocity = class'Translocator'.Default.MaxTossForce * dir - VectZ( Region.Zone.ZoneGravity.Z / 40.0 );
	else
		T.Velocity = class'Translocator'.Default.MaxTossForce * dir + Vect(0,0,200);
	return T.Velocity;
}

function ReplaceTTarget( TranslocatorTarget T, optional bool bNoCollide, optional bool bReDrop)
{
	local BotzTTarget BTarget;

	T.SetCollision( false, false, false);
	BTarget = spawn(class'BotzTTarget',,, T.Location, T.Rotation);
	BTarget.Master = MyTranslocator;
	BTarget.DesiredTarget = MyTranslocator.DesiredTarget Or T.DesiredTarget;
	if ( bNoCollide)
		BTarget.SetCollisionSize(0,0); 
	BTarget.bBounce = true;
	if ( bReDrop )
		BTarget.DropFrom(T.Location);
	else
	{
		BTarget.SetPhysics( PHYS_Falling);
		BTarget.Velocity = T.Velocity;
	}
	BTarget.LifeSpan = 20;
	T.Destroy();
	MyTranslocator.TTarget = BTarget;
}

function BotzTranslocateToTarget( actor Destn, bool bWaitAfter, optional bool bTeleImpact)
{
	local Vector Start, X,Y,Z;	
	local bool bCombatMove;

	if (Level.Game.LocalLog != None)
		Level.Game.LocalLog.LogSpecialEvent("throw_translocator", PlayerReplicationInfo.PlayerID);
	if (Level.Game.WorldLog != None)
		Level.Game.WorldLog.LogSpecialEvent("throw_translocator", PlayerReplicationInfo.PlayerID);

	if ( bWaitAfter )
		Disable('Tick');

	PendingWeapon = MyTranslocator;
	ViewRotation = Rotator( Destn.Location + vect(0,0,40) - Location);
	bPendingTransloc = True;
	DeleteTranslocators(True);
	DesiredRotation = ViewRotation;

	MyTranslocator.DesiredTarget = none; //Some fix here

	if ( Weapon == None )
	{	ChangedWeapon();
		SpecialPause = 0.7;
	}
	else if ( Weapon != PendingWeapon )
	{	Weapon.PutDown();
		SpecialPause = 1.2;
	}
	else
	{

		GetAxes(ViewRotation,X,Y,Z);		
		Start = Location + MyTranslocator.CalcDrawOffset() + MyTranslocator.FireOffset.X * X + MyTranslocator.FireOffset.Y * Y + MyTranslocator.FireOffset.Z * Z; 		
	
		MyTranslocator.TTarget = Spawn(class'BotzTTarget',,, Start);
		if (MyTranslocator.TTarget!=None)
		{
			bCombatMove = True;
			if ( bAirTransloc )
				NoDeleteTranslocs = 3.0 + VSize( Location - Destn.Location) /1000;
			bAirTransloc = False;
			MyTranslocator.bTTargetOut = true;
			MyTranslocator.TTarget.Master = MyTranslocator;
			MyTranslocator.TTarget.DesiredTarget = Destn;
			MyTranslocator.TTarget.Throw( self, MyTranslocator.MaxTossForce, Start);
			MyTranslocator.TTarget.LifeSpan = 18;
			BotzTTarget(MyTranslocator.TTarget).bMoveAdjust = True;
			BotzTTarget(MyTranslocator.TTarget).bTeleImpact = bTeleImpact;
			MyTranslocator.PlayFiring();
		}
	}

//	MoveTarget = Destn;
	if ( bCombatMove && (Enemy != none) && (Physics != PHYS_Falling) )
	{
		NoDeleteTranslocs = 2.0 + VSize( Location - Destn.Location) /1000;
		SpecialPause = 0;
		GotoState('Wander', 'Begin');
	}
	else if ( !bWaitAfter )
		SpecialPause = 0;
}


function bool AddInventory( inventory NewItem )
{
	if (  MoveTarget Or SpecialMoveTarget == NewItem Or NewItem.MyMarker )
	{
		SpecialMoveTarget = none;
		MoveTimer = -1;
	}
	MasterEntity.FlightDatabase.ItemAdded( self, NewItem);
	if ( Weapon(NewItem) != None ) //Randomize weapon eligibility
		Weapon(NewItem).AIRating *= RandRange( 0.85, 1.25);
	return Super.AddInventory( NewItem);
}

function TakeDamage( int Damage, Pawn instigatedBy, Vector hitlocation, 
						Vector momentum, name damageType)
{
	bHasToJump = False;
	if ( Physics == PHYS_Walking )
		LastTranslocCounter = 0.5 + float(Damage) / 100.0;
	Super.TakeDamage(Damage,instigatedBy,hitlocation,momentum,damagetype);
}
event Landed(vector HitNormal)
{
	bAirTransloc = False;
	bHasToJump = True;
	if ( (Weapon == MyTranslocator) && (Enemy != none) )
		SwitchToBestWeapon();
	TakeFallingDamage();
	DodgeAgain = 0.6 * Level.TimeDilation;
	SpecialPause = 0;
	Super.Landed(HitNormal);
	if ( SpecialMoveTarget != none && FastTrace(SpecialMoveTarget.Location) ) //I was falling at something, reset life signal
		LifeSignal( 0.5 + HSize(Location - SpecialMoveTarget.Location) * 1.1 / GroundSpeed);
}


exec function bool SwitchToBestWeapon()
{
	if ( Inventory == None )
		return false;

	PendingWeapon = BFM.BotzBestWeapon( self);

	if ( PendingWeapon == None )
		return false;

	if ( Weapon == None )
		ChangedWeapon();
	else if ( Weapon != PendingWeapon )
		Weapon.PutDown();

	return true;
}


final function float ThisWeaponOnBest( out float Rating, out weapon Best, weapon Current) //The return means the current weapon's rating
{
	local /*Obsolete*/ int bUseAltMode;
	local float ThisRating;
	local int i;
	local BotzWeaponProfile thisProf;

	ThisRating = Current.RateSelf(bUseAltMode);
	
	if ( (Current.AmmoType != none) && (Current.AmmoType.AmmoAmount <= 0) )
		return ThisRating;

	if ( MasterEntity != none )
	{
		While( ++i < MasterEntity.WProfileCount )
		{
			if ( MasterEntity.WProfiles[i].WeaponClass == Current.Class )
			{
				thisProf = MasterEntity.WProfiles[i];
				break;
			}
		}
	}

	if ( Current.IsA('WarHeadLauncher') )
	{
		ThisRating = 0.3;
		if ( Enemy != none )
			ThisRating += 0.3;
		if ( Health < 60 )
			ThisRating += 0.2;
		if ( Orders == 'Defend')
			ThisRating += 0.2;
		if ( Suicida )
			ThisRating += 0.3;
		if ( AttackDistance == AD_Larga )
			ThisRating += 0.4;
	}

	//Extra rating for rifles
	if ( AttackDistance == AD_Larga )
	{
		if ( Current.IsA('SniperRifle') || Current.IsA('Rifle') )
			ThisRating += 0.5;	//Default
		else
		{
			For ( i=0 ; i<MasterEntity.iSniperW ; i++ )
				if ( MasterEntity.SniperWeapons[i] == Current.Class )
				{
					ThisRating += 0.5;
					break;
				}
		}
	}

	if (ThisRating <= 0)
		return ThisRating;

	if ( thisProf != none )
		ThisRating = thisProf.SetRating( self, ThisRating, Current) * thisProf.SpecialRating(Self);
	else
		ThisRating += AddRatingFor(Current);

	if (Current.Class == ArmaFavorita)
		ThisRating *= 1.3;
	else if ( (ArmaFavorita != none) && ClassIsChildOf( Current.Class, ArmaFavorita) )
		ThisRating *= 1.2;

	if (ThisRating > Rating)
	{
//		if ( DebugMode && (Best != none) )
//			Log("Rating override: "$Best.GetItemName(string(best))$" ("$Rating$") for "$Current.GetItemName(string(Current))$" ("$ThisRating$")");
		Best = Current;
		Rating = ThisRating;
	}
	return ThisRating;
}

function SwitchToWeapon( Weapon aWeapon)
{
	if ( Weapon != aWeapon )
		return;

	if ( (Weapon == none) || ((2.5 + FRand()) < (Skill * 0.5)) ) //Fast weapon switch (bot cheat)
	{
		PendingWeapon = aWeapon;
		ChangedWeapon();
		return;
	}
	Weapon.PutDown();
	PendingWeapon = aWeapon;
}

final function float AddRatingFor( weapon Rated)
{
	local int i;
	local float Added;

	if ( Rated.Class == ArmaFavorita )
		Added = 0.40;
	else
		Added = -0.10;

	if ( (Enemy == none) || (MasterEntity == None) )
		return 0;

	if ( AttackDistance == AD_Cercana )
		For (i=0;i<16;i++)
			if ( ClassIsChildOf(Rated.Class, MasterEntity.ClassCercano[i]) )
				return MasterEntity.ValorCercano[i] + Added;

	else if ( AttackDistance == AD_Larga )
		For (i=0;i<16;i++)
			if ( ClassIsChildOf(Rated.Class, MasterEntity.ClassLejano[i]) )
				return MasterEntity.ValorLejano[i] + Added;

	else
		For (i=0;i<16;i++)
			if ( ClassIsChildOf(Rated.Class, MasterEntity.ClassMedio[i]) )
				return MasterEntity.ValorMedio[i] + Added;

	return 0.1; //Armas no registradas parten en desventaja si no se aplica esto
}

exec function GetWeapon(class<Weapon> NewWeaponClass )
{
	local Inventory Inv;
	local Weapon W, BestW;

	if ( (Inventory == None) || (NewWeaponClass == None) || ((Weapon != None) && (Weapon.Class == NewWeaponClass)) )
		return;
	ForEach InventoryActorsW ( NewWeaponClass, W, true)
	{
		if ( (W.AmmoType != None) && (W.AmmoType.AmmoAmount <= 0) )
			continue;
		if ( W.class == NewWeaponClass ) //Prioritize original weapon
		{
			BestW = W;
			break;
		}
		BestW = W; //Prioritize oldest weapon in inventory chain (good for gunloc mutator)
	}
	if ( BestW != none )
	{
		PendingWeapon = BestW;
		if ( Weapon != none )
			Weapon.PutDown();
		else
		{
			Weapon = PendingWeapon;
			Weapon.BringUp();
		}
	}
}

function GetSniperWeapon()
{
	local Inventory Inv;

	AttackDistance = AD_Larga;
	for ( Inv=Inventory; Inv!=None; Inv=Inv.Inventory )
		if ( ClassIsChildOf( Inv.Class, class'SniperRifle') || (InStr( caps( string(Inv.Class) ) ,"SNIPER") >= 0 ) )
		{
			PendingWeapon = Weapon(Inv);
			if ( PendingWeapon == none )
				continue;
			if ( (PendingWeapon.AmmoType != None) && (PendingWeapon.AmmoType.AmmoAmount <= 0) )
			{
				PendingWeapon = None;
				continue;
			}
			if ( PendingWeapon != Weapon )
				Weapon.PutDown();
			return;
		}
}

//Snipers will deliberately find the best player on the enemy team or the flag carrier
function LocateEnemy( rotator DirectionToLook, optional int Tolerance)
{
	local pawn P;
	local int iRegion;
	local bool bContinue;
	local float weight, bestweight;
	local int score, bestscore;
	local pawn Best;
	local vector Start, Dir;

	if ( AimPoint.AimGuy != None )
		return;
	
	Start = Location;
	Start.Z += EyeHeight;
	Dir = vector(DirectionToLook);
	if ( !AimPoint.SniperWeapon(Self) )
	{
		if ( (FRand() < 0.25) && FastTrace( Start+Dir*2500, Start) )
			GetSniperWeapon();
		return;	//Reducir iteraciones y mensajes al pedo
	}

	if ( (FRand() < 0.5) && FastTrace( Location+Dir*2000 ) && (HSize(Acceleration) < 2) ) //Ducking is possible
		BaseEyeHeight = 0;
	else
		BaseEyeHeight = Default.BaseEyeHeight;

	if ( Tolerance < 2)
		Tolerance = 4096;
	Tolerance += Skill*49 - Punteria*10;
	bestweight = (130.0 + Punteria*10 - Skill*7) * RandRange( 0.5, 1.5); //Ability to find enemies, low bot needs 180, top needs 81
	bestscore = 0;

	For ( P=Level.PawnList ; P!=none ; P=P.nextPawn )
	{
		if ( !SetEnemy(P,true) )
			continue;

		weight = 0.0; //Initial weight

		For ( iRegion=0 ; iRegion<5 ; iRegion++ )
			if ( FastTrace( P.Location + VectZ(15 * (iRegion - 2)), Location + VectZ( EyeHeight) ) )
				Goto NO_CONTINUE;
		continue;
NO_CONTINUE:
		
		if (BFM.CompareRotation( rotator(P.Location - Location), DirectionToLook, Tolerance, False) )
			weight += 150;
			
		weight += P.Health * 0.1;
		weight -= int(P.Region.Zone.bWaterZone) * 20; //Harder to spot in water
		weight += int((P.Weapon == None) || (P.Weapon.AiRating > 0.5)) * 40; //Prioritize enemy with big weapon
		weight += int(P.Health < 64) * 80; //One shot, one kill
		if ( BFM.CompareRotation( P.ViewRotation, rotator( Location - P.Location), 5000, false) ) //Aiming at me!
			weight += 50;
		weight -= VSize( P.Location - Location) * 0.005; //Divide by 200 (10000 = -50)

		if ( P.PlayerReplicationInfo != none )
		{
			if ( P.PlayerReplicationInfo.Score > PlayerReplicationInfo.Score )
				weight += 25; //Target more relevant players
			if ( P.PlayerReplicationInfo.HasFlag != none )
				weight += 151; //Make this a primary target
			else if ( P.PlayerReplicationInfo.bFeigningDeath )
				weight -= 200;
		}
		else
			weight += 35;

		if ( weight > bestweight)
		{
			bestweight = weight;
			best = P;
		}
	}

	if ( Best != none )
	{
		AimPoint.AimGuy = best;
		AimPoint.SniperCounter = 0.4 + Punteria * 0.5; //Disparo casi inmediato
		if ( DebugMode )
			TeamSay("ENEMIGO: "$Caps(Best.GetHumanName() )$", RATING: "$ string(int(BestWeight)) );
	}
}

function bool EnemyAimingAt( actor Aimed, optional bool bFiring)
{
	local pawn P;

	if ( Aimed == none)
		return false;

	ForEach PawnActors( class'Pawn', P, 8000)
	{
		if ( SetEnemy( P, true) && P.CanSee(Aimed) ) //Only check, enemy isn't actually set
		{
			if ( ScriptedPawn(P) != None )
				ScriptedPawn(P).ViewRotation = P.Rotation;
			if ( BFM.CompareRotation( P.ViewRotation, rotator( Aimed.Location - P.Location), 5000, false) )
				if ( (!bFiring) || (P.bFire == 1) || (P.bAltFire == 1) )
					return true; //Me estan apuntando!
		}
	}
	return false;
}

exec function Say( string Msg )
{
	local Pawn P;

	if ( Level.Game.AllowsBroadcast(self, Len(Msg)) )
		for( P=Level.PawnList; P!=None; P=P.nextPawn )
			if( P.bIsPlayer || P.IsA('MessagingSpectator') )
			{
				if ( (Level.Game != None) && (Level.Game.MessageMutator != None) )
				{
					if ( Level.Game.MessageMutator.MutatorTeamMessage(Self, P, PlayerReplicationInfo, Msg, 'Say', true) )
						P.TeamMessage( PlayerReplicationInfo, Msg, 'Say', true );
				} else
					P.TeamMessage( PlayerReplicationInfo, Msg, 'Say', true );
			}
	return;
}

exec function TeamSay( string Msg )
{
	local PlayerPawn P;

	if ( !Level.Game.bTeamGame )
	{
		Say(Msg);
		return;
	}

	if ( Msg ~= "Help" )
	{
		CallForHelp();
		return;
	}
			
	if ( Level.Game.AllowsBroadcast(self, Len(Msg)) )
		ForEach PawnActors( class'PlayerPawn',P,,,true)
			if( P.bIsPlayer && (P.PlayerReplicationInfo.Team == PlayerReplicationInfo.Team) )
			{
				if ( (Level.Game != None) && (Level.Game.MessageMutator != None) )
				{
					if ( Level.Game.MessageMutator.MutatorTeamMessage(Self, P, PlayerReplicationInfo, Msg, 'TeamSay', true) )
						P.TeamMessage( PlayerReplicationInfo, Msg, 'TeamSay', true );
				} else
					P.TeamMessage( PlayerReplicationInfo, Msg, 'TeamSay', true );
			}
}

exec function CallForHelp()
{
	local Pawn P;

	if ( !Level.Game.bTeamGame || (Enemy == None) || (Enemy.Health <= 0) )
		return;

	ForEach PawnActors (class'Pawn', P,,,true)
		if ( P.bIsPlayer && (P.PlayerReplicationInfo.Team == PlayerReplicationInfo.Team) )
			P.HandleHelpMessageFrom(self);
}

function ChangedWeapon()
{
	Super.ChangedWeapon();
	Weapon.SetHand(1);
}	

function CheckFlag()
{
	if ( (FrontActions == MAL_CarryingFlag) && (PlayerReplicationInfo.HasFlag == none) )
	{
		FrontActions = MAL_None;
		QueHacerAhora();
	}
	else if ( (FrontActions != MAL_CarryingFlag) && (PlayerReplicationInfo.HasFlag != none))
	{
		FrontActions = MAL_CarryingFlag;
		bCanTranslocate = False;
		GotoState('Attacking');
	}
}

function UpdateRunAnim()
{
	local vector X,Y,Z, Dir;
	local name NewAnim;
	local Rotator SupraRotation;


	if ( (MoveTarget != none) && (HSize(Location - MoveTarget.Location) < 30) )
		return; //Dont update near MoveTarget



	BaseEyeHeight = Default.BaseEyeHeight;
	SupraRotation = Rotation;

	if ( (AimPoint.PointTarget != none) && (AimPoint.PointTarget != self) )
		SupraRotation = Rotator( AimPoint.Location - Location );

	GetAxes(SupraRotation, X,Y,Z);
	Dir = Normal(Acceleration);
	if ( (Dir Dot X < 0.75) && (Dir != vect(0,0,0)) )
	{
		if ( Dir Dot X < -0.75 )
			NewAnim = 'BackRun';
		else if ( Dir Dot Y > 0 )
			NewAnim = 'StrafeR';
		else
			NewAnim = 'StrafeL';
	}
	else if (Weapon == None)
		NewAnim = 'RunSM';
	else if ( Weapon.bPointing ) 
	{
		if (Weapon.Mass < 20)
			NewAnim = 'RunSMFR';
		else
			NewAnim = 'RunLGFR';
	}
	else
	{
		if (Weapon.Mass < 20)
			NewAnim = 'RunSM';
		else
			NewAnim = 'RunLG';
	}
	if ( (GetAnimGroup(AnimSequence) == 'MovingFire') || (AnimSequence == 'RunSM') || (AnimSequence == 'RunLG') )
		AnimSequence = NewAnim;
	else
		LoopAnim(NewAnim);
	bAnimNotify = True;
}

function TryToDodge()
{
	local Projectile DodgeThis, P;
	local Mutator TheMut;
	local int i, j;
	local vector RunSpot, Vectus, ProjDir, ProjDirMove;
	local vector HitLocation, SplashLoc, HitNormal;
	local float DangerF, WorseDanger, MaxTime, CounterF, AD, TD;
	local bool bDanger, bRecommendJump;
	local BotzProjectileStore BPS; //Quick lookup

	if ( Physics != PHYS_Walking )
		return;
	if ( MyMutator == none )
		For ( TheMut=Level.Game.BaseMutator ; TheMut!=none ; TheMut=TheMut.NextMutator )
			if (TheMut.IsA('BotzMutator') )
				MyMutator = BotzMutator(TheMut);
	if ( MyMutator == none )
		return;
	BPS = MyMutator.BPS;

//	RunSpot = Location + Velocity; //Documentacion

	i = 9999;
	While ( i >= 0 ) //Proceso de detección, optimizado
	{
		P = BPS.NextDangerProj(self, 300 + Skill*10 + Aggresiveness*2 + TacticalAbility*5 , i);
		if ( P == none )
			break;
		Assert( j++<1000);
//		if ( !LineOfSightTo( P) )	//Si no lo veo, no estoy al tanto de el
//			continue;
		bDanger = False;
		ProjDirMove = Normal( P.Velocity );
		ProjDir =  Normal( Location - P.Location );
		if ( VSize( ProjDir - ProjDirMove) > 1 ) //Proyectil se aleja de mi, ENCUENTRAME; BUG, REVIRTIENDO
			continue;
		P.Trace( SplashLoc, HitNormal, P.Location + ProjDirMove * 500);
		if ( SplashLoc == vect(0,0,0) )
			SplashLoc = P.Location + ProjDirMove * 500;
		MaxTime = VSize( SplashLoc - P.Location) / VSize(P.Velocity);
		CounterF = MaxTime;
		if ( CounterF > 2.7 )
			CounterF = 2.7;
		AD = CollisionRadius + P.CollisionRadius + 10; //Safety
		TD = CollisionHeight + P.CollisionHeight + 5;
		While ( CounterF > 0 && !bDanger)
		{
			if ( VectorInCylinder( Location + Velocity * CounterF, P.Location + P.Velocity * CounterF, AD, TD) ) //Analizar posiciones cada 0.1 segundo
				bDanger = True;	//Este proyectil puede golpearme
			CounterF -= 0.1;
		}
		if ( !bDanger && (VSize(SplashLoc - (Location + Velocity * MaxTime) ) > 100 ) ) //No hay peligro, no explotara cerca de mi trayectoria
			continue; //Ignorar si no explota cerca y no hay riesgo de colisión
		DangerF = 3.0 - VSize(P.Location - Location) / 133.3;
		DangerF += Float(bDanger);
		DangerF += 2 - VSize( Location - SplashLoc) / 50.0;
		if ( DangerF < WorseDanger )
			continue; //Hay otro proyectil aun más preocupante...
		WorseDanger = DangerF;
		DodgeThis = P;
	}
	// Proceso de elección de punto, tengo que hacerlo menos redundante
	if ( DodgeThis == none )
		return;
	DodgeThis.Trace( SplashLoc, HitNormal, DodgeThis.Location + ProjDirMove * 500);
	if ( SplashLoc == vect(0,0,0) )
		SplashLoc = DodgeThis.Location + ProjDirMove * 500;
	MaxTime = VSize( SplashLoc - dODGEtHIS.Location) / VSize(DodgeThis.Velocity);
	CounterF = MaxTime;
	if ( CounterF > 2.7 )
		CounterF = 2.7;
	bDanger = False;
	TD = 999;

	AD = 0.0;
	While ( CounterF > 0 )	//Analizar colisión MISIL-BOT
	{
		RunSpot = (Location + Velocity * CounterF);
		if ( VSize( RunSpot - (DodgeThis.Location + DodgeThis.Velocity * CounterF) ) < 100 )
		{
			AD = VSize( RunSpot - (DodgeThis.Location + DodgeThis.Velocity * CounterF) );
			if ( TD > AD )
				TD = AD;
			else
				break;
			bDanger = True;
		}
		if ( !bDanger )
			CounterF -= 0.1;
		else
			CounterF -= 0.01;
	}
	Vectus = DodgeThis.Location + DodgeThis.Velocity * CounterF;
	if ( Vectus.Z < Location.Z )
		bRecommendJump = True;

	//Elegir Zona y modo de huida (comparandolo con MoveTarget)
	if ( VSize(Acceleration) < 20 )
	{
		DangerM = DodgeThis;
		BestDodgeLocation = AvoidSpots( Vectus, SplashLoc, Location);
		Destination = BestDodgeLocation;
		if ( !IsInState('DodgeProj') )
			GotoState('DodgeProj','StandDodge');
	}
	else if ( (MoveTarget != none) && (VSize(MoveTarget.Location - Location) > 90 ) && bRecommendJump && (Physics != PHYS_Swimming) )
	{
		if ( !IsInState('DodgeProj') )
		{
			bTickedJump = True;
			bHasToJump = True;
		}
	}
	else if ( (MoveTarget != none) && (VSize(MoveTarget.Location - Location) > 50 ) ) //El bot no siempre toca los movetarget, esta condicion se dara mas de lo que se cree
	{
		DangerM = DodgeThis;
		BestDodgeLocation = AvoidMissileRun( Vectus, MoveTarget.Location, DodgeThis.Location, DodgeThis.Velocity);
		FaceTarget = MoveTarget;

		Destination = BestDodgeLocation;
		if ( !IsInState('DodgeProj') )
			GotoState('DodgeProj','RunDodge');
	}
}

function Vector AvoidMissileRun( vector CriticalPoint, vector MovingTo, vector MisLoc, vector MisVel)
{
	//Funcion rapida para eludir proyectiles durante movimiento
	//Movimiento simple y tactico avanzado cuyos criterios son:
	//Misil es frontal: eludir diagonalmente hacia zona mas espaciosa
	//Misil viene de diagonal-adelante: eludir en direccion paralela a su velocidad en sentido opuesto (rozarlo por el costado)
	//Misil viene de costado: eludir diagonalmente hacia el proyectil (hacerlo pasar por adelante)
	//Misil viene de diagonal-atras: eludir en direccion perpendicular hacia adelante (cruzarlo por detras)
	//Misil viene de atras: eludir horizontalmente hacia zona espaciosa
	
	local vector Vectus, HitLocation, HitNormal, X, Y, Z;
	local rotator Rotus;
	local float Desicion;

	//De donde procede el proyectil?
	Rotus = Rotator( (MovingTo - Location) * vect(1,1,0) ); //Direccion base
	GetAxes( Rotus, X, Y, Z);
	Vectus = vector(Rotator(MisVel * vect(1,1,0) ) - Rotus); //Normal de la direccion relativa del misil
	if ( Vectus.X > 0.95 ) //Coseno de arco trasero 32º
		Goto BACK;
	else if ( abs(Vectus.X) < 0.25 ) //Coseno de arcos laterales 30º
		Goto SIDE;
	else if ( Vectus.X < -0.93) //Coseno de arco frontal 40º
		Goto FRONTAL;
	else if ( Vectus.X < 0 )
	{
//		JugadorSimulado.ClientMessage("DIAGONAL FRONT DODGE");
		return Location + HNormal( MisVel * -1) * 55 - Y*10; //Goto DIAGF
	}
	else
		Goto DIAGBACK;

FRONTAL:
//	JugadorSimulado.ClientMessage("FRONT DODGE");
	if ( FRand() < 0.5) //Randomize a dir
		Y *= -1;
	if ( FastTrace( MovingTo, Location + (X+Y)*40 ) )
		return Location + (X+Y)*40;
	if ( FastTrace( MovingTo, Location + (X-Y)*40 ) )
		return Location + (X-Y)*40;
	return Location + (Y-X)*50; //Go behind if all else fails
BACK:
//	JugadorSimulado.ClientMessage("BACK DODGE");
	if ( FRand() < 0.5) //Randomize a dir
		Y *= -1;
	if ( FastTrace( MovingTo, Location + Y*55+X*15) )
		return Location + Y*55+X*15;
	if ( FastTrace( MovingTo, Location + X*15-Y*55) )
		return  Location + X*15-Y*55;
	Goto FRONTAL; //Keep pushing forward if sides fail
SIDE:
//	JugadorSimulado.ClientMessage("SIDE DODGE");
	if ( Vectus.Y > 0 )
		Y *= -1;
	if ( FastTrace( MovingTo, Location + X*15+Y*30) )
		return Location + X*15+Y*30;
	return Location - X * 35; //Step back if not possible
DIAGBACK:
//	JugadorSimulado.ClientMessage("DIAGONAL BACK DODGE");
	if ( Vectus.Y > 0 )
		return Location + vector(Rotator( MisVel * vect(1,1,0) ) - rot(0,26384,0) ) * 40; //Left side
	return Location + vector(Rotator( MisVel * vect(1,1,0) ) + rot(0,26384,0) ) * 40; //Right side
}

function Vector AvoidSpots( vector Spot1, vector Spot2, vector MovingTo)	//FUTURO, CRITICO
{	//NUEVO: Analizar plano de apoyo si esta sobre una superficie
	local float X, Y, O;
	local vector HitLocation, HitNormal, Vectus;
	local float fCurrent, fBest, Yfactor, Xfactor;
	local int CurrentDir, BestDir, i; 
	local rotator SpotRot, CurrentRot;

	//Analización de plano	(conveniente dejar esto ordenado para copiarlo) (FUTURO: funcion del BFM)
	//Analiza diferencias de altura de los puntos del Eje X, Eje Y, y el punto central
	//FUTURO: multiples puntos X, Y para promediar ( mejor para escaleras y detección de caidas)
	if ( Physics == PHYS_Walking )
	{	Vectus = Location - vect( 0, 0, 120);
		//Punto central
		if (Trace( HitLocation, HitNormal, Vectus) != none )
			O = HitLocation.Z;
		else O = Location.Z - CollisionHeight;
		//Punto eje X
		Vectus.X += 10;
		if ( Trace( HitLocation, HitNormal, Vectus) != none )
			X = HitLocation.Z;
		else X = Vectus.Z;
		Vectus.X -= 10;
		//Punto eje Y
		Vectus.Y += 10;
		if (Trace( HitLocation, HitNormal, Vectus) != none )
			Y = HitLocation.Z;
		else Y = Vectus.Z;
		//Registrar diferencias de alturas
		X -= O;
		Y -= O;
		O = 0;	//CUIDADO: primero letra (o), luego numero (cero)
		if ( (abs(Y) + abs(X)) > 13.9 )
		{	Y = 0;	X = 0;	}	//Por si esta al borde de una zona inescalable (arreglar para checkear otra zona del plano, y escaleras)
		Y /= 4.0;	//Mantener escala 1 a 1 (no 1 a 4, haciéndolo mas facil de usar)
		X /= 4.0;
	}
	Vectus = vect(0,0,0);

	//Metodo de elección direccional uniforme en modo de huida en un punto estático
	//Elegir el mejor lugar para alejarse de los spots evitando obstáculos
	//Se checkean Regiones: Alta, Baja y Central del Botz para evitar obstáculos
	//Rotación utilizada: 4096 (16 direcciones uniformes)
	//Info del plano de apoyo utilizada aqui
	if ( VSize(MovingTo - Location) < 5 )
	{	//FUTURO, implementar preferencia de dirección (Berserker o Avoidant) (mas argumentos en funcion)
		CurrentRot = Rot(0,0,0);
		CurrentDir = 0;
		fBest = 0.0;
		For ( i=0; i<16 ; i++ )	//Limite maximo del iterador = numero de direcciones posibles
		{
			fCurrent = 0.0;
			CurrentDir = i * 4096;
			CurrentRot.Yaw = CurrentDir;
			//Spot 1		//FUTURO: tabajar con innumerables spots!
			if ( HSize( Location - Spot1) > 6 )	//Si proyectil pasa muy cerca, cualquier dirección sirve
			{	//Aunque siempre existe la chance de que el bot salga disparado hacia el propio misil =)
				SpotRot = Rotator( Spot1 - Location);
				if ( BFM.CompareRotation( SpotRot, CurrentRot, 4096, True) && (VSize(Spot1 - Location) < 140) )
					fCurrent += VSize( Spot1 - Location) / 28.0;
				else
					fCurrent += 5.0;
			}
			//Spot 2
			if ( HSize( Location - Spot2) > 6 )
			{
				SpotRot = Rotator( Spot2 - Location);
				if ( BFM.CompareRotation( SpotRot, CurrentRot, 4096, True) && (VSize(Spot2 - Location) < 140) )
					fCurrent += VSize( Spot2 - Location) / 28.0;
				else
					fCurrent += 5.0;
			}
			//Analizar disponibilidad del camino
			//Prioridades: Centro, Alto, Bajo
			Vectus = normal(Vector( CurrentRot));	//Aca entra en acción el plano de apoyo
			Vectus *= 128.0;
			Vectus.Z += Vectus.X * X;
			Vectus.Z += Vectus.Y * Y;
			Trace( HitLocation, HitNormal, Location + Vectus);
			fCurrent += VSize(Location - HitLocation) / 12.0;
			if ( !FastTrace(Location + Vectus) || !FastTrace(Location + Vectus - vect(0,0,100), Location + Vectus) )  
			{
				Trace( HitLocation, HitNormal, Location + Vectus + VectZ( CollisionHeight * 0.8), Location + VectZ(CollisionHeight * 0.8) );
				fCurrent += VSize( Location + VectZ(CollisionHeight * 0.8) - HitLocation) / 16.0;
				Trace( HitLocation, HitNormal, Location + Vectus + VectZ( CollisionHeight * -0.4), Location + VectZ(CollisionHeight * -0.4) );
				fCurrent += VSize( Location + VectZ(CollisionHeight * -0.4) - HitLocation) / 25.0;
			}
			else	//Hay caida
				fCurrent = 0;

			if ( fCurrent > fBest )
			{
				fBest = fCurrent;
				BestDir = CurrentDir;
			}
		}
		CurrentRot = Rot(0,0,0);
		CurrentRot.Yaw = BestDir;
		Vectus = Vector(CurrentRot) * 150;
		return Location + Vectus;
	}


	//Metodo de eleccion direccional acorde al punto de movimiento, evitando ambos spots
	//Se eligen 5 direcciones distintas aqui: -70º, -50º, 0º, 50º, 70º	(FUTURO: implementar mas direcciones)
	//Info del plano de apoyo utilizada aqui
	//DEPRECADO

}

//Requiere: MoveTarget=none, SpecialMoveTarget, MoveTimer < 0
function UnstateMovement( float DeltaTime) // NATIVE <-> NORMAL parity
{
	local vector aVec, eVec;
	local bool bReachedDestination;
	
	if ( CurFlight != none )
	{
		if ( !CurFlight.HandleFlight( self, DeltaTime) )
			Goto NOFLIGHT;
	}
	else
	{
		NOFLIGHT:
		
		if ( FaceTarget != None )
			Focus = FaceTarget.Location;
		if ( Focus != vect(0,0,0) )
			DesiredRotation = rotator( Focus - (Location + vect(0,0,1) * BaseEyeHeight) );
		
		if ( SpecialPause > 0 )
		{
		SPECIAL_PAUSE:
			//Do not let default navigation code interfere
			if ( SpecialPause == 2.5 )
			{
				Log("Detected SpecialPause 2.5"@SpecialGoal@MoveTarget);
				if ( Mover(Base) != None )
					SpecialPause = 0.15;
				else
					SpecialPause = 0.5;
			}
			SpecialPause -= DeltaTime;
			TiempoDeVida += DeltaTime * 0.7;
			Acceleration = vect(0,0,0);
			return;
		}
		
		//Leave unstate
		if ( SpecialMoveTarget == self )
		{
			SpecialMoveTarget = None;
			return;
		}
		
		//Timer control
		if ( (MoveTimer += DeltaTime) > -0.31 )
		{
			StopMoving( true);
			return;
		}
		
		//Reach decision
		if ( SpecialMoveTarget.bCollideActors )
		{
			bReachedDestination = InRadiusEntity(SpecialMoveTarget);
			if ( !bReachedDestination && (Physics == PHYS_Walking) )
			{
				bReachedDestination = HSize(Location - SpecialMoveTarget.Location) < CollisionRadius+SpecialMoveTarget.CollisionRadius;
				bTickedJump = SpecialMoveTarget.Location.Z > Location.Z; //Attempt to touch something above self
			}
		}
		if ( !bReachedDestination )
		{
			eVec = Location - OldLocation;
			aVec.X = VSize(eVec); //aka, movement distance
			if ( (aVec.X < GroundSpeed*10*DeltaTime) && (aVec.X > 0.01) ) //Not teleported, but moved
			{
				aVec.Y = (SpecialMoveTarget.Location - Location) dot Normal(eVec); //Is target in front or behind (relative to last movement)
				bReachedDestination = aVec.X * aVec.Y < 0; //Distance is always positive, but if behind the product is negative
			}
			bReachedDestination = bReachedDestination || VectorInCylinder(Location,SpecialMoveTarget.Location, 4+DeltaTime*100, 40); //Last resort
		}
		
		//Destination control
		if ( bReachedDestination )
		{
			if ( F_TempDest(SpecialMoveTarget) != none )
			{
				F_TempDest(SpecialMoveTarget).ReachedByBot(); //Can be chained
				if ( SpecialPause > 0 ) //Commanded to stop
					Goto SPECIAL_PAUSE;
				if ( (SpecialMoveTarget != None) && (SpecialMoveTarget != Self) )
					Goto POPPED;
			}
			else if ( !bCanFly && (Physics == PHYS_Falling) ) //If we can land, we should land before searching new path
			{
				//Cases where we shouldn't pop route cache during fall
				if ( (Mover(SpecialMoveTarget.Base) != none) || !Class'Botz_NavigBase'.static.IsHighPath(SpecialMoveTarget) || !Class'Botz_NavigBase'.static.IsHighPath(Self) )
					Goto END_MOVEMENT;
				if ( SpecialMoveTarget == RouteCache[0] )
				{
					if ( (RouteCache[1] != None) && (Mover(RouteCache[1].Base) != None) ) //Elevator
						Goto END_MOVEMENT;
					if ( LiftExit(SpecialMoveTarget) != none && LiftCenter(RouteCache[1]) != None ) //Scripted path
						Goto END_MOVEMENT;
					PopRouteCache(true);
					if ( SpecialMoveTarget != None )
						Goto POPPED;
				}
			}
		END_MOVEMENT:
			bUnStateMove = false;
			if ( bScriptedMove )
			{
				bScriptedMove = false;
				return;
			}
			SpecialMoveTarget = None;
			return;
		}
	POPPED:
		
		if ( Physics != PHYS_Falling )
		{
			aVec = Velocity * vect(1,1,0);
			aVec = MirrorVectorByNormal( aVec, HNormal(SpecialMoveTarget.Location - Location) );
			if ( VSize(aVec) > AccelRate )
				aVec = Normal( aVec) * AccelRate;
		}
		
		if ( Physics == PHYS_Swimming ) //AIR ACCEL HANDLED BY ANALYSEFALL
		{
			Acceleration = aVec + Normal(SpecialMoveTarget.Location - Location) * AccelRate * 2;
			if ( SpecialMoveTarget.Region.Zone.bWaterZone )
				Acceleration.Z *= 1.4;
			else
				Acceleration = Acceleration * vect(1.3,1.3,1) + aVec * 0.2;
			Destination = SpecialMoveTarget.Location;
		}
		else if ( Physics == PHYS_Walking )
			Acceleration = aVec + HNormal(SpecialMoveTarget.Location - Location) * AccelRate * 1.5;
		else if ( Physics == PHYS_Falling ) //Evaluate dest switching
		{
			//FUTURO: EVITAR CAER HACIA LA MUERTE, MEDIR FUTURO DAÑO
			if ( !bGeneralCheck && (F_TempDest(SpecialMoveTarget) == none) && (SpecialMoveTarget == RouteCache[0]) && (RouteCache[1] != none) )
			{
				aVec = BFM.SuperFlyLocation( self, RouteCache[1].Location);
				if ( (aVec.Z > RouteCache[1].Location.Z) //I can hover above the air point
					&& FastTrace( RouteCache[1].Location) //I can see the air point
					&& ( Class'Botz_NavigBase'.static.IsHighPath(SpecialMoveTarget) //Air point is strictly aerial, or I can safely land in it
						|| SpecialMoveTarget.Region.Zone.bWaterZone
						|| (BFM.FreeFallVelocity( SpecialMoveTarget.Location.Z-Location.Z, Region.Zone.ZoneGravity.Z) > -750 - JumpZ))
						)
					PopRouteCache(true);
			}
			
			AnalyseFall( DeltaTime);
		}
	}
}

//maintick
event Tick(float DeltaTime)
{
	local int i, j;
	local pawn P;
	local actor SomeTarget;
	local vector SomeVector;
	local float SomeFloat;
	local bool bCombatState;

	bGeneralCheck = !bGeneralCheck;
	SomeTarget = MoveTarget Or SpecialMoveTarget;
	CurDelta = DeltaTime;
	if ( bDebugLog )
		Log("BOTZ TICK 1, bGeneralCheck="$bGeneralCheck);

	Accumulator -= DeltaTime;
	if ( CombatWeariness < 0 )
		CombatWeariness += DeltaTime;

	bViewTarget = True;
	if ( NoDeleteTranslocs >= 0 )
		NoDeleteTranslocs -= DeltaTime;
	if ( DodgeAgain > 0 )
		DodgeAgain -= DeltaTime;
	For ( i=0 ; i<iFlight ; i++ )
		FlightProfiles[i].BotzUpdate( self, DeltaTime);


	//CPU INTENSIVE

	bCombatState = IsInState('CombatState');
	if (bCombatState)
		Goto IN_COMBAT;

	if ( !bUnstateMove && (MoveTarget != None) && (Physics == PHYS_Swimming || CurFlight != none || SpecialPause > 0) )
	{
		if ( SpecialPause > 0 )
			LifeSignal( SpecialPause + 0.2 );
		SwitchToUnstate();
	}
	if ( !bScriptedMove && bUnstateMove ) //Non state movement
	{
		if ( SpecialMoveTarget == none )
			bUnStateMove = false;
		else
			UnstateMovement( DeltaTime);
	}

	if ( bDebugLog )
		Log("BOTZ TICK 1.5");


	if ( (SpecialGoal != none) )
	{
		if ( Mover(SpecialGoal) != none )
		{	if ( Mover(SpecialGoal).TriggerActor == None )
				SpecialGoal.Bump( self); // FUTURO, movimiento en todas las ocasiones?
			else if ( Mover(SpecialGoal).bTriggerOnceOnly || VSize(Mover(SpecialGoal).TriggerActor.Location - Location) > 1200 ) //This is a special event, do not trigger
			{
			}
			else if ( !PointReachable(Mover(SpecialGoal).TriggerActor.Location) ) //Use point to avoid bot going to triggers placed inside the lift trayectory
				Mover(SpecialGoal).TriggerActor.Touch(self);
			else
			{
				SetMoveTarget( Mover(SpecialGoal).TriggerActor);
				Destination = Mover(SpecialGoal).TriggerActor.Location;
			}
		}
		else
			SetMoveTarget( SpecialGoal);
//			SpecialGoal.Touch(self);
		SpecialGoal = none;
	}

	if ( bDebugLog )
		Log("BOTZ TICK 2");
	if ( DeltaTime > MinDesiredDelta * Level.TimeDilation ) //Save some CPU if server is filled
	{
		if ( FRand() < 0.1 )
			Goto AFTER_GENERAL;
	}

	if ( bGeneralCheck ) //Divide CPU intensive actions in these 2 blocks
	{
		if (FRand() < (Skill * 0.143) + DeltaTime ) //Divide by 7, add deltatime (0.015 on local, 0.05 on server)
			TryToDodge();
		if ( (FRand() < 0.12 + Skill*0.015 - Punteria*0.01) && (Enemy == none) )
		{
			if ( FRand() < 0.5 )	BFM.FindMonsters( self);
			else					BFM.ScanEnemies( self);
		}
		if ( (FRand() < 0.40 + MinDesiredDelta * 2) && (Physics == PHYS_Walking) ) //Handle jumping before having to hit an obstacle
		{
			if ( (MoveTimer > 0) && (SomeTarget != none) && (Destination != vect(0,0,0) ) && (VSize(Destination - SomeTarget.Location) > 40) )
				SomeTarget = none;
			if ( (VSize(Acceleration) > 50) && ( (SomeTarget != none) || (Destination != vect(0,0,0)) ) )
			{ //I am running towards some place
				if ( NeedNoFloorJump( SomeTarget, Destination) )
				{
					SomeVector = SimpleDirectJump( SomeTarget, Destination);
					if ( SomeVector == vect(0,0,0) ) //FUTURO: elegir un salto mas perpendicular entre ambos pisos
					{
					}
					else if ( SomeVector == vect(0,0,1) )
					{
						MoveTarget = SomeTarget;
						if ( MoveTarget != none)
							bTickedJump = true; //Simple jump here
					}
					else if ( SomeVector == vect(0,0,-1) )
					{	//Do nothing
					}
					else
					{
						PendingTouch = self; //This disables TickJump set in BaseChange and takes us to WaitForLanding
						Velocity = SomeVector;
						Acceleration = SomeVector;
						Acceleration.Z = 0;
						if ( SomeTarget != none)
						{
							MoveTarget = SomeTarget;
							SpecialMoveTarget = SomeTarget;
						}
						PlayInAir();
						SetPhysics( PHYS_Falling);
						PlaySound(JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
					}
				}
				
			}
		}
	}
	else
	{ //Don't shorten during flight
		if ( (CurFlight == none) && (FRand() < 0.3 + MinDesiredDelta) && (Physics == PHYS_Walking) && IsMoving( true) && ((MoveTarget Or SpecialMoveTarget) == RouteCache[0]) ) //Renewing navigation outside of state code, happens around 1/6 ticks
		{
			i = 1;
			While ( i<16 )
			{
				if ( RouteCache[i] != none)
					i++;
				else
					break;
			}
			For ( --i ; i>0 ; i--) //May not even happen at all
			{
				if ( !PointReachable( BFM.SlantStep(RouteCache[i].Location, CollisionRadius, CollisionHeight * 2)) || BadEventTowards( RouteCache[i].Location) )
					continue;

				if ( (FaceTarget != none) && ((FaceTarget == RouteCache[0]) || !FastTrace(FaceTarget.Location)) )
					FaceTarget = RouteCache[1];
				if ( DebugMode )
					Log("TICK PATH SHORTENING: "$GetItemName(string(RouteCache[0]))@">"@GetItemName(string(RouteCache[0])) );
				PopRouteCache( true);
				Destination = RouteCache[0].Location;

				MoveTimer = 0.1 + (HSize( Destination - Location) * 1.1) / GroundSpeed;
				LifeSignal( MoveTimer);
				if ( MoveTarget == none ) //UNSTATE!
					MoveTimer = -1;

				PickLocalInventory(200, float(IsInState('Attacking')) * 0.15 );
				if ( MoveTarget == none ) //UnState
				{
					MoveTarget = SpecialMoveTarget;
					PostPathEvaluate(); //Perform shortcuts while shortcutting, nice
					SpecialMoveTarget = MoveTarget;
					if ( !IsInState('TranslocationChain') && !IsInState('ImpactMode') )
						MoveTarget = none;
				}
				else
					PostPathEvaluate(); //Perform shortcuts while shortcutting, nice
				break;
			}
		}
		if (FRand() < (Skill - 6.0) ) //Uber dodging from skill level 6
			TryToDodge();
		if ( (FRand() < (0.05 - Punteria*0.01)*0.5 ) && AimPoint.SniperWeapon(self) )
			LocateEnemy( ViewRotation, 3500);
	}

	
	if ( (Enemy != None) && (bFire+bAltFire != 0) && (DodgeAgain <= 0) && (F_TempDest(SomeTarget) == None) )
	{
		DodgeAgain = 0.5 + DeltaTime - Skill * 0.01;
		//Check if charging against melee/big enemy
		SomeVector = Enemy.Location - Location;
		//Assess danger factor
		SomeFloat = 3 - fMin( 1200, VSize(SomeVector + Enemy.Velocity)) / 200; //3 to -3
		if ( Enemy.Enemy != self )
			SomeFloat *= 0.5;
		if ( Enemy.Weapon != None ) //Enemy's weapon
			SomeFloat += (int(Enemy.Weapon.bMeleeWeapon) + int(Enemy.Weapon.bRapidFire) + Enemy.Weapon.AIRating) * 0.5;
		if ( Weapon != None ) //My weapon
			SomeFloat -= int(Weapon.bMeleeWeapon) + int(Weapon.bRapidFire) + Weapon.AIRating;
		//What makes the bot be cautious
		SomeFloat += fClamp( float(Enemy.Health-Health) * 0.02, -2, 2)
				+ fClamp( (Enemy.CollisionRadius - CollisionRadius) * 0.02, -2, 2)
				+ int(Enemy.IsA('ScriptedPawn')) * 2; //Monsters are good melee fighters
		//What makes the bot rush
		SomeFloat -= Aggresiveness*2 + DistractionLimit*2
				+ int( !EnemyAimingAt( self)) * 2 //Nobody's paying attention to me
				+ int( Region.Zone.IsA('KillingField')) * 100 //Assault killing fields, override all logic
				+ int( Enemy.IsA('StationaryPawn')) * 2  //But charge towards cannons
				+ int( Region.Zone.bWaterZone ^^ Enemy.Region.Zone.bWaterZone ) * 2;

		ForEach PawnActors( class'Pawn', P, 3000)
			if ( P.Enemy != None )
			{
				if ( P.Enemy.PlayerReplicationInfo != None && P.Enemy.PlayerReplicationInfo.Team == PlayerReplicationInfo.Team )
					SomeFloat += 0.1;
				else
					SomeFloat -= 0.1;
			}
				
		//Continue task
		if ( SomeFloat < 0 )
		{
			if ( Velocity dot SomeVector >= 0 ) //Heading towards the enemy or stationary
			{
				SomeTarget = MoveTarget Or SpecialMoveTarget;
				if ( SomeTarget == Enemy ) //Keep reasonable distance from enemy
				{
					if ( VSize( SomeVector) < 200+Enemy.CollisionRadius+Enemy.CollisionHeight*0.3 )
						MasterEntity.TempDest().Setup( Self, Self, DodgeAgain - DeltaTime*2, NearSpot(Location,500,200,-Normal(SomeVector)) );
				}
				else if ( (SomeTarget != none) && IsMoving() ) //Moving
				{
					Destination = Normal(SomeTarget.Location - Location);
					Destination = Location + Destination * (Destination dot SomeVector); //Get orthogonal projection of enemy onto my path
					if ( VSize( Destination - Enemy.Location) < 70 + Enemy.CollisionRadius )
					{
						CollideTrace( Destination, SomeVector, Destination + (Destination - Enemy.Location), Destination);
						MasterEntity.TempDest().Setup( Self, SomeTarget, DodgeAgain - DeltaTime*2, Destination);
					}
				}
			}

		}
		//Flee or sit
		else
		{
			if ( VSize( SomeVector) < 500+SomeFloat*100 ) //Flee
			{
				MasterEntity.TempDest().Setup( Self, Self, DodgeAgain - DeltaTime*2, NearSpot(Location,700,300,-Normal(SomeVector)) );
			}
			else
			{
				SpecialPause = DodgeAgain - DeltaTime * 2;
				if ( MoveTimer > 0 )
					SwitchToUnstate();
			}
		}
				
		if ( DebugMode || DebugSoft )
			Log( "Evaluate for " $ Enemy.Name $ ": "$SomeFloat);
	}
	
	
	IN_COMBAT:
	AFTER_GENERAL:
	if ( bDebugLog )
		Log("BOTZ TICK 3");

	if ( (SubOrders == 'GetOurFlag') && ( (SubOrderObject == none ) || SubOrderObject.IsInState('Home')) )
	{
		SetSubOrders(OldSubOrders, OldSubOrderObject);
		StopMoving();
	}

	if (bPendingTransloc)
	{
		bPendingTransloc = False;
		if ( !bAirTransloc )
			SwitchToBestWeapon();
		if ( NoDeleteTranslocs <= 0 )
			DeleteTranslocators(false);
	}
	if ( bTickedJump )
		ProcessTickJump();
	CheckFlag();
	if ( (TiempoDeVida + 3) < Level.TimeSeconds ) //Post-Pause fix
		LifeSignal(1);
	if (bGameStarted && (Physics != PHYS_Falling) && !bCombatState && (TiempoDeVida < Level.TimeSeconds) )
	{
		if ( DebugMode )
		{
			Log("Life-Signal trajo al bot de nuevo al juego");
			Log("State es"@string(GetStateName())$"; SavedState es"@string(SavedState)$"; SavedLabel es"@string(SavedLabel) );
		}
		QueHacerAhora();
	}


	//Stop tick if in a scripted fire state
	if ( IsInState('ImpactMode') )
		return;
		
	if ( Weapon == PendingWeapon )
		PendingWeapon = none;

	if ( Weapon != none && !IsInState('InitialStand') )
	{
		if ( !ClassIsChildOf(Weapon.class, WeaponProfile.WeaponClass) && (PendingWeapon == none) )
			UpdateProfile(Weapon);
		else if ( (PendingWeapon != none) && (WeaponProfile.WeaponClass != PendingWeapon.class) )
		{
			HaltFiring();
			UpdateProfile( PendingWeapon);
		}

		if ( ProfileFire( DeltaTime, bCombatState) )
			return;

		if ( bCombatState )
		{
			if ( FRand() * 28 < (Skill+7) )
				WeaponProfile.SuggestFire( self, CurrentTactic); //FUTURO, HACK FIX
			return;
		}
		if ( (CombatWeariness >= 0) && WeaponProfile.SuggestCombat(self,"") )
		{
			return;
		}
	}

	//Don't process firing code all frames if FPS is below desired
	if ( DeltaTime > MinDesiredDelta * Level.TimeDilation)
	{
		if ( !bGeneralCheck )
			return;
		DeltaTime *= 2;
	}


	if ( bDebugLog )
		Log("BOTZ TICK 4, enemy is"@Enemy);
	if ( bDebugLog && Health > 0 )
		bDebugLog = false;
	//Enemy handling from here below, don't insert code here
	if ( Enemy == none || AimPoint == none )
	{
		HaltFiring();
		return;
	}
	if ( !LineOfSightTo(Enemy) && !FastTrace(Enemy.Location) )
	{
		SomeVector.Z = Level.TimeSeconds - AimPoint.LastSeenTime;
		if ( (SomeVector.Z > (1.7 + (Level.TimeSeconds%1.0))) || (!FastTrace(AimPoint.Location) && SomeVector.Z > 0.5) )
		{
			HaltFiring();
			return;
		}
	}
	if ( (Enemy.Health <= 0)  || (Enemy == self) )
	{
		if ( Skill > 2 )
			HaltFiring();
		Enemy = none;
		bKeepEnemy = false;
		QueHacerAhora();
		return;
	}

	if ( (AimPoint.PointTarget != none) && (AimPoint.PointTarget != self) )
	{
		FinalMoveTarget = AimPoint.PointTarget;
		FaceTarget = AimPoint.PointTarget;
		Focus = AimPoint.PointTarget.Location;
	}


	if ( bGeneralCheck )
		SetAttackDistance(Enemy);
	if ( (Enemy != none) && (AimPoint != none) )
		AimPoint.Tick(0.0);
	UpdateEyeHeight(0.0);	//No disparar a los compañeros
	FireWeapon();
	if ( bDebugLog )
		Log("BOTZ TICK 5");
}

///////////////////////////////////////////////////////////
//////// Control latente de animaciones, revisado en cada tick
//**********************************************************
//Notes: PlayRunning() sets BaseEyeHeight to default

function AnimationControl()
{
	local vector X,Y,Z, Dir;
	local name MyAnimGroup, NewAnim;
	
	MyAnimGroup = GetAnimGroup(AnimSequence);

	//Walking physics
	if ( Physics == Phys_Walking )
	{
		//I am moving
		if ((Velocity.X * Velocity.X + Velocity.Y * Velocity.Y) >= 1000)
		{
			//I am crouching
			if ( BaseEyeHeight == 0 )
			{
				//Beggining crouch
				if ( MyAnimGroup != 'Ducking' )
				{
					if ( (Weapon == None) || (Weapon.Mass < 20) )
						NewAnim = 'DuckWlkS';
					else
						NewAnim = 'DuckWlkL';
					LoopAnim( NewAnim, , 0.25);
				}
				//Already in crouch mode
				else
					PlayCrawling();
			}
			//I am running
			else
			{
				//Resuming running
				if ( (MyAnimGroup == 'Waiting') || (MyAnimGroup == 'Gesture') || (MyAnimGroup == 'TakeHit') || (MyAnimGroup == 'Landing') || (MyAnimGroup == 'Jumping') || (MyAnimGroup == 'Ducking') )
				{
					//This is TweenToRunning
					GetAxes(Rotation, X,Y,Z);
					Dir = Normal(Acceleration);
					if ( (Dir Dot X < 0.75) && (Dir != vect(0,0,0)) )
					{
						// strafing or backing up
						if ( Dir Dot X < -0.75 )
							NewAnim = 'BackRun';
						else if ( Dir Dot Y > 0 )
							NewAnim = 'StrafeR';
						else
							NewAnim = 'StrafeL';
					}
					else if (Weapon == None)
						NewAnim = 'RunSM';
					else if ( Weapon.bPointing ) 
					{
						if (Weapon.Mass < 20)
							NewAnim = 'RunSMFR';
						else
							NewAnim = 'RunLGFR';
					}
					else
					{
						if (Weapon.Mass < 20)
							NewAnim = 'RunSM';
						else
							NewAnim = 'RunLG';
					} 
					if ( !HasAnim( NewAnim) )
						NewAnim = 'RunSM'; //Default, fixes yoshi
					LastAnimFrame = 0; //Reset for safety
					LoopAnim( NewAnim, , 0.1);
					return;
 				}
 				//Force running
 				else
 				{
 					//Change animation to movingfire
 					if ( (MyAnimGroup != 'MovingFire') && (Weapon != none) && Weapon.bPointing )
 						PlayFiring(); //Works here
 					//Animation just looped
 					if ( LastAnimFrame > AnimFrame )
 					{
 						//This is TournamentPlayer's PlayRunning();
					 	BaseEyeHeight = Default.BaseEyeHeight;
					
						GetAxes(Rotation, X,Y,Z);
						Dir = Normal(Acceleration);
						if ( (Dir Dot X < 0.75) && (Dir != vect(0,0,0)) )
						{
							// strafing or backing up
							if ( Dir Dot X < -0.75 )
								NewAnim = 'BackRun';
							else if ( Dir Dot Y > 0 )
								NewAnim = 'StrafeR';
							else
								NewAnim = 'StrafeL';
						}
						else if (Weapon == None)
							NewAnim = 'RunSM';
						else if ( Weapon.bPointing ) 
						{
							if (Weapon.Mass < 20)
								NewAnim = 'RunSMFR';
							else
								NewAnim = 'RunLGFR';
						}
						else
						{
							if (Weapon.Mass < 20)
								NewAnim = 'RunSM';
							else
								NewAnim = 'RunLG';
						}
						//Don't change to a new animation if I don't have one, fixes yoshi
						if ( HasAnim(NewAnim) )
						{	//Only change animation if i have to
							if ( NewAnim != AnimSequence )
							{
								LoopAnim( NewAnim);
								LastAnimFrame = 0;
								return;
							}
						}

 					}
 				}
 
			}
			//I am walking?
			//else
		}
		//I am not moving
		else
		{
			//I am crouching
			if ( BaseEyeHeight == 0 )
			{
				//Begin ducking
				if ( MyAnimGroup != 'Ducking' )
				{
					if ( (Weapon == None) || (Weapon.Mass < 20) )
						TweenAnim('DuckWlkS', 0.25);
					else
						TweenAnim('DuckWlkL', 0.25);
				}
				//Continue crouching, FUTURO: implementar rotacion
				else
					AnimRate = 0;
			}
			//I am standing
			else if ( BaseEyeHeight > 0 )
			{
				//Begin waiting
				if ( MyAnimGroup != 'Waiting' )
				{
					//TweenToWaiting()
					BaseEyeHeight = Default.BaseEyeHeight;
					if ( (Weapon == None) || (Weapon.Mass < 20) )
						TweenAnim('StillSMFR', 0.2);
					else 
						TweenAnim('StillFRRP', 0.2);
				}
				//Animation stopped, pick a new one
				else if ( !IsAnimating() )
				{
					PlayWaitingF();
				}

			}

		}
	}
	else if ( Physics == PHYS_Swimming ) //FUTURO: TERMINAR
	{
		if ( (vector(Rotation) Dot Acceleration) > 0 )
			PlaySwimming();
		else
			PlayWaiting();
		return;
	}

	LastAnimFrame = AnimFrame;
}

final function AnalyseFall( float DeltaTime)
{ //*** ESTA FUNCION SE CENTRA EN EL MOVETARGET, SI SOLO HAY VECTOR DEST, CREAR MOVETARGET TEMPORARIO
	local vector RealFall, Adjust;
	local float MaxSpeedToTarget, Total;
	local int i;

	//Ai Helper vars
	local vector CalcSpeed, vOS;


//******* ANIMACIÓN
	if ( bAnimFinished )
		PlayInAir();

	if ( SpecialMoveTarget == none || SpecialMoveTarget == self )
		return;
	MoveTarget = none;

	if ( bCanTranslocate && (Weapon == MyTranslocator) && Weapon.IsInState('Idle') && (MyTranslocator.TTarget == none) )
	{
		if ( (Enemy != none) && (HSize(SpecialMoveTarget.Location - Enemy.Location) < 150) )
		{
			BotzTranslocateToTarget( Enemy, false, true);
			MyTranslocator.TTarget.LifeSpan = 3.5;
			MyTranslocator.SetCollisionSize( 10, 10);
			Goto FALLACCEL;
		}
		Total = Skill + FRand() * 2;
		if ( (HSize( SpecialMoveTarget.Location - Location) < 30) && FastTrace(SpecialMoveTarget.Location) )
		{//FUTURO: Tirar translocalizador trucado para no trancarse en el aire
			if ( VSize( SpecialMoveTarget.Location - Location) > 150 )
			{
				if ( NavigationPoint(SpecialMoveTarget) != none )
				{
					For ( i=int(Total) ; i>0 ; i-- )
					{
						if ( (RouteCache[i] != none) && FastTrace(RouteCache[i].Location) )
						{
							BotzTranslocateToTarget( RouteCache[i], False, True);
							if ( BotzTTarget(MyTranslocator.TTarget) != none ) 
								BotzTTarget(MyTranslocator.TTarget).PostTarget = RouteCache[i+1];
							break;
						}
					}
				}
				else
					BotzTranslocateToTarget( SpecialMoveTarget, False);
			}
			else
				SwitchToBestWeapon();
			return;
		}
		bAirTransloc = True;
		if ( NavigationPoint(SpecialMoveTarget) != none )
		{
			For ( i=int(Total) ; i>0 ; i-- )
			{
				if ( (RouteCache[i] != none) && FastTrace(RouteCache[i].Location) )
				{
					BotzTranslocateToTarget( RouteCache[i], False, True);
					if ( BotzTTarget(MyTranslocator.TTarget) != none ) 
						BotzTTarget(MyTranslocator.TTarget).PostTarget = RouteCache[i+1];
					break;
				}
			}
			if ( MyTranslocator.TTarget == none )
				BotzTranslocateToTarget( SpecialMoveTarget, False, True);
		}
		else
			TranslocateToTarget( SpecialMoveTarget);
		return;
	}
	else if ( bCanTranslocate && (Weapon == MyTranslocator) && (MyTranslocator.TTarget != none) )
	{
		SwitchToBestWeapon();
	}
	Total = 0;



	if ( (VSize( SpecialMoveTarget.Location - Location) < 150) && (HSize( SpecialMoveTarget.Location - Location) < 70) && FastTrace(SpecialMoveTarget.Location, Location - VectZ(CollisionHeight * 0.8) ) )
	{ //Reached Target, don't translocate
	}
	else if ( (Velocity.Z > 100.0) && (Location.Z < SpecialMoveTarget.Location.Z) )
	{	//Chill out, still trying to reach my target
	}
	else if ( (Enemy != none) && (Enemy.Health < 80) && (Location.Z > SpecialMoveTarget.Location.Z) && (Velocity.Z < 0.0) && CheckPotential() && (Weapon != MyTranslocator) )
	{	// Lets kill the guy if i can
	}
	else if ( (Enemy != none) && (HSize(SpecialMoveTarget.Location - Enemy.Location) < 100) )
	{	//Enemy is in front of you, don't be stupid
	}
	else if ( EnemyAimingAt(self, true) )
	{	//Enemy is firing at me
	}
	else if ( bCanTranslocate && (Weapon != MyTranslocator) && (PendingWeapon != MyTranslocator) && (MyTranslocator.TTarget == none) && (LastTranslocCounter <= 0) && (SpecialMoveTarget != OrderObject) )
	{//FUTURO: Fix de la ultima condicion, transloc no al lider, pero un punto cercano =)
		DeleteTranslocators( False);
		GetWeapon( class'Translocator');
	}
	
		
FALLACCEL:
//BETTER AIR CONTROL
	MaxSpeedToTarget = fMax( AirSpeed, Velocity dot HNormal(SpecialMoveTarget.Location - Location)); //Kickers can make the bot able to reach unreasonable distant locations
	if ( BFM.CanFlyTo( Location, SpecialMoveTarget.Location, Region.Zone.ZoneGravity.Z, Velocity.Z, MaxSpeedToTarget) )
	{
		CalcSpeed = BFM.AdvancedJump( Location,  SpecialMoveTarget.location, Region.Zone.ZoneGravity.Z, Velocity.Z, MaxSpeedToTarget, false);
		Acceleration = (CalcSpeed - Velocity) * 2;
		if ( bSuperAccel && Velocity.Z > 0 )
			Acceleration += HNormal( Acceleration) * AirSpeed * 2;
	}
	else
	{
		CalcSpeed = HNormal( SpecialMoveTarget.Location - Location) cross vect(0,0,1); //Rotate 90º to right
		CalcSpeed = (Velocity dot CalcSpeed) * CalcSpeed;
		Acceleration = HNormal( SpecialMoveTarget.Location - Location) * accelrate - CalcSpeed;
		if ( bSuperAccel && (Velocity.Z > 0) )
			Acceleration += HNormal( SpecialMoveTarget.Location - Location) * (AirSpeed * 2.2);
	}
}

function SetMove(vector DestLoc, actor NFace, optional /*future*/ bool Vertical)
{
	Destination = DestLoc;
	FaceTarget = NFace;
}


function SetAttackDistance(actor AttackTarget)
{
	local float Dist;

	if (AttackTarget == none)
		return;

	Dist = VSize(AttackTarget.Location - Location) * (1+Punteria*0.1+Aggresiveness*0.1) + Punteria*10 - Aggresiveness * 100;

	if (Dist < 650)
		AttackDistance = AD_Cercana;
	else if (Dist < 2300)
		AttackDistance = AD_Media;
	else
		AttackDistance = AD_Larga;
}

//******************************************************************************************
//******************************************************************************************
//****************************FUNCIONES DE EVALUACION DEL NIVEL*****************************
//USOS:		CHECKEAR PUNTOS DE DEFENSA CON RESPECTO A LOS BOTZ Y BOT DEFENDIENDO************
/*
function EvaluarPuntosDefensivos()
{
	local actor Defensivos[32];
	local DefensePoint TDef;						Posiblemente obsoleto
	local 
*/

function PostPathEvaluate()
{
	local Mover Lift;
	local Actor A;
	local LiftCenter LC;
	local LiftExit LE;
	local NavigationPoint N;
	local int i, j;
	local vector aVec, eVec;
	local Botz_NavigBase cNavig;

	if ( bNative )
	{
		For ( i=0 ; i<15 ; i++ )
			if ( Botz_NavigBase(RouteCache[i]) != none )
				Botz_NavigBase(RouteCache[i]).QueuedForNavigation( self, i);
		cNavig = Botz_NavigBase(MoveTarget);
		if ( (cNavig != none) && cNavig.PostPathEvaluate(self) ) //Path evaluation handled by custom navigation routines
			return;
	}

	if (MoveTarget == none)
		return;

	//Handle inventory and touchables
	if ( BFM.ISpotCorrection( self, InventorySpot(MoveTarget)) )
		MoveTarget = InventorySpot(MoveTarget).MarkedItem;

	
	if ( MoveTarget.bCollideActors && InRadiusEntity(MoveTarget) )
	{
		aVec = MoveTarget.Location;
		aVec.Z += MoveTarget.CollisionHeight; //Land point
		eVec = Location;
		eVec.Z = aVec.Z + CollisionHeight + 2; //Mininum zero velocity point needed to jump above item
		if ( (Physics == PHYS_Walking)
		&& FastTrace(eVec + vect(0,0,1)*CollisionHeight) //Won't hit ceiling
		&& (Region.Zone.ZoneGravity.Z < -900)
		&& BFM.CanFlyTo( Location, eVec, Region.Zone.ZoneGravity.Z, JumpZ, 99999)		) //Can jump high enough
		{
			bTickedJump = true;
			bTickedSuperJump = true;
		}
		else
			MoveTarget = MasterEntity.TempDest().PassiveSetup( Self, MoveTarget, 2, HNormal(VRand()*2+Location-MoveTarget.Location)*(CollisionRadius*2+MoveTarget.CollisionRadius) );
		return;
	}
		
/*	if ( LiftCenter(MoveTarget) != None )
		Lift = LiftCenter(MoveTarget).MyLift;
	else if ( Botz_LiftCenter(MoveTarget) != None )
		Lift = Botz_LiftCenter(MoveTarget).MyMover;
	if ( Lift != none )
	{								//Se Viene una dificil
		if ( PointReachable(MoveTarget.Location) )
			return;
		if ( BFM.CanFlyTo( Location, MoveTarget.Location, Region.Zone.ZoneGravity.Z, JumpZ, GroundSpeed * 1.05)
			&& (BFM.FreeFallVelocity( MoveTarget.Location.Z-Location.Z, Region.Zone.ZoneGravity.Z) > -850 - JumpZ - Lift.Velocity.Z ) )
			return;
		//Elevator could be closer?
		if ( (MoveTarget.Location.Z > ( Location.Z + CollisionHeight*0.5)) || !BFM.NearestMoverKeyFrame( Lift, Location, 50) )
		{
			LE = LiftExit( FindCurrentPath(class'LiftExit') );
			if ( !Lift.bOpening && !Lift.bDelaying && (Lift.SavedTrigger == none) && (Lift.Instigator == none) && (LE != None) )
				SpecialGoal = LE.RecommendedTrigger;
			//Elegir un punto que permita tocar el Trigger
			if ( SpecialGoal != None )
			{
				aVec = SpecialGoal.Location + (Normal(Location - SpecialGoal.Location)*FRand()+VRand()*vect(1,1,0.5)) * (CollisionRadius + SpecialGoal.CollisionRadius);
				if ( HSize( aVec - SpecialGoal.Location) > CollisionRadius + SpecialGoal.CollisionRadius )
					aVec = (aVec + SpecialGoal.Location) * 0.5;
			}
			if ( (SpecialGoal != none) && PointReachable(aVec) )
				MoveTarget = MasterEntity.TempDest().PassiveSetup( Self, MoveTarget, 5, aVec);
			else
			{
				SpecialPause = 0.5;
				MoveTarget = Self;
			}
			return;
		}
	}*/
	
	//Lifts can be complex AttachMovers
	if ( Base != None )					Lift = Mover(Base.Base);
	else if ( MoveTarget.Base != None )	Lift = Mover(MoveTarget.Base.Base);
	Lift = Mover(Lift Or Mover(Base) Or Mover(MoveTarget.Base));
	if ( Lift != None )
	{
		A = BFM.SimpleHandleLift( Lift, self, FindCurrentPath() );
		if ( A == Lift ) //Bump the lift
		{
			bTickedJump = true;
			MoveTarget = Lift; //Will this work?
			return;
		}
		if ( A != None )
		{
			//Botz super handling!
			if ( Lift.bInterpolating && (Base == Lift) && (Lift.Velocity.Z > 0) && !PointReachable(MoveTarget.Location) )
			{
				aVec.Z = JumpZ + Lift.Velocity.Z;
				
				i = Min(5,1+Rand(Skill));
				while ( (i-- > 0) && !bTickedJump )
				{
					N = RouteCache[i];
					if ( (N != None)
						&& BFM.CanFlyTo( Location, N.Location, Region.Zone.ZoneGravity.Z, aVec.Z, GroundSpeed * 1.05) 
						&& BFM.JumpCollision( self, Location, N.Location, Region.Zone.ZoneGravity.Z, aVec.Z, 50, 6 /*steps*/) )
					{
						A = N;
						bTickedJump = true;
						bTickedSuperJump = true;
					}
				}
			}
			
			//No super handling
			if ( !bTickedJump )
			{
				if ( InRadiusEntity(A) )
					SpecialPause = 0.15;
			}
			
			MoveTarget = A;
			return;
		}
		
	}
	
	LC = LiftCenter( FindCurrentPath(class'LiftCenter'));	
/*
	if ( Mover(Base) != none )
	{
		Lift = Mover(Base);
		MoveTarget = BFM.SimpleHandleLift;
		if ( MoveTarget.Base != Lift ) //Generic
		{
			
			//Evaluate fall
			if ( (Base.Velocity.Z < 0)
				&& !MoveTarget.Region.Zone.bWaterZone
				&& (MoveTarget.Location.Z < Location.Z)
				&& ((BFM.FreeFallVelocity( MoveTarget.Location.Z-Location.Z, Region.Zone.ZoneGravity.Z) < -750 - JumpZ) //Fall too hard
					|| (BFM.FreeFallVelocity( MoveTarget.Location.Z-Location.Z, Region.Zone.ZoneGravity.Z) > Base.Velocity.Z) ) //Fall slower than elevator
					)
				Goto STOP_FORCE;

			if ( !PointReachable( MoveTarget.Location) )
			{
				aVec = Normal(Base.Velocity);
				if ( (aVec.Z > 0.7) && (Base.Velocity.Z > 1) ) //Subiendo
				{
					if ( Location.Z+CollisionHeight+MoveTarget.CollisionHeight*0.5 < MoveTarget.Location.Z )
						Goto STOP_FORCE; 				//Destino encima del bot
					if ( HSize(Location - MoveTarget.Location)/GroundSpeed > (MoveTarget.Location.Z-Location.Z)/Base.Velocity.Z )
						goto STOP_FORCE;				//Destino aun no alcanzable antes de tocar punto superior (acortamiento de camino)
				}
				if ( Abs(aVec.Z) < 0.2 && !BFM.NearestMoverKeyFrame( Mover(Base), MoveTarget.Location, GroundSpeed*0.2) ) 
					Goto STOP_FORCE;					//Z-Estacionario + no dirigiendose al LiftExit designado
				if ( Mover(Base).bDelaying && MoveTarget.Location.Z > Location.Z+CollisionHeight )
					goto STOP_FORCE;					//Aun no empezamos a subir
				if ( !Mover(Base).bInterpolating && !Mover(Base).bDelaying )
				{
					if ( Mover(Base).KeyNum == 0 )
					{
						if ( Base.IsInState('StandOpenTimed') || Base.IsInState('BumpOpenTimed') || (Base.IsInState('TriggerOpenTimed') && (Mover(Base).BumpEvent == Base.Tag || Mover(Base).PlayerBumpEvent == Base.Tag)) )
						{
							bTickedJump = true;
							SpecialPause = 0.5;
							Goto STOP_FORCE;
						}
						else if (  Base.IsInState('TriggerOpenTimed') )
							Goto BACK_TO_LIFT_CENTER;

					}
					else if ( Mover(Base).KeyNum+1 == Mover(Base).NumKeys ) //LastKey
					{
						//Handle ElevatorMover's
						if ( Base.IsInState('TriggerToggle') && !BFM.NearestMoverKeyFrame( Mover(Base), MoveTarget.Location) )
							Goto BACK_TO_LIFT_CENTER;
					}
				}
				else
				{
					if ( Mover(Base).KeyNum+1 == Mover(Base).NumKeys ) //Last key
					{
						aVec.Z = Default.JumpZ * Level.Game.PlayerJumpZScaling() + Mover(Base).Velocity.Z;
						if ( BFM.CanFlyTo( Location, MoveTarget.Location, Region.Zone.ZoneGravity.Z, aVec.Z, GroundSpeed * 1.05) )
						{
							if ( Mover(Base).BasePos.Z + Mover(Base).KeyPos[Mover(Base).KeyNum].Z < MoveTarget.Location.Z - 60 ) //Unreachable
								bTickedJump = true;
							else if ( bGeneralCheck && BFM.JumpCollision( self, Location, MoveTarget.Location, Region.Zone.ZoneGravity.Z, aVec.Z, , 0/*steps*/) )
								bTickedJump = true;
						}
					}
				}
			}
			if ( false )
			{
			STOP_FORCE:
				MoveTarget = LC Or Self;
				SpecialPause = 0.5;
				RouteCache[0] = NavigationPoint(MoveTarget);
				RouteCache[1] = none;
				return;
			BACK_TO_LIFT_CENTER: //BASE ES UN MOVER, FUTURO: ACORTAR PUNTO DE SALIDA SI EL TRIGGER ESTA EN EL ELEVADOR
				ForEach NavigationActors (class'LiftExit', LE, 500,, true)
					if ( (LE.LiftTag == Base.Tag) && PointReachable(LE.Location) )
					{
						MoveTarget = LE;
						RouteCache[0] = LE;
						RouteCache[1] = none;
						return;
					}
				return;
			}			
		}
	}*/


	if (DebugMode && (MoveTarget.IsA('LiftCenter') || MoveTarget.IsA('LiftExit') ) )
	{
		log("Alcanzable"@MoveTarget.Name$": "$ActorReachable(MoveTarget)$", "$PointReachable(MoveTarget.Location) );
	}

	if ( (LiftCenter(MoveTarget) != none) && (LiftCenter(MoveTarget).MyLift == none) )
	{
		if ( !PointReachable(MoveTarget.Location)  )
		{
			if ( MoveTarget.IsA('JumpSpot') )	//JumpSpot Handling
			{
				if ( CanHighJump() )
					HighJump(MoveTarget);
				else if (bCanTranslocate)
				{
					TranslocateToTarget(MoveTarget);
					if ( BotzTTarget(MyTranslocator.TTarget) != none ) 
						BotzTTarget(MyTranslocator.TTarget).PostTarget = RouteCache[1];
				}
				return;
			}
			else if (MoveTarget.IsA('TranslocDest') && bCanTranslocate)
			{
				TranslocateToTarget(MoveTarget);
				if ( BotzTTarget(MyTranslocator.TTarget) != none ) 
					BotzTTarget(MyTranslocator.TTarget).PostTarget = RouteCache[1];
				return;
			}
		}
	}

	if ( (LC != none) && (LC.MyLift == none) && MoveTarget.IsA('LiftExit') )
	{
		if (MoveTarget.IsA('TranslocDest') && bCanTranslocate && !PointReachable(MoveTarget.Location)) 
		{
			TranslocateToTarget(MoveTarget);
			return;
		}
		if ( !PointReachable(MoveTarget.Location) && LC.IsA('JumpSpot') )
		{
			if ( (VSize(Location - MoveTarget.Location) < 200) 			//Condición del BotPack
				 && ( abs(Location.Z - MoveTarget.Location.Z) < 500) && (Location.Z > Movetarget.Location.Z) )
				Goto ASSIGN_LIFESIGNAL;
			if ( CanHighJump() )
				HighJump(MoveTarget);
			else if (bCanTranslocate)
			{
				TranslocateToTarget(MoveTarget);
				if ( BotzTTarget(MyTranslocator.TTarget) != none ) 
					BotzTTarget(MyTranslocator.TTarget).PostTarget = RouteCache[1];
			}
			return;
		}
	}
	

	//**************************
	//Shortcuts taken by the bot
	if ( LiftExit(RouteCache[0]) != none ) //Approaching lift exit
	{
		LC = LiftCenter( RouteCache[1]);
			
		if ( JumpSpot(LC) != none )
		{
			if (false) //FUTURO: Can make a clean jump to the lift center
			{
			}
			else if ( bCanTranslocate )
				if ( (Enemy == none) || (VSize(Enemy.Location - Location) > 200) )
				{
					PendingWeapon = MyTranslocator;
					Weapon.PutDown();
				}
			return;
		}
		else if ( (TranslocDest(LC) != none) && bCanTranslocate)
		{
			if ( (Enemy == none) || (VSize(Enemy.Location - Location) > 200) )
			{
				PendingWeapon = MyTranslocator;
				Weapon.PutDown();
			}
			return;
		}		
		else if ( (LC != none) && RouteCache[0].IsA('TranslocStart') && bCanTranslocate )
		{
			if ( (Enemy == none) || (VSize(Enemy.Location - Location) > 200) )
			{
				PendingWeapon = MyTranslocator;
				Weapon.PutDown();
			}
			return;
		}
	}

	if ( bCanTranslocate && (Enemy == none) && (FRand()*16 < Skill) && (RouteCache[7] != none) )
	{
		GotoState('TranslocationChain','FireTransloc');
		return;
	}

	//Impact launch
	if ( bHasImpactHammer && bCanTranslocate && (FRand()*10 < Skill) && (BotzTTarget(MyTranslocator.TTarget) == none || !BotzTTarget(MyTranslocator.TTarget).bImpactLaunch ) && !EnemyAimingAt( self) )
	{
		if ( RouteCache[9] != none )
			i = 15;
		else
			i = 8;
		For ( i=i; i>0 ; i-- )
		{
			if ( RouteCache[i] == none )
				continue;
			if ( VSize(RouteCache[i].Location - Location) < 2500 )
				break;
			//Comprobar que la vel maxima del TTarget llega (45º para alto, menos para bajo) 2 veces
			// 2000.0 es su momentum
			
			aVec = Normal( HNormal( RouteCache[i].Location - Location) + Vect(0,0,-0.5)) * 2000.0; //Crear un vector diagonalizado de 33º (mas o menos)
			aVec.Z = FMax(aVec.Z, 0.7 * VSize(aVec));
			if ( BFM.CanFlyTo( Location, RouteCache[i].Location, Region.Zone.ZoneGravity.Z, aVec.Z, HSize(aVec) ) 
				&& BFM.JumpCollision( self, Location, RouteCache[i].Location, Region.Zone.ZoneGravity.Z, aVec.Z, , 0/*steps*/) )
			{
				bShouldDuck = true;
				FinalMoveTarget = RouteCache[i];
				GotoState('ImpactMode','TranslocLaunch');
				return;
			}

			aVec = Normal( HNormal( RouteCache[i].Location - Location) + Vect(0,0,-1)) * 2000.0; //Crear un vector diagonalizado de 45º
			aVec.Z = FMax(aVec.Z, 0.7 * VSize(aVec));
			if ( BFM.CanFlyTo( Location, RouteCache[i].Location, Region.Zone.ZoneGravity.Z, aVec.Z, HSize(aVec) ) 
				&& BFM.JumpCollision( self, Location, RouteCache[i].Location, Region.Zone.ZoneGravity.Z, aVec.Z, , 0/*steps*/) )
			{
				FinalMoveTarget = RouteCache[i];
				GotoState('ImpactMode','TranslocLaunch');
				return;
			}
		}
	}
	
	//Jump shortcut
	if ( CanHighJump() && (RouteCache[6] != none) )
	{

		for ( i=Min(15, 10 + Rand(Skill+1)) ; i>5 ; i-- )
		{
			if ( RouteCache[i] == none )
				continue;
			if ( BFM.CanFlyTo( Location, RouteCache[i].Location, Region.Zone.ZoneGravity.Z, JumpZ, GroundSpeed * 1.05)
				&& BFM.JumpCollision( self, Location, RouteCache[i].Location, Region.Zone.ZoneGravity.Z, JumpZ, CollisionHeight * 2, 8) )
			{
				PopRouteCache();
				HighJump( RouteCache[0]);
				return;
			}
		}
	}

	//Transloc shotcut

	//Avoid obstruction
	if ( (MoveTarget.Location.Z > Location.Z + MaxStepHeight) && (HSize(Location - MoveTarget.Location) < Abs(Region.Zone.ZoneGravity.Z * 0.4)) )
	{
		aVec = MoveTarget.Location;
		aVec.Z += Location.Z + MaxStepHeight;
		if ( (CollideTrace( aVec, eVec, Location + vect(0,0,1)*MaxStepHeight, aVec) != None) && (Abs(eVec.Z) < 0.3) )
			bTickedJump = (Physics == PHYS_Walking);
	}
	
	//Assign LifeSignal
	ASSIGN_LIFESIGNAL:
	LifeSignal( 1.5 + ArrivalTime( MoveTarget) * 1.1 );
}


function EvaluarPuntosDeControl()
{
	local ControlPoint CP;

	if (bCpEv && FRand() > 0.1) //Native is faster, check more often
		return;
	iCP = 0;
	ForEach NavigationActors (class'ControlPoint', CP)
		ControlPointList[iCP++] = CP;

	bCpEv = True;
}
//=================================DESTROYED
singular event Destroyed()
{
	local GameInfo GI;
	Super.Destroyed();
	if ( AimPoint != none )
		AimPoint.Destroy();
	if ( BFM != none )
		BFM.UnInit();
	BFM = none;
	While ( FlightProfiles[0] != none )
		FlightProfiles[0].DetachFromBotz( self);
	SaveConfig();
}


//*****************************************************************
//***************************************************************
//******************FUNCIONES DECLARADAS************************
//***************************************************************
//*****************************************************************
function ElegirDestino();
function Actor FindDefensePointFor( actor DefenseObject, name CodeSign);
function bool CheckCampDistance();
function ControlPoint SelectControlPoint();
function bool LogicaDeCP();

//******************ResumeSaved
final function bool ResumeSaved()
{
	if ( Health <= 0)
	{	QueHacerAhora();	return false;	}

	if ( SavedLabel == '' )
		GotoState( SavedState);
	else
		GotoState( SavedState, SavedLabel);
	return true;
}

//*******************FindLiftFor
final function Mover FindLiftFor( NavigationPoint Nava )
{
	local LiftCenter LC;
	local LiftExit LE;
	local name TheName;
	local Mover M;

	LC = LiftCenter(Nava);
	LE = LiftExit(Nava);
	if ( LC != none )
		TheName = LC.LiftTag;		
	else if ( LE != none )
		TheName = LE.LiftTag;
	else
		return None;

	if ( TheName != '')
		ForEach AllActors (class'Mover', M, TheName)
			break;
	return M;
}

//********************NearSpot
final function vector NearSpot( vector Desired, float MaxDist, optional float MinDist, optional vector AlterTendency)
{
	local vector Result;
	local int i;

	For ( i=0 ; i<24 ; i++ )	//No quiero un bot cayendose de una fina plataforma
	{
		Result = HNormal( VRand() + AlterTendency) * RandRange( MinDist, MaxDist);
		if ( FastTrace(Desired+Result,Desired) && !FastTrace( Desired + Result - vect(0,0,90) , Desired + Result) )
			return Result + Desired;
	}

	return Desired;
}

//*****************IRango
final function INT IRango(int Min, int Max, int Valor, optional bool Invert)
{
	if (Min == Max)
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

//********************SetPointByRotation
final function VECTOR SetPointByRotation(rotator TheRotation, vector TheOrigin)
{
	return ( vector(TheRotation) * 2000 + TheOrigin );
}

//*************LifeSignal
final function LifeSignal(float ExtensionT)
{
	TiempoDeVida = fClamp( (Level.TimeSeconds + fMin(ExtensionT, 10) ), TiempoDeVida, 9999999999999);
}


//******************InRadiusEntity
final function BOOL InRadiusEntity(actor TheEnt)
{
	local float Float1;

	if (TheEnt == none)
		return false;

	Float1 = HSize(TheEnt.Location - Location);

	if ( !TheEnt.bCollideActors )
		if ( (Float1 <= CollisionRadius) && ( abs(Location.Z - TheEnt.Location.Z) <= CollisionHeight) )
			return True;
	else
		if ( (Float1 <= CollisionRadius + TheEnt.CollisionRadius) && ( abs(Location.Z - TheEnt.Location.Z) <= CollisionHeight + TheEnt.CollisionHeight) )
			return True;
	
	return False;
}


//*************************VectorInCylinder
static final function bool VectorInCylinder( vector test, vector Org, float hRadius, float hHeight)
{
	Test -= Org;
	return (Abs(Test.Z) <= hHeight) && (HSize(Test) <= hRadius);
}



//******************TraceToTarget
final function bool TraceToTarget(actor TTTarget)
{
	local float HighestPoint;
	local float LowestPoint;
	local vector VDir, Vectus;

	HighestPoint = Location.Z + CollisionHeight;
	LowestPoint = TTTarget.Location.Z - TTTarget.CollisionHeight;

	if (HighestPoint < LowestPoint)
		return false;

	Vectus = TTTarget.Location;
	Vectus.Z = LowestPoint;
	VDir = Normal( (Location - Vectus) * vect(1,1,0) );
	Vectus += VDir * (TTTarget.CollisionRadius + CollisionRadius - 5);

	return FastTrace(Vectus);
}


//******************bCollideTrace - Faster version for specific checks - MOVE TO NATIVE CODE!!!
final function bool bCollideTrace( vector End, optional vector Start)
{
	local Actor A;
	local Vector HL, HN;

	if ( Start == vect(0,0,0) )
		Start = Location;
	ForEach TraceActors( class'Actor', A, HL, HN, End, Start )
		if ( BFM.IsSolid(A) )
			return true;
}

//**======================== VectZ; sumar alturas más rapido
static final function vector VectZ( float Height)
{
	return vect(0,0,1) * Height;
}

//*****************GetDefenderCount
final function INT GetDefenderCount( Actor Defended, float Radius, byte Team, optional bool bTrace)
{
	local float Dist;
	local pawn P;
	local int i;

	if ( Defended == none )
		return 0;

	i = 0;
	bTrace = bTrace || Radius < 20;
	if ( Radius < 20 )
		Radius = 5000;
	ForEach PawnActors (class'Pawn', P, Radius+30, Defended.Location, true)
	{
		if ( (Team != 255) && (P.PlayerReplicationInfo.Team != Team) )
			continue;
		if ( bTrace && ( !P.LineOfSightTo(Defended) ) )
			continue;
		i++;
	}
	return i;
}

//******************DefendingPoint
final function BOOL DefendingPoint( Actor Defended, pawn Defender, float Radius, optional bool bTrace)
{
	local float Dist;

	if ( Defended == none || Defender == None )
		return false;
	bTrace = bTrace || Radius < 20;
	Dist = VSize(Defended.Location - Defender.Location);
	if ( bTrace && ( !Defender.LineOfSightTo(Defended) ) )
		return false;
	return Radius < 20 || Dist < Radius;
}


//********************FallTo
final function VECTOR FallTo(actor JumpDest)
{
	local vector testa, Hitloc, HitNorm;


	testa = JumpDest.Location;
	testa.Z -= CollisionHeight * 2;
	
	JumpDest.Trace( Hitloc, HitNorm, testa);
	if ( VSize( Hitloc - testa) < 3 )
		testa = JumpDest.Location;
	else
		testa.Z = Hitloc.Z + CollisionHeight;


	return BFM.AdvancedJump( Location, testa, Region.Zone.ZoneGravity.Z, Velocity.Z, GroundSpeed);

}


//******************BadEventTowards
final function bool BadEventTowards( vector End)
{
	local Triggers T;
	local vector HitLocation, HitNormal, Extent;
	local Actor A;
	
	Extent.X = CollisionRadius;
	Extent.Y = CollisionRadius;
	Extent.Z = CollisionHeight;
	ForEach TraceActors( class'Triggers', T, HitLocation, HitNormal, End, Location, Extent)
	{
		if ( !T.IsA('Triggers') || T.Event == '' || T.bBlockActors )
			continue;
		if ( T.Event == BadEvent || T.IsA('TriggeredDeath') )
			return true;
		ForEach AllActors( class'Actor', A, T.Event)
		{
			if ( A.IsA('SpecialEvent') && (A.IsInState('KillInstigator') || A.IsInState('DamageInstigator')) )
			{
				BadEvent = T.Event;
				return true;
			}
		}
	}
}

//******************TraceToDir - Revisar que este punto sea alcanzable para un posible movimiento
final function bool TraceToDir( vector Dir, out float Dist, float MaxDist)
{
	local Actor Hit;
	local vector HitLocation, HitNormal, Dest;
	
	Dest = Location + Dir * (Dist+CollisionRadius);
	Hit = Trace( HitLocation, HitNormal, Location + Dir * (Dist+CollisionRadius),, True);
	if ( Hit == None )
		HitLocation = Dest - Dir*CollisionRadius;
	Dist = HSize(Location - HitLocation);
	if ( HitNormal.Z > 0.7 ) //Suelo, improbable que sea dañino
		return true;
	Dest = HitLocation;
	Dest.Z -= Dist * 0.8;
	Hit = Trace( HitLocation, HitNormal, Dest, HitLocation,True); //SHOULD BE A COLLIDETRACE!!!!
	return ( Hit != None && HitNormal.Z > 0.7 );
}



//******************NeedNoFloorJump - tell if bot needs some sort of jump during simple navigation
final function bool NeedNoFloorJump( actor Dest, optional vector ODest)
{
	local vector HitNormal, HitLocation, X;
	local float Jumpo, aZ, fZ; //If Jumpo reaches 1, return true and tickjump?

	if ( Dest != none )
		ODest = Dest.Location;
	//Esta funcion viene luego de elegir un punto de movimiento
	//No evaluar si es alcanzable con un salto, sino que debo
	//evaluar si simplemente no hay un piso saltable entre ambos

	//Hack fix: don't jump if climbing stair
	if ( ODest.Z > Location.Z + CollisionHeight*1.5 )
		return false;

	//First check between both actors if there is no floor
	X = (ODest + Location) * 0.5;
	CollideTrace( HitLocation, HitNormal, X - vect(0,0,100), X);
	aZ = HitLocation.Z;

	if ( Trace( HitLocation, HitNormal, ODest - vect(0,0,100), ODest ) == none )
		return false;
	fZ = HitLocation.Z;


	HitLocation.Z = Location.Z - CollisionHeight; //Use this as temporary height meter for self
	
	if ( (fZ+HitLocation.Z)*0.5 > aZ) //Floor between is lower than average between origin and start
		Jumpo = ( ((fZ+HitLocation.Z)*0.5) - aZ) / 60.0;	

	//Second, add more probability if target floor is higher ;REVISED, LESS PROBABILITY
	if ( (Location.Z - CollisionHeight) < fZ )
		Jumpo -= 0.1; //FUTURO: Deberia ser 0.1 + 0.1 * JUMPY
	else if ( Location.Z - CollisionHeight * 1.3 > fZ ) //Less probability if below
		Jumpo -= 0.05;

	if ( Jumpo >= 1)
		return true;

	//Third, see if it's a higher platform or block were the objective is
	if ( (Location.Z - CollisionHeight * 0.7) < fZ )
	{
		X = HitLocation;
		X.Z = fZ - 30;
		CollideTrace( HitLocation, HitNormal, X, Location - VectZ(CollisionHeight * 0.7) );
		if ( VSize(HitLocation - X) < 5 )
			return true; //Don't wait for PickWallAdjust(), jump directly?
		else if ( HitNormal != vect(0,0,0) )
		{
			if ( HitNormal.Z < 0.3 ) //Impassable obstacle
				return true;
		}
	}
	return false;
}

//********************SimpleDirectJump - vector 0,0,0 is false
final function vector SimpleDirectJump( actor Dest, optional vector ODest)
//If return is (0,0,-1) then nullify the whole operation and run normally
//If return is (0,0,1) then simply enable bTickJump
//If return is other, then use it as jump speed
{
	local float fAlpha, fStep, fDist, lastreg, jZ;
	local vector X, HitLocation, HitNormal, LastGood, vel;
	
	if ( Dest != none)
		ODest = Dest.Location;

	//Always work using normal jumpz
	jZ = Default.JumpZ * fMin(1.18, Level.Game.PlayerJumpZScaling());

	if (Trace( HitLocation, HitNormal, ODest - VectZ(CollisionHeight*2), ODest) == none)
	{
		X = HNormal( ODest - Location) * GroundSpeed * 1.05;
		X.Z = jZ;
		return X; //Target is flying, recommend SuperAccel jump
	}


	//Pick sane stepping
	fDist = HSize( Location - ODest) / 10;
	if ( Region.Zone.ZoneGravity.Z > -940) //Gravity modified, use higher step
		fDist *= 2;
	fStep = 1 / fDist; //Invert, now ready to work on [0,1] range

	//First check
	LastGood = HitLocation + VectZ(CollisionHeight + 1 + (1-HitNormal.Z) * CollisionRadius );
	if ( BFM.CanFlyTo( Location, LastGood, Region.Zone.ZoneGravity.Z, jZ, GroundSpeed) )
		return vect(0,0,1); //Perform Normal jump afterwards


	//Can directly jump? Only use bSuperAccel variations
	For ( fAlpha=1-fStep ; fAlpha > 0.4 ; fAlpha-=fStep )
	{
		X = Location + (ODest - Location) * fAlpha; //Start from there

		CollideTrace( HitLocation, HitNormal, X - VectZ(CollisionHeight*2.2), X);

		if ( VSize( HitLocation - X-VectZ(CollisionHeight*2.2)) < 3 ) //Hole
			break;
		if ( (HitNormal != vect(0,0,0)) && (HitNormal.Z < 0.7) ) //Slant
			break;
		HitLocation.Z += (CollisionHeight + 1 + (1-HitNormal.Z) * CollisionRadius); //SlantStep
		if ( VSize( LastGood - HitLocation ) > fDist*1.4) //Un angulo de casi 43º es el minimo admitido, si esta mas lejos que eso, hay separacion
			break;
		LastGood = HitLocation;
		vel = BFM.AdvancedJump( Location, LastGood, Region.Zone.ZoneGravity.Z, jZ, GroundSpeed * 2, false );
		if ( HSize(Vel) < GroundSpeed * 1.01 )
			return (HNormal(ODest - Location) * GroundSpeed * 1.03) + VectZ( jZ); //Frontal Jump
	}

	//No return, check from player if can run a bit more before falling
	//Modify ODest since it is no longer used
	ODest = LastGood;
	LastGood = Location;

	For ( fAlpha=fStep ; fAlpha < 0.3 ; fAlpha+=fStep)
	{
		X = Location + (ODest - Location) * fAlpha; //Start from here

		CollideTrace( HitLocation, HitNormal, X - VectZ( CollisionHeight * 1.6), X);

		if ( VSize( HitLocation - X-VectZ(CollisionHeight*1.6)) < 3 ) //Hole
			break; //Hitnormal will only return DIR, if hole is reached, so we're safe to assume HitNormal below here is real hitnormal
		if ( (HitNormal != vect(0,0,0)) && (HitNormal.Z < 0.7) ) //Slant
			break;
		if ( VSize( (LastGood - VectZ( CollisionHeight)) - (HitLocation+HitNormal) ) > fDist*1.5) //Un angulo de casi 47º es el minimo admitido, si esta mas lejos que eso, hay separacion
			break;
		LastGood = HitLocation + VectZ(CollisionHeight + 1);
		vel = BFM.AdvancedJump( LastGood, ODest, Region.Zone.ZoneGravity.Z, jZ, GroundSpeed * 2, false );
		if ( HSize( Vel) < (GroundSpeed * 1.03) )
			return vect(0,0,-1); //Keep running
	}

	//Impossible to jump
	return vect(0,0,0);
}


//*******************BestInventoryPath - Global method for Inv finding (MinWeight averages at 0.3, nearby items can return 0.7 to 1.1)
final function Actor BestInventoryPath( out float MinWeight, optional int AddStartDist)
{
	local Actor Result;
	local InventorySpot IS, BestIS;
	local float CurWeight;
	local Inventory Item;
	
	if ( !LocateStartAnchor( FRand() > VSize(Acceleration)) ) //If bot isn't moving, then we better try unreachable paths for a while
		return None;

	AddStartDist = Max( 1, AddStartDist); //The higher the value of this is, the further the bot will consider going for items
	MapRoutes( StartAnchor, CollisionRadius, CollisionHeight,, 'GlobalModifyCost');
	ForEach NavigationActors( class'InventorySpot', IS)
		if ( IS.MarkedItem != None && (IS.VisitedWeight < 10000000) )
		{
			CurWeight = InvSqrt( (IS.VisitedWeight + AddStartDist) / 100 );
			Item = IS.MarkedItem;
			if ( (Item.MaxDesireability*CurWeight > MinWeight)  //Less expensive that BotDesireability
				&& (Item.IsInState('Pickup') || (Item.LatentFloat < FRand()*Skill) && Item.IsInState('Sleeping')) ) 
			{
				CurWeight *= Item.BotDesireability( self);
				if ( CurWeight > MinWeight )
				{
					MinWeight = CurWeight;
					BestIS = IS;
				}
			}
		}
	if ( BestIS != None )
	{
		Result = BuildRouteCache( BestIS, RouteCache);
		if ( !Result && !InRadiusEntity(BestIS.MarkedItem) )
		{
			RouteCache[0] = BestIS;
			Result = BestIS.MarkedItem;
		}
		if ( DebugPath )
			Log("BestInventory to"@BestIs.MarkedItem.Name$":"@MinWeight@BestIS.VisitedWeight);
	}
	return Result;
}

//*******************FindFlyingPathToward - Quick flying path finder
final function Actor FindFlyingPathToward( actor Dest)
{
	local EPhysics OldPhysics;
	local actor NewMT;

	OldPhysics = Physics;
	if ( Physics == PHYS_Falling )
		SetPhysics( PHYS_Swimming);
	bCanFly = true;
	NewMT = FindPathToward( Dest,,false);
	if ( NewMT == none )
		NewMT = FindPathToward( BFM.NearestNavig(Dest.Location, 2500),, false );
	bCanFly = false;
	if ( Physics != OldPhysics )
		SetPhysics( OldPhysics);
	return NewMT;
}

//*************SetMoveTarget - Global handler for both state and unstate movements
final function SetMoveTarget( actor Other)
{
	if ( SpecialMoveTarget != none )
		SpecialMoveTarget = Other;
	else
		MoveTarget = Other;
}

//*******************GetMoveTarget - Global handler for both state and unstate movements
final function Actor GetMoveTarget()
{
	return SpecialMoveTarget or MoveTarget;
}

//******************IsMoving - Global movement condition
final function bool IsMoving( optional bool bOntoDestination)
{
	if ( Acceleration == vect(0,0,0) )
		return false;
	if ( MoveTarget != none && MoveTimer > 0 && (!bOntoDestination || Destination == MoveTarget.Location) )
		return true;
	if ( MoveTarget == none && MoveTimer < 0 && (SpecialMoveTarget != none) && (!bOntoDestination || Destination == SpecialMoveTarget.Location) )
		return true;
}

//*************StopMoving - Cease all movement
final function StopMoving( optional bool bFullStop)
{
	Acceleration	 =		Vect(0,0,0);
	MoveTarget		 =		none;
	MoveTimer		 =		-0.01;
	if ( bFullStop )
		SpecialMoveTarget = none;  
}

//******************CanLeaveUnstate - Global unstate condition
final function bool CanLeaveUnstate()
{
//	if ( (Physics != PHYS_Falling) || bCanFly )
//	{
		if ( (SpecialMoveTarget == none) || SpecialMoveTarget.bDeleteMe || !bUnstateMove ) //Move has timed out
		{
			Enable('Tick');
			bUnstateMove = false;
			SpecialMoveTarget = None;
			MoveTimer = 0;
			return true;
		}
//	}
}

//*************UpdateUnstate - Update UnState movement if altered from outside
final function UpdateUnstate()
{
	bUnstateMove = true;
	if ( MoveTarget != none ) //Something changed our movetarget!
	{
		SpecialMoveTarget = MoveTarget;
		MoveTarget = none;
	}
	if ( MoveTimer > 0 ) //MoveTimer updated, send new signal
	{
		LifeSignal( MoveTimer + 0.1);
		MoveTimer = -MoveTimer;
	}
}

//******************ScriptMoveToward - sets up unstate movement controlled by state code
final function bool ScriptMoveToward( Actor Other, optional actor FaceAt)
{
	if ( Other == None )
	{
		bScriptedMove = false;
		return False;
	}
	bScriptedMove = true;
	SpecialMoveTarget = Other;
	MoveTarget = None;
	MoveTimer = 1.0 + ArrivalTime( Other) * 1.3;
	DesiredSpeed = 1;
	if ( DebugPath )
		Log("[MOVE] Scripting move towards"@Other.Name$", MT="$MoveTimer);
	LifeSignal( MoveTimer);
	MoveTimer *= -1;
	Focus = vect(0,0,0);
	if ( FaceAt == self )			FaceTarget = None;
	else if ( FaceTarget == None )	FaceTarget = Other;
	else							FaceTarget = FaceAt;
	ScriptMovePoll();
	return True;
}

//******************UnstateMoving - sleep query for UnstateMovement
final function bool ScriptMovePoll()
{
	if ( (MoveTarget != None) && (MoveTarget != SpecialMoveTarget) )
	{
		if ( DebugPath && (SpecialMoveTarget != None) )
			Log("[MOVE] External detour"@SpecialMoveTarget.Name@"to"@MoveTarget.Name);
		SpecialMoveTarget = MoveTarget;
	}
	if ( bScriptedMove && (SpecialMoveTarget != None) && (MoveTimer < -0.3) )
	{
		UnstateMovement( CurDelta);
		if ( bScriptedMove )
			return True;
	}
	bScriptedMove = false;
	if ( DebugPath )
		Log("[MOVE] ScriptMovePoll end");
	return false;
}

//*************SwitchToUnstate - Sends botz to UnStateMovement
final function SwitchToUnstate()
{
	if ( MoveTarget Or SpecialMoveTarget == none )
		return;
	if ( bScriptedMove || IsInState('Freelancing') || IsInState('Attacking') || IsInState('Defending') )
		return;
	if ( SpecialMoveTarget == none )
		SpecialMoveTarget = MoveTarget;
	MoveTarget = none;
	MoveTimer = 1.5 + ArrivalTime( SpecialMoveTarget) * 1.1;
	LifeSignal( MoveTimer );
	MoveTimer *= -1;
	Focus = vect(0,0,0);
	if ( !bUnstateMove )
		GotoState( GetStateName(), 'UnStateMove');
	bUnstateMove = true;
}

//*******************ArrivalTime - Evaluate arrival time using current physics
final function float ArrivalTime( Actor Other)
{
	if ( Physics == PHYS_Swimming )
		return VSize( Location - Other.Location) / WaterSpeed;
	if ( Physics == PHYS_Walking )
		return HSize( Location - Other.Location) / GroundSpeed;
	if ( Physics == PHYS_Falling )
		return BFM.FallTime( Other.Location.Z - Location.Z, Region.Zone.ZoneGravity.Z, Velocity.Z);
}




//*************PopRouteCache - Ditches element 0 in list
final function PopRouteCache( optional bool bSetMoveTarget)
{
	local int i, j;
	
	if ( RouteCache[8] == none )
		i = 7;
	else
	{
		i = 14;
		RouteCache[15] = none;
	}

	While ( j<=i )
		RouteCache[j] = RouteCache[++j];
	if ( bSetMoveTarget )
	{
		SetMoveTarget( RouteCache[0] );
		if ( RouteCache[0] != None )
		{
			if ( MoveTimer > 0 )		MoveTimer += 1;
			else if ( MoveTimer < 0 )	MoveTimer -= 1;
			LifeSignal(2);
		}
	}
}


defaultproperties
{
     CarcassType=Class'Botpack.TBossCarcass'
     bHumanMove=True
     bNative=True
     bSuperAim=True
     bCanJump=True
     bCanWalk=True
     bCanSwim=True
     bCanOpenDoors=True
     bCanDoSpecial=True
     TacticalAbility=5.000000
     PlayerReplicationInfoClass=Class'Botpack.BotReplicationInfo'
     InitialState=InitialStand
     bTravel=True
     iIndex=-1
}
