//=============================================================================
// F_HoldPosition.
// Para Hold y Patrol
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class F_HoldPosition expands InfoPoint;

var(InfoPoint) float Extension;
var(InfoPoint) float LastMsgTime;
var(InfoPoint) bool Ocupado;

event PostBeginPlay()
{
	SetTimer( 5, True);
}

event Timer()
{
	local pawn P;
	local botz B;
	local bool bSuccess;
	local int i;

	P = Level.PawnList;

	Do
	{
		B = Botz(P);
		if ( B != none)
		{	if (B.MyHoldSpot == self)
				bSuccess = True;
			For ( i=0 ; i<12 ; i++ )
				if ( B.PatrolStops[i] == self )
				{	bSuccess = True;
					i = 12;
				}
		}
		P = P.NextPawn;
	}
	Until ( (P == none) || bSuccess )

	if (!bSuccess)
		Destroy();
}

defaultproperties
{
     Extension=100.000000
}
