//=============================================================================
// EventLink
//
// Rules:
// - I point to a single actor (Owner).
// - Owner must be set via 'Spawn'
// - My Tag is always equal to Owner's.
// - I do not exist without Owner
//=============================================================================
class EventLink expands EventChainSystem;

const XCS = class'XC_CoreStatics';

var() string EventList;

var EventChainHandler Handler;
var EventLink NextEvent;
var EventChainTriggerNotify NotifyList;
var int ReachCount;
var int AnalysisDepth;
var EventLink AnalysisRoot;
var XC_NavigationPoint AIMarker;

var() bool bRoot; //Can emit 'Trigger' notifications by direct action
var() bool bActive; //Can receive 'Trigger' notifications
var() bool bInProgress; //Is in the middle of scripted action
var() bool bDestroyMarker;


event XC_Init();


singular event Destroyed() //Singular is important to prevent reentrancy
{
	while ( NotifyList != None )
	{
		NotifyList.Destroy();
		NotifyList = NotifyList.NextNotify;
	}
	
	if ( (AIMarker != None) && (AIMarker.upstreamPaths[0] == -1 || AIMarker.Paths[0] == -1 || bDestroyMarker) ) //Useless marker
		DestroyAIMarker();
	
	ResetEvents();
	AnalyzedBy( none);
}

//========================== Notifications
//
function Reset()
{
	AnalysisDepth = 0;
	ReachCount = 0;
	AnalysisRoot = none;
}

function BeginEvent()
{
	bActive = true;
	bInProgress = true;
}

function EndEvent()
{
	bInProgress = false;
}


//========================== Modifiable Traits
//

//Set Root, Active, InProgress here
function Update(); 

//Initiate analysis of whatever this can trigger
function AnalyzedBy( EventLink Other); 

//Actor can initiate event chain by interacting with owner
function bool CanFireEvent( Actor Other)
{
	return false;
}

//Analysis wants to register this trigger notify (for Update notifications)
//If EventLink knows how to do this without a notify, override so it does nothing
function AutoRegisterNotify( name aEvent)
{
	RegisterNotify( aEvent);
}

//AutoNotify sent a notify signal due to owner emitting an event
function TriggerNotify( name aEvent)
{
	Update();
}

//Creates a NavigationPoint to mark this event
function CreateAIMarker()
{
	if ( AIMarker == None )
	{
		AIMarker = Spawn( class'XC_NavigationPoint', self, 'AIMarker');
		LockToNavigationChain( AIMarker, true);
		DefinePathsFor( AIMarker, Owner);
		AIMarker.Move( Normal(Location - AIMarker.Location) * 5);
	}
}

//Destroys AI marker
function DestroyAIMarker()
{
	if ( AIMarker != None )
	{
		LockToNavigationChain( AIMarker, false);
		AIMarker.Destroy();
		AIMarker = None;
	}
}

//Optional AI marker to defer to
function NavigationPoint DeferTo()
{
	return AIMarker;
}


//========================== Event digest
//
final function bool AddEvent( name InEvent)
{
	if ( (InEvent != '') && !HasEvent(InEvent) )
		EventList = EventList $ string(InEvent) $ ";";
}

final function bool HasEvent( name InEvent)
{
	return InStr( EventList, ";" $ string(InEvent) $ ";") >= 0;
}

final function bool ResetEvents()
{
	local string NextEvent;
	local EventLink E;
	local int i;
	local name aEvent;
	
	Reset();
	AnalysisDepth++;
	while ( EventList != "" )
	{
		EventList = Mid( EventList, 1);
		i = InStr( EventList, ";");
		if ( i > 0 )
		{
			aEvent = XCS.static.StringToName( Left(EventList,i) );
			if ( aEvent != '' )
			{
				ForEach DynamicActors( class'EventLink', E, aEvent)
					if ( E != self )
					{
						E.Reset();
						E.Update();
					}
			}
		}
	}
	AnalysisDepth--;
	EventList = ";";
}

final function AcquireEvents( EventLink From)
{
	local string RemainingEvents;
	local int i;
	
	For ( RemainingEvents=Mid(From.EventList,1) ; RemainingEvents!="" ; RemainingEvents=Mid(RemainingEvents,i+1) )
	{
		i = InStr( RemainingEvents, ";");
		AddEvent( XCS.static.StringToName( Left( RemainingEvents, i) ) );
	}
}

//========================== Event Analysis
// When analyzing upon destruction, all chained events lose their 'root'
//
final function AnalyzeEvent( name aEvent)
{
	local EventLink E, ERoot;

	if ( (aEvent != '') && !HasEvent(aEvent) )
	{
		AddEvent( aEvent);
		if ( !bDeleteMe )
		{
			ERoot = self;
			AutoRegisterNotify( aEvent);
		}
		AnalysisDepth++;
		ForEach DynamicActors( class'EventLink', E, aEvent)
		{
			E.AnalysisRoot = ERoot;
			E.ReachCount++;
			if ( E.AnalysisDepth == 0 ) //Never self
			{
				E.AnalyzedBy( ERoot);
				AcquireEvents( E);
			}
		}
		AnalysisDepth--;
	}
}

final function RegisterNotify( name aEvent)
{
	local EventChainTriggerNotify N;
	
	for ( N=NotifyList ; N!=None ; N=N.NextNotify )
		if ( N.Tag == aEvent )
			return;
	N = NotifyList;
	NotifyList = Spawn( class'EventChainTriggerNotify', self, aEvent, Location);
	NotifyList.NextNotify = N;
}

final function EventLink GetLastRoot()
{
	local EventLink Link;
	For ( Link=AnalysisRoot ; Link!=None && Link.AnalysisRoot!=None ; Link=Link.AnalysisRoot )	{}
	return Link;
}

final function bool RootInProgress()
{
	local EventLink Link;
	local bool bRootInProgress;
	
	//Coded for minimum unrealscript iteration count
	For ( Link=AnalysisRoot ; Link!=None && !bRootInProgress ; Link=Link.AnalysisRoot )
		bRootInProgress = Link.bInProgress;
			
	return bRootInProgress;
}


defaultproperties
{
     EventList=";"
     bActive=True
}
