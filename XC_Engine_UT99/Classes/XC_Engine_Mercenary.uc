class XC_Engine_Mercenary expands Mercenary
	abstract;

function Tw_SprayTarget()
{
	local vector EndTrace, fireDir;
	local vector HitNormal, HitLocation;
	local actor HitActor;
	local rotator AdjRot;
	local vector X,Y,Z;

//	log ("Tw_SprayTarget");
	AdjRot = Rotation;
	if ( AnimSequence == 'Dead5' )
		AdjRot.Yaw += 3000 * (2 - sprayOffset);
	else
		AdjRot.Yaw += 1000 * (3 - sprayOffset);
	sprayoffset++;
	fireDir = vector(AdjRot);
	if ( (sprayoffset == 1) || (sprayoffset == 3) || (sprayoffset == 5) )
	{
		GetAxes(Rotation,X,Y,Z);
		if ( AnimSequence == 'Spray' )
			spawn(class'MercFlare', self, '', Location + 1.25 * CollisionRadius * X - CollisionRadius * (0.2 * sprayoffset - 0.3) * Y);
		else
			spawn(class'MercFlare', self, '', Location + 1.25 * CollisionRadius * X - CollisionRadius * (0.1 * sprayoffset - 0.1) * Y);
	}
	if ( AnimSequence == 'Dead5' )
		sprayoffset++;
	EndTrace = Location + 2000 * fireDir;
	if ( Target != None )
	{
		EndTrace.Z = Target.Location.Z + Target.CollisionHeight * 0.6;
		HitActor = TraceShot(HitLocation,HitNormal,EndTrace,Location);
		if ( HitActor != None ) //Does it hit something, genius ???
		{
			if ( HitActor == Level ) // Hit a wall
			{
				spawn(class'SmallSpark2',,,HitLocation+HitNormal*5,rotator(HitNormal*2+VRand()));
				spawn(class'SpriteSmokePuff',,,HitLocation+HitNormal*9);
			}
			else if ( HitActor != self && HitActor != Owner )
			{
				HitActor.TakeDamage(10, self, HitLocation, 10000.0*fireDir, 'shot');
				spawn(class'SpriteSmokePuff',,,HitLocation+HitNormal*9);
			}
		}
	}
}