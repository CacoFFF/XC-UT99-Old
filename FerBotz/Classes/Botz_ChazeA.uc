//=============================================================================
// Botz_ChazeA.
// Esto es util, probablemente vaya para la orden de apoyar en asalto y CTF
// Utilizar lifespan para determinar el limite de tiempo
// Debe ser usado con un TARGET-ADDER (sea personalizado o no)
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_ChazeA expands InfoPoint;

var pawn Chazer;
var pawn Chazed;
var float ChazeAt;
var float NoChazeIfVisibleAt;
//var bool bBackIfChazerTouch; POSIBLE REEMPLAZO DE UNA ORDEN
var bool bDeleteForDeath;
var string CrDeathSParam; //Parametro a aplicarse si muere el chazer
var string CrDeathOParam; //Parametro a aplicar a chazed si muere chazer
var string CdDeathSParam; //Parametro a aplicarse si muere el chazed
var string CdDeathOParam; //Parametro a aplicar a chazer si muere chazed
var int CountMoves;
var int iMoveCounter;
var float fMover; //No tomar en cuenta movimientos muy cortos

event PostBeginPlay()
{
	super.PostBeginPlay();
	Enable('Tick');
}

function Tick( float DeltaTime)
{
	if ( (Chazed.Health <= 0) || (Chazer.Health <= 0) && bDeleteForDeath )
		Destroy();
	if ( (Chazed == none) || (Chazer == none) || (Chazed == Chazer) )
	{
		Destroy();
		return;
	}
	fMover -= DeltaTime;
	if ( fMover < -1.0)
		fMover = -1.0;

	if ( (VSize(Chazed.Location - Chazer.Location) < 90) && (Chazer.MoveTarget == Chazed) && (VSize(Chazer.Acceleration) > 50) )
		Chazer.MoveTarget = none;
}

function actor UpdateChase()
{
	if ( fMover <= 0 )
	{
		iMoveCounter--;
		fMover = 0.6;
	}
//Pre i


	if ( iMoveCounter < 0)
		iMoveCounter = 0;
	else
		return none;

//Post i
//No seguir si:
	if ( (Chazed.Physics == PHYS_Flying) || (Chazed.Health <= 0) )
	{
		iMoveCounter = CountMoves;
		return none;
	}
	if ( (VSize(Chazed.Location - Chazer.Location) < NoChazeIfVisibleAt) && Chazed.FastTrace( Chazer.Location ) )
	{
		iMoveCounter = CountMoves;
		return none;
	}
	if ( VSize(Chazed.Location - Chazer.Location) < ChazeAt )
	{
		iMoveCounter = CountMoves;
		return none;
	}
//Seguir si no
	return Chazed;
}

defaultproperties
{
}
