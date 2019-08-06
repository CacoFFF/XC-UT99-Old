//=============================================================================
// EventDetractorPath.
//
// Event Chain system's basic detractor
//
// Added as a proxy to a NavigationPoint in order to control access to it.
// Takes paths that go into TargetPath, and reroutes them into itself.
// Then connects itself into TargetPath (if copies taken)
//
// In order to detect a possible destruction of TargetPath, this actor will be
// based in TargetPath, and destruction will be detected via BaseChange
//
// Ideally, a Detractor should have an Attractor as counterpart.
// Additionally, Detractors are always one way routes
//=============================================================================
class EventDetractorPath expands EventModifierPath;

//
// Route/AI modifiers
//
event int SpecialCost( Pawn Seeker)
{
//	Log( OwnerEvent.ChainInProgress(true) @ OwnerEvent.bLink @ EnablerEvent.bInProgress @ EnablerEvent.bRoot @ EnablerEvent.bRootEnabled);
	
	if ( (OwnerEvent == None)   || OwnerEvent.ChainInProgress(true) || !OwnerEvent.bLink 
	  || (EnablerEvent == None) || EnablerEvent.bInProgress         || !EnablerEvent.bRoot || !EnablerEvent.bRootEnabled
	  || (Scout(Seeker) != None) ) //Scouts should bypass this detractor
		return 0;
	return 10000000;
}

event Actor SpecialHandling( Pawn Other)
{
	if ( TargetPath != None ) //When Detractor allows going thru here, let TargetPath handle the route
		return TargetPath.SpecialHandling( Other);
}

function Setup( NavigationPoint InTargetPath, EventLink InOwnerEvent, EventLink InEnablerEvent)
{
	local EventDetractorPath EDP;
	local NavigationPoint TargetLink;

	Assert( TargetPath == None);
	Super.Setup( InTargetPath, InOwnerEvent, InEnablerEvent);

	//We assume all previous Detractors are already properly linked
	TargetLink = TargetPath; 
	ForEach DynamicActors( class'EventDetractorPath', EDP)
		if ( (EDP.TargetPath == TargetPath) && (EDP != self) )
			TargetLink = EDP;
			
	OwnerEvent.DetractorUpdate( self);
	OwnerEvent.SpecialConnectNavigationPoints( self, TargetLink);
}


// A NavigationPoint may have more than one detractor, it's necessary to notify them of destruction.
event Destroyed()
{
	local EventDetractorPath EDP;
	local array<EventDetractorPath> Detractors;
	local int i, iEDP;
	
	Super.Destroyed();
	
	if ( (TargetPath != None) && (OwnerEvent != None) )
	{
		//Pass 1: unlink all Detractors leading to TargetPath (self and others)
		ForEach DynamicActors( class'EventDetractorPath', EDP)
			if ( EDP.TargetPath == TargetPath )
			{
				OwnerEvent.CleanupNavOutgoing( EDP);
				if ( EDP != self )
					Detractors[iEDP++] = EDP;
			}
				
		//Pass 2: give my UpstreamPaths back to TargetPath (Pass 1 needed to guarantee free path slots)
		RestorePaths();
			
		//Pass 3: re-check TargetPath with the other detractors
		for ( i=0 ; i<iEDP ; i++ )
			OwnerEvent.DetractorUpdate( Detractors[i]);

		//Pass 4: re-link detractors
		if ( iEDP > 0 )
			OwnerEvent.SpecialConnectNavigationPoints( Detractors[0], TargetPath);
		for ( i=1 ; i<iEDP ; i++ )
			OwnerEvent.SpecialConnectNavigationPoints( Detractors[i], Detractors[i-1]);
		TargetPath = None;
	}
}

//Transfer paths leading here towards TargetPath
function RestorePaths()
{
	local int i;
	
	if ( TargetPath == None || OwnerEvent == None )
		return;
	
	while ( i<16 && (upstreamPaths[i] >= 0) )
	{
		if ( OwnerEvent.GetReachSpec( OwnerEvent.DummyReachSpec, upstreamPaths[i]) && (OwnerEvent.DummyReachSpec.End == self) )
		{
			OwnerEvent.DummyReachSpec.End = TargetPath;
			OwnerEvent.SetReachSpec( OwnerEvent.DummyReachSpec, upstreamPaths[i], true);
		}
		else
			i++;
	}
}




