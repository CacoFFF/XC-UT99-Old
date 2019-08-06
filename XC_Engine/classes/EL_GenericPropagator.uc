class EL_GenericPropagator expands EL_GenericEvent;

function Update()
{
	// Is this propagator still relevant?
	if ( Owner == None || Owner.Event == '' )
		Destroy();
}

defaultproperties
{
     bLink=True
     bLinkEnabled=True
}
