//=============================================================================
// EventAttractorPath.
//
// Event Chain system's basic attractor
//
// Added as a bridge between an EventLink's AI Marker and a set of destination
// NavigationPoint(s) in order to attract bots to the trigger that enables them.
//
// In order to detect a possible destruction of TargetPath, this actor will be
// based in TargetPath, and destruction will be detected via BaseChange
//
// Ideally, an Attractor should have a Detractor as counterpart.
// Additionally, Attractors are always one way routes
//=============================================================================
class EventAttractorPath expands EventModifierPath;


native(3538) final function NavigationPoint MapRoutes_SingleAnchor( Pawn Seeker, NavigationPoint StartAnchor, optional name RouteMapperEvent);

//
// Route/AI modifiers
//
event int SpecialCost( Pawn Seeker)
{
	if ( (OwnerEvent   == None) || OwnerEvent.ChainInProgress() || !OwnerEvent.bLink
	  || (EnablerEvent == None) || EnablerEvent.bInProgress     || !EnablerEvent.bRoot || !EnablerEvent.bRootEnabled
	  || (Scout(Seeker) != None) ) //Scouts should not use this attractor
		return 10000000;
	return 0;
}

event Actor SpecialHandling( Pawn Other)
{
	if ( EnablerEvent != None )
		EnablerEvent.AIQuery( Other, self);		

	if ( (EnablerEvent != None)
	&& (HSize(Other.Location - Location) < Other.CollisionRadius || VSize(Other.Location - Location) < Other.CollisionHeight)
	&& (EnablerEvent.Owner.Brush != None || EnablerEvent.Owner.bCollideActors) )
		return EnablerEvent.Owner;
		
	Other.SpecialGoal = Other;
	Other.SpecialPause = 1;
	return Other;
}

event SetEndPoint()
{
	if ( TargetPath != None )
		TargetPath.bEndPoint = true;
}

function Setup( NavigationPoint InTargetPath, EventLink InOwnerEvent, EventLink InEnablerEvent)
{
	local NavigationPoint DeferPoint;
	local int i;
	
	Super.Setup( InTargetPath, InOwnerEvent, InEnablerEvent);

	// Force creation of an AI Marker (marked for destruction after not needed)
	DeferPoint = EnablerEvent.DeferTo();
	if ( DeferPoint == None )
	{
		EnablerEvent.bDestroyMarker = true;
		EnablerEvent.CreateAIMarker();
		DeferPoint = EnablerEvent.DeferTo();
	}

	if ( DeferPoint != None )
	{
		SetLocation( DeferPoint.Location);
		EnablerEvent.SpecialConnectNavigationPoints( DeferPoint, self,, EnablerEvent.R_SPECIAL);
	}

	//Try locations outside of the level
	for ( i=10 ; i>0 && Region.ZoneNumber != 0 ; i-- )
		SetLocation( Location - vect(0,0,10));
	for ( i=15 ; i>0 && Region.ZoneNumber != 0 ; i-- )
		SetLocation( VRand() * 30000);
}


function AddAttractorDestinations( array<NavigationPoint> NewDestinations)
{
	local FV_Scout Scout;
	local int rIdx, Weight;
	local int i, DestinationCount;
	local NavigationPoint StartAnchor;
	local Name MapperEvent;
	
	StartAnchor = EnablerEvent.DeferTo();
	if ( StartAnchor == None )
		return;
		
	Scout = Spawn( class'FV_Scout');
	if ( Scout == None )
		return;
		
	//Optimize route mapping for finding a single navigaiton point
	DestinationCount = Array_Length( NewDestinations);
	if ( DestinationCount == 1 )
	{
		TargetPath = NewDestinations[0];
		MapperEvent = 'SetEndPoint';
	}
		
	MapRoutes_SingleAnchor( Scout, StartAnchor, MapperEvent);
	Scout.Destroy();
	
	For ( i=0 ; i<DestinationCount ; i++ )
	{
		Weight = Clamp( class'XC_NavigationPoint'.static.LowestReachableWeight(NewDestinations[i]) - 200, 1, 10000000 - 100000);
		rIdx = EnablerEvent.FindReachSpec( self, NewDestinations[i]);
		
		if ( rIdx >= 0 )
		{
			EnablerEvent.GetReachSpec( EnablerEvent.DummyReachSpec, rIdx);
			EnablerEvent.DummyReachSpec.Distance = Weight;
			EnablerEvent.SetReachSpec( EnablerEvent.DummyReachSpec, rIdx, true); //Update existing route
		}
		else
			EnablerEvent.SpecialConnectNavigationPoints( self, NewDestinations[i], Weight, EnablerEvent.R_SPECIAL);
	}
}

defaultproperties
{
     SpriteProjForward=48
}