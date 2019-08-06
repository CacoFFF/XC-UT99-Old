class EL_Trigger expands EL_GenericToucher;

var bool bAICheck;

function Update()
{
	local Trigger T;
	local float WaitTime;
	local name TState;
	
	// Is this trigger still relevant?
	T = Trigger(Owner);
	if ( (T == None) || !T.bCollideActors || (T.IsInState('OtherTriggerTurnsOff') && !T.bInitiallyActive) )
	{
		Destroy();
		return;
	}
	
	bRootEnabled = T.bInitiallyActive;
	TState = class'XC_EngineStatics'.static.GetState( T);
	bLink = (TState == 'OtherTriggerTurnsOn' && !T.bInitiallyActive)
		|| (TState == 'OtherTriggerTurnsOff' && T.bInitiallyActive)
		|| (TState == 'OtherTriggerToggles');
	bInProgress = (T.ReTriggerDelay > 0) && (Level.TimeSeconds - T.TriggerTime < T.ReTriggerDelay);
	if ( bInProgress )
		SetTimer( T.ReTriggerDelay - (Level.TimeSeconds - T.Triggertime) + 0.001, false);
	
	if ( NeedsMarker() )
		CreateAIMarker();
}

function bool CanFireEvent( Actor Other)
{
	if ( Trigger(Owner) != None )
		return Trigger(Owner).IsRelevant( Other);
	return false;
}

function bool NeedsMarker()
{
	local NavigationPoint N;
	local vector V;
	
	if ( !bAICheck )
	{
		bAICheck = true;
		V.X = Owner.CollisionHeight;
		V.Y = Owner.CollisionRadius;
		V.Z = 150;
		ForEach NavigationActors( class'NavigationPoint', N, VSize(V), Owner.Location)
			if ( N.upstreamPaths[0] != -1 )
				return false;
		return true;
	}
	return false;
}

//A pawn is at location or approaching us
function AIQuery( Pawn Seeker, NavigationPoint Nav)
{
	if ( (Trigger(Owner) != None) && (Trigger(Owner).TriggerType == TT_Shoot) )
	{
		Seeker.SpecialGoal = self;
		if ( Seeker.bCanDoSpecial && (Seeker.Weapon != None) )
		{
			Seeker.Target = self;
			Seeker.ViewRotation = rotator( Owner.Location - (Seeker.Location + vect(0,0,1)*Seeker.BaseEyeHeight));
			Seeker.Weapon.Fire( 1.0);
			Seeker.bFire = 0;
			Seeker.bAltFire = 0;
			if ( Trigger(Owner).DamageThreshold <= 50 )
				Owner.TakeDamage( 50, Seeker, Owner.Location, vect(0,0,0), 'shot');
		}
	}
}

defaultproperties
{
     bLinkEnabled=True
}