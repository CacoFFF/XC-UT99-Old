//=============================================================================
// Quantum fighter jet handler!
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class FP_JetG expands FlightProfileBase;

var Projectile GuidedJet;
var bool bHadJet; //Just in case
var float JetVelocity;

native(3555) static final operator(22) Actor Or (Actor A, skip Actor B); //Supports object, but we're hacking it here for Actor

function BotzUpdate( Botz B, float DeltaTime)
{
	Super.BotzUpdate( B, DeltaTime); //Detach?
	if ( Item == none )
	{
		GuidedJet = none;
		bHadJet = false;
		return;
	}
	if ( B.CurFlight == self && B.Physics == PHYS_None )
	{
		if ( !B.bHidden || B.Health <= 0 )
			ForceEndFlight( B);
	}

}

function ForceEndFlight( Botz B)
{
	B.CurFlight = none;
	if ( (B.Health > 0) && (B.Physics == PHYS_None) )
	{
		B.BFM.SetVisibleAndValid( B);
		B.SpecialMoveTarget = none;
		B.SetMovementPhysics();
	}
	GuidedJet = none;
	bHadJet = false;
	if ( (Item != none) && Item.IsInState('Guiding') )
		Item.GotoState('Idle');
}

//Criterias:
//50 + (abs(Turn angle cosine - 1) * 150) free space around for turns
function bool ValidateRoute( Botz B)
{
	local int i;
	local vector aVec, tNormal;
	local float turnSize;

//	if ( B.DummyPawn == none )
		return false;
	if ( Weapon(Item) == none || (Weapon(Item).AmmoType == none) || (Weapon(Item).AmmoType.AmmoAmount <= 0) )
		return false;

	For ( i=1 ; i<15 ; i++ )
	{
		if ( B.RouteCache[i+1] == none ) //Ignore last path
			break;
		if ( B.RouteCache[i] != none )
		{
			if ( !FlightSegment( B.RouteCache[i-1], B.RouteCache[i]) ) //Can walk thru this place
				continue;
			aVec = Normal( B.RouteCache[i-1].Location - B.RouteCache[i].Location)
			 + Normal( B.RouteCache[i+1].Location - B.RouteCache[i].Location);
			if ( aVec != vect(0,0,0) )
			{
				turnSize = 50 + VSize( aVec) * 150;
				tNormal = Normal( aVec);
				aVec = B.RouteCache[i].Location;
				if ( !B.RouteCache[i].FastTrace( aVec + tNormal * turnSize) || !B.RouteCache[i].FastTrace( aVec - tNormal * turnSize) )
					return false;
			}
		}
	}
	return true;
}


function bool HandleFlight( Botz B, float DeltaTime)
{
	if ( GuidedJet != none )
	{
		B.SetLocation( GuidedJet.Location);
		if ( GuidedJet.bDeleteMe || !B.bHidden ) //Rocket ended flight prematurely
		{
			ForceEndFlight( B);
			return false;
		}
		B.LifeSignal(2);
		GuidedJet.SetPropertyText("ServerUpdate", string(B.Level.TimeSeconds) );
		if ( B.SpecialMoveTarget != none )
			SetJetAccel( B, DeltaTime);
		return true;
	}
	else if ( bHadJet ) //Jet was lost
	{
		if ( CatchJet( B) )
		{
			Log("Recovering jet");
			return true;
		}
		bHadJet = false;
		return true;
	}
	else
	{
		if ( Weapon(Item) == none )
			return false;
		if ( (Weapon(Item).AmmoType == none) || (Weapon(Item).AmmoType.AmmoAmount <= 0) ) //Validate
		{
			ForceEndFlight( B);
			return false;
		}
		if ( B.Weapon != Item )
		{
			if ( B.PendingWeapon != Item )
			{
				B.PendingWeapon = Weapon(Item);
				if ( B.Weapon == none )
				{
					B.Weapon = B.PendingWeapon;
					B.Weapon.BringUp();
				}
				else
					B.Weapon.PutDown();
			}
			return false;
		}
		if ( IsOnFlightPath(B) )
		{
			StartJet( B);
			return true;
		}
	}
}


function StartJet( Botz B)
{
	local PlayerReplicationInfo PRI;

/*	B.DummyPawn.ViewRotation = rotator( B.RouteCache[0].Location - B.Location);
	PRI = B.DummyPawn.PlayerReplicationInfo;
	B.DummyPawn.PlayerReplicationInfo = B.PlayerReplicationInfo;
	Item.SetOwner(B.DummyPawn);
	Weapon(Item).Fire(1); //Spawn the jet
	Item.SetOwner(B);
	B.DummyPawn.PlayerReplicationInfo = PRI;
	if ( !CatchJet(B.DummyPawn) )
		return;
	B.LifeSignal( 1);
	B.BFM.SetInvisiblaAndInvalid( B);
	B.SetPhysics( PHYS_None);
	GuidedJet.Disable('Tick');
	GuidedJet.Instigator = B;
	GuidedJet.SetOwner( B);
	GuidedJet.Velocity = Normal( (B.MoveTarget Or B.SpecialMoveTarget).Location - B.Location) * JetVelocity;
	GuidedJet.SetRotation( rotator(GuidedJet.Velocity) );
	GuidedJet.SetPropertyText("ServerUpdate", string(B.Level.TimeSeconds) );
	GuidedJet.SetPropertyText("Guider", string(B) );
	GuidedJet.RemoteRole = ROLE_SimulatedProxy;
	bHadJet = true;*/
}

function bool CatchJet( Actor A)
{
	local Projectile P;
	ForEach A.ChildActors( class'Projectile', P)
		if ( P.IsA('GuidedJetFighter') )
		{
			GuidedJet = P;
			return true;
		}
}


//SpecialMoveTarget assumed
function SetJetAccel( Botz B, float DeltaTime)
{
	local vector aVec;
	local vector X, Y, Z;
	local float ExtraFactor;

	aVec = B.SpecialMoveTarget.Location - GuidedJet.Location;
	GetAxes( rotator(aVec), X, Y, Z);
	GuidedJet.Velocity -= Y * (GuidedJet.Velocity dot Y) * (7+B.Skill) * DeltaTime * 0.5;
	GuidedJet.Velocity -= Z * (GuidedJet.Velocity dot Z) * (7+B.Skill) * DeltaTime * 0.5;
	if ( VSize(GuidedJet.Velocity) < JetVelocity * 0.9 )
		GuidedJet.Velocity = Normal( GuidedJet.Velocity) * JetVelocity * 0.85;
	else
	{
		ExtraFactor = VSize( Normal(GuidedJet.Velocity) + Normal(GuidedJet.Acceleration)) - 1; //-1 bad, 1 good
		GuidedJet.Velocity = Normal( GuidedJet.Velocity) * JetVelocity * (1 + ExtraFactor*0.1);
	}
	GuidedJet.SetRotation( rotator(GuidedJet.Velocity));
	if ( (VSize( aVec) < 120) ) //Temporary
	{
		B.PopRouteCache(true);
		if ( B.SpecialMoveTarget == none ) //EJECT
		{
			if ( Item.IsInState('Guiding') )
				Weapon(Item).DropFrom( B.Location);
			ForceEndFlight(B);
		}
	}
}

defaultproperties
{
    bOwnsFire=True
    bOwnsAim=True
    JetVelocity=650
}