class EL_RoundRobin expands EventLink;


function Update()
{
	// Is this RoundRobin still relevant?
	if ( (RoundRobin(Owner) == None) || !Owner.bCollideActors )
		Destroy();
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

defaultproperties
{
     bLink=True
     bLinkEnabled=True
}
