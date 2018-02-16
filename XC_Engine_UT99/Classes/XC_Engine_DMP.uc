class XC_Engine_DMP expands DeathMatchPlus
	abstract;
	



var int NC_Counter;
var float NC_TimeStamp;

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

static final function bool InCylinder( vector V, float Radius, float Height)
{
	return (Abs(V.Z) < Height) && (class'XC_CoreStatics'.static.HSize(V) < Radius);
}



//**************
//Log spam fixes
function EndSpree(Pawn Killer, Pawn Other)
{
	local TournamentPlayer T;
	local PlayerReplicationInfo KillerPRI;

	if ( !Other.bIsPlayer || Other.PlayerReplicationInfo == None )
		return;
	if ( Killer != None && Killer.bIsPlayer )
		KillerPRI = Killer.PlayerReplicationInfo;
		
	ForEach PawnActors ( class'TournamentPlayer', T)
		T.EndSpree( KillerPRI, Other.PlayerReplicationInfo);
}
function ScoreKill(pawn Killer, pawn Other)
{
	Super(GameInfo).ScoreKill(Killer, Other);

	if ( bAltScoring && (Killer != Other) && (killer != None) && (Other.PlayerReplicationInfo != None) )
		Other.PlayerReplicationInfo.Score -= 1;
}

//************************************************
//Prevent name change bandwidth exploit/server lag
final function bool NC_CanBroadcast()
{
	if ( class'XC_Engine_DMP'.default.NC_TimeStamp != Level.TimeSeconds )
	{
		class'XC_Engine_DMP'.default.NC_TimeStamp = Level.TimeSeconds;
		class'XC_Engine_DMP'.default.NC_Counter = 0;
	}
	return ( class'XC_Engine_DMP'.default.NC_Counter++ < 3 ); //Spam up to 3 messages per tick
}

function ChangeName(Pawn Other, string S, bool bNameChange)
{
	local pawn APlayer;

	if ( S == "" || Other == None || Other.PlayerReplicationInfo == None )
		return;

	S = left(S,24);
	if (Other.PlayerReplicationInfo.PlayerName~=S)
		return;
		
	ForEach PawnActors ( class'Pawn', APlayer,,, true)
		if ( APlayer.PlayerReplicationInfo.PlayerName ~= S )
		{
			if ( NC_CanBroadcast() )
				Other.ClientMessage(S$NoNameChange);
			return;
		}

	Other.PlayerReplicationInfo.OldName = Other.PlayerReplicationInfo.PlayerName;
	Other.PlayerReplicationInfo.PlayerName = S;
	if ( NC_CanBroadcast() )
	{
		if ( bNameChange && !Other.IsA('Spectator') )
			BroadcastLocalizedMessage( DMMessageClass, 2, Other.PlayerReplicationInfo );			

		if (LocalLog != None)
			LocalLog.LogNameChange(Other);
		if (WorldLog != None)
			WorldLog.LogNameChange(Other);
	}
}

//****************************************************
//Optimize start finding and better rank player starts
function NavigationPoint FindPlayerStart(Pawn Player, optional byte InTeam, optional string incomingName)
{
	local Array<PlayerStartScore> PS;
	local PlayerStartScore Buffer;
	local vector Delta;
	
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

	//Choose candidates
	ForEach NavigationActors( class'PlayerStart', Dest)
		if ( Dest.bEnabled && !Dest.Region.Zone.bWaterZone && Array_Insert_PS( PS, Num) )
			PS[Num++].Start = Dest;
	if( Num == 0 )
	{
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
			PS[i].Score = -10000.0;
		else
			PS[i].Score = 3000.0 * FRand();
		//Find possible occupants
		ForEach CollidingActors( class'Pawn', OtherPlayer, Delta.Z, Dest.Location)
		{
			if ( !OtherPlayer.bBlockPlayers && !OtherPlayer.bBlockActors && OtherPlayer.Health <= 0 )
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
					if ( VSize(Delta) < 2000 && FastTrace( Dest.Location, OtherPlayer.Location) )
						PS[i].Score -= (11500.0 - VSize(Delta) );
					else
						PS[i].Score -= 1500.0;
				}
				else if ( NumPlayers + NumBots == 2 )
					PS[i].Score += 2 * VSize(OtherPlayer.Location - Dest.Location) - 10000 * int(FastTrace( Dest.Location, OtherPlayer.Location));
			}

	Buffer = PS[0];
	for ( i=1 ; i<Num ; i++ )
		if (PS[i].Score > Buffer.Score)
			Buffer = PS[i];
	Array_Length_PS( PS, 0);
	LastStartSpot = Buffer.Start;
	return LastStartSpot;
}
