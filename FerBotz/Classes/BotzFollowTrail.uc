//=============================================================================
// BotzFollowTrail
// Punto invisible al que el bot seguira y tirará transloc sin matar al seguido
// Varia dependiendo del movimiento y se queda estacionario si hay transloc
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BotzFollowTrail expands Effects;

var Botz Follower;
var Vector CurrentOffset;
var float ReductionFactor, Counter;
var int bRight; // 1 o -1, 1 a la derecha, -1 a la izquierda
var bool bEnable;
var bool bFirstTick;

event Tick( float DeltaTime)
{
	local vector dir;
	local Rotator rotus;

	if ( !bFirstTick )
	{
		bFirstTick = True;
		return;
	}

	if ( (Follower != none) && (Owner == none ) )
	{
		SetOwner( Follower.OrderObject);
		return;
	}


	if ( (Follower == none) || (Owner == none) )
	{
		Destroy();
		return;
	}

	if ( (Physics == PHYS_Trailer) && (Follower.MyTranslocator != none) && (Follower.MyTranslocator.TTarget != none) && (Follower.MyTranslocator.TTarget.DesiredTarget == Owner) && (Follower.MyTranslocator.TTarget.Physics == PHYS_Falling) )
		setPhysics( PHYS_None);
	if ( (Physics == PHYS_None) && ((Follower.MyTranslocator == none) || (Follower.MyTranslocator.TTarget == none) || (Follower.MyTranslocator.TTarget.DesiredTarget != Owner) || (Follower.MyTranslocator.TTarget.Physics == PHYS_None)) )
		setPhysics( PHYS_Trailer);


	if ( bEnable )
	{

		rotus = rot(0,0,0);
		rotus.Yaw += 16384;

		if ( VSize( Owner.Acceleration) > 50)
			dir = vector( rotator(Owner.Acceleration) + rotus);
		else
			dir = vector( Owner.Rotation + rotus);


		Counter -= DeltaTime;
		if ( Counter < 0 )
		{
			Counter = 0.25;
			CheckForWalls( dir);
		}

		CurrentOffset = Owner.Acceleration * ((1.0 + ReductionFactor) / 12.0);
		CurrentOffset *= 0.4; //FIX
		CurrentOffSet += dir * (80 * ReductionFactor * bRight);
		PrePivot = CurrentOffset;
	}
	else
	{
		PrePivot = vect(0,0,0);
		Counter -= DeltaTime;
		if ( Counter < 0 )
		{
			Counter = 0.25;
			if ( (VSize(Location - Follower.Location) < 450 ) && FastTrace( Follower.Location, Location + CurrentOffset) )
				bEnable = True;
		}

	}
}

function CheckForWalls( vector RightLook)
{
	local vector HitLocation, HitNormal, HitTarget;
	local int BiggestL, BiggestR;
	local int i;
	local bool bLeftIs, bRightIs;
	local actor HitActor;

	if ( bRight == 0)
		bRight = 1;

	//4 HITS PARA CADA COSTADO
	For ( i=4 ; i>0 ; i-- )
	{
		HitTarget = Owner.Location + RightLook * ((20 * i) + 10 );
		HitActor = Owner.Trace( HitLocation, HitNormal, HitTarget );				
		if ( HitActor == Follower )
			bRightIs = true;
		else if ( HitActor != none )
			bRightIs = False;
		else
			bRightIs = True;

		HitTarget = Owner.Location + RightLook * ((25 * (-i)) - 10 );
		HitActor = Owner.Trace( HitLocation, HitNormal, HitTarget );				
		if ( HitActor == Follower )
			bLeftIs = true;
		else if ( HitActor != none )
			bLeftIs = False;
		else
			bLeftIs = True;

		if ( bLeftIs || bRightIs )
			break;
	}

	if ( i > 0 )
		ReductionFactor = float(i) / 4.0;
	else
	{
		ReductionFactor = 0;
		return;
	}

	if ( bLeftIs && !bRightIs )
		bRight = -1;
	else if ( !bLeftIs && bRightIs )
		bRight = 1;
}

defaultproperties
{
     bHidden=True
     bOwnerNoSee=True
     bNetTemporary=False
     bTrailerPrePivot=True
     Physics=PHYS_Trailer
     DrawType=DT_Sprite
     AmbientGlow=128
}
