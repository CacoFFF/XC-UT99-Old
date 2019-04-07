//=============================================================================
// PathNodeIterator_XCGE
//
// PathNodeIterator replacement code for Predator.u conversion
//=============================================================================

class PathNodeIterator_XCGE expands PathNodeIterator
	abstract;

/*
var NavigationPoint NodePath[ 64 ];
var int             NodeCount;
var int             NodeIndex;
var int             NodeCost;
var vector          NodeStart;
*/
	
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );
native(3540) final iterator function PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional Pawn StartAt);
native(3541) final iterator function NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint P, optional float Distance, optional vector VOrigin, optional bool bVisible);

function BuildPath_XC( vector Start, vector End )
{
	local Predator P;
	local NavigationPoint N;
	local XC_UPakPredator Caller;
	
	ForEach DynamicActors( class'XC_UPakPredator', Caller)
		break;
		
	if ( Caller == None )
		return;
	
	NodeIndex = 0;
	NodeCount = 0;
	NodeCost = 0;
	NodeStart = Start;
	NodePath[0] = None;
	P = Predator(Owner);
	if ( P == None )
		ForEach PawnActors( class'Predator', P, 10, Start)
		{
			SetOwner(P);
			break;
		}
	if ( (P != None) && (P.Location == Start) )
	{
		N = Caller.MapRoutes_PNI( P,, 'SetEndPoint');
		if ( N == None ) ForEach NavigationActors( class'NavigationPoint', N, 100, End, true) break;
		if ( N == None ) ForEach NavigationActors( class'NavigationPoint', N, 200, End, true) break;
		if ( N == None ) ForEach NavigationActors( class'NavigationPoint', N, 300, End, true) break;
		Caller.BuildRouteCache_PNI( N, NodePath);
		while ( (NodeCount < 64) && (NodePath[NodeCount] != None) )
			NodeCount++;
	}
}


function NavigationPoint GetFirst_XC()
{
	NodeIndex = 0;
	return GetCurrent();
}

function NavigationPoint GetPrevious_XC()
{
	NodeIndex--;
	return GetCurrent();
}

function NavigationPoint GetCurrent_XC()
{
	if ( (NodeIndex >= 0) && (NodeIndex < 64) )
		return NodePath[NodeIndex];
	return None;
}

function NavigationPoint GetNext_XC()
{
	NodeIndex++;
	return GetCurrent();
}

function NavigationPoint GetLast_XC()
{
	NodeIndex = NodeCount - 1;
	return GetCurrent();
}

