class EventChainSystem expands FV_Addons
	abstract;

/** ================ Initialization
 *
 * General EventLink analysis functions.
*/
static final function StaticInit( XC_Engine_Actor XCGEA)
{
	local EventLink E;

	ForEach XCGEA.DynamicActors( class'EventLink', E)
	{
		E.Update();
		if ( !E.bDeleteMe )
			E.AnalyzedBy( None);
	}
}

/** ================ Utils
 *
 * GetEnabler       - Looks for an enabler using the Event Chain System.
 * GetEnablerActor  - Returns the actor said enabler corresponds to.
*/
static final function EventLink GetEnabler( Actor Other)
{
	local EventLink EL;
	local Actor A;
	
	Assert( Other != None );
	ForEach Other.DynamicActors( class'EventLink', EL, Other.Tag)
		if ( (EL.Owner == Other) && EL.bLink )
			return EL.GetEnabledRoot();
	return None;
}

static final function Actor GetEnablerActor( Actor Other)
{
	local EventLink Enabler;
	
	Enabler = GetEnabler( Other);
	if ( Enabler != None )
		return Enabler.Owner;
	return None;
}

/** ================ Reroute EndPoint
 *
 * Conditional path creation and reassignment based on analyzed events.
 *
 * OwnerEvent      - EventLink that controls path creation and reassignment.
 * TargetPaths     - List of EndPoints that need an alternate route to be reached.
 * Seeker          - Instigator of this action.
 * ForceEnabler    - Instigator wants this specific actor to be considered as primary Enabler.
 *
 * Event Attactor is a single instance of an actor that can force attraction towards multiple
 * locked destinations.
 *
 * Event Detractors are multiple intercepters between the TargetPaths and their upstream paths.
*/

static final function RerouteEndPoint( EventLink OwnerEvent, NavigationPoint TargetPath, Pawn Seeker, optional Actor ForceEnabler)
{
	local array<NavigationPoint> TargetPaths;
	
	if ( TargetPath != None )
	{
		TargetPaths[0] = TargetPath;
		RerouteEndPoints( OwnerEvent, TargetPaths, Seeker, ForceEnabler);
	}
}

static final function RerouteEndPoints( EventLink OwnerEvent, array<NavigationPoint> TargetPaths, Pawn Seeker, optional Actor ForceEnabler)
{
	local int i;
	local int PathCount;

	local EventLink EnablerEvent; //TODO: Multiple enabler support
	local EventDetractorPath EDP;
	local EventAttractorPath EAP;
	
	local Pawn OldInstigator;
	
	if ( OwnerEvent == None )
		return;

	PathCount = Array_Length( TargetPaths);
	if ( PathCount <= 0 )
		return;
	
	//Add a specific enabler
	if ( ForceEnabler != None )
	{
		ForEach ForceEnabler.ChildActors( class'EventLink', EnablerEvent)
			if ( EnablerEvent.bRoot )
			{
				EnablerEvent = EnablerEvent.GetEnabledRoot();
				break;
			}
	}
			
	//Find an enabler (using AnalysisRoot)
	if ( EnablerEvent == None )
	{
		EnablerEvent = OwnerEvent.GetEnabledRoot();
		if ( EnablerEvent == None )
			return;
	}
	
	//Setup or update attractor if needed
	ForEach EnablerEvent.DynamicActors( class'EventAttractorPath', EAP)
		if ( (EAP.OwnerEvent == OwnerEvent) && (EAP.EnablerEvent == EnablerEvent) )
			break;
	if ( EAP == None )
	{
		EAP = EnablerEvent.Spawn( class'EventAttractorPath',None,, EnablerEvent.Location);
		EAP.Setup( None, OwnerEvent, EnablerEvent);
	}
	EAP.AddAttractorDestinations( TargetPaths);
	
	//Update existing detractors
	OldInstigator = OwnerEvent.Instigator;
	OwnerEvent.Instigator = Seeker;
	ForEach OwnerEvent.DynamicActors( class'EventDetractorPath', EDP)
		if ( (EDP.OwnerEvent == OwnerEvent) && (EDP.EnablerEvent == EnablerEvent) )
		{
			For ( i=0 ; i<PathCount ; i++ )
				if ( EDP.TargetPath == TargetPaths[i] )
				{
					OwnerEvent.DetractorUpdate( EDP);
					TargetPaths[i] = TargetPaths[--PathCount];
					i = PathCount;
				}
		}
		
	//Setup missing detractors
	For ( i=0 ; i<PathCount ; i++ )
	{
		EDP = OwnerEvent.Spawn( class'EventDetractorPath', None, OwnerEvent.Tag, TargetPaths[i].Location + VRand(), TargetPaths[i].Rotation);
		EDP.Setup( TargetPaths[i], OwnerEvent, EnablerEvent);
	}
	OwnerEvent.Instigator = OldInstigator;
}
