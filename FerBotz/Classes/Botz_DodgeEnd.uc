//=============================================================================
// End dodging node
// This is nothing but a marker.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_DodgeEnd expands Botz_NavigBase;

//Called after botZ decides this is the path to take
function bool PostPathEvaluate( botz other)
{
	local Botz_DodgeStart DodgeStart;

	if ( Other.Physics == PHYS_Walking && !other.PointReachable(Location) )
	{
		DodgeStart = Botz_DodgeStart(Other.FindCurrentPath());
		if ( DodgeStart != none )
		{
			PerformDodge( Other, DodgeStart);
			return true;
		}
	}
	return false;
}

function PerformDodge( BotZ Other, Botz_DodgeStart DodgeStart)
{
	Other.bHasToJump = false;
	Other.SetPhysics(PHYS_Falling);
	Other.Velocity = Other.HNormal( vector(DodgeStart.Rotation)) * Other.GroundSpeed * (1.51 + FRand() * (0.25+Other.Skill*0.05) ) + vect(0,0,164);
	if ( DodgeStart.Location.Z < Location.Z )
		Other.bSuperAccel = true;
	if ( VSize( Other.HNormal(Other.Velocity) - vector(Other.Rotation) ) < 0.5 )
			Other.PlayFlip();
	else if ( VSize( Other.HNormal(Other.Velocity) - vector(Other.Rotation) ) > 1.84)
		Other.TweenAnim('DodgeB', 0.35);
	else
	{
		if ( vector(Other.Rotation - Rotator(Other.Velocity)).Y > 0 )
			Other.PlayDodge( False);
		else
			Other.PlayDodge( True);
	}
	Other.PlaySound(Other.JumpSound, SLOT_Talk, 1.0, true, 800, 1.0 );
}

defaultproperties
{
	FriendlyName="Dodge End"
	MaxDistance=950
	ExtraCost=10
	bSpecialCost=True
}