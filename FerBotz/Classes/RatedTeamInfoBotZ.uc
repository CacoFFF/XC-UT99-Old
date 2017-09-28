//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org

class RatedTeamInfoBotZ expands RatedTeamInfo;

//#exec OBJ LOAD File=..\System\Fernando.u

var BotzMutator TheMutator;
var() string		BotVoice[8];
var() string		SimulatedPlayer[8];
var() string		OverrideVoice;

function Individualize(bot NewBot, int n, int NumBots, bool bEnemy, float BaseDifficulty)
{
	local Botz NewBotZ;
	local MasterGasterFer MGF;
	local int aTeam;
	local pawn P;

	if ( (n<0) || (n>7) )
	{
		log("Accessed RatedTeamInfo out of range!");
		return;
	}
	// Set Bot Team
	if ( bEnemy )
	{
		if (DeathMatchPlus(Level.Game).RatedPlayer.PlayerReplicationInfo.Team == 1)
			aTeam = 0;
		else if (DeathMatchPlus(Level.Game).RatedPlayer.PlayerReplicationInfo.Team == 0)
			aTeam = 1;
	} else {
		aTeam = DeathMatchPlus(Level.Game).RatedPlayer.PlayerReplicationInfo.Team;
	}


	NewBotZ = Spawn(class'Botz',,,Level.Game.FindPlayerStart( none, aTeam).Location);
	NewBotZ.PlayerReplicationInfo.PlayerName = BotNames[n];
	NewBotZ.Skill = BotSkills[n];
	NewBotZ.Punteria = BotAccuracy[n];
	NewBotZ.CampChance = Camping[n];
	NewBotZ.MySimulated = class<PlayerPawn>( DynamicLoadObject( SimulatedPlayer[n], class'Class') );
	NewBotZ.SetVisualProps();
	NewBotZ.PlayerReplicationInfo.bIsABot = True;
	NewBotZ.PlayerReplicationInfo.PlayerID = NewBot.PlayerReplicationInfo.PlayerID;
	NewBotZ.PlayerReplicationInfo.Team = aTeam;
	NewBotZ.PlayerReplicationInfo.TeamID = 1 + n;
	NewBotZ.AvgCampTime = 5 + (Camping[n] * 15.0);

	if ( NewBotZ.MySimulated != none )
		NewBotZ.MySimulated.Static.SetMultiSkin( NewBotZ, BotSkins[n], BotFaces[n], NewBotZ.PlayerReplicationInfo.Team);
	else
		NewBotZ.Static.SetMultiSkin(NewBotZ, BotSkins[n], BotFaces[n], NewBotZ.PlayerReplicationInfo.Team);
	if ( (FavoriteWeapon[n] != "") && (FavoriteWeapon[n] != "None") )
		NewBotZ.ArmaFavorita = class<Weapon>(DynamicLoadObject(FavoriteWeapon[n],class'Class'));

//	NewBot.CombatStyle = NewBot.Default.CombatStyle + 0.7 * CombatStyle[n];
//	NewBot.BaseAggressiveness = 0.5 * (NewBot.Default.Aggressiveness + NewBot.CombatStyle);
//	NewBot.bJumpy = ( BotJumpy[n] != 0 );

	if ( BotVoice[n] != "" )
		NewBotZ.VoiceType = BotVoice[n];
	else if ( NewBotZ.MySimulated != none )
		NewBotZ.VoiceType = NewBotZ.MySimulated.Default.VoiceType;
	else
		NewBotZ.VoiceType = "BotPack.VoiceBoss";

	NewBotZ.PlayerReplicationInfo.VoiceType = class<VoicePack>(DynamicLoadObject(NewBotZ.VoiceType, class'Class'));

	NewBot.LifeSpan = 1;

	if ( (DeathMatchPlus(Level.Game).RatedPlayer != none) && (OverrideVoice != "") && !bEnemy )
		DeathMatchPlus(Level.Game).RatedPlayer.PlayerReplicationInfo.VoiceType = class<VoicePack>(DynamicLoadObject(OverrideVoice, class'Class'));

}



defaultproperties
{
     TeamName="Caco's elite"
     TeamSymbol=
     TeamBio="Caco's best, an elite squad performing assignments in different realms, the Tournament is no exception"
     BotNames(0)="Aegor"
     BotNames(1)="Gildor"
     BotNames(2)="Nargo"
     BotNames(3)="Trascolim"
     BotNames(4)="Negrovictor"
     BotNames(5)="Negroncho"
     BotNames(6)="Tamerlane"
     BotNames(7)=""
     BotClassifications(0)="Elite Balance"
     BotClassifications(1)="Elite Perfection"
     BotClassifications(2)="Elite Power"
     BotClassifications(3)="Elite Skill"
     BotClassifications(4)="Elite Support"
     BotClassifications(5)="Elite Support"
     BotClassifications(6)="Elite Recruit"
     BotClassifications(7)="Elite Recruit"
     BotClasses(0)="BotPack.TBossBot"
     BotClasses(1)="BotPack.TBossBot"
     BotClasses(2)="SkeletalChars.WarBossBot"
     BotClasses(3)="SkeletalChars.XanMk2Bot"
     BotClasses(4)="BotPack.TMale2Bot"
     BotClasses(5)="BotPack.TMale2Bot"
     BotClasses(6)="BotPack.TMale2Bot"
     BotClasses(7)="BotPack.TMale2Bot"
     SimulatedPlayer(0)="Fernando.TFerBoss"
     SimulatedPlayer(1)="BotPack.TBoss"
     SimulatedPlayer(2)="SkeletalChars.WarBoss"
     SimulatedPlayer(3)="SkeletalChars.XanMk2"
     SimulatedPlayer(4)="BotPack.TMale2"
     SimulatedPlayer(5)="BotPack.TMale2"
     SimulatedPlayer(6)="BotPack.TMale2"
     SimulatedPlayer(7)="BotPack.TMale2"
     BotSkins(0)="BossSkinsFer2.Bozz"
     BotSkins(1)="BossSkinsPlat.Metl"
     BotSkins(2)=""
     BotSkins(3)=""
     BotSkins(4)="SoldierSkins_SL.swat"
     BotSkins(5)="Soldier_nOsClanV2.acid"
     BotSkins(6)="SoldierBAHv2.babw"
     BotSkins(7)=""
     BotVoice(0)="BSodPackage.VoiceBSod"
     BotVoice(1)="Botpack.VoiceMaleOne"
     BotVoice(2)="multimesh.skaarjvoice"
     BotVoice(3)="Botpack.VoiceMaleTwo"
     FavoriteWeapon(0)="BotPack.minigun2"
     FavoriteWeapon(1)="BotPack.shockrifle"
     FavoriteWeapon(2)="BotPack.ut_flakcannon"
     FavoriteWeapon(3)="BotPack.pulsegun"
     FavoriteWeapon(4)="BotPack.sniperrifle"
     FavoriteWeapon(6)="BotPack.sniperrifle"
     BotAccuracy(0)=1
     BotAccuracy(1)=0
     BotAccuracy(2)=2
     BotAccuracy(3)=2.5
     BotAccuracy(4)=1
     BotAccuracy(5)=4
     BotAccuracy(5)=0.3
     BotSkills(0)=6
     BotSkills(1)=5
     BotSkills(2)=6.5
     BotSkills(3)=7
     BotSkills(4)=2
     BotSkills(5)=4
     BotSkills(6)=5
     BotFaces(0)=""
     BotFaces(1)=""
     BotFaces(2)=""
     BotFaces(3)=""
     BotFaces(4)="SoldierSkins_SL.swat"
     BotFaces(5)="Soldier_nOsClanV2.toxic"
     BotFaces(6)="SoldierBAHv2.luc"
     BotFaces(7)=""
     BotBio(0)="Squad founder, he's the one who put together the team, the definition of an all around fighter."
     BotBio(1)="Squad's public face, Gildor's the one to negotiate the team's missions and fees, best at long ranges."
     BotBio(2)="Squad's powerhouse, becomes a pillar at the absence of Aegor, leading back to front style assaults."
     BotBio(3)="Squad scout and recoinassance first choice, performs most of the behind enemy lines assignments when he's not in the midst of a battle."
     BotBio(4)="Support sniper."
     BotBio(5)="Support attacker."
     BotBio(6)="Hired for specific matches due to being serious marksman, can ruin the enemy's night anytime."
     BotBio(7)=""
     MaleClass=Class'botpack.TFerboss'
     MaleSkin="BossSkinsFer2.bozz"
     FemaleClass=Class'botpack.TFerboss'
     FemaleSkin="BossSkinsGold.bril"
     OverrideVoice="BSodPackage.VoiceBSod"
}
