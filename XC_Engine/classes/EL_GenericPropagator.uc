class EL_GenericPropagator expands EventLink;

function Update()
{
	// Is this propagator still relevant?
	if ( Owner == None )
	{
		Destroy();
		return;
	}
	
	bRoot = false;
	bActive = true;
	bInProgress = false;
}

function AnalyzedBy( EventLink Other)
{
	Assert( Owner != None);
	AnalyzeEvent( Owner.Event);
}
