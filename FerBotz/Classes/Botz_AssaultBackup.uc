//=============================================================================
// The Assault Backup
// If a Botz hits this actor, he may wait for backup in assault games
// Team size only counts up to 16, always wait for a minimum of 1
// Closest node must be the related Fort
// This actor is not even spawned on clients.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_AssaultBackup extends Botz_BugSlayer;

var Botz TouchersZ[16];

var() int TeamMembers; //Cuantos jugadores hay en el equipo
var() int AttackingTeam;

var bool bGeneralCheck;
var bool bInit;
var float DistToFort;
var float NoCheckFor; //Once sent, wait till start stopping again

var bool bCountBeyond;
var() float GatherAlpha;
var() bool bOnlyDelay;

var int FirstCircle[8]; //Status for these points, 50 points away from me
var int SecondCircle[12]; //100 points away from me
var int ThirdCircle[16]; //150 points away from me
//Point info:
// 0=don't use
// 1=free
// 2=occupied


//Spawn Flag description:
// 1  Duplicar tamaño
// 2  Solo retrasar (no hacer que esperen, sino retrasarlos apenitas)
// 4  Reunir 25% del equipo
// 8  Reunir 50% del equipo //flags 4+8 significan 75%
// 16 Contar a los adelantados

event PostBeginPlay()
{
	super.PostBeginPlay();

	SetTimer( 1.5 + FRand() , false);
}

function SetOption( int OptionNum )
{
	Switch (OptionNum)
	{
		case 0:
			Log("Script Error in Base-Level-Point, FIXME!");
			break;
		case 1:
			SetCollisionSize( 120, 60);
			break;
		case 2:
			bOnlyDelay = true;
			break;
		case 4:
			GatherAlpha = 0.25;
			break;
		case 8:
			GatherAlpha += 0.50;
			break;
		case 16:
			bCountBeyond = true;
		Default:
			Log("Specified wrong spawn number (Maybe too high, maybe script-error");
	}

}

singular event Touch( actor Other)
{
	local int i, j; //j es el primer slot libre
	local bool bSuccess;

	if ( (Other != none) && Other.IsA('BotZ') && (Botz(Other).Orders == 'Attack') )
	{
		j = 17;
		bSuccess = True;
		For ( i=0 ; i<16 ; i++ )
		{
			if ( TouchersZ[i] == Botz(Other) )
			{
				bSuccess = False;
				break;
			}
			else if ( TouchersZ[i] == none )
				j = Min(i, j);
		}

		if ( bSuccess )
		{
			if ( j>16 )
				return;
			TouchersZ[j] = Botz(Other);
			WaitHere( Botz(Other));
			if ( j!=0 )
				TouchersZ[0].SendVoiceMessage( TouchersZ[0].PlayerReplicationInfo, Botz(Other).PlayerReplicationInfo, 'OTHER', 10, 'TEAM' );
		}
		Enable('Tick');
	}
}

event Tick( float DeltaTime)
{
	local int i, j;

	bGeneralCheck = !bGeneralCheck;

	if ( NoCheckFor >= 0 )
	{
		NoCheckFor -= DeltaTime;
		return;
	}

	if ( bGeneralCheck )
		return;
	if ( ClosestNode == none )
		return;

	For ( i=0 ; i<16 ; i++ )
		if ( TouchersZ[i] != none )
		{
			if ( VSize( TouchersZ[i].Location - Location) > 190 + CollisionRadius ) //I'm outside the wait zone
			{
				if ( !bCountBeyond ||  (VSize(TouchersZ[i].Location - ClosestNode.Location) > DistToFort) )
				{
					TouchersZ[i] = none;
					continue;
				}
				if ( bCountBeyond )
					j++;
				continue;
			}
			j++;
			if ( !bOnlyDelay )
				WaitHere( TouchersZ[i] );
		}

	if ( j==0 )
		Disable('Tick');
		
	if ( bOnlyDelay )
		return;
}

function WaitHere( Botz Other)
{
	local int i, Circle;
	local vector sample;

	Circle = 1;
	i = 0;
	if ( Other.InRadiusEntity( self) )
		Goto PickPointA;

	if ( Other.Acceleration == Vect(0,0,0) )
	{
		if ( Other.SpecialPause <= 0)
			Other.SpecialPause = 1; //Add an extra 1 second special pause
		return;
	}

PickPointA:
	if ( i>7)
	{
		i=0;
		Circle=2;
		goto PickPointB;
	}
	if ( FirstCircle[i] == 0 )
	{
		++i;
		goto PickPointA;
	}
	sample = Location + (vector(rot(0,8192,0)*i) * (CollisionRadius+35));

	if ( FirstCircle[i] == 1 ) //Free
	{
		if ( Other.HSize( Other.Location - sample) < Other.CollisionRadius )
		{
			Other.SpecialPause = 1;
			FirstCircle[i] = 2;
		}
		else if ( F_TempDest(Other.GetMoveTarget()) == None )
			Other.MasterEntity.TempDest().Setup( Other, Other, 2, sample);
		return;
	}
	else if ( FirstCircle[i] == 2 )
	{
		if ( Other.HSize( Other.Location - sample) < Other.CollisionRadius ) //ITS-A-ME-BOTZ
			return;
		else
		{	++i;
			goto PickPointA;
		}
	}
	else		FirstCircle[i] = 0; //Set this point to zero, avoid critical errors

PickPointB:
	if ( i>11)
	{
		i=0;
		Circle=3;
		goto PickPointC;
	}
	if ( SecondCircle[i] == 0 )
	{
		++i;
		goto PickPointB;
	}
	sample = Location + (vector(rot(0,5461,0)*(i+3)) * (CollisionRadius+90));

	if ( SecondCircle[i] == 1 ) //Free
	{
		if ( Other.HSize( Other.Location - sample) < Other.CollisionRadius )
		{
			Other.SpecialPause = 1;
			SecondCircle[i] = 2;
		}
		else
			Other.MasterEntity.TempDest().Setup( Other, Other, 2, sample);
		return;
	}
	else if ( SecondCircle[i] == 2 )
	{
		if ( Other.HSize( Other.Location - sample) < Other.CollisionRadius ) //ITS-A-ME-BOTZ
			return;
		else
		{	++i;
			goto PickPointB;
		}
	}

PickPointC:
	if ( i>15)
	{
		NoCheckFor = 10.0;
		Log("NO HAY PUNTO DE ESPERA, ATTACK NOW!");
		return;
	}
	if ( ThirdCircle[i] == 0 )
	{
		++i;
		goto PickPointC;
	}
	sample = Location + (vector(rot(0,4096,0)*(i+7)) * (CollisionRadius+135));

	if ( ThirdCircle[i] == 1 ) //Free
	{
		if ( Other.HSize( Other.Location - sample) < Other.CollisionRadius )
		{
			Other.SpecialPause = 1;
			ThirdCircle[i] = 2;
		}
		else
			Other.MasterEntity.TempDest().Setup( Other, Other, 2, sample);
		return;
	}
	else if ( ThirdCircle[i] == 2 )
	{
		if ( Other.HSize( Other.Location - sample) < Other.CollisionRadius ) //ITS-A-ME-BOTZ
			return;
		else
		{	++i;
			goto PickPointB;
		}
	}
}

//Update teams here
event Timer()
{
	local int i;
	local pawn p;
	local float testf, j;

	if ( (FortStandard( ClosestNode) == none) || !Level.Game.IsA('Assault')  )
	{
		Log("DESTROYING ASSAULT BACKUP POINT");
		Destroy();
		return;
	}

	if ( bInit )
	{
		//Check what occupied circles became free
		For ( i=0 ; i<8 ; i++ )
		{
			if ( (FirstCircle[i] == 2) && CollideTrace( Location + vector(rot(0,8192,0)*i)*(CollisionRadius+35) ) )
				FirstCircle[i] = 1;
			else if ( (FirstCircle[i] == 1) && !CollideTrace( Location + vector(rot(0,8192,0)*i)*(CollisionRadius+35) ) )
				FirstCircle[i] = 2;
		}
		For ( i=0 ; i<12 ; i++ )
		{
			if ( (SecondCircle[i] == 2) && CollideTrace( Location + vector(rot(0,5461,0)*(i+3))*(CollisionRadius+90) ) )
				SecondCircle[i] = 1;
			else if ( (SecondCircle[i] == 1) && !CollideTrace( Location + vector(rot(0,5461,0)*(i+3))*(CollisionRadius+90) ) )
				SecondCircle[i] = 2;
		}
		For ( i=0 ; i<16 ; i++ )
		{
			if ( (ThirdCircle[i] == 2) &&  CollideTrace( Location + vector(rot(0,4096,0)*(i+7))*(CollisionRadius+135) ) )
				ThirdCircle[i] = 1;
			else if ( (ThirdCircle[i] == 1) && !CollideTrace( Location + vector(rot(0,4096,0)*(i+7))*(CollisionRadius+135) ) )
				ThirdCircle[i] = 2;
		}
		i=0;
		j=0.0;
		For ( P=Level.PawnList ; P!=none ; P=P.NextPawn )
		{
			if ( P.PlayerReplicationInfo == none )
				continue;
			if ( P.PlayerReplicationInfo.Team != AttackingTeam )
				continue;
			if ( P.bIsPlayer && (P.Health > 0) ) //Avoid catching commanders and dead players
				i++;
			else
				continue;
			if ( VSize(P.Location - Location) < (190 + CollisionRadius) )
			{
				j += 1.0;
				if ( (NoCheckFor < 0.1) && P.IsA('Botz') && Botz(P).EnemyAimingAt(P, true) )
				{
					LOG("ENEMY DETECTED!");
					NoCheckFor = 5.0;
				}
			}
			else if ( bCountBeyond && (VSize(P.Location - ClosestNode.Location) < DistToFort) )
				j += 1.0;
		}
		TeamMembers = i;
		if ( (NoCheckFor > 0.1) && (NoCheckFor != 5.0) )
			return;
		testf = TeamMembers;
		if ( (GatherAlpha > 0.1) && (testf * GatherAlpha <= j) ) //There are enough attackers, go!
			NoCheckFor = 10.0;
		else if ( (GatherAlpha <= 0) && j>1 )
			NoCheckFor = 6.0;

		if ( NoCheckFor > 0.1 )
			Log("ATTACK NOW!, TOTAL IN TEAM: "$TeamMembers$", ATTACKERS HERE: "$int(j));

		return;
	}

	AttackingTeam = Assault(Level.Game).Attacker.TeamIndex;
	DistToFort = VSize( Location - ClosestNode.Location) * 0.95 - 100.0;

//Locate circle information
	For ( i=0 ; i<8 ; i++ )
		if ( CollideTrace( Location + vector(rot(0,8192,0)*i)*(CollisionRadius+55) ) )
		{
			Log("CIRCULO 1, PUNTO "$i$" ACTIVADO");
			FirstCircle[i] = 1;
		}
	For ( i=0 ; i<12 ; i++ )
		if ( CollideTrace( Location + vector(rot(0,5461,0)*(i+3))*(CollisionRadius+110) ) )
		{
			Log("CIRCULO 2, PUNTO "$i$" ACTIVADO");
			SecondCircle[i] = 1;
		}
	For ( i=0 ; i<16 ; i++ )
		if ( CollideTrace( Location + vector(rot(0,4096,0)*(i+7))*(CollisionRadius+155) ) )
		{
			Log("CIRCULO 3, PUNTO "$i$" ACTIVADO");
			ThirdCircle[i] = 1;
		}
	bInit = true;
	SetTimer( 1, true);
}

function bool CanPickItem( Pawn Other, Inventory Inv)
{
	return (Inv.BotDesireability( Other) > 0.0);
}


function bool CollideTrace( vector End)
{
	local vector HitLocation, HitNormal;
	local actor tempActor;

	ForEach TraceActors ( class'Actor', tempActor, HitLocation, HitNormal, End, Location)
	{
		if ( tempActor.bBlockActors || tempActor.bBlockPlayers || (tempActor == Level) )
			return false;
	}
	return true; //No actor
}

defaultproperties
{
     CollisionHeight=30
     CollisionRadius=60
     bCollideActors=True
}
