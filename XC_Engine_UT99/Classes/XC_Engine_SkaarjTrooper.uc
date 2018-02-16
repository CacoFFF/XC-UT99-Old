class XC_Engine_SkaarjTrooper expands SkaarjTrooper
	abstract;

native(3552) final iterator function CollidingActors( class<actor> BaseClass, out actor Actor, float Radius, optional vector Loc);
	
function StartUp_BeginState()
{
	local Weapon W;

	Super.BeginState();
	bIsPlayer = true; // temporarily, till have weapon
	if ( WeaponType != None )
	{
		bIsPlayer = true;
		myWeapon = Spawn(WeaponType, self);
		//If weapon has been replaced, find it using the collision grid
		//LCWeapons replacer will not trigger this
		if ( myWeapon == None || myWeapon.bDeleteMe )
		{
			ForEach CollidingActors( class'Weapon', W, CollisionRadius + WeaponType.default.CollisionRadius ) //Because the level may adjust the location of this item
				if ( W.Owner == self )
				{
					myWeapon = W;
					break;
				}
		}
		if ( myWeapon != None )
			myWeapon.ReSpawnTime = 0.0;
	}
}