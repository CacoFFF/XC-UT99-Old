class EL_Dispatcher expands EventLink;

var(EventLink) bool bOldProgress;

function Update()
{
	local Dispatcher D;
	
	// Is this Dispatcher still relevant?
	D = Dispatcher(Owner);
	if ( D == None )
	{
		Destroy();
		return;
	}
	
	bRoot = false;
	bActive = true;
	bOldProgress = bInProgress;
	bInProgress = D.LatentFloat > 0;
	
	if ( bInProgress )
		SetTimer( D.LatentFloat + 0.001, false);
	if ( bOldProgress && !bInProgress )
		EndEvent();
}

function AnalyzedBy( EventLink Other)
{
	local Dispatcher D;
	
	D = Dispatcher(Owner);
	Assert( D != None);
	AnalyzeEvent( D.OutEvents[0]);
	AnalyzeEvent( D.OutEvents[1]);
	AnalyzeEvent( D.OutEvents[2]);
	AnalyzeEvent( D.OutEvents[3]);
	AnalyzeEvent( D.OutEvents[4]);
	AnalyzeEvent( D.OutEvents[5]);
	AnalyzeEvent( D.OutEvents[6]);
	AnalyzeEvent( D.OutEvents[7]);
}

function AutoRegisterNotify( name aEvent)
{
}

function Trigger( Actor Other, pawn EventInstigator )
{
	if ( !bOldProgress )
		BeginEvent();
}

event Timer()
{
	Update();
}





