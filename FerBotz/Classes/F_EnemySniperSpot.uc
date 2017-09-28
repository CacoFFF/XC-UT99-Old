//=============================================================================
// F_EnemySniperSpot.
// Botz no pertenecientes al equipo señalado deberían apuntar aquí
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class F_EnemySniperSpot expands BaseLevelPoint;

var bool bUnseeable;

//Spawn Flag description:
// 1  Ignorar equipos en Team Game Plus (por si originalmente es CTF o AS)
// 2  Unseeable, poco visible a simple vista (se requiere rifle, visión previa o estar cerca)

function SetOption( int OptionNum )
{
	Switch (OptionNum)
	{
		case 0:
			Log("Script Error in Base-Level-Point, FIXME!");
			break;
		case 1:
			if ( Level.Game.class == class'BotPack.TeamGamePlus' )
				Team = 255;
			break;
		case 2:
			bUnseeable = true;
			break;
		Default:
			Log("Specified wrong spawn number (Maybe too high, maybe script-error");
	}

}

defaultproperties
{
}
