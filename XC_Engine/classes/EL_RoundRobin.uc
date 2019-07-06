class EL_RoundRobin expands EventLink;


function Update()
{
	local RoundRobin R;
	
	// Is this RoundRobin still relevant?
	R = RoundRobin(Owner);
	if ( (R == None) || !R.bCollideActors )
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
	local RoundRobin R;
	local int i;
	
	R = RoundRobin(Owner);
	Assert( R != None);
	for ( i=0 ; i<16 && (R.OutEvents[i] != '') ; i++ )
		AnalyzeEvent( R.OutEvents[i]);
}
