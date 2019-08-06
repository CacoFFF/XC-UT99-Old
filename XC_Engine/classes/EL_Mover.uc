class EL_Mover expands EL_GenericPropagator;

const EMH = class'EngineMoversHandler';
var Pawn TmpSeeker;

//Optional AI marker to defer to
function NavigationPoint DeferTo()
{
	if ( (Mover(Owner) != None) && (Mover(Owner).myMarker != None) )
		return Mover(Owner).myMarker;
	return AIMarker;
}

function Update()
{
	local Mover M;
	local name MState;
	local bool bTouchable;
	
	// Is this mover still relevant?
	M = Mover(Owner);
	if ( !EMH.static.IsMoverRelevant(M) )
	{
		Destroy();
		return;
	}

	bRoot = false;
	bLink = false;
	bLinkEnabled = false;
	bInProgress = false;
	if ( !EMH.static.IsKnownState(M) )
		return;

	MState = class'XC_EngineStatics'.static.GetState( M);
	bTouchable = (MState == 'StandOpenTimed') || (MState == 'BumpOpenTimed') || (MState == 'BumpButton');
	bRoot = bTouchable || M.BumpEvent == Tag || M.PlayerBumpEvent == Tag;

	if ( !bTouchable )
	{
		bLink = (M.Tag != '');
		if ( MState == 'TriggerOpenTimed' )
			bLinkEnabled = !M.bDelaying && !M.bInterpolating && M.KeyNum == 0;
		else if ( (MState == 'TriggerControl') || (MState == 'TriggerPound') )
			bLinkEnabled = !M.bInterpolating && (M.KeyNum + 1 < M.NumKeys);
		else if ( (MState == 'TriggerToggle') )
			bLinkEnabled = !M.bInterpolating && !M.bDelaying;
		bInProgress = !bLinkEnabled;
	}
	else if ( bRoot )
	{
		bInProgress = M.bDelaying || M.bInterpolating || M.KeyNum > 0;
		bRootEnabled = !bInProgress;
	}
	
	if ( M.LatentFloat > 0 ) //Re-enter
		SetTimer( M.LatentFloat + 0.01, false);
	else if ( bInProgress )
		SetTimer( 0.2, false);
}


//Detractor wants this EventLink to grab paths leading to its marked TargetPath and redirect them
//ReachSpecs going through this mover will be redirected
//Additionally, 'Instigator' is the pawn that triggered this search (increases chance of blocking a reachspec)
function DetractorUpdate( EventDetractorPath EDP)
{
	local int i, iReach;
	local ReachSpec R;
	local vector HitLocation, HitNormal;
	local Actor A;
	local bool bHit, bMove;
	local vector OffsetNormal;
	
	if ( EDP == None || EDP.TargetPath == None )
		return;
	bMove = EDP.UpstreamPaths[0] == -1;
		
	CompactPathList(EDP.TargetPath);
	For ( i=0 ; i<16 && EDP.TargetPath.upstreamPaths[i]>=0 ; i++ )
		if ( GetReachSpec( R, EDP.TargetPath.upstreamPaths[i]) 
		&& (R.End == EDP.TargetPath) && (R.Start != None) && (EventDetractorPath(R.Start) == None) )
		{
			bHit = false;
			ForEach R.End.TraceActors( class'Actor', A, HitLocation, HitNormal, R.Start.Location, R.End.Location, vect(17,17,39))
				if ( A == self || A == Instigator )
				{
					bHit = true;
					break;
				}
				
			if ( !bHit ) //Try simple line in opposite direction
				ForEach R.Start.TraceActors( class'Actor', A, HitLocation, HitNormal, R.End.Location)
					if ( A == self || A == Instigator )
					{
						bHit = true;
						break;
					}
	
			if ( bHit )
			{
				R.End = EDP;
				SetReachSpec( R, EDP.TargetPath.upstreamPaths[i--], true);
				OffsetNormal += Normal( R.End.Location - R.Start.Location);
			}
		}
	if ( bMove )
		EDP.SetLocation( EDP.TargetPath.Location + Normal(OffsetNormal) * 5);
}
