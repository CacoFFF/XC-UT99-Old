class EL_Counter expands EL_GenericPropagator;

function Update()
{
	// Is this propagator still relevant?
	if ( (Counter(Owner) == None) || (Counter(Owner).NumToCount <= 0) )
		Destroy();
}

defaultproperties
{
     bLink=True
     bLinkEnabled=True
}
