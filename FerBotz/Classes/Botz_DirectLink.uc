//=============================================================================
// DirectLinkType
// Targeted pathing to the Nav i'm aiming at
// Rejects all normal pathing, will take nearest flat for start point
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_DirectLink expands Botz_NavigBase;

#exec TEXTURE IMPORT NAME=BWP_Direct FILE=..\CompileData\BWP_Direct.bmp FLAGS=2

var NavigationPoint NearestFlat;
var NavigationPoint LinkedP;


//Do not do normal pathing, leave for End
function EPathMode IsCandidateTo( Botz_NavigBase Other)
{
	local EPathMode eResult;

	if ( Other.IsA('Botz_DirectLink') )
		return PM_None;

	eResult = Super.IsCandidateTo(Other);
	if ( eResult > 0 )
	{
		if ( (abs(Normal( Location - Other.Location).Z) < 0.17) || (VSize(Location - Other.Location) < 50) )  //Flat point or very close
		{
			if ( (NearestFlat == none) || (VSize(NearestFlat.Location - Location) > VSize(Location - Other.Location)) )
				NearestFlat = Other;
		}
	}
	return PM_None;
}
function EPathMode OtherIsCandidate( NavigationPoint Nav)
{
	local EPathMode eResult;

	if ( Nav.IsA('Botz_DirectLink') )
		return PM_None;

	eResult = Super.OtherIsCandidate(Nav);
	if ( eResult > 0 )
	{
		if ( (abs(Normal( Location - Nav.Location).Z) < 0.17) || (VSize(Location - Nav.Location) < 50) ) //Flat point or very close
		{
			if ( (NearestFlat == none) || (VSize(NearestFlat.Location - Location) > VSize(Location - Nav.Location)) )
				NearestFlat = Nav;
		}
	}
	return PM_None;
}

event FinishedPathing()
{
	local float fBest;
	local NavigationPoint N, Best;
	local vector aVec, Dir;

	if ( NearestFlat != none )
	{
		AddPathHere( self, NearestFlat, true);
		AddPathHere( NearestFlat, self, true);
	}

	Dir = Vector(Rotation);
	ForEach AllActors (class'NavigationPoint', N)
	{
		if ( N == self )
			continue;
		aVec = Normal( N.Location - Location);
		if ( VSize( aVec + Dir) > fBest )
		{
			Best = N;
			fBest = VSize( aVec + Dir);
		}
	}


	if ( best != none )
	{
		if ( !bOneWayOut )
			AddPathHere( self, best, true);
		if ( !bOneWayInc )
			AddPathHere( best, self, true);
		LinkedP = Best;
	}
	else
		Style = STY_Translucent;

}

defaultproperties
{
	FriendlyName="Direct Link"
	MaxDistance=600
	Texture=Texture'BWP_Direct'
	bPushSave=True
	bDirectConnect=True
}
