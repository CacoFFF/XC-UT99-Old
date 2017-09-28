//=============================================================================
// BotzNode
// Aparentemente los BotzNode sirven para interconectar zonas sin waypoints.
// Tendran forma de camino lineal supongo?
// Tienen una similaridad con los path del jumbot... supongo que asi encuentro
// variantes
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BotzNode expands BaseLevelPoint;

var name SpecialName;
var int Order;
var BotzNode NextNode;
var BotzNode LastNode;
var bool Blocked;

//Nuevo codigo y variables
// FUTURO: implementar caminos estilo jumbot
// FUTURO: implementar creador en tiempo real
// FUTURO: implementar variacion para jumpspots?

// Descripcion de spawnflags
//
//

function AddNode()
{
	local MasterGasterFer M;
	local BotzNode Current;

	ForEach AllActors (class'MasterGasterFer', M)
	{
		if (Order == 0)
			M.BNodeList = Self;
		break;
	}	//Asumo que existe solo un MasterGaster

	if (Blocked)
		Tag = SpecialName;

	ForEach AllActors (class'BotzNode', Current)
	{
		if (Current.Order == (Order - 1) )
		{
			LastNode = Current;
			Current.NextNode = self;
		}
		if (Current.Order == (Order + 1) )
		{
			NextNode = Current;
			Current.LastNode = self;
		}
	}

}


function SetOption( int OptionNum )
{
	Switch (OptionNum)
	{
		case 0:
			Log("Script Error in Base-Level-Point, FIXME!");
			break;
		Default:
			Log("Specified wrong spawn number (Maybe too high, maybe script-error");
	}

}



defaultproperties
{
}
