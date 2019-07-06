class EL_Trigger expands EL_GenericPropagator;

var bool bAICheck;

function Update()
{
	local Trigger T;
	
	// Is this trigger still relevant?
	T = Trigger(Owner);
	if ( (T == None) || !T.bCollideActors )
	{
		Destroy();
		return;
	}
	
	bRoot = T.bInitiallyActive;
	bActive = T.bInitiallyActive;
	bInProgress = (T.ReTriggerDelay > 0) && (Level.TimeSeconds - T.TriggerTime < T.ReTriggerDelay);
	
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


