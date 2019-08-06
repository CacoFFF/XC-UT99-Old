class EL_GenericToucher expands EL_GenericEvent;

function Update()
{
	// Is this propagator still relevant?
	if ( Owner == None || Owner.Event == '' )
		Destroy();
	else
		bRootEnabled = Owner.bCollideActors;
}

defaultproperties
{
     bRoot=True
}
