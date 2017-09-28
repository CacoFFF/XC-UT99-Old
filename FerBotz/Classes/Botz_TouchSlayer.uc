//=============================================================================
// The Touch Slayer
// If a Botz hits this actor, he will go to 'ClosestNode'
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_TouchSlayer extends Botz_BugSlayer;

var Botz TouchersZ[12];
var float Touchus[12];

var bool bSlightChange;
var bool bCheckForInv;
var bool bCheckDirectInv;
var bool bRotational; //Punto rotacional, si el botz se mueve en tal direccion, ir a tal punto, sino no se hara (util para caminos de 2 sentidos)

//Spawn Flag description:
// 1  Rotacional (60º)
// 2  Checkear inventario
// 4  Checkear inventario e ir a el directamente
// 8  Solo cambiar el moveTarget

function SetOption( int OptionNum )
{
	Switch (OptionNum)
	{
		case 0:
			Log("Script Error in Base-Level-Point, FIXME!");
			break;
		case 1:
			bRotational = true;
			break;
		case 2:
			bCheckForInv = true;
			break;
		case 4:
			bCheckDirectInv = true;
			break;
		case 8:
			bSlightChange = true;
			break;
		Default:
			Log("Specified wrong spawn number (Maybe too high, maybe script-error");
	}

}

singular event Touch( actor Other)
{
	local int i;
	local bool bSuccess;

	if ( bCheckForInv || bCheckDirectInv )
	{
		if ( ClosestNode.IsA('InventorySpot') && (!InventorySpot(ClosestNode).MarkedItem.IsInState('PickUp') || CanPickItem(Botz(Other), InventorySpot(ClosestNode).MarkedItem) ) )
			return;
	}

	if ( bRotational && !Class'BotzFunctionManager'.static.CompareRotation(Rotation, Rotator(Other.Acceleration), 10922, True) )
		return;

	if ( (Other != none) && Other.IsA('BotZ') )
	{
		bSuccess = True;
		For ( i=0 ; i<12 ; i++ )
			if ( TouchersZ[i] == Botz(Other) )
			{
				bSuccess = False;
				break;
			}
		if ( bSuccess )
		{
			Botz(Other).MoveTarget = ClosestNode;
			if ( bCheckDirectInv && ClosestNode.IsA('InventorySpot') && (InventorySpot(ClosestNode).MarkedItem != none) )
				Botz(Other).MoveTarget = InventorySpot(ClosestNode).MarkedItem;
			Botz(Other).Destination = Botz(Other).MoveTarget.Location;
			if ( !bSlightChange ) //Prevent shortening
				Botz(Other).MasterEntity.TempDest().Setup( Botz(Other), Botz(Other).MoveTarget, 4, Botz(Other).MoveTarget.Location);
			For( i=0 ; i<12 ; i++ )
				if ( TouchersZ[i] == none )
				{
					TouchersZ[i] = Botz(Other);
					Touchus[i] = 4.5;
				}
		}
		Enable('Tick');
	}
}

event Tick( float DeltaTime)
{
	local int i;
	local bool bNoOne;

	bNoOne = True;
	For ( i=0 ; i<12 ; i++ )
		if ( TouchersZ[i] != none )
		{
			bNoOne = False;
			Touchus[i] -= DeltaTime;
			if ( Touchus[i] < 0 )
			{
				Touchus[i] = 0;
				TouchersZ[i] = none;
				ReCheckTouchers();
			}
		}
	if ( bNoOne )
		Disable('Tick');
}

function bool CanPickItem( Botz Other, Inventory Inv)
{
	return (Inv.BotDesireability( Other) > 0.0);
}

function ReCheckTouchers()
{
	local int i;

	For ( i=0 ; i<4 ; i++ )
		if ( Botz(Touching[i]) != none )
			Touch( Touching[i]);
}

defaultproperties
{
     bCollideActors=True
}
