class XC_Engine_Decoration expands Decoration
	abstract;

singular function ZoneChange( ZoneInfo NewZone )
{
	local float splashsize;
	local actor splash;

	if( NewZone.bWaterZone )
	{
		if( bSplash && !Region.Zone.bWaterZone && Mass<=Buoyancy 
			&& ((Abs(Velocity.Z) < 100) || (Mass == 0)) && (FRand() < 0.05) /*&& !PlayerCanSeeMe() */ ) //Splash play a sound - which is audible anyway
		{
			bSplash = false;
			SetPhysics(PHYS_None);
		}
		else if( !Region.Zone.bWaterZone && (Velocity.Z < -200) )
		{
			// Else play a splash.
			splashSize = FClamp(0.0001 * Mass * (250 - 0.5 * FMax(-600,Velocity.Z)), 1.0, 3.0 );
			if( NewZone.EntrySound != None )
				PlaySound(NewZone.EntrySound, SLOT_Interact, splashSize);
			if( NewZone.EntryActor != None )
			{
				splash = Spawn(NewZone.EntryActor); 
				if ( splash != None )
					splash.DrawScale = splashSize;
			}
		}
		bSplash = true;
	}
	else if( Region.Zone.bWaterZone && (Buoyancy > Mass) )
	{
		bBobbing = true;
		if( Buoyancy > 1.1 * Mass )
			Buoyancy = 0.95 * Buoyancy; // waterlog
		else if( Buoyancy > 1.03 * Mass )
			Buoyancy = 0.99 * Buoyancy;
	}

	if( NewZone.bPainZone && (NewZone.DamagePerSec > 0) )
		TakeDamage(100, None, location, vect(0,0,0), NewZone.DamageType);
}

function Tw_Destroyed()
{
	local actor dropped, A;
	local class<actor> tempClass;

	if ( (Pawn(Base) != None) && (Pawn(Base).CarriedDecoration == self) )
		Pawn(Base).DropDecoration();
	if ( (Contents != None) && !Level.bStartup )
	{
		tempClass = Contents;
		if (Content2 != None && FRand()<0.3) tempClass = Content2;
		if (Content3 != None && FRand()<0.3) tempClass = Content3;
		dropped = Spawn(tempClass);
		if ( dropped != None )
		{
			dropped.RemoteRole = ROLE_DumbProxy;
			dropped.SetPhysics(PHYS_Falling);
			dropped.bCollideWorld = true;
			if ( Inventory(dropped) != None )
				Inventory(dropped).GotoState('Pickup', 'Dropped');
		}
	}

	if( Event != '' )
		foreach AllActors( class 'Actor', A, Event )
			A.Trigger( Self, None );

	if ( bPushSoundPlaying )
		PlaySound( EndPushSound, SLOT_Misc, 0.0);

	Super(Actor).Destroyed();
}

simulated function Tw_skinnedFrag(class<fragment> FragType, texture FragSkin, vector Momentum, float DSize, int NumFrags) 
{
	local int i;
	local Actor A;
	local Fragment s;

	if ( !bOnlyTriggerable )
	{
		if ( Event != '' ) //Original code is flawed, this keeps the same effect but cleaned up
			ForEach AllActors( class'Actor', A, Event )
				A.Trigger( None, None);
		if ( !Region.Zone.bDestructive )
		{
			For ( i=0 ; i<NumFrags ; i++ ) 
			{
				s = Spawn( FragType, Owner);
				if ( s != None )
				{
					s.CalcVelocity(Momentum/100,0);
					s.Skin = FragSkin;
					s.DrawScale = DSize*0.5+0.7*DSize*FRand();
				}
			}
		}
		Destroy();
	}
}

simulated function Tw_Frag(class<fragment> FragType, vector Momentum, float DSize, int NumFrags) 
{
	local int i;
	local actor A;
	local Fragment s;

	if ( !bOnlyTriggerable )
	{
		if ( Event != '' ) //Original code is flawed, this keeps the same effect but cleaned up
			foreach AllActors( class 'Actor', A, Event )
				A.Trigger( None, None);
		if ( !Region.Zone.bDestructive )
		{
			For ( i=0 ; i<NumFrags ; i++ ) 
			{
				s = Spawn( FragType, Owner);
				if ( s != None )
				{
					s.CalcVelocity(Momentum,0);
					s.DrawScale = DSize*0.5+0.7*DSize*FRand();
				}
			}
		}
		Destroy();
	}
}
