//=============================================================================
// BaseSpawner.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BaseSpawner expands InfoPoint;

var() class<BaseLevelPoint> Points[32];
var() byte Teams[32];
var() vector Locations[32];
var() rotator Rotations[32];
var() int bTransloc[32];
var() int bJumpBoot[32];
var() string ClosestPath[32];
var() int SpawnFlags[32];

event PostBeginPlay()
{
	local int i;
	local actor R;
	local BaseLevelPoint TempPoint;
	i = 0;

	while (i < 32)
	{
		if ( Points[i] == none )
			break;
		TempPoint = Spawn(Points[i],,,Locations[i],Rotations[i]);
		TempPoint.Team = Teams[i];
		TempPoint.bTransloc = bool(bTransloc[i]);
		TempPoint.bJumpBoot = bool(bJumpBoot[i]);
		TempPoint.SpawnFlags = SpawnFlags[i];
		TempPoint.SetFlags();

		if ( ClosestPath[i] != "" )
			ForEach AllActors (class'actor',R)
				if ( string(R.Name) ~= ClosestPath[i] )
				{
					TempPoint.ClosestNode = R;
					break;
				}
		i++;
	}
}

defaultproperties
{
}
