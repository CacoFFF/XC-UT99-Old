class EL_GenericToucher expands EL_GenericEvent;

function Update()
{
	// Is this propagator still relevant?
	if ( Owner == None || Owner.Event == '' )
	{
		Destroy();
		return;
	}
	
	bRoot = Owner.bCollideActors;
	bActive = Owner.bCollideActors;
	bInProgress = false;
}
