class XC_Engine_CVPack expands ChallengeVoicePack
	abstract;
	
native(3540) final iterator function PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional Pawn StartAt);

//static APlayerReplicationInfo* NearestFriendlySightPawn( APawn* PL, FLOAT MaxCone=512.f)
final function PlayerReplicationInfo NearestFriendlySightPawn( PlayerPawn PL)
{
	local Pawn P, Best;
	local vector X, Y, Z, Delta;
	local float Dist, BestDist;
	
	GetAxes( PL.ViewRotation, X, Y, Z);
	BestDist = 99999;
	ForEach PawnActors (class'Pawn', P,,, true)
	{
		if ( (P.PlayerReplicationInfo.Team == PL.PlayerReplicationInfo.Team) && (P != PL) )
		{
			Delta = P.Location - PL.Location;
			Dist = Delta dot X;
			if ( Dist < 0 )
				continue;
			Dist += Square( Delta dot (Y+Z));
			if ( Dist < BestDist )
			{
				BestDist = Dist;
				Best = P;
			}
		}
	}
	if ( Best != none )
		return Best.PlayerReplicationInfo;
}


function PlayerSpeech( int Type, int Index, int Callsign )
{
	local name SendMode;
	local PlayerReplicationInfo Recipient;
	local Pawn P;
	local PlayerPawn PL;
	local bool bTeamGame;

	PL = PlayerPawn(Owner);
	if ( (PL == none) || (PL.PlayerReplicationInfo == none) || (Type < 0) || (Type > 4) )
		return;
	bTeamGame = (PL.GameReplicationInfo != none) && PL.GameReplicationInfo.bTeamGame;
	
	SendMode = 'TEAM';
	switch (Type)
	{
		case 0:			// Acknowledgements
			if ( Callsign == -1 )
				SendMode = 'GLOBAL';
			break;
		case 1:			// Friendly Fire
			break;
		case 2:			// Orders
			if (Index == 2)
			{
				if (Level.Game.IsA('CTFGame'))
					Index = 10;
				if (Level.Game.IsA('Domination') || Level.Game.IsA('MonsterHunt') )
					Index = 11;
			}
			if ( bTeamGame && (Callsign >= 0) )
			{
				ForEach PawnActors (class'Pawn', P,,, true )
					if ( (P.PlayerReplicationInfo.TeamId == Callsign) && (P.PlayerReplicationInfo.Team == PL.PlayerReplicationInfo.Team) )
					{
						Recipient = P.PlayerReplicationInfo;
						break;
					}
			}
			break;
		case 3:			// Taunts
			SendMode = 'GLOBAL';	// Send to all teams.
			break;
		case 4:			// Other
			if ( Index == 10 || Index == 7 || Index == 15 || Index == 3 )
				Recipient = NearestFriendlySightPawn( PL);
			else if ( Index == 5 && Callsign == -1 ) //MAN DOWN! Taunt
				SendMode = 'GLOBAL';
			else if ( InStr(Caps(OtherString[Index]),"GOOD GAME") != -1 ) //Some voices have this
				SendMode = 'GLOBAL';
			break;
	}
	if ( !bTeamGame )
		SendMode = 'GLOBAL';  // Not a team game? Send to everyone.

	PL.SendVoiceMessage( PL.PlayerReplicationInfo, Recipient, SendType[Type], Index, SendMode );
}
