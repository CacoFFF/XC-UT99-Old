//=============================================================================
// XC_NavigationPoint
// XC_Engine extended navigation point
//=============================================================================
class XC_NavigationPoint expands NavigationPoint;

var transient XC_Engine_Actor XCGEA; //Must be reinitialized on saved games

event Destroyed()
{
	if ( XCGEA != None )
	{
		XCGEA.CleanupNavSpecs( Self);
		XCGEA.LockToNavigationChain( Self, false);
	}
}


defaultproperties
{
     bStatic=False
     bNoDelete=False
}