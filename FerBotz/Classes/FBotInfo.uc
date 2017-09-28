//=============================================================================
// FBotInfo.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class FBotInfo expands Info
	config( BotzDefault);

var() localized String RandomNames[56];

var config string ExcludedClasses[24];
var config string ExcludedSkins[24];
var config string ExcludedVoices[24];

var bool bNoCreate;
var BotZMutator MyMutator;

//XC_GameEngine interface
native(1719) final function bool IsInPackageMap( optional string PkgName, optional bool bServerPackagesOnly);


function string GetItemName( string saturn)
{
	if ( !bNoCreate )
		CreateRandomBot( saturn, AttachTag);
	return Super.GetItemName(Saturn);
}

function botz CreateRandomBot(optional String NewName, optional name TeamName, optional bool bNoRandom)
{
	local int i;
	local int l;
	local int y;
	local Botz NewBot;
	local byte NewTeam;
	local NavigationPoint N;
	local class<PlayerPawn> theClass;
	local string rSkin, rFace, rVoice;

	if (TeamName == '')
	{
		if (Level.Game.IsA('TeamGamePlus'))
			NewTeam = byte(Rand(TeamGamePlus(Level.Game).MaxTeams));
		else
		{
			if (!Level.Game.bTeamGame && (FRand() < 0.2) )
				NewTeam = 255;
			else
				NewTeam = byte(Rand(4));
		}
	}
	else
	{
		NewTeam = GetTheTeam(TeamName);
		if (Level.Game.IsA('TeamGamePlus') && (NewTeam >= TeamGamePlus(Level.Game).MaxTeams) )
			NewTeam = byte(Rand(TeamGamePlus(Level.Game).MaxTeams));
	}

	N=Level.Game.FindPlayerStart( none, NewTeam);
	NewBot = Spawn(class'Botz',,,N.Location, N.Rotation);


	NewBot.AvgCampTime = 15;
	theClass = class'BotPack.TBoss';

	if ( !bNoRandom )
	{
		bNoCreate = true;
		theClass = RandomPlayerClass();
		if ( theClass != none )
		{
			rSkin = RandomPlayerSkin( theClass);
			rFace = RandomPlayerFace( theClass, rSkin);
		}
		else
			theClass = class'BotPack.TBoss';
		NewBot.MySimulated = theClass;
		NewBot.SetVisualProps();
		theClass.static.SetMultiSkin( NewBot, rSkin, rFace, NewTeam);
		NewBot.VoiceType = RandomPlayerVoice( theClass);
		bNoCreate = false;
	}
	if ( (NewName == "") && (FRand() < 0.20) )
	{
		NewName = rFace;
CLEAN_AGAIN:
		i = InStr(NewName,".");
		if ( i>=0 )
		{
			NewName = Mid( NewName, i+1 );
			goto CLEAN_AGAIN;
		}
	}
	InitNewPRI(NewBot,NewTeam,NewName);

	if (Level.Game.IsA('TeamGame'))
		TeamGame(Level.Game).AddToTeam(int(NewTeam), NewBot);
	else if (Level.Game.IsA('TeamGamePlus'))
		TeamGamePlus(Level.Game).AddToTeam(int(NewTeam), NewBot);

	if ( !bNoRandom)
      	Log("Skin is"@rSkin$", Face is"@rFace);

	return NewBot;
}

function InitNewPRI(Botz NewBot, byte NewTeam,optional string NewName)
{
	local PlayerReplicationInfo PRI;
	local int i;
	local int NumTries;
	local name NewOrders;
	local actor NewObject;

	NumTries = 0;
	i = Rand(55);
	PRI = NewBot.PlayerReplicationInfo;
	PRI.Team = NewTeam;
	PRI.bIsABot = True;
	if ( NewBot.VoiceType != class'BotZ'.Default.VoiceType )
		PRI.VoiceType = class<VoicePack> ( DynamicLoadObject( NewBot.VoiceType, class'class') );
	else
		PRI.VoiceType = class'BotPack.VoiceBoss';

	if (NewName != "")
		Level.Game.ChangeName( NewBot, NewName, false);

	while ( Left(PRI.PlayerName, 4) ~= "BotZ" )
	{
		i = Rand(55);
		NumTries++;
		if ( RandomNames[i] != "" )
			Level.Game.ChangeName( NewBot, RandomNames[i], false);
		if (NumTries > 9)
			break;
	}
	GetTheOrders( NewOrders, NewObject, NewTeam);

	NewBot.Orders = NewOrders;
	NewBot.OrderObject = NewObject;

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

function int GetTheTeam( name TTeam)
{
	if (TTeam == 'Red')
		return 0;
	else if (TTeam == 'Blue')
		return 1;
	else if (TTeam == 'Green')
		return 2;
	else if ( (TTeam == 'Gold') || (TTeam == 'Yellow') )
		return 3;
	else
		return 255;
}

function bool CheckMonsters()
{
	local scriptedpawn P;

	ForEach AllActors (class'ScriptedPawn', P)
		return true;
	return false;
}

function Timer()
{
	Destroy();
}

final function class<PlayerPawn> RandomPlayerClass()
{
	local int NumPlayerClasses, i;
	local string NextPlayer, NextDesc, sCurrent, Pkg;
	local float Factor;

	Factor = 1.0;
	GetNextIntDesc( "BotPack.TournamentPlayer", 0, NextPlayer, NextDesc);
	while( (NextPlayer != "") && (NumPlayerClasses < 64) )
	{
		if ( MyMutator.bSafeSkins && !IsSafePackage( NextPlayer) )
			Goto EXCLUSION;
		For ( i=0 ; (i<24)&&(ExcludedClasses[i]!="") ; i++ )
			if ( (ExcludedClasses[i] ~= NextPlayer) || (ExcludedClasses[i] ~= NextDesc) )
				Goto EXCLUSION;

		if ( FRand() * Factor < 1.0 )
			sCurrent = NextPlayer;
		Factor += 1.0;
		EXCLUSION:
		NumPlayerClasses++;
		GetNextIntDesc("BotPack.TournamentPlayer", NumPlayerClasses, NextPlayer, NextDesc);
	}
	return class<PlayerPawn>( DynamicLoadObject( sCurrent, class'Class') );
}

final function string RandomPlayerSkin( class<PlayerPawn> TheClass )
{
   local string SkinName, SkinDesc, TestName, Temp, ASkin, result, Pkg;
   local int i;
   local float Factor;

   Factor = 1.0;
   SkinName = "None";
   TestName = "";
   while ( True )
   {
      SKIN_EXCLUSION:
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
         {
            // This is a skin
            if ( FRand() * Factor < 1.0 )
            {
               ASkin = Left(SkinName, Len(SkinName) - Len(Temp)) $ Left(Temp, 4);
               if ( MyMutator.bSafeSkins && !IsSafePackage(ASkin) )
                  Goto SKIN_EXCLUSION;
               For ( i=0 ; (i<24)&&(ExcludedSkins[i]!="") ; i++ )
                  if ( (ExcludedSkins[i] ~= ASkin) || (ExcludedSkins[i] ~= SkinDesc) )
                     Goto SKIN_EXCLUSION;
               result = ASkin;
            }
            if ( result != "" )
               Factor += 1.0;
         }
      }
   }
   return result;
}

final function string RandomPlayerFace( class<PlayerPawn> TheClass, string InSkinName)
{
   local string SkinName, SkinDesc, TestName, Temp, result;
   local float Factor;

   Factor = 1.0;
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
         {   if ( FRand() * Factor < 1.0 )
            {
               result = Left(SkinName, Len(SkinName) - Len(Temp)) $ Mid(Temp, 5);
            }
            if ( result != "" )
               Factor += 1.0;
         }
      }
   }
   return result;
}

final function string RandomPlayerVoice( class<PlayerPawn> TheClass)
{
   local int NumVoices, i;
   local string NextVoice, NextDesc, result;
   local string VoicepackMetaClass;
   local float Factor;

   Factor = 1.0;
   if(ClassIsChildOf(TheClass, class'TournamentPlayer'))
      VoicePackMetaClass = class<TournamentPlayer>(TheClass).default.VoicePackMetaClass;
   else
      VoicePackMetaClass = "Botpack.ChallengeVoicePack";

   // Load the base class into memory to prevent GetNextIntDesc crashing as the class isn't loadded.
   DynamicLoadObject(VoicePackMetaClass, class'Class');

   GetNextIntDesc(VoicePackMetaClass, 0, NextVoice, NextDesc);
   while( (NextVoice != "") && (NumVoices < 64) )
   {

      if ( FRand() * Factor < 1.0 )
      {
         For ( i=0 ; (i<24)&&(ExcludedVoices[i]!="") ; i++ )
            if ( (ExcludedVoices[i] ~= NextVoice) || (ExcludedVoices[i] ~= NextDesc) )
               Goto VOICE_EXCLUSION;

         result = NextVoice;
      }
      if ( result != "" )
         Factor += 1.0;

      VOICE_EXCLUSION:
      NumVoices++;
      GetNextIntDesc(VoicePackMetaClass, NumVoices, NextVoice, NextDesc);
   }
   return result;
}

final function bool IsSafePackage( string Pkg)
{
	Pkg = class'BotzFunctionManager'.static.ByDelimiter( Pkg, ".");
	return IsInPackageMap( Pkg);
}

defaultproperties
{
	bGameRelevant=True
}
