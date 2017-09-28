//=============================================================================
// FerDefensePoint.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class FerDefensePoint expands BaseLevelPoint;

var bool Sniping;
var bool NoSnipe;
var bool DoubleTime;
var bool GreatRange;
var bool DoubleChance;

//Spawn Flag description:
// 1  Sniper
// 2  Duplicar tiempo de estadia
// 4  Largo alcance (capacidad de detectar a cualquiera sin importar alcance)
// 8  Duplicar las chances de visitarlo

function SetOption( int OptionNum )
{
	Switch (OptionNum)
	{
		case 0:
			Log("Script Error in Base-Level-Point, FIXME!");
			break;
		case 1:
			Sniping = true;
			break;
		case 2:
			DoubleTime = true;
			break;
		case 4:
			GreatRange = true;
			break;
		case 8:
			DoubleChance = true;
			break;
		Default:
			Log("Specified wrong spawn number (Maybe too high, maybe script-error");
	}

}

defaultproperties
{
     bDirectional=True
}
