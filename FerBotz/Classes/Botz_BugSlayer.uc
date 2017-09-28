//=============================================================================
// The Bug Slayer for the amazing Botz.
// It is a pity to program the Botz to work in 'most' maps in a common way than
// programming it to work in some maps in an amazing way, the bug slayer will
// ensure the Botz to work greatly in all supported maps. How it Works?
// Easy, place a fix-point to solve a common error, like getting stuck in a
// misplaced item, or place a reference point to perform a special action,
// like avoiding a mortar shell.
// The will be standard preset points like:
//   - Pick certain item (or actor) if touched
//   - Jump if touched
//   - Add extra cost to closest path (Value 'ClosestNode' i mean)
//   - No path Redirector (send botz to this point if he has no path)
//   - Move botz if stuck (send botz to certain path if get stuck)
// The user can program customized Bug Slayers to make specific actions in
// specific levels, like avoiding a mortar shell in AS-Overlord for attackers.
// This actor is not even spawned on clients.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_BugSlayer extends BaseLevelPoint
	abstract;

//Deberia hacer los bug slayers dependientes de una raiz o ubicarlos con el ALLACTORS?
//ALLACTORS, que es C++ y funciona 20 veces mas rapido que UnrealScript
//pero USAR CADENA EN MASTERGASTERFER para Modificador de costo de caminos o de
//checkeos recurrentes.
//Utilizar el BugSlayer con EVENTOS preferentemente, son mas rapidos y efectivos

// ESTO ES UNA CLASE RAIZ, HAGA SUS PROPIOS BUGSLAYERS AQUI CON LOS AGREGADORES
// DE CAMINOS-EN-JUEGO (ver MASTERGASTERFER)

defaultproperties
{
}
