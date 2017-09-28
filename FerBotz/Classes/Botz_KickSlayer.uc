//=============================================================================
// The Kick Slayer
// This actor works as kicker for botz
// Kicks to where bot wants to go, or just jump
// This actor is not spawned on clients.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_KickSlayer extends Botz_BugSlayer;

var bool bUseDir; //Kick toward botz destination
var bool bAddZ; //Add jump velocity (on dir kicks, dir becomes horizontal)
var bool bForceFall; //Force PHYS_Falling
var bool bDoubleStrenght; //Double velocity

function SetOption( int OptionNum )
{
	Switch (OptionNum)
	{
		case 0:
			Log("Script Error in Base-Level-Point, FIXME!");
			break;
		case 1:
			bUseDir = true;
			break;
		case 2:
			bAddZ = true;
			break;
		case 4:
			bForceFall = true;
			break;
		case 8:
			bDoubleStrenght = true;
			break;
		case 16:
			SetCollisionSize(70, 70);
			break;
		Default:
			Log("Specified wrong spawn number (Maybe too high, maybe script-error");
	}

}

event Touch( actor Other)
{
	local vector vectus, targot;

	if ( Botz(Other) != none )
	{
		if ( bUseDir)
		{
			if ( Pawn(Other).MoveTarget != none ) //Decidir la direccion
				targot = Pawn(Other).MoveTarget.Location;
			else
			{
				if ( Botz(Other).SpecialMoveTarget != none )
					targot = Botz(Other).SpecialMoveTarget.Location;
				else
					targot = Pawn(Other).Destination;
			}
			vectus = targot - Other.Location;
			if ( bAddZ) //Es un salto?
				vectus.Z = 0;
			vectus = normal( vectus);
			if ( Other.Physics == PHYS_Walking ) //Decidir la velocidad
				vectus *= Pawn(Other).GroundSpeed;
			else if ( Other.Physics == PHYS_Swimming )
				vectus *= Pawn(Other).WaterSpeed;
			else
				vectus *= Pawn(Other).AirSpeed;
		}
		if ( bAddZ ) //Es un salto?
			vectus.Z = Pawn(Other).Default.JumpZ * Level.Game.PlayerJumpZScaling();
		if ( bDoubleStrenght)
			vectus *= 2;

		if ( (Other.Physics == PHYS_Walking) && bAddZ && !bDoubleStrenght ) //Esto es un salto normal
		{
			Other.PendingTouch = self;
			Other.PlaySound( Botz(Other).JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
			Other.Velocity = vectus;
			Other.SetPhysics( PHYS_Falling);
			Botz(Other).PlayInAir();
		}
		else if ( Other.Physics == PHYS_Swimming )
		{
			Other.Velocity = vectus;
			if ( bForceFall )
			{
				Other.PendingTouch = self;
				Other.SetPhysics( PHYS_Falling);
				Botz(Other).PlayOutOfWater();
			}
		}
		else
			Other.Velocity = vectus;
	}

	
}

defaultproperties
{
	bCollideActors=True
}
