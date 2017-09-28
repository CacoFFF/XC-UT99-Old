//=============================================================================
// MasterMenuSpawnNotify.
// Notify every single projectile spawned
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_SpawnNotify expands SpawnNotify;

var BotzMutator MyMutator;


event Actor SpawnNotification(actor Actor)
{
	local playerpawn P;

	if ( Level.NetMode == NM_Client )
		return Actor; //AVOID IN CLIENTS, TESTING

	if ( Actor.bCollideActors )
		MyMutator.BPS.AddProj( Projectile(Actor) );

	return Actor;
}

defaultproperties
{
     bAlwaysRelevant=False
     RemoteRole=ROLE_None
     ActorClass=Class'Engine.Projectile'
}
