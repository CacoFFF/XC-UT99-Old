//=============================================================================
// Botz_UdpServerQuery.
//
// El proposito de utilizar un query personalizado es el de soportar los
// jugadores emulados por el FerBotz_cl, ademas de incrementar la funcionalidad
// de este informando sobre presencia de botz y bots
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_UdpServerQuery expands UdpServerQuery;

// Send data for each player
function bool SendPlayers(IpAddr Addr, int QueryNum, out int PacketNum, int bFinalPacket)
{
	local Pawn P, FinalP;
	local int i, iType;
	local bool Result, SendResult;
	
	Result = false;

//	P = Level.PawnList;

	//Pick latest spawned player
	if ( bFinalPacket == 1 )
	{
		For ( P=Level.PawnList ; P!=none ; P=P.NextPawn )
		{
			if ( PlayerType(P) > 0 )
			{
				FinalP = P;
				break;
			}
		}
	}
	
	ForEach AllActors (class'Pawn', P)
	{
		iType = PlayerType(P);
		if ( iType == 0 ) //Small opt for monsterhunt
			continue;
		
		if ( iType == 1 )
			SendResult = SendQueryPacket(Addr, GetPlayer(PlayerPawn(P), i), QueryNum, PacketNum, int(P==FinalP) );
		else if ( iType == 2 )
			Sendresult = SendQueryPacket(Addr, GetBot(Bot(P), i), QueryNum, PacketNum, int(P==FinalP) );
		else if ( iType == 3 )
			Sendresult = SendQueryPacket(Addr, GetBotz(Botz(P), i), QueryNum, PacketNum, int(P==FinalP) );
		else
			continue;

		Result = SendResult || Result;
		i++;
	}

/*	while( i < Level.Game.NumPlayers )
	{
		if (P.IsA('PlayerPawn'))
		{
			if( i==Level.Game.NumPlayers-1 && bFinalPacket==1)
				SendResult = SendQueryPacket(Addr, GetPlayer(PlayerPawn(P), i), QueryNum, PacketNum, 1);
			else
				SendResult = SendQueryPacket(Addr, GetPlayer(PlayerPawn(P), i), QueryNum, PacketNum, 0);
			Result = SendResult || Result;
			i++;
		}
		P = P.nextPawn;
	}*/

	return Result;
}


// Return a string of information on a botz.
function string GetBotz( Botz P, int PlayerNum )
{
	local string ResultSet;
	local string SkinName, FaceName;

	// Name
	ResultSet = "\\player_"$PlayerNum$"\\[BotZ]"$P.PlayerReplicationInfo.PlayerName;

	// Frags
	ResultSet = ResultSet$"\\frags_"$PlayerNum$"\\"$int(P.PlayerReplicationInfo.Score);

	// Ping
	ResultSet = ResultSet$"\\ping_"$PlayerNum$"\\0";

	// Team
	ResultSet = ResultSet$"\\team_"$PlayerNum$"\\"$P.PlayerReplicationInfo.Team;

	// Class
	ResultSet = ResultSet$"\\mesh_"$PlayerNum$"\\"$P.MySimulated.Default.Menuname;

	// Skin
	if(P.Skin == None)
	{
		P.static.GetMultiSkin(P, SkinName, FaceName);
		ResultSet = ResultSet$"\\skin_"$PlayerNum$"\\"$SkinName;
		ResultSet = ResultSet$"\\face_"$PlayerNum$"\\"$FaceName;
	}
	else
	{
		ResultSet = ResultSet$"\\skin_"$PlayerNum$"\\"$string(P.Skin);
		ResultSet = ResultSet$"\\face_"$PlayerNum$"\\None";
	}
	ResultSet = ResultSet$"\\ngsecret_"$PlayerNum$"\\bot";
	return ResultSet;
}

// Return a string of information on a bot.
function string GetBot( Bot P, int PlayerNum )
{
	local string ResultSet;
	local string SkinName, FaceName;

	// Name
	ResultSet = "\\player_"$PlayerNum$"\\[Bot]"$P.PlayerReplicationInfo.PlayerName;

	// Frags
	ResultSet = ResultSet$"\\frags_"$PlayerNum$"\\"$int(P.PlayerReplicationInfo.Score);

	// Ping
	ResultSet = ResultSet$"\\ping_"$PlayerNum$"\\0";

	// Team
	ResultSet = ResultSet$"\\team_"$PlayerNum$"\\"$P.PlayerReplicationInfo.Team;

	// Class
	ResultSet = ResultSet$"\\mesh_"$PlayerNum$"\\"$P.Menuname;

	// Skin
	if(P.Skin == None)
	{
		P.static.GetMultiSkin(P, SkinName, FaceName);
		ResultSet = ResultSet$"\\skin_"$PlayerNum$"\\"$SkinName;
		ResultSet = ResultSet$"\\face_"$PlayerNum$"\\"$FaceName;
	}
	else
	{
		ResultSet = ResultSet$"\\skin_"$PlayerNum$"\\"$string(P.Skin);
		ResultSet = ResultSet$"\\face_"$PlayerNum$"\\None";
	}
	ResultSet = ResultSet$"\\ngsecret_"$PlayerNum$"\\bot";
	return ResultSet;
}

function int PlayerType( pawn P)
{
	if ( P.PlayerReplicationInfo == none ) //Monster or other pawn
		return 0;
	if ( (P.PlayerReplicationInfo.PlayerID <= 0) && (P.PlayerReplicationInfo.bIsSpectator) ) //This is an admin tool or a dummy PRI
		return 0;
	if ( P.IsA('PlayerPawn') )
		return 1;
	if ( P.IsA('Bot') )
		return 2;
	if ( P.IsA('Botz') )
		return 3;
	return 0;
}