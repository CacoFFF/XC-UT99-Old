//=============================================================================
// BotzMutator.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BotzMutator expands Mutator
	config( BotzDefault);

//#exec OBJ LOAD File=..\System\Fernando.u

var BotzProjectileStore BPS;
var BaseLevelPoint BLPlist[96];	//Para empezar, 96
var MasterGasterFer MasterG;
var PlayersVsBotz PlayersVsBotz;
var string LastMsg;//Evitar que una orden se procese multiples veces
var bool bMessageMutator;
var ServerBotzManager SBM;
var Botz_SpawnNotify SPN;
var config int MinTotalPlayers; //Works like DMPlus MinTotalPlayers, but with BotZ
var config bool bOnlyAdjustDedicated; //Only adjust in servers
var config string CustomFunctionManager;
var class<BotzFunctionManager> BFM;
var Botz_FactionInfo FactionManager;
var() bool bSafeSkins;
var() string PackagesList;

//Sistema de replicacion falsa

//	Sistema WFC
// Ventana: dar ordenes, luego en esta, un boton para entrar al creador de Botz
var() string WFCode;
var bool WFOpen;
var float TickWFOpener;
var() string UWindowClass;
var localized string MutatorCaption;
//var FV_MasterMenuMutator Master;
var Mutator Master;
//

//Hacks
var class<ReplicationInfo> SmartCTF_hack;

native(1718) final function bool AddToPackageMap( optional string PkgName);


//Prevent mutator overloading
event PreBeginPlay()
{
	local BotzMutator M;
	ForEach AllActors (class'BotzMutator', M)
		if ( M != self )
		{
			Destroy();
			return;
		}
}

event PostBeginPlay()
{
	local class BC;

	if ( MasterG == none )
		MasterG = Spawn(class'MasterGasterFer');
	SPN = Spawn( class'Botz_SpawnNotify');
	SPN.MyMutator = self;
	SetTimer( 3.0 ,True);	//FIX: En esta etapa, el jugador local o server puede no haber aparecido

	if ( (DeathMatchPlus(Level.Game) != none) && DeathMatchPlus(Level.Game).bRatedGame )
		MinTotalPlayers = 0;

	if ( Level.NetMode != NM_Standalone )
	{
		bSafeSkins = true;
		BC = class'XC_CoreStatics'.static.GetParentClass( class'Botz');
		AddToPackageMap( string(BC.Outer.Name) );
		ConsoleCommand("Set Botz bSuperClassRelevancy 1");
		ConsoleCommand("Set BotzTTarget bSuperClassRelevancy 1");
	}

	//Special stuff
//	class'Botpack.Ladder'.Default.LadderTeams[7] = class'RatedTeamInfoBotZ';
//	class'Botpack.Ladder'.Default.NumTeams = 8;


	if ( CustomFunctionManager != "" )
		BFM = Class<BotzFunctionManager> ( DynamicLoadObject(CustomFunctionManager,class'class') );
	if ( BFM == none )
		BFM = class'BotzFunctionManager';
	if ( (CTFGame(Level.Game) != none) && (SmartCTF_hack == none) )
		CheckSmartCTF();

	//Projectile store
	if ( BFM.default.DefaultBPS == none )
		BFM.default.DefaultBPS = class'BotzProjectileStore';
	BPS = Spawn(BFM.default.DefaultBPS);

	SBM = spawn(class'ServerBotzManager');
	SBM.MyMutator = self;
}

function AddMutator( Mutator M)
{
	local string sPkg;
	if ( M == none )
		return;
	if ( M.IsA('SmartCTF') )
	{
		sPkg = string(M.class);
		sPkg = Left(sPkg, InStr(sPkg,".")+1);
		SmartCTF_hack = class<ReplicationInfo>(DynamicLoadObject(sPkg$"SmartCTFPlayerReplicationInfo",class'class'));
	}
	if ( M.class == Class'PlayersVsBotz' ) //Do not hook to chain
	{
		PlayersVsBotz = PlayersVsBotz(M);
		PlayersVsBotz.BotzMutator = self;
		return;
	}
	Super.AddMutator( M);
}

function ModifyLogin(out class<playerpawn> SpawnClass, out string Portal, out string Options)
{
	//Reject dynamic botz player if net games
	if ( SpawnClass == class'DynamicBotzPlayer' && (Level.TimeSeconds > 0.01) )
		SpawnClass = class'TBoss';
	Super.ModifyLogin(SpawnClass, Portal, Options);
}

simulated event Timer() //FIX: por eso, espero 3 segundos
{
	local int i, j, k;
	local float Factor;
	local PlayerReplicationInfo PRI;

	if (Level.NetMode == NM_Client)
		return;

	k = -1;
	//Count players, botz, see if we have to add some more.
	if ( (MinTotalPlayers > 0) && (!bOnlyAdjustDedicated || (Level.NetMode == NM_DedicatedServer) ) )
	{
		Factor = 1.0;
		For ( i=0 ; i<32 ; i++ )
		{
			PRI = Level.Game.GameReplicationInfo.PRIArray[i];
			if ( PRI != none )
			{
				if ( !(PRI.PlayerName ~= "Player") && (PRI.PlayerName != "") && !PRI.bIsSpectator )
				{
					if ( Botz(PRI.Owner) != none )
					{
						if ( Botz(PRI.Owner).bIgnoredByMutator )
							continue;
						if ( !Botz(PRI.Owner).bSpawnedByUser )
						{
							if ( FRand() * Factor < 1.0 )
								k = i;
							Factor += 1.0;
						}
					}
					j++;
				}
			}
			else if ( i >= 16 ) //Optimization?
				break;
		}

		if ( (j > MinTotalPlayers) && (k >= 0) )
		{
			Level.Game.GameReplicationInfo.PRIArray[k].Owner.Destroy();
			ReBalance();
		}
		else if ( j < MinTotalPlayers )
		{
			CreateBot( "","","","");
			ReBalance();
		}
	}
}

simulated event Tick( float DeltaTime)
{
	local PlayerPawn P, Test;
	local int i;

	LastMsg = "";

	if ( TickWFOpener > 0)
	{
		TickWFOpener -= DeltaTime;
		if ( TickWFOpener <= 0.0 )
		{
			ForEach AllActors ( class'PlayerPawn', P)
				if ( MachinePlayer(P) )
					Test = P;
			OpenOrderWindow( Test);
			TickWFOpener = 500; //Evitar Enlentecimientos
		}
	}

	if ( (Role == ROLE_AUTHORITY) && !bMessageMutator)	//Solo server
	{//Registrarnos como mutador de mensajes
		NextMessageMutator = Level.Game.MessageMutator;
		Level.Game.MessageMutator = Self;
		bMessageMutator = True;
	}
}


simulated final function bool MachinePlayer( playerPawn Test)
{
	return ( (Test != none) && (Test.Player != none) && (Test.Player.Console != none) );
}

simulated function OpenOrderWindow( playerPawn Test)
{
}


function SetBLP( BaseLevelPoint Example, int index)
{
	BLPlist[index] = Example;
}
function BaseLevelPoint GetBLP( int i)
{
	return BLPlist[i];
}

function Mutate(string MutateString, PlayerPawn Sender)
{
	local string SpecialString;
	local string Command;
	local string Params[6];
	local int i;
	local Botz_FactionInfo tmpFaction;

	if ( (Level.NetMode == NM_Standalone) && Caps(MutateString) == "EDITPATHS" )
	{
		Sender.ConsoleCommand("open "$Left( string(self), inStr(string(self),".")) $ "?class=FerBotz.DynamicBotzPlayer");
		return;
	}

	if ( (Level.NetMode != NM_Standalone) && (Sender != none) && (NetConnection(Sender.Player) != none) && !Sender.bAdmin )
		Goto NEXT_MUTATOR;

	if (Caps(MutateString) == "BOTZMENU")
	{
		SetupMenu(Sender);
		ServerOnlyMessage( Sender.PlayerReplicationInfo.PlayerName@"intentó abrir el menú de los botz");
		if ( NextMutator != None )
			NextMutator.Mutate(MutateString, Sender);
		return;
	}

	SpecialString = MutateString;
	ClearSpaces( SpecialString);
	Command = GetTheWord( SpecialString);
	SpecialString = EraseTheWord( SpecialString);
	ClearSpaces( SpecialString);
	For ( i=0 ; i<6 ; i++ )
	{
		Params[i] = GetTheWord( SpecialString);
		SpecialString = EraseTheWord( SpecialString);
		ClearSpaces( SpecialString);
	}

	if ( Caps(Command) == "ADDBOTZ")
	{
		For ( i=0 ; i<6 ; i++ )
			BFM.static.ReplaceText( Params[i], " ", "");

		if ( Params[0] == "?")
		{
			Sender.ClientMessage("FORMATO: mutate ADDBOTZ #nombre# #equipo# #dificultad# #punteria# #forma# #camp#");
			Sender.ClientMessage("Los parametros nulos van como _ (guion bajo)");
			Sender.ClientMessage("Equipo puede ir como 'GREEN' o como '2'");
			Sender.ClientMessage("Forma va como: classname;skin;cara;voz. Usando_localizaciones_asi (no los classnames ni skinnames)");
			Sender.ClientMessage("SKILL: 0 < 7, PUNTERIA: 5 < 0, CAMP: chance");
		}
		else if ( Caps(Params[0]) == "HELP" )
		{
			Sender.ClientMessage("FORMAT: mutate ADDBOTZ #name# #team# #skill# #accuracy# #looks# #camp#");
			Sender.ClientMessage("Use underscore as null parameters  _ ");
			Sender.ClientMessage("Team can be like 'GREEN' or '2'");
			Sender.ClientMessage("#Looks# format: class;skin;face;voice. Using_localizations_like_this (EX: male_soldier;marine;malcom;male_two)");
			Sender.ClientMessage("SKILL: 0 < 7, ACCURACY: 5 < 0, CAMP: chance");
		}
		else 
		{
			BFM.static.ReplaceText( Params[0], "_", "");
			BFM.static.ReplaceText( Params[1], "_", "255");
			BFM.static.ReplaceText( Params[2], "_", string(FRand() * 6.0) );
			BFM.static.ReplaceText( Params[3], "_", string( 1.0 + FRand() * 4.0) );
			BFM.static.ReplaceText( Params[4], "_", " ");
			CreateBot( Params[0], Params[1], Params[2], Params[3], Params[4], Params[5] );
			if ( Sender != none )
			{
				Sender.ClientMessage("Agregar BOTZ:");
				For (i=0;i<6;i++)
					if ( Params[i] != "" )
						Sender.ClientMessage("Comando numero"@i+1$":"@Params[i]);
			}
		}

	}
	else if ( Caps(Command) == "ADDBOTZLIST")	//Botz de una lista
	{
		BFM.static.ReplaceText( Params[0], " ", "");
		BFM.static.ReplaceText( Params[1], " ", "");
		if ( Caps(Params[0]) == "?" )
		{
			Sender.ClientMessage("FORMATO: mutate ADDBOTZLIST #nombre# (#equipo#)");
			Sender.ClientMessage("Equipo puede ir como 'GREEN' o como '2'");
		}
		else if ( (Caps(Params[0]) == "ALL") || ( Caps(Params[0]) == "TODOS" ) )
		{
			SBM.AddAllBotz( Params[1] );
			Log("Agregar todos los BOTZ, en equipo"@Params[2]);
			return;
		}
		else if ( Params[0] != "")
		{
			SBM.AddListBotz( Params[0], Params[1] );
			Log("Agregar BOTZ:"@Params[0]$"en equipo"@Params[2]);
			return;
		}

	}
	else if ( Caps(Command) == "ADDBOTZFACTION" ) //Botz perteneciente a faccion
	{
//		if ( PlayersVsBotz != none )
//		{
//			ServerOnlyMessage("You may not add Botz in PlayersVsBotz mode");
//			return;
//		}
		if ( FactionManager == none )
		{
			FactionManager = Spawn( class'Botz_FactionInfo');
			FactionManager.MyMutator = self;
			ServerOnlyMessage( "Creando manager de facciones");
		}

		if ( Params[0] == "?" )
		{
			Sender.ClientMessage("FORMATO: mutate ADDBOTZFACTION #nombre# #cantidad# #equipo# #modificador#");
			Sender.ClientMessage("Los parametros nulos van como _ (guion bajo)");
			Sender.ClientMessage("Nombre de faccion no debe tener espacios");
			Sender.ClientMessage("Equipo puede ir como 'GREEN' o como '2'");
			Sender.ClientMessage("Modificadores: FACIL o DIFICIL para modificar habilidad");
		}
		else if ( Caps(Params[0]) == "HELP" )
		{
			Sender.ClientMessage("FORMAT: mutate ADDBOTZFACTION #name# #amount# #team# #modifier#");
			Sender.ClientMessage("Use underscore as null parameters  _ ");
			Sender.ClientMessage("Faction name must not have spaces");
			Sender.ClientMessage("Team be like 'GREEN' or like '2'");
			Sender.ClientMessage("Modifiers: EASY o HARD to modify skill");
		}
		else if ( Params[0] != "" )
		{
			tmpFaction = FactionManager.InitFaction( Params[0], true);
			if ( tmpFaction == none )
			{
				Sender.ClientMessage("NO FACTION "$Params[0] );
				return;
			}
			
			if ( Caps(Params[3]) == "HARD" || Caps(Params[3]) == "DIFICIL" )
			{
				tmpFaction.SkillMult = 1.5;
				Sender.ClientMessage("HARD MODE");
			}
			else if ( Caps(Params[3]) == "NORMAL" )
			{
				tmpFaction.SkillMult = 1.0;
				Sender.ClientMessage("NORMAL MODE");
			}
			else if ( Caps(Params[3]) == "EASY" )
			{
				tmpFaction.SkillMult = 0.6;
				Sender.ClientMessage("EASY MODE");
			}

			if ( Params[2] != "" )
			{
				if ( Params[2] != "_" )
					i = GetTheTeam2( Params[2] );
				if ( (Params[2] == "_") || (i != Clamp(i,0,3)) )
				{
					Sender.ClientMessage("BAD TEAM");
					return;
				}
				tmpFaction.FactionTeam = i;
			}

			i = int( Params[1] );
			if ( (i > 0) && (i < 16) )
				tmpFaction.AddBotz( i);
			else if ( Params[1] != "_" )
				Sender.ClientMessage( "BAD NUMBER "$Params[1]);
		}

	}

	NEXT_MUTATOR:

	if ( NextMutator != None )
		NextMutator.Mutate(MutateString, Sender);
}

function Botz CreateBot( string BotName, string StrTeam, string Skill, string Punteria, optional string BotClass, optional string BotCamp)
{
	local FBotInfo FBI;
	local Botz NewBot;
	local class<PlayerPawn> TheSimulated;
	local class<VoicePack> newVoice;
	local string TheClass, TheSkin, TheFace, TheVoice, TempSkin, TempFace, TempVoice;
	local int i;

	FBI = Spawn(class'FBotInfo');
	FBI.MyMutator = self;
	NewBot = FBI.CreateRandomBot( BotName, GetTheTeam(StrTeam), (BotClass != "") && (BotClass != " ") );
	if ( (Skill != "") && ( Caps(Skill) != "NONE") )
		NewBot.Skill = float(Skill);
	else
		NewBot.Skill = FRand() * 7;
	if ( (Punteria != "") && ( Caps(Punteria) != "NONE") )
		NewBot.Punteria = float(Punteria);
	else
		NewBot.Punteria = FRand() * 4;
	if ( (BotCamp != "") && ( Caps(BotCamp) != "NONE") )
		NewBot.CampChance = float(BotCamp) / 100.0;

	
	if ( (BotClass == "") || (BotClass == " ") )
	{
		FBI.Destroy();
		return NewBot;
	}

		i = InStr( BotClass, ";");
		if ( i < 0 )
			TheClass = BotClass;
		else
		{
			TheClass = Left( BotClass,i);
			BotClass = Right(BotClass, Len(BotClass) - ++i);
	
			i = InStr( BotClass, ";");
			if ( i == 0 ) //Evitar remover 2 ';' juntos (que significa skin y cara en default)
				BotClass = Right(BotClass, Len(BotClass) - 1);
			//Repetir para skin y cara
			i = InStr( BotClass, ";");
			if ( i < 0 )
				TheSkin = BotClass;
			else
			{
				TheSkin = Left( BotClass, i);
				BotClass = Right(BotClass, Len(BotClass) - ++i);
	
				i = InStr( BotClass, ";");
				if ( i<0 )
					TheFace = BotClass;
				else
				{
					TheFace = Left( BotClass, i);
					BFM.static.ReplaceText( TheFace, ";", "");
	
					BotClass = Right(BotClass, Len(BotClass) - ++i);
					i = InStr( BotClass, ";");
					if ( i == 0 )
						BotClass = Right(BotClass, Len(BotClass) - 1);
					
					if ( BotClass != "" )
						TheVoice = BotClass;
				}
				Log("TheFace: "$TheFace);
			}
		}

		if ( TheClass != "" )
			GetPlayerClass( TheClass, NewBot.MySimulated);
		if ( NewBot.MySimulated == none )
			NewBot.MySimulated = class'BotPack.TBoss';
		NewBot.SetVisualProps();
		if ( TheSkin != "" )
			GetPlayerSkin( NewBot.MySimulated, TheSkin, TempSkin);
		if ( TheFace != "" )
			GetPlayerFace( NewBot.MySimulated, TempSkin, TheFace, TempFace);
		if ( TheVoice != "")
			GetPlayerVoice( NewBot.MySimulated, TheVoice, TempVoice);
		NewBot.MultiSkins[0] = none;
		NewBot.MultiSkins[1] = none;
		NewBot.MySimulated.static.SetMultiSkin( NewBot, TempSkin, TempFace, NewBot.PlayerReplicationInfo.Team);
		if ( TempVoice != "" )
			NewBot.VoiceType = TempVoice;
		newVoice = class<VoicePack>( DynamicLoadObject(NewBot.VoiceType, class'class', true) );
		if ( newVoice != none )
			NewBot.PlayerReplicationInfo.VoiceType = newVoice;
	FBI.Destroy();
	return NewBot;
}

final function GetPlayerClass( string LocalizationName, out class<PlayerPawn> PClass)
{
	local int NumPlayerClasses;
	local string NextPlayer, NextDesc;
	local int SortWeight;

	BFM.static.ReplaceText( LocalizationName, "_", " ");
	GetNextIntDesc( "BotPack.TournamentPlayer", 0, NextPlayer, NextDesc);
	while( (NextPlayer != "") && (NumPlayerClasses < 64) )
	{
		if ( Caps(LocalizationName) == Caps(NextDesc) )
		{
			PClass = Class<PlayerPawn>( DynamicLoadObject( NextPlayer, class'Class') );
			return;
		}
		NumPlayerClasses++;
		GetNextIntDesc("BotPack.TournamentPlayer", NumPlayerClasses, NextPlayer, NextDesc);
	}
}

final function GetPlayerSkin( class<PlayerPawn> TheClass, string LocalSkin, out string ASkin)
{
	local string SkinName, SkinDesc, TestName, Temp, FaceName;
	local int i;

	BFM.static.ReplaceText( LocalSkin, "_", " ");
	SkinName = "None";
	TestName = "";
	while ( True )
	{
		GetNextSkin( GetItemName(string(TheClass.Default.Mesh)), SkinName, 1, SkinName, SkinDesc);
		if( SkinName == TestName )
			break;
		if( TestName == "" )
			TestName = SkinName;
		// Multiskin format
		if( SkinDesc != "")
		{			
			Temp = GetItemName(SkinName);
			if(Mid(Temp, 5, 64) == "")
				// This is a skin
				if ( Caps(LocalSkin) == Caps(SkinDesc) )
				{	ASkin = Left(SkinName, Len(SkinName) - Len(Temp)) $ Left(Temp, 4);
					Log("Skin dio: "$ASkin$". Esta bien?");
					return;
				}
		}
	}
}

final function GetPlayerFace( class<PlayerPawn> TheClass, string InSkinName, string DesiredFace, out string SomeFace)
{
	local string SkinName, SkinDesc, TestName, Temp, FaceName;

	BFM.static.ReplaceText( DesiredFace, "_", " ");
	SkinName = "None";
	TestName = "";
	while ( True )
	{
		GetNextSkin( GetItemName(string(TheClass.Default.Mesh)), SkinName, 1, SkinName, SkinDesc);
		if( SkinName == TestName )
			break;
		if( TestName == "" )
			TestName = SkinName;
		// Multiskin format
		if( SkinDesc != "")
		{			
			Temp = GetItemName(SkinName);
			if(Mid(Temp, 5) != "" && Left(Temp, 4) == GetItemName(InSkinName))
				if ( Caps(DesiredFace) == Caps( SkinDesc) )
				{	SomeFace = Left(SkinName, Len(SkinName) - Len(Temp)) $ Mid(Temp, 5);
					return;
				}
		}
	}
}

final function GetPlayerVoice( class<PlayerPawn> TheClass, string DesiredVoice, out string SomeVoice)
{
	local int NumVoices;
	local string NextVoice, NextDesc;
	local string VoicepackMetaClass;

	if(ClassIsChildOf(TheClass, class'TournamentPlayer'))
		VoicePackMetaClass = class<TournamentPlayer>(TheClass).default.VoicePackMetaClass;
	else
		VoicePackMetaClass = "Botpack.ChallengeVoicePack";

	// Load the base class into memory to prevent GetNextIntDesc crashing as the class isn't loadded.
	DynamicLoadObject(VoicePackMetaClass, class'Class');

	GetNextIntDesc(VoicePackMetaClass, 0, NextVoice, NextDesc);
	while( (NextVoice != "") && (NumVoices < 64) )
	{
		if ( Caps(NextDesc) == Caps(DesiredVoice) )
		{
			SomeVoice = NextVoice;
			return;
		}

		NumVoices++;
		GetNextIntDesc(VoicePackMetaClass, NumVoices, NextVoice, NextDesc);
	}

}

final function SetupMenu( PlayerPawn Dunno)
{
	local BotzMenuInfo BMI;

	if (Dunno.IsA('Spectator') || !Dunno.bIsPlayer)
	{
		ServerOnlyMessage("Hay un espectador llamado"@Dunno.PlayerReplicationinfo.PlayerName@"intentando usar el BotzMenu");
		return;
	}

	ForEach AllActors (class'BotzMenuInfo', BMI)
		if (BMI.Owner == Dunno)
		{
			SBM.MenuSetUp( Dunno);
			return;
		}
	ServerOnlyMessage("Jugador"@Dunno.PlayerReplicationinfo.PlayerName@"no tiene MenuInfo");
	BMI = Dunno.Spawn(class'BotzMenuInfo');
	BMI.SetOwner(Dunno);
	BMI.MyManager = SBM;
	SBM.MenuSetUp( Dunno);
}

/*
final function string GetTheWord(string Text)
{
	local int i;
	ClearSpaces(Text);
	i = InStr( Text, " ");
	return Left(Text,i);
}

final function string EraseTheWord(string Text)
{
	local int i;
	ClearSpaces(Text);
	i = InStr( Text, " ");
	return Right(Text, Len(Text) - i - 1);
}

final function ClearSpaces(out string Text)
{
	local int i;
	local string Input;
		
	Input = Text;
	Text = "";
	i = InStr(Input, " ");
	while( (i == 0) || (i == 1) )
	{	
		Text = Right(Input, Len(Input) - 1);
		Input = Text;	
		i = InStr(Input, " ");
	}
}
*/


final function ServerOnlyMessage( coerce string ServerMessage)
{
	Local playerpawn P;

	ForEach AllActors (class'playerPawn', P)
		P.ClientMessage("Server:"@ServerMessage);

	Log("Mutador de botz: "$ServerMessage);
}

function name GetTheTeam( string TTTeam)
{
	local string TTeam;
	TTeam = Caps(TTTeam);

	if ( (TTeam == "RED") || (TTeam == "0") )
		return 'Red';
	else if ( (TTeam == "BLUE")  || (TTeam == "1") )
		return 'Blue';
	else if ( (TTeam == "GREEN")  || (TTeam == "2") )
		return 'Green';
	else if ( (TTeam == "GOLD") || (TTeam == "YELLOW") || (TTeam == "3") )
		return 'Gold';
	else
		return '';
}

function byte GetTheTeam2( string TTeam)
{
	TTeam = Caps(TTeam);

	if ( (TTeam == "RED") || (TTeam == "ROJO") || (TTeam == "0") )
		return 0;
	else if ( (TTeam == "BLUE") || (TTeam == "AZUL") || (TTeam == "1") )
		return 1;
	else if ( (TTeam == "GREEN") || (TTeam == "VERDE") || (TTeam == "2") )
		return 2;
	else if ( (TTeam == "GOLD") || (TTeam == "YELLOW") || (TTeam == "AMARILLO") || (TTeam == "3") )
		return 3;
	else
		return -1;
}

//************* DAR ORDENES A LOS BOTZ
function bool MutatorTeamMessage( Actor Sender, Pawn Receiver, PlayerReplicationInfo PRI, coerce string S, name Type, optional bool bBeep )
{
	local int i;
	local string TheWord, Phrase, TheOrder;
	local Botz Subject;
	local actor OrderObject;
	local bool bOrderLocated;

	if ( ((Type == 'Say') || (Type == 'TeamSay')) && (LastMsg != S) )
	{	
		//Aegor: dame un SniperRifle
		//Aegor: consigue un FlakCannon a Nargo
		//Nargo, Patrulla aqui
		//Nargo. y aqui (y asi sucesivamente)
		//Xan cubre a Aegor
		//Killer, mata a Gaudor
		//Chuban, defiende a Punto_Superior	(control point o fort standard guiones_en_vez_de_espacios)
		//Formato: Nombre, orden, objeto/s (si es necesario)
		Phrase = S;
		ClearSpaces( Phrase);
		TheWord = GetTheWord( Phrase);
		BFM.static.ReplaceText( TheWord, ",", "");	//Eliminar caracteres extra
		BFM.static.ReplaceText( TheWord, ":", "");
		BFM.static.ReplaceText( TheWord, ".", "");
		Subject = LocateBotZ( TheWord);
		if ( (Subject != none) && (Subject.PlayerReplicationInfo.Team == Pawn(Sender).PlayerReplicationInfo.Team) )
		{//Ahora, localizar la orden
			bOrderLocated = False;
			While ( Phrase != "" )
			{
				Phrase = EraseTheWord( Phrase);
				ClearSpaces( Phrase);
				TheWord = GetTheWord( Phrase);
				BFM.static.ReplaceText( TheWord, " ","");
				if ( (Caps(TheWord) == "DEFIENDE") )
				{//No ubicar objeto de defensa aún
					Subject.SetOrders( 'Defend', Pawn(Sender), False);
					bOrderLocated = True;
					break;
				}
				else if ( (Caps(TheWord) == "REVIVE") )
				{
					Subject.GotoState('Dead','Go');
					bOrderLocated = True;
					break;
				}
				else if ( InStrF( caps(Phrase), "NUEVA PATRULLA") || InStrF( caps(Phrase), "NUEVO PATRULLAJE") || InStrF( caps(Phrase), "OTRA GUARDIA") )
				{
					Subject.SetOrders( 'NewPatrol', Pawn(Sender), False);
					bOrderLocated = True;
					break;
				}
				else if ( (Caps(TheWord) == "PATRULLA") || (Caps(TheWord) == "PATRULLAJE") || (Caps(TheWord) == "GUARDIA") )
				{
					Subject.SetOrders( 'AddPatrol', Pawn(Sender), False);
					bOrderLocated = True;
					break;
				}
				else if ( (Caps(TheWord) == "ATACA") || (Caps(TheWord) == "DESTRUYE") || (Caps(TheWord) == "ASALTA") )
				{
					Subject.SetOrders( 'Attack', Pawn(Sender), False);
					bOrderLocated = True;
					break;
				}
				else if ( InStrF( caps(Phrase), "MANTEN MI POSICION") || InStrF( caps(Phrase), "MANTEN ESTA POSICION") || InStrF( caps(Phrase), "QUEDATE AQUI")  || InStrF( caps(Phrase), "QUEDATE ACA") )
				{
					Subject.SetOrders( 'Hold', Pawn(Sender), False);
					bOrderLocated = True;
					break;
				}
				else if ( InStrF( caps(Phrase), "MANTEN TU POSICION") || InStrF( caps(Phrase), "MANTEN POSICION ACTUAL") || InStrF( caps(Phrase), "MANTEN TAL POSICION") || InStrF( caps(Phrase), "MANTEN ESA POSICION") || InStrF( caps(Phrase), "QUEDATE AHI") )
				{
					Subject.SetOrders( 'Hold', Pawn(Sender), False);
					Subject.OrderObject = Subject.Spawn(class'F_HoldPosition',Subject,,Subject.Location,Subject.ViewRotation);
					Subject.MyHoldSpot = F_HoldPosition(Subject.OrderObject);
					bOrderLocated = True;
					break;
				}
				else if ( (Caps(TheWord) == "CUBREME") || (Caps(TheWord) == "SIGUEME") )
				{
					Subject.SetOrders( 'Follow', Pawn(Sender), False);
					bOrderLocated = True;
					break;
				}
				else if ( (Caps(TheWord) == "CUBRE") || (Caps(TheWord) == "SIGUE") || (Caps(TheWord) == "PROTEGE") )
				{
					bOrderLocated = False;
					While ( (Phrase != "") && (OrderObject == none) )
					{
						Phrase = EraseTheWord( Phrase);
						ClearSpaces( Phrase);
						TheWord = GetTheWord( Phrase);
						BFM.static.ReplaceText( TheWord, " ","");
						OrderObject = locatePlayer( TheWord);
						if ( (OrderObject != none) && ( Pawn(OrderObject).PlayerReplicationInfo.Team == Subject.PlayerReplicationInfo.Team ) )
						{
							Subject.SetOrders( 'Follow', Pawn(Sender), False);
							BotReplicationInfo(Subject.PlayerReplicationInfo).OrderObject = OrderObject;
							BotReplicationInfo(Subject.PlayerReplicationInfo).SetRealOrderGiver( Pawn(OrderObject) );
							Subject.OrderObject = OrderObject;
							Subject.thetrail.SetOwner( OrderObject);
							bOrderLocated = True;
							break;
						}
					}
					if ( bOrderLocated )
						break;
				}
			}
		}
	}
	LastMsg = S;

	if ( NextMessageMutator != None )
		return NextMessageMutator.MutatorTeamMessage( Sender, Receiver, PRI, S, Type, bBeep );
	else
		return true;
}

function ReBalance()
{
	local int big, small, i, bigsize, smallsize;
	local Pawn P, A;
	local BotZ B;
	local TeamGamePlus TGP;

	TGP = TeamGamePlus( Level.Game);

	if ( TGP == none )
		return;

	big = 0;
	small = 0;
	bigsize = TGP.Teams[0].Size;
	smallsize = TGP.Teams[0].Size;
	for ( i=1; i<TGP.MaxTeams; i++ )
	{
		if ( TGP.Teams[i].Size > bigsize )
		{
			big = i;
			bigsize = TGP.Teams[i].Size;
		}
		else if ( TGP.Teams[i].Size < smallsize )
		{
			small = i;
			smallsize = TGP.Teams[i].Size;
		}
	}
	
	TGP.bBalancing = true;
	while ( bigsize - smallsize > 1 )
	{
		for ( P=Level.PawnList; P!=None; P=P.NextPawn )
			if ( P.bIsPlayer && (P.PlayerReplicationInfo.Team == big)
				&& P.IsA('BotZ') )
			{
				B = Botz(P);
				break;
			}
		if ( B != None )
		{
			B.Health = 0;
			B.Died( None, 'Suicided', B.Location );
			bigsize--;
			smallsize++;
			TGP.ChangeTeam(B, small);
		}
		else
			Break;
	}
	TGP.bBalancing = false;

	// re-assign orders to follower bots with no leaders
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( P.bIsPlayer && P.IsA('Botz') && (BotReplicationInfo(P.PlayerReplicationInfo).RealOrders == 'Follow') )
		{
			A = Pawn(Botz(P).OrderObject);
			if ( (A == None) || A.bDeleteMe || !A.bIsPlayer || (A.PlayerReplicationInfo.Team != P.PlayerReplicationInfo.Team) )
			{
				Botz(P).OrderObject = None;
				Botz(P).SetOrders('Freelancing', none);
			}
		}

}


function string GetTheWord(string Text)
{
	local int i;
	ClearSpaces(Text);
	i = InStr( Text, " ");
	if ( i < 0 )
		return Text;
	return Left(Text,i);
}

function string EraseTheWord(string Text)
{
	local int i;
	ClearSpaces(Text);
	i = InStr( Text, " ");
	if ( i < 0 )
		return "";
	return Right(Text, Len(Text) - i - 1);
}

function ClearSpaces(out string Text)
{
	local int i;

	i = InStr(Text, " ");
	while( i == 0 )
	{
		Text = Right(Text, Len(Text) - 1);
		i = InStr(Text, " ");
	}
}

static final function bool InStrF( string S, string T)
{
	local int i;
	i = Instr( S, T);
	return ( (i == 0) || (i == 1) );
}

function Botz LocateBotZ( string PlayerName)
{
	local pawn P;

	if ( (PlayerName == "") || (PlayerName == "Player") )
		return none;

	for ( P=Level.Pawnlist ; P!=none ; P=P.nextPawn )
		if ( P.IsA('Botz') )
			if ( Caps(P.PlayerReplicationInfo.PlayerName) == Caps(PlayerName) )
				return Botz(P);
}
function Pawn LocatePlayer( string PlayerName)
{
	local pawn P;

	if ( (PlayerName == "") || (PlayerName == "Player") )
		return none;

	for ( P=Level.Pawnlist ; P!=none ; P=P.nextPawn )
		if ( !P.IsA('ScriptedPawn') && !P.IsA('Spectator') )
			if ( Caps(P.PlayerReplicationInfo.PlayerName) == Caps(PlayerName) )
				return P;
}

function CheckSmartCTF()
{
	local Mutator M;
	local string sPkg;

	For ( M=Level.Game.BaseMutator ; M!=none ; M=M.nextMutator )
	{
		if ( M.IsA('SmartCTF') )
		{
			sPkg = string(M.class);
			sPkg = Left(sPkg, InStr(sPkg,".")+1);
			SmartCTF_hack = class<ReplicationInfo>(DynamicLoadObject(sPkg$"SmartCTFPlayerReplicationInfo",class'class'));
			return;
		}
	}
}

defaultproperties
{
	bOnlyAdjustDedicated=True
	MinTotalPlayers=0
}
