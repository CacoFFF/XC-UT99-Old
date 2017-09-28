//=============================================================================
// Botz_FactionInfo.
//
// Generic faction spawner + Faction int definitions
// Generic mode will generate a faction on the fly based on mesh-skins
// Definitions will have these saved in int files, like skins and stuff
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_FactionInfo extends InfoPoint;

//	NewBotZ.AvgCampTime = 5 + (Camping[n] * 15.0);

//Used to add more BotZ on an existing faction
var Botz_FactionInfo nextFaction;
var BotzMutator MyMutator; //Mutator is the ONLY way to add factions, stick to it

var() string ErrorString;

var() string FactionID;
var() byte FactionTeam;
var() float BaseSkill;
var() float BaseAcc;
var() float SkillMult;

var() byte Members;
var() string BotName[16];
var() class<PlayerPawn> BotClass[16];
var() string BotSkin[16], BotFace[16];
var() float BotAcc[16], BotSkill[16]; //0 to 100
var() class<Weapon> BotWeapon[16];
var() class<VoicePack> BotVoice[16];
var() float BotCamp[16]; //0 to 100

var() class<VoicePack> RegVoices[8];
var() class<PlayerPawn> RegClasses[8];
var() string RegSkins[8];


function Botz_FactionInfo InitFaction( string FactionName, bool bNotThis)
{
	local Botz_FactionInfo aFac;
	
	//Base faction info, do not process anything here
	if ( bNotThis )
	{
		aFac = nextFaction;
		While (aFac != none)
		{
			if ( aFac.FactionID == Caps(FactionName) )
				return aFac;
			aFac = aFac.nextFaction;
		}
		aFac = Spawn( class).InitFaction(FactionName, false);
		if ( aFac == none )
			return none;
		aFac.MyMutator = MyMutator;
		aFac.nextFaction = nextFaction;
		nextFaction = aFac;
		return aFac;
	}

	//Non base, return true if success, none if fail
	if ( GrabFaction(FactionName) )
		return self;

	ServerOnlyMessage( ErrorString );
	Destroy();
	return none;
}

function bool AddBotz( int Amount)
{
	local int i, j, MaxPRI, iCount;
	local GameReplicationInfo GRI;
	local byte AddedArray[16];

	GRI = Level.Game.GameReplicationInfo;
	MaxPRI = 32;
	For ( i=0 ; i<32 ; i++ )
	{
		if ( GRI.PRIArray[i] != none )
			MaxPRI = i+1;
	}

	//Build list of added members
	For ( i=0 ; i<Members ; i++ )
	{
		For ( j=0 ; j<MaxPRI ; j++ )
		{
			if ( GRI.PRIArray[j].PlayerName ~= BotName[i] )
			{
				AddedArray[i] = 1;
				iCount++;
				break;
			}
		}
	}

	//Check for leaders, these are likely to appear (one at first, second between second or 5th)
	ADDAGAIN:
	if ( Amount <= 0 )
		return true;

	if ( iCount == 0 )
	{
		j = Rand(2);	 AddedArray[j] = 1;
		Individualize( j );		Amount--;		iCount++;	Goto ADDAGAIN;
	}
	else if ( iCount < 6 )
	{
		MaxPRI = min(8,Members);
		j = Rand( MaxPRI );
		For ( i=j ; i<MaxPRI ; i++ )
		{
			if ( AddedArray[i] == 0 )
			{
				Individualize(i);
				Amount--;
				iCount++;
				AddedArray[i] = 1;
				Goto ADDAGAIN;
			}
		}
		For ( i=0 ; i<j ; i++ )
		{
			if ( AddedArray[i] == 0 )
			{
				Individualize(i);
				Amount--;
				iCount++;
				AddedArray[i] = 1;
				Goto ADDAGAIN;
			}
		}
	}
	else
	{
		MaxPRI = min(16,Members);
		j = Rand( MaxPRI );
		For ( i=j ; i<MaxPRI ; i++ )
		{
			if ( AddedArray[i] == 0 )
			{
				Individualize(i);
				Amount--;
				iCount++;
				AddedArray[i] = 1;
				Goto ADDAGAIN;
			}
		}
		For ( i=0 ; i<j ; i++ )
		{
			if ( AddedArray[i] == 0 )
			{
				Individualize(i);
				Amount--;
				iCount++;
				AddedArray[i] = 1;
				Goto ADDAGAIN;
			}
		}
	}

	ServerOnlyMessage( "Not enough botZ in faction");
	return false;
}

function Individualize( int ThisBot)
{
	local float fSkill, fAcc;
	local FBotInfo FBI;
	local Botz NewBot;
	local int i;
	local NavigationPoint N;

	Log( "Individualizando: "$ ThisBot);

	fSkill = BotSkill[ThisBot];
	fAcc = BotAcc[ThisBot];
	
	if ( SkillMult < 1)
	{
		fSkill *= SkillMult;
		fAcc += (5 - fAcc) * (1 - SkillMult);
	}
	else if ( SkillMult > 1 )
	{
		fSkill += (7 - fSkill) * (SkillMult - 1);
		fAcc *= abs(SkillMult - 2);
	}

	N=Level.Game.FindPlayerStart( none, FactionTeam);
	NewBot = Spawn(class'Botz',,,N.Location, N.Rotation);

	NewBot.AvgCampTime = 15 + BotCamp[ThisBot] / 10;
	NewBot.PlayerReplicationInfo.Team = FactionTeam;
	NewBot.PlayerReplicationInfo.bIsABot = True;
	Level.Game.ChangeName( NewBot, BotName[ThisBot], false);

	NewBot.Skill = fSkill;
	NewBot.Punteria = fAcc;
	NewBot.CampChance = BotCamp[ThisBot] / 100.0;
	NewBot.MySimulated = BotClass[ThisBot];
	NewBot.ArmaFavorita = BotWeapon[ThisBot];
	NewBot.SetVisualProps();

	NewBot.MultiSkins[0] = none;
	NewBot.MultiSkins[1] = none;
//	Log("Skin here");
	BotClass[ThisBot].static.SetMultiSkin( NewBot, BotSkin[ThisBot], BotFace[ThisBot], FactionTeam);
	NewBot.PlayerReplicationInfo.VoiceType = BotVoice[ThisBot];
/*	
	For ( i=0 ; i<32 ; i++ )
		if ( Level.Game.GameReplicationInfo.PRIArray[i] == none)
		{
			Level.Game.GameReplicationInfo.PRIArray[i] = NewBot.PlayerReplicationInfo; //Important
			break;
		}
*/
	if (Level.Game.IsA('TeamGame'))
		TeamGame(Level.Game).AddToTeam( FactionTeam, NewBot);
	else if (Level.Game.IsA('TeamGamePlus'))
		TeamGamePlus(Level.Game).AddToTeam( FactionTeam, NewBot);

	GetTheOrders( NewBot.Orders, NewBot.OrderObject, FactionTeam);
}

function bool GrabFaction( string FactionName)
{
	local string testStr, testDesc, tmpStr;
	local int i, j, k, h;

	FactionName = Caps(FactionName);
	FactionID = FactionName;
	BaseSkill = -1;
	BaseAcc = -1;

	GetNextIntDesc("FerBotz.Botz_FactionInfo",0,testStr,testDesc);
	while( testStr != "" )
	{
		if ( (testDesc == "FACTION") && (Caps(testStr) == FactionName) )
			Goto FACTION_FOUND;
		GetNextIntDesc("FerBotz.Botz_FactionInfo",++i,testStr,testDesc);
	}
	ErrorString = "Faction not found: "$FactionName;
	return False;

	//Register new elements, else, go into bot definition mode
	FACTION_FOUND:
	while( testStr != "" )
	{
		GetNextIntDesc("FerBotz.Botz_FactionInfo",++i,testStr,testDesc);

		if ( testDesc == "VOICE" )
			RegVoices[j++] = class<VoicePack>( DynamicLoadObject( testStr,class'class') );
		else if ( testDesc == "CLASS" )
			RegClasses[k++] = class<PlayerPawn>( DynamicLoadObject( testStr,class'class') );
		else if ( testDesc == "SKIN" )
			RegSkins[h++] = testStr;
		else if ( testDesc == "FACTION" )
		{
			//Faction with more than one name?
		}
		else if ( testDesc == "BASESKILL" )
			BaseSkill = fClamp(float(testStr), 0, 100);
		else if ( testDesc == "BASEACCURACY" )
			BaseAcc = fClamp(float(testStr), 0, 100);
		else
			Goto FIND_MEMBERS;
	}
	ErrorString = "Nothing defined after faction or elements, check your file";
	return False;

	FIND_MEMBERS:
	k=0; j=0; h=0;
	if ( BaseSkill == -1 ) BaseSkill = 50 + Rand(20);
	if ( BaseAcc == -1 ) BaseAcc = 40 + Rand(20);
	while ( testStr != "" )
	{
		if ( testDesc == "FACTION" )
			break;

		BotName[Members] = testStr;

		testDesc = RemoveText( testDesc, " ");
		BotSkill[Members] = fClamp( BaseSkill * 0.07, 0, 7);
		BotAcc[Members] = fClamp(5.0 - BaseAcc * 0.05, 0, 5);
		while ( testDesc != "" )
		{
			if ( inStr(testDesc, ",") != -1 )
			{
				tmpStr = Left( testDesc, inStr(testDesc,",") );
				testDesc = Mid( testDesc, inStr(testDesc,",") + 1);
			}
			else
			{
				tmpStr = testDesc;
				testDesc = "";
			}

			if ( Left( tmpStr, 6) ~= "class=" )
				k = int( Mid(tmpStr, 6)) - 1;
			else if ( Left( tmpStr, 5) ~= "skin=" )
				h = int( Mid(tmpStr, 5)) - 1;
			else if ( Left( tmpStr, 5) ~= "face=" )
				BotFace[Members] = Mid( tmpStr, 5);
			else if ( Left( tmpStr, 6) ~= "voice=" )
				j = int( Mid(tmpStr, 6)) - 1;
			else if ( Left( tmpStr, 7) ~= "weapon=" )
				BotWeapon[Members] = class<Weapon>( DynamicLoadObject( Mid(tmpStr,7),class'class') );
			else if ( Left( tmpStr, 6) ~= "skill=" )
				BotSkill[Members] = fClamp(float( Mid(tmpStr, 6)) * 0.07, 0, 7);
			else if ( Left( tmpStr, 9) ~= "accuracy=" )
				BotAcc[Members] = fClamp(5.0 - float( Mid(tmpStr, 9)) * 0.05, 0, 5);
			else if ( Left( tmpStr, 5) ~= "camp=" )
				BotCamp[Members] = fClamp( float( Mid(tmpStr, 5)), 0, 100);
			else
				Log( "Invalid argument in faction definition: Name="$testStr$", "$tmpStr );
		}
		BotClass[Members] = RegClasses[k];
		BotSkin[Members] = RegSkins[h];
		BotVoice[Members] = RegVoices[j];
		if ( inStr( BotFace[Members], ".") == -1 )
			BotFace[Members] = Left( BotSkin[Members], inStr(BotSkin[Members], ".") ) $ "." $ BotFace[Members];

		++Members;
		GetNextIntDesc("FerBotz.Botz_FactionInfo",++i,testStr,testDesc);
	}

	if ( Members > 0 )
		return True;

	ErrorString = "No members found on faction "$FactionName;
	return False;
}


function GetTheOrders(out name TheOrders, out actor OrderObject, byte TeamNum)
{
	local TeamInfo MyTeam;
	local int TeamSize;

	MyTeam = FindTheTeam(TeamNum, TeamSize);

	if (Level.Game.IsA('TeamGamePlus'))
	{
		if (Level.Game.IsA('CTFGame'))
		{
			if (FRand() < 0.6)
				TheOrders = 'Attack';
			else if (FRand() < 0.9)
				TheOrders = 'Defend';
			else
				TheOrders = 'Freelance';
		}
	}
}

function TeamInfo FindTheTeam(byte TeamIndex, out int Size)
{
	local TeamInfo T;

	ForEach AllActors(class'TeamInfo', T)
		if (T.TeamIndex == TeamIndex)
			return T;

	return None;
}


static final function string RemoveText( string Text, string Replace)
{
	local int i;
	local string Input;
		
	Input = Text;
	Text = "";
	i = InStr(Input, Replace);
	while(i != -1)
	{	
		Text = Text $ Left(Input, i);
		Input = Mid(Input, i + Len(Replace));	
		i = InStr(Input, Replace);
	}
	return Text $ Input;
}

defaultproperties
{
	SkillMult=1.000000
}