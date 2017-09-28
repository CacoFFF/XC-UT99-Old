//
// BotzProjectileStore
// Used to store all projectiles flying around for evasion purposes
//
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org

class BotzProjectileStore expands InfoPoint;


var() Projectile ProjList[96]; //Para empezar, 96
var int iProj;	//Optimizacion

//New functionality: recently spawned projectile always to slot 0
function AddProj( projectile Other)
{
	local int i;

	if ( iProj >= Arraycount(ProjList) )
		ProjList[Rand(Arraycount(ProjList))] = ProjList[0];
	else
		ProjList[iProj++] = ProjList[0];
	ProjList[0] = Other;

}

//Simple Accessor
function Projectile GetProj( int i)
{
	return ProjList[i];
}


function Projectile NextDangerProj( BotZ B, float Dist, out int OI)
{
	if ( iProj <= 0 )
		return none;
	if ( OI == 9999 )
		OI = iProj - 1;

	if ( false )
	{
		AGAIN:
		if (--OI < 0)
			return none;
	}

	if ( (ProjList[OI] == none) || ProjList[OI].bDeleteMe )
		Goto AGAIN;

	if ( (ProjList[OI].Instigator == B) || (VSize(ProjList[OI].Location - B.Location) - VSize(ProjList[OI].Velocity)*0.1) > Dist )
		Goto AGAIN;

	return ProjList[OI--];
}

event Tick( float DeltaTime)
{
	local int i;

	while ( (iProj > 0) && (ProjList[iProj-1] == none || ProjList[iProj-1].bDeleteMe) )
		ProjList[--iProj] = none;

	For ( i=iProj-2 ; i>=0 ; i-- )
	{
		if ( ProjList[i] == none || ProjList[i].bDeleteMe )
		{
			ProjList[i] = ProjList[--iProj];
			ProjList[iProj] = none;
		}
	}

}

