class EL_GenericEvent expands EventLink;

function Update()
{
	if ( Owner == None || Owner.Event == '' )
		Destroy();
}

function AnalyzedBy( EventLink Other)
{
	Assert( Owner != None);
	AnalyzeEvent( Owner.Event);
}
