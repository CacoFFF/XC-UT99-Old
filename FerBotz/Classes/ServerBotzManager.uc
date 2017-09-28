//=============================================================================
// ServerBotzManager.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class ServerBotzManager expands InfoPoint
	config(BotzDefault); //NEVER save the config, just LOAD

var PlayerPawn LocalPlayer;
var SBotzInfo LastBot;

var bool bAnswering;
var bool bPendingResponse;
var BotzMutator MyMutator;

	var config string InfoSName[32];
	var config byte InfoSTeam[32]; //If 255, bRandom for team-games
	var config string InfoSClass[32];
	var config string InfoSSkin[32];
	var config string InfoSFace[32];
	var config float InfoSSkill[32]; //no implementado aun
	var config byte InfoSAccuracy[32]; //0 a 200, mas es mejor
	var config string InfoSVoiceType[32];
	var config byte InfoSCChance[32]; //0 a 200
	var config int InfoSCTime[32];
	var config string InfoSWeapon[32];

replication
{	//Server a cliente
	reliable if (ROLE == ROLE_Authority && bNetOwner)
		LocalPlayer;	//Todos deben saber quien es el host
	reliable if (ROLE == ROLE_Authority && bNetOwner)
		ServerAddBot;

	reliable if (ROLE < ROLE_Authority)
		ClientAddBot;

}

event PreBeginPlay()
{
	local PlayerPawn P;

	if ( (ROLE < ROLE_Authority) && (Level.NetMode != NM_Standalone) )
		return;

	ForEach AllActors (class'PlayerPawn', P)
		if ( ViewPort(P.Player) != none )
		{
			LocalPlayer = P;
			break;
		}
}

function MenuSetUp( playerpawn Dunno)
{
	local botzmenuinfo BMI, MenuInfo;

	ServerOnlyMessage(Dunno.PlayerReplicationInfo.PlayerName@"está usando el menú de botz");
	if ( !MachinePlayer( Dunno ) )
		return;

	ForEach AllActors (class'BotzMenuInfo', BMI)
		if (BMI.Owner == Dunno)
		{
			MenuInfo = BMI;
			break;
		}
	MenuInfo.SetupWindow();
}

function ClientAddBot( SBotzInfo BInfo)
{
	ServerAddBot( BInfo);
}

function Botz AddListBotz( string NewBotzName, string OptionalTeam)
{
	local SBotzInfo NewOne;
	local int i, NewIndex, MaxTeams;

	if ( Left(NewBotzName,6) == "Index=" )
	{
		NewIndex = Clamp(Int(Mid(NewBotzName,6)), 0, ArrayCount(InfoSName) );
		if ( InfoSName[NewIndex] == "" )
			return none;
	}
	else
	{
		NewIndex = -1;
		For ( i=0 ; i<ArrayCount(InfoSName) ; i++ )
			if ( caps(InfoSName[i]) == caps(NewBotzName) )
			{
				NewIndex = i;
				break;
			}
		if ( NewIndex < 0 )
			return none;
	}


	NewOne.BotName = InfoSName[NewIndex];
	NewOne.BotSkin = InfoSSkin[NewIndex];
	NewOne.Face = InfoSFace[NewIndex];
	NewOne.Team = InfoSTeam[NewIndex];
	NewOne.CampTime = InfoSCTime[NewIndex];
	NewOne.Punteria = InfoSAccuracy[NewIndex];
	NewOne.Skill = InfoSSkill[NewIndex];
	NewOne.CampChance = InfoSCChance[NewIndex];
	NewOne.SimulatedPP = class<PlayerPawn>(DynamicLoadObject(InfoSClass[NewIndex], class'Class'));
	NewOne.ArmaFavorita = class<Weapon>( DynamicLoadObject( InfoSWeapon[NewIndex], class'class', True));
	NewOne.VoiceBot = class<ChallengeVoicePack>( DynamicLoadObject( InfoSVoiceType[NewIndex], class'Class') );
	NewOne.RandomWeapon = False;

	if ( (caps(OptionalTeam) == "RED") || (OptionalTeam == "0" ))
		NewOne.Team = 0;
	else if ( (caps(OptionalTeam) == "BLUE") || (OptionalTeam == "1" ))
		NewOne.Team = 1;
	else if ( (caps(OptionalTeam) == "GREEN") || (OptionalTeam == "2" ))
		NewOne.Team = 2;
	else if ( (caps(OptionalTeam) == "GOLD") || (caps(OptionalTeam) == "YELLOW") || (OptionalTeam == "3" ))
		NewOne.Team = 3;
	else if ( (caps(OptionalTeam) == "NONE") || (OptionalTeam == "255" ))
		NewOne.Team = 255;
	if ( Level.Game.bTeamGame )
	{
		if ( !Level.Game.IsA('MonsterHunt') )
		{
			MaxTeams = int( Level.Game.GetPropertyText("MaxTeams") );
			if ( MaxTeams == 0 )
				MaxTeams = 2;
			if ( NewOne.Team >= MaxTeams )
				NewOne.Team = Rand(MaxTeams);
		}
	}
	return ServerAddBot( NewOne);
}

function AddAllBotz( string TeamParam)
{
	local int i;

	For ( i=0 ; i<32 ; i++ )
		if ( (InfoSName[i] != "") && (InfoSClass[i] != "") )
		{
			AddListBotz( InfoSName[i] , TeamParam);
		}

}

function Botz ServerAddBot( SBotzInfo BInfo)
{
	local name NewOrders;
	local actor OObject;
	local class<Pawn> BotzClass;
	local Botz NewBot;
	local NavigationPoint StartSpot;

	BotzClass = class'Botz';

	StartSpot = Level.Game.FindPlayerStart( none, BInfo.Team);
	NewBot = Spawn(class'Botz',,,StartSpot.Location, StartSpot.Rotation);
	if ( BInfo.Team == 100 )
		BInfo.Team = Rand( CountTeams() );
	NewBot.PlayerReplicationInfo.Team = BInfo.Team;
	if ( BInfo.SimulatedPP == none )
		NewBot.Static.SetMultiSkin( NewBot, BInfo.BotSkin, BInfo.Face, Binfo.Team);
	else
	{
		NewBot.Mesh = BInfo.SimulatedPP.Default.Mesh;
		BInfo.SimulatedPP.Static.SetMultiSkin( NewBot, BInfo.BotSkin, BInfo.Face, Binfo.Team);
	}
	Level.Game.ChangeName(NewBot, BInfo.BotName, false);
	NewBot.PlayerReplicationInfo.VoiceType = BInfo.VoiceBot;
	NewBot.VoiceType = string(BInfo.VoiceBot);
	GetTheOrders( NewOrders, OObject, BInfo.Team);
//	if (NewBot.IsA('Botz') ) CHECKEO INNECESARIO
//	{
		NewBot.Skill = float(BInfo.Skill) * 0.1;
		NewBot.Orders = NewOrders;
		NewBot.OrderObject = OObject;
		NewBot.CampChance = ( float(BInfo.CampChance) / 200 );
		NewBot.Punteria = abs( -5.0 + ( float(BInfo.Punteria) / 40));
		NewBot.AvgCampTime = BInfo.CampTime;
		NewBot.ArmaFavorita = BInfo.ArmaFavorita;
//	}

	NewBot.MySimulated = BInfo.SimulatedPP;

	if ( Level.Game.Isa('TeamGamePlus') )
		TeamGamePlus(Level.Game).AddToTeam( BInfo.Team, NewBot);
	if ( Level.Game.IsA('TeamGame') )
		TeamGame(Level.Game).AddToTeam( BInfo.Team, NewBot);

//FIX: (addtoteam cambia skins!!!)
	if ( BInfo.SimulatedPP == none )
		NewBot.Static.SetMultiSkin( NewBot, BInfo.BotSkin, BInfo.Face, Binfo.Team);
	else
	{
		NewBot.Mesh = BInfo.SimulatedPP.Default.Mesh;
		BInfo.SimulatedPP.Static.SetMultiSkin( NewBot, BInfo.BotSkin, BInfo.Face, Binfo.Team);
	}

	NewBot.SetVisualProps();
	NewBot.bSpawnedByUser = true;
	return NewBot;
}

function GetTheOrders(out name TheOrders, out actor OrderObject, byte TeamNum)
{
	local TeamInfo MyTeam;
	local int TeamSize;

	MyTeam = FindTheTeam(TeamNum, TeamSize);

	if (Level.Game.IsA('TeamGamePlus'))
	{
		if (Level.Game.IsA('Domination'))
			TheOrders = 'Freelance';
		else if (Level.Game.IsA('CTFGame'))
		{
			if (FRand() < 0.6)
				TheOrders = 'Attack';
			else if (FRand() < 0.9)
				TheOrders = 'Defend';
			else
				TheOrders = 'Freelance';
		}
		else if (Level.Game.IsA('Assault'))
		{
			if (MyTeam == Assault(Level.Game).Defender)
				TheOrders = 'Defend';
			else
				TheOrders = 'Attack';
		}
	}
}

function TeamInfo FindTheTeam(byte TeamIndex, out int Size)
{
	local TeamInfo T;
	local bool Success;

	success = False;
	ForEach AllActors(class'TeamInfo', T)
		if (T.TeamIndex == TeamIndex)
		{	Success = True;
			break;
		}
	if (Success)
		return T;
	return None;
}

function byte CountTeams()
{
	local TeamInfo T;
	local int i;

	ForEach AllActors(class'TeamInfo', T)
		i++;
	return byte(i);
}

final function bool MachinePlayer( playerPawn Test)
{
	return ( (Test != none) && (Test.Player != none) && (Test.Player.Console != none) );
}

defaultproperties
{
     InfoSName(0)="Aegor"
     InfoSName(1)="NegroVictor"
     InfoSName(2)="LAPD_Elite"
     InfoSName(3)="Higor"
     InfoSName(4)="Pushi"
     InfoSName(5)="Yoshi"
     InfoSName(6)="Wang"
     InfoSTeam(0)=2
     InfoSTeam(1)=1
     InfoSTeam(2)=255
     InfoSTeam(3)=255
     InfoSTeam(4)=1
     InfoSTeam(5)=2
     InfoSTeam(6)=255
     InfoSClass(0)="Fernando.TFerBoss"
     InfoSClass(1)="BotPack.TMale2"
     InfoSClass(2)="BotPack.TMale2"
     InfoSClass(3)="BotPack.TMale2"
     InfoSClass(4)="Yoshi.Yoshi"
     InfoSClass(5)="Yoshi.Yoshi"
     InfoSClass(6)="SkeletalChars.XanMk2"
     InfoSSkin(0)="BossSkinsFer2.Bozz"
     InfoSSkin(1)="SoldierSkins_SL.swat"
     InfoSSkin(2)="SoldierSkins_SP.lapd"
     InfoSSkin(3)="SoldierBAHv2.babw"
     InfoSSkin(4)="YoshiSkins.dark"
     InfoSSkin(5)="YoshiSkinsF.fvcf"
     InfoSFace(0)="BossSkinsFer2.Xan"
     InfoSFace(1)="SoldierSkins_SL.SWAT"
     InfoSFace(2)="SoldierSkins_SP.opps"
     InfoSFace(3)="SoldierBAHv2.Dexter"
     InfoSFace(4)="YoshiSkins.gree"
     InfoSFace(5)="YoshiSkins.gree"
     InfoSSkill(0)=70.000000
     InfoSSkill(1)=20.000000
     InfoSSkill(2)=17.000000
     InfoSSkill(3)=50.000000
     InfoSSkill(4)=69.000000
     InfoSSkill(5)=69.000000
     InfoSSkill(6)=46.000000
     InfoSAccuracy(0)=200
     InfoSAccuracy(1)=170
     InfoSAccuracy(2)=170
     InfoSAccuracy(3)=150
     InfoSAccuracy(4)=40
     InfoSAccuracy(5)=40
     InfoSAccuracy(6)=120
     InfoSVoiceType(0)="BSodPackage.VoiceBSod"
     InfoSVoiceType(1)="BotPack.VoiceMaleTwo"
     InfoSVoiceType(2)="BotPack.VoiceMaleTwo"
     InfoSVoiceType(3)="BotPack.VoiceMaleTwo"
     InfoSVoiceType(4)="MultiMesh.SkaarjVoice"
     InfoSVoiceType(5)="MultiMesh.SkaarjVoice"
     InfoSVoiceType(6)="BSodPackage.VoiceBSod"
     InfoSCChance(1)=100
     InfoSCChance(2)=100
     InfoSCTime(0)=15
     InfoSCTime(1)=25
     InfoSCTime(2)=20
     InfoSCTime(3)=5
     InfoSCTime(4)=30
     InfoSCTime(5)=30
     InfoSCTime(6)=20
     InfoSWeapon(0)="BotPack.minigun2"
     InfoSWeapon(1)="BotPack.SniperRifle"
     InfoSWeapon(2)="BotPack.SniperRifle"
     InfoSWeapon(4)="BotPack.pulsegun"
     InfoSWeapon(5)="BotPack.pulsegun"
     InfoSWeapon(6)="BotPack.UT_Eightball"
}
