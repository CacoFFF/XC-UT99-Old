
class XC_Engine_Queen expands Queen
	abstract;

//Let enemy off the hook if can't chase
//Attempt to chase using non-QueenDests
//Post-teleport rotation half-adjusted to enemy
	
native(3541) final iterator function NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint N, optional float Distance, optional vector VOrigin, optional bool bVisible);
native(3570) static final function vector HNormal( vector A);
native(3571) static final function float HSize( vector A);


function QT_Tick(float DeltaTime)
{
	local int NewFatness; 
	local rotator EnemyRot;
	local bool bOldBA, bOldBP;

	if ( Style == STY_Translucent )
	{
		ScaleGlow -= 3 * DeltaTime;
		if ( ScaleGlow < 0.3 )
		{
			Spawn(class'QueenTeleportEffect',,, TelepDest);
			Spawn(class'QueenTeleportLight',,, TelepDest);
			EnemyRot = rotator( HNormal(Enemy.Location - TelepDest) + HNormal(Enemy.Location - Location) );
			EnemyRot.Pitch = 0;
			if ( VSize(TelepDest - Location) < CollisionRadius * 0.5 )
			{
				if ( !LineOfSightTo(Enemy) && FRand()*10 > Aggressiveness ) //Default is 5
					Enemy = none;
			}
			bOldBA = bBlockActors;
			bOldBP = bBlockPlayers;
			SetCollision( bCollideActors, false, false);
			SetLocation(TelepDest); //Avoid telefragging pawns in vicinity
			SetCollision( bCollideActors, bOldBA, bOldBP);
			SetRotation(EnemyRot);
			PlaySound(sound'Teleport1', SLOT_Interface);
			GotoState('Attacking');
		}
		return;
	}
	else
	{
		NewFatness = fatness - 100 * DeltaTime;
		if ( NewFatness < 80 )
		{
			bUnlit = true;
			ScaleGlow = 2.0;
			Style = STY_Translucent;
		}
	}

	fatness = Clamp(NewFatness, 0, 255);
}


function QT_ChooseDestination()
{
	local NavigationPoint N;
	local QueenDest Q;
	local vector ViewPoint, Best;
	local float rating, newrating;

	//Typecast to access Enemy and TelepDest
	TelepDest = Location;
	if ( Enemy == None )
		return;

	Best = Location;
	rating = -999999;

	ForEach NavigationActors( class'QueenDest', Q)
	{
		ViewPoint = Q.Location + EyeHeight * vect(0,0,1);

		newrating = 20000 * int(FastTrace( Enemy.Location, ViewPoint));
		newrating = newrating - VSize(Q.Location - Enemy.Location) + 1000 * FRand() + 4 * VSize(Q.Location - Location);

		if ( Q.Location.Z > Enemy.Location.Z )
			newrating += 1000;
				
		if ( newrating > rating )
		{
			rating = newrating;
			Best = Q.Location;
		}
	}
	
	if ( rating < -999990 ) //Not found lol, let's make it crazier
	{
		ForEach NavigationActors( class'NavigationPoint', N, (Enemy.CollisionRadius+CollisionRadius) * 3, Enemy.Location, true) //Find furthest spot near the player
		{
			if ( N.Region.Zone.DamagePerSec > 0 || N.Region.Zone != Enemy.Region.Zone )
				continue;
			newrating = HSize( N.Location - Enemy.Location);
			if ( newrating < CollisionRadius - Enemy.CollisionRadius*3 )
				continue;
			if ( newrating > rating )
			{
				newrating = rating;
				Best = N.Location + vect(0,0,25);
			}
		}
	}
	TelepDest = Best;
}


