//=============================================================================
// XC_UdpServerQuery.
//=============================================================================
class XC_UdpServerQuery expands UdpServerQuery;

native(3540) final iterator function PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional Pawn StartAt);

//*****************************************
// Validate crashfix
function string Validate( string ValidationString, string GameName )
{
	if ( Len(ValidationString) == 6 )
		return Validate_Org( ValidationString, GameName);
	return "";
}

final function string Validate_Org( string ValidationString, string GameName );





//*****************************************
// Send data for each player
function bool SendPlayers(IpAddr Addr, int QueryNum, out int PacketNum, int bFinalPacket)
{
	local Pawn P;
	local int i, SendCount;
	local bool Result, SendResult;
	
	Result = false;

	ForEach PawnActors( class'Pawn', P,,,true)
		if ( !IgnorePawn(P) )
			SendCount++;

	ForEach PawnActors( class'Pawn', P,,,true)
		if ( !IgnorePawn(P) )
		{
			if ( i==SendCount-1 && bFinalPacket==1 )
				SendResult = SendQueryPacket(Addr, GetPawn(P, i), QueryNum, PacketNum, 1);
			else
				SendResult = SendQueryPacket(Addr, GetPawn(P, i), QueryNum, PacketNum, 0);
			Result = SendResult || Result;
			i++;
		}

	return Result;
}

final function bool IgnorePawn( Pawn P)
{
	return P == None || P.PlayerReplicationInfo.PlayerName ~= "Player" || (PlayerPawn(P) != None && P.PlayerReplicationInfo.bIsSpectator && PlayerPawn(P).bAdmin);
}

// Return a string of information on a pawn.
final function string GetPawn( Pawn P, int PlayerNum )
{
	local string ResultSet;
	local string SkinName, FaceName;
	local PlayerReplicationInfo PRI;
	local PlayerPawn PP;

	PP = PlayerPawn(P);
	PRI = P.PlayerReplicationInfo;

	// Name
	ResultSet = "\\player_"$PlayerNum$"\\"$PRI.PlayerName;

	// Frags
	ResultSet = ResultSet$"\\frags_"$PlayerNum$"\\"$int(PRI.Score);

	// Ping
	if ( PP != None )
		ResultSet = ResultSet$"\\ping_"$PlayerNum$"\\"$PP.ConsoleCommand("GETPING");
	else
		ResultSet = ResultSet$"\\ping_"$PlayerNum$"\\Bot";


	// Team
	ResultSet = ResultSet$"\\team_"$PlayerNum$"\\"$PRI.Team;

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
	if( PRI.bIsABot )
		ResultSet = ResultSet$"\\ngsecret_"$PlayerNum$"\\bot";
	else if( PP != None && PP.ReceivedSecretChecksum )
		ResultSet = ResultSet$"\\ngsecret_"$PlayerNum$"\\true";
	else
		ResultSet = ResultSet$"\\ngsecret_"$PlayerNum$"\\false";
	return ResultSet;
}

defaultproperties
{
}
