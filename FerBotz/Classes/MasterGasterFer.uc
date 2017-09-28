//==================================================================================
// MasterGasterFer => El agregador de caminos en-juego
// Para lograr que los botz se translocalizen, salten y otras cosas.
// Un botz lo crea, este duplica los JumpSpots y TranslocNodes, y para evitar que se
// vuelvan a duplicar, esta entidad no se borra (indicando que está todo hecho)
// Tambien monitorea el estado de los botz y se asegura de que no se 'tranquen'
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//==================================================================================
class MasterGasterFer expands InfoPoint;

const BFM = class'BotzFunctionManager';

var() string LevelName;
var() class<BaseSpawner> SpawnerClass;
var() BaseSpawner TheSpawner;
var BotzNode BNodeList;
var class<BotzTargetAdder> TargeterClass;
var BotzTargetAdder MyTargeter;

var float DistInvScaler;
var BotzMutator TheMutator;
var int TickCount;

var Botz_BaddingSpot TeamBads[4], PoolBads;
var FlightItemsDatabase FlightDatabase;
var FlightProfileBase FlightProfiles[256];
var int iFlight;

var Botz SampleBotz; //For native function calls
var Botz OldBotzList[63];
var int OldBotzCount;

var F_TempDest PoolDests;

var BotzWeaponProfile WProfiles[63];
var int WProfileCount;

// Tranke y no reaparecen
var Botz Tranker;
var float TrankTime;

// Tranke con Teletransportadores
var Botz TeleTranker;
var Teleporter TeleTranked;
var float TeleTrankTime;
var int TeleSteps;

// Tranke luego de transloc
var Botz TTranker;
var vector TLocation;
var float TTime;

//Navigation point arrays
var array<LiftCenter>		LiftCenters;
var array<LiftExit>			LiftExits;
var array<JumpSpot>			JumpSpots;
var array<TranslocStart>	TranslocStarts;
var array<TranslocDest>		TranslocDests;
var array<NavigationPoint>	ElevatorPaths;

var class<Weapon> SniperWeapons[24];	//Soporte externo
var int iSniperW;
var localized string SniperWeaponsSTR[24];

var() localized string IndiceCercano[16]; //Seleccion de armas, mejor que el viejo metodo
var() localized string IndiceLejano[16];
var() localized string IndiceMedio[16];
var class<Weapon> ClassCercano[16], ClassMedio[16], ClassLejano[16];
var() localized float ValorCercano[16];
var() localized float ValorLejano[16];
var() localized float ValorMedio[16];


native(640) static final function int Array_Length_Obj( out array<Object> Ar, optional int SetSize);

event PostBeginPlay()
{
	local int i;
	local NavigationPoint N;
	local bool bReturnInside;
	local Botz_PathLoader aLoader;
	local WeaponProfileLoader pLoader;
	local LiftExit LE;
	local LiftCenter LC;
	local TranslocStart TS;
	local TranslocDest TD;
	local JumpSpot JS;
	local class<GameInfo> GameClass;

	SetLocation(vect(0,0,0));
	SetRotation(Rot(0,0,0));
	SetOwner( none);

	LevelName = GetLevelName( string(self) );
	SpawnerClass = class<BaseSpawner>( DynamicLoadObject( LevelName$"Botz."$LevelName$"Spawn", class'Class', true) );

	if ( SpawnerClass == none )
	{
		BFM.static.ReplaceText(LevelName, "]", "_1");
		BFM.static.ReplaceText(LevelName, "[", "_2");
		BFM.static.ReplaceText(LevelName, "|", "_3");
		SpawnerClass = class<BaseSpawner>( DynamicLoadObject( LevelName$"Botz."$LevelName$"Spawn", class'Class', true) );
	}

	For ( i=0 ; i<ArrayCount(SniperWeaponsSTR) ; i++ )
		if ( SniperWeaponsSTR[i] != "" )
		{
			SniperWeapons[iSniperW] = Class<Weapon>( DynamicLoadObject( SniperWeaponsSTR[i], class'Class', true) );
			if ( SniperWeapons[iSniperW] != none )
				iSniperW++;
		}

	SetTimer( 0.5, True);

	if (SpawnerClass != none)
		TheSpawner = spawn(SpawnerClass);

	//Setup Targeter
	if ( Level.Game != None )
		For ( GameClass=Level.Game.Class ; (GameClass != None) && (TargeterClass == None) ; GameClass=class<GameInfo>(GetParentClass(GameClass)) )
			TargeterClass = class<BotzTargetAdder>( DynamicLoadObject( GameClass.Name$"UBZFV."$GameClass.Name$"UBZSupport", class'Class') );
	if ( TargeterClass == none )
		TargeterClass = class'FerBotz.BotzTargetAdder';
	MyTargeter = Spawn(TargeterClass);
	MyTargeter.MyMaster = self;



	LoadOldWeapons();

// Cargar perfiles de armas
	//This will crash the game if MasterGasterFer is spawned twice, which is intended
	//Weapon profiles are created in the context of the level
	WProfiles[0] = new(self,'BotzBaseWeaponProfile') class'BotzWeaponProfile';
	//Default weapons
	WProfiles[1] = new(self) class'Botz_WePro_Piston';
	WProfiles[1].PostInit();
	WProfiles[2] = new(self) class'Botz_WePro_BioRifleTEST';
	WProfiles[2].PostInit();
	WProfiles[3] = new(self) class'Botz_WePro_FlakTEST';
	WProfiles[3].PostInit();
	WProfiles[4] = new(self) class'Botz_WePro_ShockTEST';
	WProfiles[4].PostInit();
	WProfiles[5] = new(self) class'Botz_WePro_RocketTEST';
	WProfiles[5].PostInit();
	
	WProfileCount = 6;
	pLoader = Spawn(class'WeaponProfileLoader');
	pLoader.MasterEntity = self;

	CalcInvScaler();
	TickCount = 6;	//6 ticks para notificar al mutador

	FlightDatabase = new(Outer,'FlightItemsDatabase') class'FlightItemsDatabase';

	i = 0;
	ForEach NavigationActors( class'TranslocStart', TS)
		TranslocStarts[i++] = TS;
	i = 0;
	ForEach NavigationActors( class'LiftExit', LE)
		if ( LE.class == class'LiftExit' )
			LiftExits[i++] = LE;
	i = 0;
	ForEach NavigationActors( class'TranslocDest', TD)
		TranslocDests[i++] = TD;
	i = 0;
	ForEach NavigationActors( class'JumpSpot', JS)
		JumpSpots[i++] = JS;
	i = 0;
	ForEach NavigationActors( class'LiftCenter', LC)
		if ( LC.class == class'LiftCenter' )
			LiftCenters[i++] = LC;

	ForEach AllActors (class'Botz_PathLoader', aLoader)
		break;
	if ( aLoader == none )
	{
		aLoader = Spawn(class'Botz_PathLoader');
		aLoader.MasterG = self;
		aLoader.LoadNodes();
	}
}

function EnumerateElevatorPaths()
{
	local NavigationPoint N;
	local int i;
	
	ForEach NavigationActors( class'NavigationPoint', N)
		if ( Mover(N.Base) != None )
			ElevatorPaths[i++] = N;
}

auto state Initializing
{
Begin:
	Sleep(0);
	FlightDatabase.Initialize( Level);
	While ( --TickCount > 0 )
		Sleep(0);
	EnumerateElevatorPaths();
	NotifyMutator();
}

//******************************************
// Modify cost of Bot-only navigation points
// SpecialHandling isn't called by Botz anyways

function AdjustCostFor( Botz B)
{
	local int i, JumpCost, TranslocCost;
	
	JumpCost = 10000000;
	TranslocCost = 10000000;
	if ( B.bCanTranslocate )
	{
		TranslocCost = 300 + int(B.Enemy != None) * (1000 - B.Health*5);
		JumpCost = TranslocCost;
	}
	if ( B.JumpZ > 1.5 * B.Default.JumpZ )
		JumpCost = 300;

	For ( i=Array_Length_Obj(TranslocDests)-1 ; i>=0 ; i-- )
		TranslocDests[i].Cost = TranslocCost;
	For ( i=Array_Length_Obj(JumpSpots)-1 ; i>=0 ; i-- )
	{
		if ( JumpSpots[i].Region.Zone.ZoneGravity.Z > -750 )
			JumpSpots[i].Cost = 0;
		else
			JumpSpots[i].Cost = JumpCost;
	}
	
	if ( MyTargeter != None )
		MyTargeter.ModifyPathCosts( B);
}


//*******************************************
//Called for each navig type to block/unblock

//Base LiftExit and LiftCenters
function CostBase( bool bCost)
{
	local int i;

	if ( bCost )
	{
		For ( i=Array_Length_Obj(LiftCenters)-1 ; i>=0 ; i-- )
			LiftCenters[i].Enable('SpecialHandling');
		For ( i=Array_Length_Obj(TranslocStarts)-1 ; i>=0 ; i-- )
			TranslocStarts[i].Enable('SpecialHandling');
	}
	else
	{
		For ( i=Array_Length_Obj(LiftCenters)-1 ; i>=0 ; i-- )
			LiftCenters[i].Disable('SpecialHandling');
		For ( i=Array_Length_Obj(TranslocStarts)-1 ; i>=0 ; i-- )
			TranslocStarts[i].Disable('SpecialHandling');
	}
}

//Jump spots
function CostJump( bool bCost )
{
	local int i;

	if ( bCost )
	{
		For ( i=Array_Length_Obj(JumpSpots)-1 ; i>=0 ; i-- )
		{
			JumpSpots[i].bSpecialCost = true;
			JumpSpots[i].Enable('SpecialHandling');
		}
	}
	else
	{
		For ( i=Array_Length_Obj(JumpSpots)-1 ; i>=0 ; i-- )
		{
			JumpSpots[i].bSpecialCost = false;
			JumpSpots[i].Disable('SpecialHandling');
		}
	}
}

//Translocator dest only, use starts as hack
function CostTransloc( bool bCost )
{
	local int i;

	if ( bCost )
	{
		For ( i=Array_Length_Obj(TranslocDests)-1 ; i>=0 ; i-- )
		{
			TranslocDests[i].bSpecialCost = true;
			TranslocDests[i].Enable('SpecialHandling');
		}
	}
	else
	{
		For ( i=Array_Length_Obj(TranslocDests)-1 ; i>=0 ; i-- )
		{
			TranslocDests[i].bSpecialCost = false;
			TranslocDests[i].Disable('SpecialHandling');
		}
	}
}
//End of Navig block/unblock routines
//********************************************

function CalcInvScaler()
{
	local inventory inv;
	local vector Lest, Most;

	ForEach Allactors (Class'inventory', inv)
	{
		if ( inv.Location.Z < Lest.Z )
			Lest.Z = inv.location.Z;
		if ( inv.Location.Y < Lest.Y )
			Lest.Y = inv.location.Y;
		if ( inv.Location.X < Lest.X )
			Lest.X = inv.location.X;

		if ( inv.Location.Z > Most.Z )
			Most.Z = inv.location.Z;
		if ( inv.Location.Y > Most.Y )
			Most.Y = inv.location.Y;
		if ( inv.Location.X > Most.X )
			Most.X = inv.location.X;
	}

	DistInvScaler = VSize( Most - Lest);

}

function NotifyMutator()
{
	local mutator M;
	local BaseLevelPoint BLP;
	local int i;

	For ( M=Level.Game.BaseMutator ; M!=none ; M=M.nextMutator )
		if ( M.IsA('BotzMutator') )
		{
			TheMutator = BotzMutator(M);
			break;
		}
	if ( TheMutator == none )	//ATENCIÓN: MUTADOR DE BOTZ SIEMPRE EXISTE!
	{
		TheMutator = Level.Game.BaseMutator.Spawn(class'BotzMutator');
		Level.Game.BaseMutator.AddMutator(TheMutator);
		TheMutator.MasterG = Self;
	}
	i = 0;
	ForEach AllActors (class'BaseLevelPoint', BLP)
	{
		TheMutator.SetBLP( BLP, i);
		i++;
	}
}

event Tick( float DeltaTime)
{
	local int i;
	local teleporter TheTelep;

	//Do nothing while there's no Botz around
	if ( SampleBotz == none || SampleBotz.bDeleteMe )
	{
		ForEach PawnActors (class'Botz', SampleBotz)
			break;
		return;
	}


//Localizar botz congelado luego de transloc
	if ( TTranker != none)
	{
		TTime -= DeltaTime;
		if ( TTime < 0 )
		{
			if ( VSize(TTranker.Location - TLocation) < 18 )
				TTranker.QueHacerAhora();
			TTranker = none;
		}
	}

	if ( (TTranker == none) && (FRand() < 0.15) )
		For ( i=0 ; i<24 ; i++ )
		{
			if ( (OldBotzList[i] != none) && (OldBotzList[i].Health > 0) && (OldBotzList[i].Physics == PHYS_Walking) && (OldBotzList[i].GetAnimGroup(OldBotzList[i].AnimSequence) == 'Ducking') )
			{
				TTranker = OldBotzList[i];
				TLocation = TTranker.Location;
				TTime = 1.5;
			}
		}

//Localizar botz trancado en un teletransportador
	if ( TeleTranker == none )
	{	TeleTranked = none;
		TeleTrankTime = 0;
		TeleSteps = 0;
	}
	if ( (TeleTranker == none) && (FRand() < 0.25) )	//Reducir uso de CPU
		For ( i=0 ; i<OldBotzCount ; i++ )
		{	TheTelep = GetNearestTelep( OldBotzList[i] );
			if ( TheTelep == none )
				break;
			if ( (OldBotzList[i] != none) && (OldBotzList[i].VectorInCylinder(TheTelep.Location, OldBotzList[i].Location, 50, 70 ) ) )
			{	TeleTranker = OldBotzList[i];
				TeleTranked = TheTelep;
				break;
			}
		}

	if ( TeleTranker != none )
	{
		TeleTrankTime += DeltaTime;
		if ( (TeleTrankTime > 0.25) && (TeleSteps == 0) )	//Intentar moverlo primero
		{
			TeleTranker.GotoState('Wander','Begin');	//Al fin le encuentro un gran uso al Wander
			TeleSteps = 1;
		}
		if ( (TeleTrankTime > 0.4) && (TeleSteps == 1) )	//No pudo moverse: esta trancado en el aire!!!
		{
			TeleTranker.SetLocation( Teletranker.Location - vect(0,0,5) );
			if ( TeleTranker.Region.Zone.bWaterZone )
				TeleTranker.SetPhysics( PHYS_Swimming );
			else
			{
				TeleTranker.bTickedJump = True;
				TeleTranker.SetPhysics( PHYS_Falling );
			}
			TeleSteps = 2;
		}
		if ( (TeleTrankTime > 2.5) && (TeleSteps == 2) )
		{
			TeleTranked.Touch(TeleTranker);
			TeleSteps = 3;
		}
		if ( (TeleTrankTime > 3.5) && (TeleSteps == 3) )	//Nada funciona, reaparecer bot
		{
			Tranker = TeleTranker;
			TrankTime = 11;
			TeleTranker = none;
		}
		if ( (TeleTranker != none) && ((!TeleTranker.VectorInCylinder(TeleTranked.Location, TeleTranker.Location, 50, 70) ) || (Teletranker.Health <= 0) || (TeleTranker.Acceleration != vect(0,0,0) )) )
			TeleTranker = none;
	}
//Localizar botz muerto que no reaparezca
	if ( Tranker == none )
		For ( i=0 ; i<OldBotzCount ; i++ )
			if ( (OldBotzList[i] != none) && (OldBotzList[i].Health <= 0) )
			{	Tranker = OldBotzList[i];
				break;
			}
	if ( Tranker != none )
	{
		TrankTime += DeltaTime;
		if ( TrankTime > 10 )
		{
//			Class'BotzFunctionManager'.static.SetVisibleAndValid( Tranker);
//			Tranker.Health = 100;
//			Level.Game.AddDefaultInventory( Tranker);
			Level.Game.RestartPlayer( Tranker);
		}
	}
	if ( (Tranker != none) && (Tranker.Health > 0) )
	{
		Tranker = none;
		TrankTime = 0;
	}
}

function Teleporter GetNearestTelep( actor Other, optional float MaxDist)
{
	local navigationpoint n;
	local float BestDist, CurrentDist;
	local teleporter Best;

	if ( Other == none )
		return none;

	if ( MaxDist < 1.0 )
		BestDist = 99999.9;
	else
		BestDist = MaxDist;

	For ( n=Level.NavigationPointList ; n!=none ; n=n.nextNavigationPoint )
		if ( n.IsA('Teleporter') )
		{
			CurrentDist = VSize( Other.Location - n.Location);
			if ( CurrentDist < BestDist )
			{
				BestDist = CurrentDist;
				Best = Teleporter(n);
			}
		}
	return Best;
}

function String GetLevelName( string FullName ) //Eliminar estos caracteres: -,
{
	local int pos;
	local string StrStart;
	local string StrEnd;

	pos = InStr(FullName, ".");

	if (pos != -1)
		FullName = Left(FullName, Pos);

	pos = InStr(FullName, "-");
	while (pos != -1)
	{
		StrStart = Left(FullName, Pos);
		StrEnd = Right(FullName, Len(FullName) - Pos - 1);
		FullName = StrStart$StrEnd;
		pos = InStr(FullName, "-");
	}

	return FullName;
}

event Timer()
{
	local Botz B;
	local int i;

	ForEach PawnActors (class'Botz', B)
		if ( B.bGameStarted )
		{
			OldBotzlist[i++] = B;
			if ( i >= 63 )
				break;
		}
	OldBotzCount = i;
}


final function Botz_BaddingSpot GetFreeBad( optional byte Team)
{
	local Botz_BaddingSpot B;

	if ( PoolBads != none )
	{
		B = PoolBads;
		PoolBads = B.NextSpot;
		B.NextSpot = none;
	}
	else
	{
		B = Spawn(class'Botz_BaddingSpot');
		B.BigBadder = self;
	}
	B.Team = Team;
	return B;
}

function LoadOldWeapons() //Old system
{
	local int i;

	For (i=0;i<16;i++)
	{
		ClassCercano[i] = class<Weapon>(DynamicLoadObject(IndiceCercano[i], class'Class',True));
		Default.ClassCercano[i] = ClassCercano[i];
		ClassMedio[i] = class<Weapon>(DynamicLoadObject(IndiceMedio[i], class'Class',True));
		Default.ClassMedio[i] = ClassMedio[i];
		ClassLejano[i] = class<Weapon>(DynamicLoadObject( IndiceLejano[i], class'Class',True));
		Default.ClassLejano[i] = ClassLejano[i];
	}
}

static final function ReplaceText(out string Text, string Replace, string With)
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

final function AddFlightProf( FlightProfileBase FP)
{
	FlightProfiles[iFlight++] = FP;
}

//Immediately removes from array, do not call this function without holding the reference!
final function FlightProfileBase RequestFlightProf( class<FlightProfileBase> FPclass)
{
	local int i;
	local FlightProfileBase FP;
	For ( i=0 ; i<iFlight ; i++ )
	{
		if ( FlightProfiles[i].class == FPClass )
		{
			FP = FlightProfiles[i];
			FlightProfiles[i] = FlightProfiles[--iFlight];
			FlightProfiles[iFlight] = none;
			return FP;
		}
	}
	return new( Outer) FPclass;
}

final function F_TempDest TempDest()
{
	local F_TempDest Result;

	if ( PoolDests == none )
	{
		Result = spawn(class'F_TempDest');
		Result.Master = self;
	}
	else
	{
		Result = PoolDests;
		PoolDests = PoolDests.NextDest;
		Result.NextDest = none;
	}
	return Result;
}

defaultproperties
{
	IndiceCercano(0)=BotPack.UT_FlakCannon
	ValorCercano(0)=0.3
	IndiceCercano(1)=Unreali.FlakCannon
	ValorCercano(1)=0.25
	IndiceCercano(2)=Unreali.Stinger
	ValorCercano(2)=0.1
	IndiceCercano(3)=Unreali.GESBioRifle
	ValorCercano(3)=0.2
	IndiceCercano(4)=Unreali.Minigun
	ValorCercano(4)=0.25
	IndiceCercano(5)=BotPack.Minigun2
	ValorCercano(5)=0.25
	IndiceCercano(6)=BotPack.PulseGun
	ValorCercano(6)=0.20
	IndiceCercano(7)=BotPack.Ripper
	ValorCercano(7)=0.2
	IndiceCercano(8)=Botpack.ut_biorifle
	ValorCercano(8)=0.2
	IndiceLejano(0)=BotPack.SniperRifle
	ValorLejano(0)=0.6
	IndiceLejano(1)=BotPack.ShockRifle
	ValorLejano(1)=0.45
	IndiceLejano(2)=Unreali.Rifle
	ValorLejano(2)=0.57
	IndiceLejano(3)=Unreali.ASMD
	ValorLejano(3)=0.43
	IndiceLejano(4)=Unreali.Minigun
	ValorLejano(4)=0.3
	IndiceLejano(5)=BotPack.Minigun2
	ValorLejano(5)=0.3
	IndiceLejano(6)=UPak.CARifle
	ValorLejano(6)=0.4
	IndiceLejano(7)=Botpack.SuperShockRifle
	ValorLejano(7)=0.9
	IndiceMedio(0)=Botpack.UT_EightBall
	ValorMedio(0)=0.2
	IndiceMedio(1)=Unreali.EightBall
	ValorMedio(1)=0.2
	IndiceMedio(2)=UPak.RocketLauncher
	ValorMedio(2)=0.8
	IndiceMedio(3)=UPak.GrenadeLauncher
	ValorMedio(3)=0.3
	IndiceMedio(4)=Unreali.FlakCannon
	ValorMedio(4)=0.3
	IndiceMedio(5)=Botpack.UT_FlakCannon
	ValorMedio(5)=0.4
	IndiceMedio(6)=BotPack.PulseGun
	ValorMedio(6)=0.1
}
