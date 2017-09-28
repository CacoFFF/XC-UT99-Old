//=============================================================================
// This path type traces thru movers
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_NavigDoorSpecial expands Botz_NavigDoor;

#exec TEXTURE IMPORT NAME=BWP_Door2 FILE=..\CompileData\BWP_Door2.bmp FLAGS=2

var Botz_NavigDoor OtherSide;
var Mover Gate;
var name GateTag;

event FinishedPathing()
{
	local Actor A, B;
	local int uReach, i;
	local vector HitLocation, HitNormal;

	ForEach ConnectedDests( Self, A, uReach, i)
		if ( A.IsA('Botz_NavigDoor') )
		{
			if ( (OtherSide == none) || (VSize(OtherSide.Location - Location) > VSize(A.Location-Location) ) )
				OtherSide = Botz_NavigDoor(A);
		}
	
	//Hard mode
	if ( OtherSide == None )
		ForEach NavigationActors( class'Botz_NavigDoor', OtherSide,,,true)
		{
			if ( (OtherSide != self) && (IsConnectedTo(OtherSide, self) != -1) )
				break;
			OtherSide = None;
		}
	
	if ( OtherSide != none )
	{
		ForEach TraceActors( class'Actor', A, HitLocation, HitNormal, OtherSide.Location)
			if ( Mover(A) != None )
			{
				Gate = Mover(A);
				if ( Gate.Tag != '' || Gate.Tag != Gate.Class.Name )
					GateTag = A.Tag;
				else
					GateTag = 'Botz_NavigDoorSpecial';
				break;
			}
			
		if ( Gate != None )
		{
			ForEach ConnectedDests( Self, A, uReach, i) //See what I'm connected to
				if ( (A != OtherSide) && (IsConnectedTo(OtherSide, NavigationPoint(A)) != -1) ) //See if other side is connected to it as well
				{
					ForEach TraceActors( Class'Actor', B, HitLocation, HitNormal, A.Location, OtherSide.Location) //If it hits the gate
						if ( (B == Gate || (Mover(B) != None && B.Tag == GateTag)) )
						{
							PruneReachSpec( IsConnectedTo(OtherSide, NavigationPoint(A)) ); //Prune (FUTURO: ELIMINAR DIRECTAMENTE)
							break;
						}
							
				}
		}
		SetTimer(1.5, true);
	}
	Super.FinishedPathing(); //Prune other paths...
}

event Timer()
{
	if ( DoorIsLocked() )
		ExtraCost = 10000000;
	else
		ExtraCost = 0;
}

function bool DoorIsLocked()
{
	if ( otherSide == None )
		return false;
	
	if ( (Gate != None) && !Gate.bTriggerOnceOnly )
	{
		if ( (Trigger(Gate.TriggerActor) != None) && (VSize(Gate.TriggerActor.Location - Location) < 1000) )
			return !Trigger(Gate.TriggerActor).bInitiallyActive;
	}
	
	return !PathVisible( self, otherSide);
}


defaultproperties
{
	FriendlyName="Special Door Node"
	MaxDistance=800
	Texture=Texture'BWP_Door'
	bLoadSpecial=True
}