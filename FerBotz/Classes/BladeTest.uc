//Experimental, for testing purposes

class BladeTest expands Razor2;


auto state Flying
{

	simulated function HitWall (vector HitNormal, actor Wall)
	{
		local vector Vel2D, Norm2D;

		bCanHitInstigator = true;
		PlaySound(ImpactSound, SLOT_Misc, 2.0);
		LoopAnim('Spin',1.0);
		if ( (Mover(Wall) != None) && Mover(Wall).bDamageTriggered )
		{
			if ( Role == ROLE_Authority )
				Wall.TakeDamage( Damage, instigator, Location, MomentumTransfer * Normal(Velocity), MyDamageType);
			Destroy();
			return;
		}
		NumWallHits++;
		SetTimer(0, False);
		MakeNoise(0.3);
		if ( NumWallHits > 6 )
			Destroy();

		if ( NumWallHits == 1 ) 
		{
			Log("HitNormal is"$HitNormal);
			Spawn(class'WallCrack',,,Location, rotator(HitNormal));
			Vel2D = Velocity;
			Vel2D.Z = 0;
			Norm2D = HitNormal;
			Norm2D.Z = 0;
			Norm2D = Normal(Norm2D);
			Vel2D = Normal(Vel2D);
			if ( (Vel2D Dot Norm2D) < -0.999 )
			{
				HitNormal = Normal(HitNormal + 0.6 * Vel2D);
				Norm2D = HitNormal;
				Norm2D.Z = 0;
				Norm2D = Normal(Norm2D);
				if ( (Vel2D Dot Norm2D) < -0.999 )
				{
					if ( Rand(1) == 0 )
						HitNormal = HitNormal + vect(0.05,0,0);
					else
						HitNormal = HitNormal - vect(0.05,0,0);
					if ( Rand(1) == 0 )
						HitNormal = HitNormal + vect(0,0.05,0);
					else
						HitNormal = HitNormal - vect(0,0.05,0);
					HitNormal = Normal(HitNormal);
				}
				Log("Adjusted HitNormal is"$HitNormal);
			}
		}
		Velocity -= 2 * (Velocity dot HitNormal) * HitNormal;  
		SetRoll(Velocity);
	}

}
