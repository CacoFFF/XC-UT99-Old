//=============================================================================
// The "don't go this way" marker.
// This marker is generated after a bot is killed and will warn him for a while
// It's a way to prevent repetitive behaviour during attack runs.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_BaddingSpot expands InfoPoint;


var Botz Badder;
var MasterGasterFer BigBadder;
var Botz_BaddingSpot NextSpot;
var byte Team;

var NavigationPoint CachedN[63];
var int iCached;
var vector CachedLoc;
var float ScanDist;
var bool bMoveToTarget;
var bool bDieWithTarget;

var float CurrentCost;
var float CostDecRate;

state BotzActivated
{
	event Tick( float DeltaTime)
	{
		CurrentCost -= CostDecRate * DeltaTime;
		if ( CurrentCost <= 0 )
			GotoState('Deactivated');
	}
	event EndState()
	{
		local Botz_BaddingSpot B;
		if ( Badder != none )
		{
			Badder.BadCount--;
			if ( Badder.MyBads == self )
				Badder.MyBads = NextSpot;
			else
			{
				For ( B=Badder.MyBads ; B.NextSpot!=none ; B=B.NextSpot )
					if ( B.NextSpot == self )
					{
						B.NextSpot = NextSpot;
						break;
					}
			}
			NextSpot = none;
			Badder = none;
		}
	}
Begin:
Loop:
	if ( bDieWithTarget && (Target == none || Target.bDeleteMe || (Target.bIsPawn && Pawn(Target).Health <= 0)) )
	{
		GotoState('Deactivated');
		Stop;
	}
	if ( bMoveToTarget && (Target != none) )
		SetLocation( Target.Location);
	if ( Badder == none || Badder.bDeleteMe )
	{
		Badder = none;
		NextSpot = none;
		GotoState('Deactivated');
		Stop;
	}
	Sleep(0.0);
	Goto('Loop');
}

state MasterActivated
{
	event Tick( float DeltaTime)
	{
		if ( bDieWithTarget && (Target == none || Target.bDeleteMe || (Target.bIsPawn && Pawn(Target).Health <= 0)) )
		{
			GotoState('Deactivated');
			return;
		}
		if ( bMoveToTarget && (Target != none) )
			SetLocation( Target.Location);
		CurrentCost -= CostDecRate * DeltaTime;
		if ( CurrentCost <= 0 )
			GotoState('Deactivated');
	}
	event EndState()
	{
		local Botz_BaddingSpot B;

		if ( BigBadder.TeamBads[Team] == self )
			BigBadder.TeamBads[Team] = NextSpot;
		else
		{
			For ( B=BigBadder.TeamBads[Team] ; B.NextSpot!=none ; B=B.NextSpot )
				if ( B.NextSpot == self )
				{
					B.NextSpot = NextSpot;
					break;
				}
		}
		NextSpot = none;
	}
}

state Deactivated
{
	event BeginState()
	{
		NextSpot = BigBadder.PoolBads;
		BigBadder.PoolBads = self;
		bDieWithTarget = false;
		bMoveToTarget = false;
		ScanDist = Default.ScanDist;
	}
}

function Setup( Botz aBotz, Actor Tracked, vector StartAt, float TotalCost, float Duration)
{
	Target = Tracked;
	SetLocation( StartAt);
	CurrentCost = TotalCost;
	CostDecRate = TotalCost / Duration;
	if ( aBotz != none )
	{
		Badder = aBotz;
		Badder.BadCount++;
		NextSpot = Badder.MyBads;
		Badder.MyBads = self;
		GotoState('BotzActivated');
	}
	else
	{
		NextSpot = BigBadder.TeamBads[Team];
		BigBadder.TeamBads[Team] = self;
		GotoState('MasterActivated');
	}
}

function ApplyBadding()
{
	local int i;
	local float fct;
	local Botz B;

	if ( CachedLoc != Location )
		CacheNodes();
	if ( iCached == 0 )
		return;

	fct = CurrentCost / iCached;
	For ( i=0 ; i<iCached ; i++ )
		CachedN[i].Cost += fct;
}

function CacheNodes()
{
	local NavigationPoint N;
	iCached = 0;

	CachedLoc = Location;
	ForEach NavigationActors (class'NavigationPoint', N, ScanDist)
	{
		CachedN[iCached++] = N;
		if ( iCached == 63 )
			return;
	}
}

function Botz_BaddingSpot TargetedBad( actor aTarget)
{
	local Botz_BaddingSpot B;

	if ( aTarget == Target )
		return self;
	For ( B=NextSpot ; B!=none ; B=B.NextSpot )
		if ( B.Target == aTarget )
			return B;
}

defaultproperties
{
    ScanDist=640
}