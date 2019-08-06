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

var() string EventList;

var EventChainHandler Handler;
var EventLink NextEvent;
var EventChainTriggerNotify NotifyList;
var int ReachCount;
var int AnalysisDepth;
var int PathModifiers;
var int QueryTag;
var EventLink AnalysisRoot;
var XC_NavigationPoint AIMarker;

var bool bStaticCleanup;
var bool bDestroying;
var bool bCleanupPending;
var() bool bRoot; //Can emit 'Trigger' notifications by direct action
var() bool bRootEnabled;
var() bool bLink; //Can receive 'Trigger' notifications
var() bool bLinkEnabled;
var() bool bInProgress; //Is in the middle of scripted action
var() bool bDestroyMarker;

event XC_Init();


event Destroyed()
{
	local EventModifierPath Modifier;
	local EventLink EL;

	if ( bDestroying )
		return;
	bDestroying = true;
		
	while ( NotifyList != None )
	{
		NotifyList.Destroy();
		NotifyList = NotifyList.NextNotify;
	}
		
	if ( (AIMarker != None) && (AIMarker.upstreamPaths[0] == -1 || AIMarker.Paths[0] == -1 || bDestroyMarker) ) //Useless marker
		DestroyAIMarker();
		
	CleanupEvents();
		
	if ( PathModifiers > 0 )
	{
		ForEach DynamicActors( class'EventModifierPath', Modifier)
			if ( Modifier.OwnerEvent == self || Modifier.EnablerEvent == self )
				Modifier.Destroy();
	}
}

//========================== Notifications
//

event Timer()
{
	Update();
}

event Trigger( Actor Other, Pawn EventInstigator)
{
	SetTimer( 0.001, false);
}

event Actor SpecialHandling( Pawn Other)
{
	if ( Owner != None )
		return Owner.SpecialHandling( Other);
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
	return bRoot && bRootEnabled && (Other != None);
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

//A pawn is at location or approaching us
function AIQuery( Pawn Seeker, NavigationPoint Nav);

//Creates a NavigationPoint to mark this event
function CreateAIMarker()
{
	if ( AIMarker == None )
	{
		AIMarker = Spawn( class'XC_NavigationPoint', self, 'AIMarker');
		LockToNavigationChain( AIMarker, true);
		DefinePathsFor( AIMarker, Owner);
		AIMarker.Move( Normal(Location - AIMarker.Location) * 4 );
		if ( Owner.Brush != None ) //More!
			AIMarker.Move( Normal(Location - AIMarker.Location) * 4 );
	}
}

//Destroys AI marker
function DestroyAIMarker()
{
	if ( AIMarker != None )
	{
		AIMarker.Destroy();
		AIMarker = None;
	}
}

//Optional AI marker to defer to
function NavigationPoint DeferTo()
{
	return AIMarker;
}

//Detractor wants this EventLink to grab paths leading to its marked TargetPath and redirect them
//SAMPLE FUNCTION: GRAB ALL REACHSPECS
function DetractorUpdate( EventDetractorPath EDP)
{
	local int i, iReach;
	local ReachSpec R;
	
	if ( EDP == None || EDP.TargetPath == None )
		return;

	CompactPathList(EDP.TargetPath);
	For ( i=0 ; i<16 && EDP.TargetPath.upstreamPaths[i]>=0 ; i++ )
		if ( GetReachSpec( R, EDP.TargetPath.upstreamPaths[i]) 
		&& (R.End == EDP.TargetPath) && (EventDetractorPath(R.Start) == None)
		/*&& ADDITIONAL CONDITIONS*/ )
		{
			R.End = EDP;
			SetReachSpec( R, EDP.TargetPath.upstreamPaths[i--], true);
		}

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

final function bool RemoveEvent( name InEvent)
{
	local int i;
	
	i = InStr( EventList, string(InEvent) $ ";");
	if ( i > 0 )
	{
		EventList = Left(EventList,i) $ Mid(EventList,i+Len(string(InEvent))+1);
		return true;
	}
}

final function CleanupEvents()
{
	local EventLink E;
	local int i;
	local name TmpEvent;
	local bool bRootCleanup;


	if ( bCleanupPending )
		return;
	bCleanupPending = true;
	
	bRootCleanup = !class'EventLink'.default.bStaticCleanup;
	class'EventLink'.default.bStaticCleanup = true;
	
	// Mark events related to self to be cleaned up.
	while ( (EventList != "") && bRootCleanup )
	{
		EventList = Mid( EventList, 1);
		i = InStr( EventList, ";");
		if ( i > 0 )
		{
			TmpEvent = XCS.static.StringToName( Left(EventList,i) );
			if ( TmpEvent != '' )
			{
				ForEach DynamicActors( class'EventLink', E, TmpEvent)
					E.CleanupEvents();
			}
		}
	}
	EventList = ";";
	
	// Queue single root for cleanup
	if ( AnalysisRoot != None )
	{
		ReachCount--;
		AnalysisRoot.CleanupEvents();
		AnalysisRoot = None;
	}

	// Workaround until CleanupDestroyed patch: queue all remaining roots
	if ( ReachCount > 0 )
	{
		ForEach DynamicActors( class'EventLink', E)
			if ( E.HasEvent(Tag) && (E != self) )
				E.CleanupEvents();
	}
	
	//Last step, done once
	if ( bRootCleanup )
	{
		ForEach DynamicActors( class'EventLink', E)
			if ( !E.bDestroying && E.bCleanupPending )
			{
				E.Update();
				if ( !E.bDeleteMe )
				{
					E.AnalysisRoot = None;
					E.ReachCount = 0;
					E.AnalysisDepth = 0;
					E.AnalyzedBy( None);
				}
			}
		ForEach DynamicActors( class'EventLink', E)
			E.bCleanupPending = false;
		class'EventLink'.default.bStaticCleanup = false;
	}
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

	if ( bDeleteMe || bDestroying )
		return;

	AnalysisDepth++;
	if ( (aEvent != '') && !HasEvent(aEvent) ) //Link events
	{
		AddEvent( aEvent);
		AutoRegisterNotify( aEvent);
		ForEach DynamicActors( class'EventLink', E, aEvent)
		{
			E.AnalysisRoot = self;
			E.ReachCount++;
			if ( E.AnalysisDepth == 0 ) //Never self
				E.AnalyzedBy( self);
		}
	}
	AnalysisDepth--;
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

final function EventLink GetFurthestRoot()
{
	local EventLink Link, LastValid;
	
	StartQuery();
	For ( Link=AnalysisRoot ; Link!=None && Link.ValidQuery() ; Link=Link.AnalysisRoot )
		LastValid = Link;
	return LastValid;
}

final function EventLink GetEnabledRoot()
{
	local EventLink Link;
	
	StartQuery();
	For ( Link=self ; Link!=None && Link.ValidQuery() ; Link=Link.AnalysisRoot )
		if ( Link.bRoot && Link.bRootEnabled )
			return Link;
	return None;
}

final function bool ChainInProgress( optional bool bNearestRootOnly)
{
	local EventLink Link;
	
	StartQuery();
	For ( Link=self ; Link!=None && Link.ValidQuery() ; Link=Link.AnalysisRoot )
	{
		if ( Link.bInProgress )
			return true;
		if ( bNearestRootOnly && Link.bRoot && (Link != self) )
			break;
	}
	return false;
}

final function bool RootIsEnabled()
{
	local EventLink Link;

	StartQuery();
	For ( Link=AnalysisRoot ; Link!=None && Link.ValidQuery() ; Link=Link.AnalysisRoot )
		if ( Link.bRoot )
			return Link.bRootEnabled;
	return false;
}

//Query macros
final function StartQuery()
{
	class'EventLink'.default.QueryTag++;
}
final function bool ValidQuery()
{
	local int OldTag;
	
	OldTag = QueryTag;
	QueryTag = class'EventLink'.default.QueryTag;
	return OldTag != QueryTag;
}

defaultproperties
{
     EventList=";"
}
