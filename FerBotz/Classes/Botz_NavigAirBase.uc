//=============================================================================
// Basic air node
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_NavigAirBase expands Botz_NavigBase;

//Distance / 10 for normal WP's
//Full dist for air nodes
event EPathMode IsCandidateTo( Botz_NavigBase Other)
{
	if ( !Other.IsA('Botz_NavigAirBase') && (VSize(Other.Location - Location) > MaxDistance * 0.1) )
		return PM_None;
	if ( PathVisible( Self, Other) )
		return PM_Forced;
	return PM_None;
}

//Distance / 10
event EPathMode OtherIsCandidate( NavigationPoint Nav)
{
	if ( VSize(Nav.Location - Location) < MaxDistance * 0.1 )
	{
		if ( Super.OtherIsCandidate( Nav) != PM_None )
			return PM_Forced;
	}
	return PM_None;
}

defaultproperties
{
	FriendlyName="Base Air Node"
	MaxDistance=3500
	bFlying=True
}