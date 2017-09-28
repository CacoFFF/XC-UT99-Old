//=============================================================================
// FerDefensePoint.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BaseLevelPoint expands InfoPoint;

var() byte Team;
var actor ClosestNode;
var bool bTransloc;
var bool bJumpBoot;
var() int SpawnFlags; //Usado para determinar opciones desde una entidad maestra

//interno

event PostBeginPlay()
{
}

function SetFlags()
{
	if ( SpawnFlags == 0 )
		return;

	if ( (SpawnFlags & 1) != 0)
		SetOption( 1);
	if ( (SpawnFlags & 2) != 0)
		SetOption( 2);
	if ( (SpawnFlags & 4) != 0)
		SetOption( 4);
	if ( (SpawnFlags & 8) != 0)
		SetOption( 8);
	if ( (SpawnFlags & 16) != 0)
		SetOption( 16);
	if ( (SpawnFlags & 32) != 0)
		SetOption( 32);
	if ( (SpawnFlags & 64) != 0)
		SetOption( 64);
	if ( (SpawnFlags & 128) != 0)
		SetOption( 128);
	if ( (SpawnFlags & 256) != 0)
		SetOption( 256);
	if ( (SpawnFlags & 512) != 0)
		SetOption( 512);
	if ( (SpawnFlags & 1024) != 0)
		SetOption( 1024);
	if ( (SpawnFlags & 2048) != 0)
		SetOption( 2048);
}



function SetOption( int OptionNum );

defaultproperties
{
}
