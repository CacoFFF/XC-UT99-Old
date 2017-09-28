//=============================================================================
// FlightProfileBase.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class FlightProfileBase expands BotzExtension;

var Inventory Item;
var int BotIndex;
var bool bOwnsFire; //Do not use botz fire
var bool bOwnsAim; //Do not use botz rotation

function BotzUpdate( Botz B, float DeltaTime)
{
	if ( (Item == none) || Item.bDeleteMe || (Item.Owner != B) )
		DetachFromBotz( B);
}


//If handleflight returns false, let botz remain in normal UnStateMovement
function bool HandleFlight( Botz B, float DeltaTime);
function bool ValidateRoute( Botz B);
function ForceEndFlight( Botz B)
{
	B.CurFlight = none;
}

final function DetachFromBotz( Botz B)
{
	B.MasterEntity.AddFlightProf( self);
	if ( B.CurFlight == self )
		ForceEndFlight( B);
	//Redundant if same profile, but we still keep it
	B.FlightProfiles[BotIndex] = B.FlightProfiles[--B.iFlight];
	B.FlightProfiles[BotIndex].BotIndex = BotIndex;
	B.FlightProfiles[B.iFlight] = none;
	BotIndex = -1;

	Item = none;
}

//Checks if botz's current path is marked for air
final function bool IsOnFlightPath( Botz B)
{
	local NavigationPoint N;
	local Actor Start, End;
	local int ReachFlags, Distance, i;

	N = B.BFM.NearestNavig( B.Location, 200);
	if ( N == none )
		return false;
	For ( i=0 ; i<16 ; i++ )
	{
		if ( N.Paths[i] >= 0 )
		{
			N.describeSpec( N.Paths[i], Start, End, ReachFlags, Distance);
			if ( (End == B.RouteCache[0] || End == B.RouteCache[1]) && ((ReachFlags & 2) == 2) ) //Has air flag!
				return true;
		}
	}
}

final function bool FlightSegment( NavigationPoint A, NavigationPoint B)
{
	local Actor Start, End;
	local int ReachFlags, Distance, i;

	if ( A == none || B == none )
		return false;
	For ( i=0 ; i<16 ; i++ )
	{
		if ( A.Paths[i] >= 0 )
		{
			A.describeSpec( A.Paths[i], Start, End, ReachFlags, Distance);
			if ( (End == B) && ((ReachFlags & 2) == 2) ) //Has air flag!
				return true;
		}
	}
}

defaultproperties
{
     BotIndex=-1
}