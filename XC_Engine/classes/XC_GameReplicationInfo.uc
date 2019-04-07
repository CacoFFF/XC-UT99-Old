class XC_GameReplicationInfo extends GameReplicationInfo
	abstract;
	
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );

simulated function Timer_Server()
{
	local PlayerReplicationInfo PRI;
	local int i, FragAcc;

	ForEach DynamicActors( class'PlayerReplicationInfo', PRI)
	{
		if ( i<32 )
			PRIArray[i++] = PRI;
		FragAcc += PRI.Score;
	}
	while ( i<32 )
		PRIArray[i++] = None;

	// Update various information.
	UpdateTimer = 0;
	if ( Level.Game != None )
		NumPlayers = Level.Game.NumPlayers;
}