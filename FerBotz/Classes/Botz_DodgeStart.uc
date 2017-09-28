//=============================================================================
// Start dodging node
// Should interconnect with nearest non-dodge path
// And with nearest dodgeEnd path
//
// Just make sure the DodgeEnd is VISIBLE!
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_DodgeStart expands Botz_NavigBase;

var NavigationPoint NearestFlat;
var Botz_DodgeEnd NearestEnd;


function EPathMode IsCandidateTo( Botz_NavigBase Other)
{
	local EPathMode eResult;

	if ( (Other.bSpecialCost && !Other.IsA('Botz_DodgeEnd') ) || Other.class == class )
		return PM_None;

	eResult = Super.IsCandidateTo(Other);
	if ( eResult > 0 )
	{
		if ( Other.IsA('Botz_DodgeEnd') )
			ConsiderDodge(Botz_DodgeEnd(Other));
		else
			ConsiderNormal( Other);
	}
	return PM_None;
}

function EPathMode OtherIsCandidate( NavigationPoint Nav)
{
	local EPathMode eResult;

	if ( Nav.IsA('Teleporter') )
		return PM_None;
	if ( (Nav.bSpecialCost && !Nav.IsA('Botz_DodgeEnd')) || Nav.class == class )
		return PM_None;
	eResult = Super.OtherIsCandidate(Nav);
	if ( eResult > 0 )
	{
		if ( Nav.IsA('Botz_DodgeEnd') )
			ConsiderDodge(Botz_DodgeEnd(Nav));
		else
			ConsiderNormal( Nav);
	}
	return PM_None;
}


function ConsiderNormal( NavigationPoint Other)
{
	if ( (NearestFlat != none) && (VSize(NearestFlat.Location - Location) < VSize(Other.Location - Location) ) )
		return;
	if ( (abs(Normal( Location - Other.Location).Z) < 0.17) || (VSize(Location - Other.Location) < 50) )
		if ( FastTrace(Other.Location) )
			NearestFlat = Other;
}

function ConsiderDodge( Botz_DodgeEnd Other)
{
	if ( (NearestEnd != none) && (VSize(NearestEnd.Location - Location) < VSize(Other.Location - Location) ) )
		return;
	if ( FastTrace(Other.Location) )
		NearestEnd = Other;
}

event int SpecialCost(Pawn Seeker)
{
	if ( Seeker.IsA('BotZ') )
		return 0;
	return 100000000;
}

//Create link between NearestFlat and self, then towards the DodgeEnd
event FinishedPathing()
{
	local Actor AA;
	local int iReachS;
	local int i;

	Super.FinishedPathing();
	
	if ( NearestFlat != none )
	{
		AddPathHere( self, NearestFlat, true);
		AddPathHere( NearestFlat, self, true);
	}
	if ( NearestEnd != none )
	{
		AddPathHere( self, NearestEnd, true);
		NearestEnd.bSpecialCost = false; //No need to keep this now, pruning already happened
	}
}

defaultproperties
{
	FriendlyName="Dodge Start"
	MaxDistance=950
	ExtraCost=10
	bPushSave=True
}