//=============================================================================
// EL_SpecialPath
//
// TODO: Expand or remove
//=============================================================================
class EL_SpecialPath expands EventLink;


//Do not create generic AI marker
function CreateAIMarker()
{
}



// Post route mapping, finds cost to reaching this path (also checks adjacents in case this is blocked)
static function int LowestReachableWeight( NavigationPoint N)
{
	local int i;
	local int Best;
	local Actor Start, End;
	local int ReachFlags, Distance;
	
	Best = GetWeight(N);
	For ( i=0 ; i<16 && N.upstreamPaths[i] >= 0 ; i++ )
	{
		N.describeSpec( N.upstreamPaths[i], Start, End, ReachFlags, Distance);
		if ( NavigationPoint( Start) != None )
			Best = Min( GetWeight(NavigationPoint(Start)) + Distance, Best);
	}
	return Best;
}

static function int GetWeight( NavigationPoint N)
{
	if ( N.StartPath == None )
		return 10000000;
	return N.VisitedWeight;
}

