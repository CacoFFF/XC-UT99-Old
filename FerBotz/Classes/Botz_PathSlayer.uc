//=============================================================================
// The Path Slayer
// Select a path to increase cost, but won't work for UT BOTS, sorry.
// This actor is not even spawned on clients.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_PathSlayer extends Botz_BugSlayer;

var float DaCost;
var NavigationPoint DaVictim;
var Botz_PathSlayer NextPS;

//Este no usa spawn flags, es el costo
event PostBeginPlay()
{
	local Botz_PathSlayer somePS;

	DaCost = SpawnFlags;
	SetTimer(1.0, False);
	ForEach AllActors (class'Botz_PathSlayer', somePS)
		if ( somePS != self )
		{
			NextPS = somePS;
			break;
		}
}
event Timer()
{
	DaCost = SpawnFlags;
	DaVictim = NavigationPoint(ClosestNode);
}

//Puedes definir un subclass para modificar el comportamiento de las cosas a tu
//manera. Pero funciona en cadena, no desabilites el NEXTPS!!!.
function CostNow()
{
	DaVictim.Cost = DaCost;
	if ( NextPS != none )
		NextPS.CostNow();
}

function UnCostNow()
{
	DaVictim.Cost = 0;
	if ( NextPS != none )
		NextPS.UnCostNow();
}

defaultproperties
{
}
