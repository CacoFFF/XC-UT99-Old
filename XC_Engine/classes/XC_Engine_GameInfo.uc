class XC_Engine_GameInfo expands GameInfo
	abstract;

native(1718) final function bool AddToPackageMap( optional string PkgName);
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );
native(3540) final iterator function PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional Pawn StartAt);



//Listen server tweaks
final function InitGame_Org( string Options, out string Error )
{
	local string InOpt, LeftOpt;
	local int pos;
	local class<Mutator> MClass;
}

event InitGame_Listen( string Options, out string Error )
{
	local string InOpt, LeftOpt;
	local int pos;
	local class<Mutator> MClass;
	
	InitGame_Org( Options, Error);

	InOpt = ParseOption( Options, "Class" );
	pos = InStr(InOpt,".");
	AddToPackageMap( Left(InOpt,pos));

	InOpt = ParseOption( Options, "Skin" );
	pos = InStr(InOpt,".");
	AddToPackageMap( Left(InOpt,pos));
	
	InOpt = ParseOption( Options, "Voice" );
	pos = InStr(InOpt,".");
	AddToPackageMap( Left(InOpt,pos));
}



//******************************************************************
//*** PostLogin
// Group up skins in batches and avoid spamming a player's log
// This should also save heaps of bandwidth in maps full of monsters
native(640) static final function int Array_Length_Tex( out array<Texture> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_Tex( out array<Texture> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_Tex( out array<Texture> Ar, int Offset, optional int Count );


event PostLogin( playerpawn NewPlayer )
{
	local Pawn P;
	local array<Texture> TextureList;
	local Texture T[3];
	local int i, j, TLMax;

	// Start player's music.
	NewPlayer.ClientSetMusic( Level.Song, Level.SongSection, Level.CdTrack, MTRAN_Fade );
	
	// replicate skins
	ForEach PawnActors( class'Pawn', P,,, true, NewPlayer.NextPawn) //Guaranteed to not collide with NewPlayer
	{
		if ( P.bIsPlayer )
		{
			if ( P.bIsMultiSkinned )
			{
				For ( j=0 ; j<4 ; j++ )
				{
					if ( P.MultiSkins[j] != None )
					{
						For ( i=0 ; i<TLMax ; i++ )
							if ( P.MultiSkins[j] == TextureList[i] )
								Goto NEXT_SKIN;
					}
					TextureList[TLMax++] = P.MultiSkins[j];
					NEXT_SKIN:
				}
			}
			else if ( (P.Skin != None) && (P.Skin != P.Default.Skin) )
			{
				For ( i=0 ; i<TLMax ; i++ )
					if ( P.MultiSkins[j] == TextureList[i] )
						Goto NEXT_PAWN;
				TextureList[TLMax++] = P.Skin;
				NEXT_PAWN:
			}

			if ( P.PlayerReplicationInfo.bWaitingPlayer && P.IsA('PlayerPawn') )
			{
				if ( NewPlayer.bIsMultiSkinned )
					PlayerPawn(P).ClientReplicateSkins(NewPlayer.MultiSkins[0], NewPlayer.MultiSkins[1], NewPlayer.MultiSkins[2], NewPlayer.MultiSkins[3]);
				else
					PlayerPawn(P).ClientReplicateSkins(NewPlayer.Skin);	
			}
		}
	}
	
	i=0;
	j=0;
	while ( i < (TLMax-3) )
		NewPlayer.ClientReplicateSkins( TextureList[i++], TextureList[i++], TextureList[i++], TextureList[i++]);
	while ( i<TLMax )
		T[j++] = TextureList[i++];
	if ( T[0] != None )
		NewPlayer.ClientReplicateSkins( T[0], T[1], T[2]);
	if ( TLMax > 0 )
		Array_Length_Tex( TextureList, 0);
}

//***************************************
// PreLogin hook - ported to UnrealScript
//
final function CheckPreLogins( string Options, string Address, out string Error, out string FailCode)
{
	local XC_Engine_Actor XCGEA;
	local int i;
	local string Parm;

	Parm = ParseOption( Options, "Class");
	if ( Parm == "" || (InStr(Parm,"%") >= 0) )
	{
		Error = "XCGE Denied, invalid class:" @ Parm;
		return;
	}

	Parm = ParseOption( Options, "Name");
	if ( Parm == "" )
	{
		Error = "XCGE Denied, invalid name";
		return;
	}

	ForEach DynamicActors( class'XC_Engine_Actor', XCGEA) //Process registered pre-login hooks
	{
		Log("Check prelogins..."@XCGEA);
		for ( i=0 ; i<12 ; i++ )
			if ( XCGEA.PreLoginHooks[i] != none && !XCGEA.PreLoginHooks[i].bDeleteMe )
				XCGEA.PreLoginHooks[i].PreLoginHook( Options, Address, Error, FailCode); //Pre-validated, won't crash
		return;
	}
}

final function PreLogin_Org( string Options, string Address, out string Error, out string FailCode);

// Linux-safe replacement of PreLogin
// Parameter count apparently cannot change so we call another 'final' function here
event PreLogin( string Options, string Address, out string Error, out string FailCode)
{
	// Linux v451 likes crashing here
	local string InPassword;
	
/*	Error="";
	InPassword = ParseOption( Options, "Password" );
	if( (Level.NetMode != NM_Standalone) && AtCapacity(Options) )
		Error=MaxedOutMessage;
	else
	{
		SaveConfig(); //Bad but necessary
		if ( ConsoleCommand("get"@class@"GamePassword")!="" && caps(InPassword)!=caps(ConsoleCommand("get"@class@"GamePassword")) 
		&& (ConsoleCommand("get"@class@"AdminPassword")=="" || caps(InPassword)!=caps(ConsoleCommand("get"@class@"AdminPassword"))) )
		{
			if( InPassword == "" )
			{
				Error = NeedPassword;
				FailCode = "NEEDPW";
			}
			else
			{
				Error = WrongPassword;
				FailCode = "WRONGPW";
			}
		}
	}*/

	PreLogin_Org( Options, Address, Error, FailCode);
	if ( Error == "" ) //Default errors override XC_Engine behaviour
		CheckPreLogins( Options, Address, Error, FailCode);
}

	
function Killed( pawn Killer, pawn Other, name damageType )
{
	local String Message, KillerWeapon, OtherWeapon;
	local bool bSpecialDamage;

	if (Other.bIsPlayer && Other.PlayerReplicationInfo != None )
	{
		if ( (Killer != None) && (!Killer.bIsPlayer) )
		{
			Message = Killer.KillMessage(damageType, Other);
			BroadcastMessage( Message, false, 'DeathMessage');
			if ( LocalLog != None )
				LocalLog.LogSuicide(Other, DamageType, None);
			if ( WorldLog != None )
				WorldLog.LogSuicide(Other, DamageType, None);
			return;
		}
		if ( (DamageType == 'SpecialDamage') && (SpecialDamageString != "") )
		{
			if ( Killer.PlayerReplicationInfo != None )
				BroadcastMessage( ParseKillMessage(
						Killer.PlayerReplicationInfo.PlayerName,
						Other.PlayerReplicationInfo.PlayerName,
						Killer.Weapon.ItemName,
						SpecialDamageString
						),
					false, 'DeathMessage');
			bSpecialDamage = True;
		}
		Other.PlayerReplicationInfo.Deaths += 1;
		if ( (Killer == Other) || (Killer == None) )
		{
			// Suicide
			if (damageType == '')
			{
				if ( LocalLog != None )
					LocalLog.LogSuicide(Other, 'Unknown', Killer);
				if ( WorldLog != None )
					WorldLog.LogSuicide(Other, 'Unknown', Killer);
			} else {
				if ( LocalLog != None )
					LocalLog.LogSuicide(Other, damageType, Killer);
				if ( WorldLog != None )
					WorldLog.LogSuicide(Other, damageType, Killer);
			}
			if (!bSpecialDamage)
			{
				if ( damageType == 'Fell' )
					BroadcastLocalizedMessage(DeathMessageClass, 2, Other.PlayerReplicationInfo, None);
				else if ( damageType == 'Eradicated' )
					BroadcastLocalizedMessage(DeathMessageClass, 3, Other.PlayerReplicationInfo, None);
				else if ( damageType == 'Drowned' )
					BroadcastLocalizedMessage(DeathMessageClass, 4, Other.PlayerReplicationInfo, None);
				else if ( damageType == 'Burned' )
					BroadcastLocalizedMessage(DeathMessageClass, 5, Other.PlayerReplicationInfo, None);
				else if ( damageType == 'Corroded' )
					BroadcastLocalizedMessage(DeathMessageClass, 6, Other.PlayerReplicationInfo, None);
				else if ( damageType == 'Mortared' )
					BroadcastLocalizedMessage(DeathMessageClass, 7, Other.PlayerReplicationInfo, None);
				else
					BroadcastLocalizedMessage(DeathMessageClass, 1, Other.PlayerReplicationInfo, None);
			}
		} 
		else 
		{
			if ( Killer.bIsPlayer && Killer.PlayerReplicationInfo != None )
			{
				KillerWeapon = "None";
				if (Killer.Weapon != None)
					KillerWeapon = Killer.Weapon.ItemName;
				OtherWeapon = "None";
				if (Other.Weapon != None)
					OtherWeapon = Other.Weapon.ItemName;
				if ( Killer.PlayerReplicationInfo.Team == Other.PlayerReplicationInfo.Team )
				{
					if ( LocalLog != None )
						LocalLog.LogTeamKill(
							Killer.PlayerReplicationInfo.PlayerID,
							Other.PlayerReplicationInfo.PlayerID,
							KillerWeapon,
							OtherWeapon,
							damageType
						);
					if ( WorldLog != None )
						WorldLog.LogTeamKill(
							Killer.PlayerReplicationInfo.PlayerID,
							Other.PlayerReplicationInfo.PlayerID,
							KillerWeapon,
							OtherWeapon,
							damageType
						);
				} else {
					if ( LocalLog != None )
						LocalLog.LogKill(
							Killer.PlayerReplicationInfo.PlayerID,
							Other.PlayerReplicationInfo.PlayerID,
							KillerWeapon,
							OtherWeapon,
							damageType
						);
					if ( WorldLog != None )
						WorldLog.LogKill(
							Killer.PlayerReplicationInfo.PlayerID,
							Other.PlayerReplicationInfo.PlayerID,
							KillerWeapon,
							OtherWeapon,
							damageType
						);
				}
				if (!bSpecialDamage && (Other != None))
				{
					BroadcastRegularDeathMessage(Killer, Other, damageType);
				}
			}
		}
	}
	ScoreKill(Killer, Other);
}

	
function ScoreKill(pawn Killer, pawn Other)
{
	Other.DieCount++;
	if( (killer == Other) || (killer == None) )
	{
		if ( Other.PlayerReplicationInfo != None )
			Other.PlayerReplicationInfo.Score -= 1;
	}
	else if ( killer != None )
	{
		killer.killCount++;
		if ( killer.PlayerReplicationInfo != None )
			killer.PlayerReplicationInfo.Score += 1;
	}

	BaseMutator.ScoreKill(Killer, Other);
}
