//=============================================================================
// EL_SpecialPath
//
// TODO: Expand or remove
//=============================================================================
class EL_SpecialPath expands EventLink;

native(519) final function describeSpec(int iSpec, out Actor Start, out Actor End, out int ReachFlags, out int Distance); 


//Do not create generic AI marker
function CreateAIMarker()
{
}


function int CreateReachSpec( optional ReachSpec R)
{
	local int rIdx;
	
	rIdx = FindReachSpec( None, None);
	if ( rIdx == -1 )
		rIdx = AddReachSpec( R, true);
	else	
		SetReachSpec( R, rIdx, true);
	return rIdx;
}


// Post route mapping, finds cost to reaching this path (also checks adjacents in case this is blocked)
function int LowestReachableWeight( NavigationPoint N)
{
	local int i;
	local int Best;
	local Actor Start, End;
	local int ReachFlags, Distance;
	
	Best = GetWeight(N);
	For ( i=0 ; i<16 && N.upstreamPaths[i] >= 0 ; i++ )
	{
		describeSpec( N.upstreamPaths[i], Start, End, ReachFlags, Distance);
		if ( NavigationPoint( Start) != None )
			Best = Min( GetWeight(NavigationPoint(Start)) + Distance, Best);
	}
	return Best;
}

function int GetWeight( NavigationPoint N)
{
	if ( N.StartPath == None )
		return 10000000;
	return N.VisitedWeight;
}


/*
native final function bool GetReachSpec( out ReachSpec R, int Idx);
native final function bool SetReachSpec( ReachSpec R, int Idx, optional bool bAutoSet);
native final function int ReachSpecCount();
native final function int AddReachSpec( ReachSpec R, optional bool bAutoSet); //Returns index of newle created ReachSpec
native final function int FindReachSpec( Actor Start, Actor End); //-1 if not found, useful for finding unused specs (actor = none)
native final function CompactPathList( NavigationPoint N); //Also cleans up invalid paths (Start or End = NONE)
native final function LockToNavigationChain( NavigationPoint N, bool bLock);
native final function iterator AllReachSpecs( out ReachSpec R, out int Idx); //Idx can actually modify the starting index!!!
*/