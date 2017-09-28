//==================================================================================
// Botz_TelePath
// Generates a link between these 2 paths in runtime
// To be used in Siege to link teleporters
//
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//==================================================================================

class Botz_TelePath expands Botz_NavigBase;


var Botz_TelePath OtherSide;
var StationaryPawn Tele;
var byte Team;

event int SpecialCost( Pawn Seeker)
{
	if ( taken )
		return 20000;
	if ( Seeker.PlayerReplicationInfo == none || Seeker.PlayerReplicationInfo.Team != Team )
		return 20000;
	return 0;
}

//Setup a connection with "Other" Botz_TelePath via "EventInstigator" sgTeleporter
event Trigger( actor Other, Pawn EventInstigator)
{
	local int iNew;
	if ( (Botz_TelePath(Other) != none) && EventInstigator.IsA('sgTeleporter') )
	{
		OtherSide = Botz_TelePath(Other);
		if ( CheckLoader() )
			OtherSide.MyLoader = MyLoader;
		Tele = StationaryPawn(EventInstigator);
		LockActor( true);
		iNew = UnusedReachSpec();
		if ( iNew < 0 )
			iNew = CreateReachSpec();
		EditReachSpec( iNew, Self, OtherSide,,, true);
		Paths[0] = iNew;
		OtherSide.UpstreamPaths[0] = iNew;
		PathCandidates();
		bSpecialCost = true;
		Team = int(Tele.GetPropertyText("Team"));
	}
}

event UnTrigger( actor Other, Pawn EventInstigator)
{
	if ( EventInstigator.IsA('sgTeleporter') )
	{
		LockActor( false);
		ClearAllPaths( self);
		OtherSide = none;
		Tele = none;
		Destroy();
	}
}

function bool CheckLoader()
{
	if ( MyLoader != none )
		return false;
	ForEach AllActors (class'Botz_PathLoader', MyLoader)
		return true;
	return false;
}


defaultproperties
{
	MaxDistance=750
	bNeverPrune=True
	ReservePaths=1
	ReserveUpstreamPaths=1
}