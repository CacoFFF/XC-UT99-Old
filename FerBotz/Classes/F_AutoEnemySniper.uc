//=============================================================================
// F_AutoEnemySniper.
// Agregar por si mismo los F_EnemySniperSpot
// No es necesario vector ni rotación, tampoco closestpath
// Se auto-elimina luego de haber creado los Spots
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class F_AutoEnemySniper expands BaseLevelPoint;

var bool bOnlySnipers;
var bool bSetUnseeableSnipers;
var bool bUseBLPs;

//Spawn Flag description:
// 1  Solo tomar en cuenta los puntos de defensa con bSniping
// 2  Unseeable para todos los bSniping
// 4  Tambien tomar los FerDefensePoint, atento: estos deben ser creados antes
// 8  Ignorar equipos y hacer los sniperpoints globales (toma ambushpoints tambien)

function SetOption( int OptionNum )
{
	Switch (OptionNum)
	{
		case 0:
			Log("Script Error in Base-Level-Point, FIXME!");
			break;
		case 1:
			bOnlySnipers = True;
			break;
		case 2:
			bSetUnseeableSnipers = true;
			break;
		case 4:
			bUseBLPs = True;
			break;
		case 8:
			Team = 255;
			break;
		Default:
			Log("Specified wrong spawn number (Maybe too high, maybe script-error");
	}

}

event Timer()
{
	local AmbushPoint A;
	local FerDefensePoint F;
	local F_EnemySniperSpot NewOne;

	ForEach AllActors( class'AmbushPoint', A)
	{
		if ( (Team == 255) && (!bOnlySnipers || A.bSniping) )
		{
			NewOne = Spawn( class'F_EnemySniperSpot', , , A.Location);
			NewOne.Team = 255;
			if ( A.bSniping && bSetUnseeableSnipers )
				NewOne.bUnseeable = True;
			continue;
		}
		if ( A.IsA('DefensePoint') && (!bOnlySnipers || A.bSniping) )
		{
			NewOne = Spawn( class'F_EnemySniperSpot', , , A.Location);
			NewOne.Team = DefensePoint(A).Team;
			if ( A.bSniping && bSetUnseeableSnipers )
				NewOne.bUnseeable = True;
		}
	}

	if ( !bUseBLPs )
		return;

	ForEach AllActors( class'FerDefensePoint', F)
	{
		if ( (Team == 255) && (!bOnlySnipers || F.Sniping) )
		{
			NewOne = Spawn( class'F_EnemySniperSpot', , , F.Location);
			if ( F.Sniping && bSetUnseeableSnipers )
				NewOne.bUnseeable = True;
			continue;
		}
		if ( (Team != 255) && (!bOnlySnipers || F.Sniping) )
		{
			NewOne = Spawn( class'F_EnemySniperSpot', , , F.Location);
			NewOne.Team = F.Team;
			if ( F.Sniping && bSetUnseeableSnipers )
				NewOne.bUnseeable = True;
		}
	}

}

event PostBeginPlay()
{
	Super.PostBeginPlay(); //SetOptions...

	SetTimer( 0.1, false);
}

defaultproperties
{
}
