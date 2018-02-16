class XC_Engine_TGP expands TeamGamePlus
	abstract;
	
struct PlayerStartScore
{
	var PlayerStart Start;
	var float Score;
	var bool bOccupied;
};

native(640) static final function int Array_Length_PS( out array<PlayerStartScore> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_PS( out array<PlayerStartScore> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_PS( out array<PlayerStartScore> Ar, int Offset, optional int Count );
native(3540) final iterator function PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional Pawn StartAt);
native(3541) final iterator function NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint P, optional float Distance, optional vector VOrigin, optional bool bVisible);
native(3552) final iterator function CollidingActors( class<actor> BaseClass, out actor Actor, float Radius, optional vector Loc);
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );

static final function bool InCylinder( vector V, float Radius, float Height)
{
	return (Abs(V.Z) < Height) && (class'XC_CoreStatics'.static.HSize(V) < Radius);
}


//****************************************************
//Optimize start finding and better rank player starts
function NavigationPoint FindPlayerStart(Pawn Player, optional byte InTeam, optional string incomingName)
{
	local Array<PlayerStartScore> PS;
	local PlayerStartScore Buffer;
	local vector Delta;
	
	local byte Team;
	local PlayerStart Dest;
	local Pawn OtherPlayer;
	local int i, Num, uNum; //Unoccupied?
	local Teleporter Tel;
	local NavigationPoint LastPlayerStartSpot;

	if ( bStartMatch && (TournamentPlayer(Player) != None) && (Level.NetMode == NM_Standalone) && (TournamentPlayer(Player).StartSpot != None) )
		return TournamentPlayer(Player).StartSpot;

	if( incomingName!="" && (Level.NetMode != NM_DedicatedServer) )
		ForEach AllActors( class'Teleporter', Tel )
			if( string(Tel.Tag)~=incomingName )
				return Tel;
				
	if ( (Player != None) && (Player.PlayerReplicationInfo != None) )
		Team = Player.PlayerReplicationInfo.Team;
	else
		Team = InTeam;
	if ( Team == 255 )
		Team = 0;

		
	//Choose candidates
	ForEach NavigationActors( class'PlayerStart', Dest)
		if ( Dest.bEnabled && (!bSpawnInTeamArea || (Team == Dest.TeamNumber)) && Array_Insert_PS( PS, Num) )
			PS[Num++].Start = Dest;
	if( Num == 0 )
	{
		log("Didn't find any player starts in list for team"@Team@"!!!"); 
		ForEach AllActors( class 'PlayerStart', Dest )
			if ( Array_Insert_PS( PS, Num) )
				PS[Num++].Start = Dest;
		if ( Num == 0 )
			return None;
	}

	Delta.X = class'TournamentPlayer'.default.CollisionRadius;
	Delta.Y = class'TournamentPlayer'.default.CollisionHeight;
	if ( Player != None )
	{
		if ( Player.IsA('TournamentPlayer') && (TournamentPlayer(Player).StartSpot != None) )
			LastPlayerStartSpot = TournamentPlayer(Player).StartSpot;
		Delta.X = Player.CollisionRadius;
		Delta.Y = Player.CollisionHeight;
	}
	Delta.Z = class'XC_CoreStatics'.static.HSize(Delta) * 2; //Lookup size, precalculated

	//Assign scores
	For ( i=0 ; i<Num ; i++ )
	{
		Dest = PS[i].Start;
		if ( Dest == LastStartSpot || Dest == LastPlayerStartSpot)
			PS[i].Score = -6000.0;
		else
			PS[i].Score = 4000.0 * FRand();
		//Find possible occupants
		ForEach CollidingActors( class'Pawn', OtherPlayer, Delta.Z, Dest.Location)
		{
			if ( !OtherPlayer.bBlockPlayers && !OtherPlayer.bBlockActors && OtherPlayer.Health <= 0 )
				continue;
			if ( OtherPlayer.PlayerReplicationInfo != None && OtherPlayer.PlayerReplicationInfo.Team != Team ) //Allow telefragging enemy players
				continue;
			if ( InCylinder( OtherPlayer.Location-Dest.Location, OtherPlayer.CollisionRadius+Delta.X, OtherPlayer.CollisionHeight+Delta.Y) )
			{
				PS[i].bOccupied = true;
				uNum++;
				break;
			}
		}
	}

	//We have unoccupied start spots, flush out occupied ones
	if ( uNum < Num ) 
	{
		For ( i=Num-1 ; i>=0 ; i-- )
			if ( PS[i].bOccupied )
				Array_Remove_PS( PS, i);
		Num = Array_Length_PS( PS);
	}
	
	//Assess candidates
	ForEach PawnActors ( class'Pawn', OtherPlayer,,,true)
		if ( OtherPlayer.bIsPlayer && (OtherPlayer.Health > 0) && !OtherPlayer.IsA('Spectator') )
			for ( i=0; i<Num; i++ )
			{
				Dest = PS[i].Start;
				if ( OtherPlayer.Region.Zone == Dest.Region.Zone )
				{
					Delta = OtherPlayer.Location - Dest.Location;
					if ( (OtherPlayer.PlayerReplicationInfo.Team != Team) && (VSize(Delta) < 2000) && FastTrace( Dest.Location, OtherPlayer.Location) )
						PS[i].Score -= (11500.0 - VSize(Delta) );
					else
						PS[i].Score -= 1500.0;
				}
			}

	Buffer = PS[0];
	for ( i=1 ; i<Num ; i++ )
		if (PS[i].Score > Buffer.Score)
			Buffer = PS[i];
	Array_Length_PS( PS, 0);
	LastStartSpot = Buffer.Start;
	return LastStartSpot;
}


//******************************************************************
// Fix massive log spams and possible crash on maps full of monsters
function AddToTeam( int num, Pawn Other )
{
	local teaminfo aTeam;
	local bool bSuccess;
	local string SkinName, FaceName;
	local PlayerReplicationInfo PRI;

	if ( Other == None || Other.PlayerReplicationInfo == None )
		return;

	aTeam = Teams[num];

	aTeam.Size++;
	Other.PlayerReplicationInfo.Team = num;
	Other.PlayerReplicationInfo.TeamName = aTeam.TeamName;
	if (LocalLog != None)		LocalLog.LogTeamChange(Other);
	if (WorldLog != None)		WorldLog.LogTeamChange(Other);
	if ( Other.IsA('PlayerPawn') )
	{
		Other.PlayerReplicationInfo.TeamID = 0;
		PlayerPawn(Other).ClientChangeTeam(Other.PlayerReplicationInfo.Team);
	}
	else
		Other.PlayerReplicationInfo.TeamID = 1;

	while ( !bSuccess )
	{
		bSuccess = true;
		ForEach DynamicActors( class'PlayerReplicationInfo', PRI)
			if ( (PRI.Team == Other.PlayerReplicationInfo.Team) && (PRI != Other.PlayerReplicationInfo) && (PRI.TeamID == Other.PlayerReplicationInfo.TeamID) )
			{
				bSuccess = false;
				PRI.TeamID++; //Magic trick to reduce 'while' loop count to 2!!
			}
	}
	BroadcastLocalizedMessage( DMMessageClass, 3, Other.PlayerReplicationInfo, None, aTeam );
	Other.static.GetMultiSkin(Other, SkinName, FaceName); //LINUX CRASH, CALLING THESE TWO STATIC FUNCTION CAUSES A DOUBLE 'MALLOC->FREE'
	Other.static.SetMultiSkin(Other, SkinName, FaceName, num);

	if ( bBalanceTeams && !bRatedGame )
		ReBalance();
}