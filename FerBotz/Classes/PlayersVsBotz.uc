//=============================================================================
// PlayersVsBotz.
//
// Dynamically adjusts botz and player count in a team game
// You have to manually specify who takes each team
// Supports up to 32 botz
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class PlayersVsBotz expands Mutator
	config( BotzDefault);

var() config float BotzRatio; //Higher = more botz per player
enum EBotzSource
{
	BS_Random,
	BS_Random_LowSkill,
	BS_Random_HighSkill,
	BS_Faction,
	BS_Faction_LowSkill,
	BS_Faction_HighSkill,
	BS_List
};
var() config EBotzSource BotzSource;
var() byte PlayerTeam, BotzTeam;
var() config bool bRoundRatioCeil;
var() config string ForceFaction;
var BotzMutator BotzMutator;
var string SelectedFaction;
var TeamGamePlus TGP;


event PostBeginPlay()
{
	if ( BotzTeam == PlayerTeam )
	{
		BotzTeam = 1;
		PlayerTeam = 0;
		SaveConfig();
	}
	SetTimer( 2, false);
}


event Timer()
{
	local int Needed;
	local int Counted;
	
	Needed = MinNeededBotz();
	Counted = CountBotz();
	
	if ( Needed > Counted )
	{
		AddBotz();
		Counted++;
	}
	else if ( Needed < Counted )
	{
		RemoveBotz();
		Counted--;
	}
	if ( Counted != Needed )
		SetTimer( 0.5, false);
	else
		SetTimer( 3, false);
}

function AddBotz()
{
	local int index;
	local Botz B;

	index = FreeIndex();
	if ( BotzSource == BS_List )
		B = BotzMutator.SBM.AddListBotz( "Index="$string(index), string(BotzTeam) );
	else if ( BotzSource == BS_Random )
		B = BotzMutator.CreateBot( "", string(BotzTeam), string(1 + FRand() * 5.0), string( 1.5 + FRand() * 2.5) , "", "");
	else if ( BotzSource == BS_Random_LowSkill )
		B = BotzMutator.CreateBot( "", string(BotzTeam), string(FRand() * 4.0), string( 2 + FRand() * 3) , "", "");
	else if ( BotzSource == BS_Random_HighSkill )
		B = BotzMutator.CreateBot( "", string(BotzTeam), string(3 + FRand() * 4.0), string( FRand() * 2.7) , "", "");

	if ( B == none )
		return;

	B.iIndex = index;
	B.bIgnoredByMutator = true; //Do not rebalance this bot!
}

function RemoveBotz()
{
	local Botz B, victim;
	
	ForEach AllActors (class'Botz', B)
	{
		if ( B.iIndex >= 0 )
			victim = B;
	}
	if ( victim != none )
		victim.Destroy();
}

function AddMutator( Mutator M)
{
	local Mutator Mut;
	Super.AddMutator( M);
	if ( M.class == Class'BotzMutator' ) //Remove from mutator chain
	{
		BotzMutator = BotzMutator(M);
		BotzMutator.PlayersVsBotz = self;
		if ( Level.Game.BaseMutator == self )
			Level.Game.BaseMutator = NextMutator;
		else
		{
			For ( Mut=Level.Game.BaseMutator ; Mut.NextMutator!=none ; Mut=Mut.NextMutator )
				if ( Mut.NextMutator == self )
				{
					Mut.NextMutator = NextMutator;
					break;
				}
		}
		NextMutator = none;
	}
}

//Also adjust teams
function int MinNeededBotz()
{
	local PlayerReplicationInfo PRI;
	local float Count;

	TGP.bBalancing = true;
	ForEach AllActors (class'PlayerReplicationInfo', PRI)
	{
		if ( PRI.bIsSpectator )
			continue;
		if ((Botz(PRI.Owner) == none) || (Botz(PRI.Owner).iIndex < 0) )
		{
			Count += BotzRatio;
			if ( PRI.Team != PlayerTeam )
			{	Level.Game.ChangeTeam( Pawn(PRI.Owner), PlayerTeam);
				Pawn(PRI.Owner).Died(None, 'Suicided', PRI.Owner.Location);
			}
		}
		else
		{
			if ( PRI.Team == PlayerTeam )
			{	Level.Game.ChangeTeam( Pawn(PRI.Owner), BotzTeam);
				Pawn(PRI.Owner).Died(None, 'Suicided', PRI.Owner.Location);
			}
		}

	}
	TGP.bBalancing = false;
	if ( bRoundRatioCeil )
		Count += 0.5;
	return int(Count);
}

function int CountBotz()
{
	local Botz B;
	local int i;
	ForEach AllActors (class'Botz', B)
		if ( B.PlayerReplicationInfo != none && B.iIndex >= 0 )
			i++;
	return i;
}

//Prevent mutator overloading
event PreBeginPlay()
{
	local PlayersVsBotz M;
	ForEach AllActors (class'PlayersVsBotz', M)
		if ( M != self )
		{
			Destroy();
			return;
		}
	TGP = TeamGamePlus( Level.Game);
	if ( TGP == none )
	{
		Destroy();
		return;
	}
	TGP.bNoTeamChanges = false;
	TGP.bBalanceTeams = false;
	TGP.bPlayersBalanceTeams = false;
}

function int FreeIndex()
{
	local Botz B;
	local byte IndexMap[32];
	local int i;

	ForEach AllActors (class'Botz', B)
		if ( B.iIndex >= 0 )
			IndexMap[B.iIndex]++;
	For ( i=0 ; i<32 ; i++ )
		if ( IndexMap[i] == 0 )
			return i;
	return -1;
}

defaultproperties
{
    BotzRatio=1
    BotzTeam=1
}