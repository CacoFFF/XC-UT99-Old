// Fancy marker for targeted waypoints
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//===============================================================================
class DynaPlayerMarker expands InfoPoint;

var DynamiCBotzPlayer Player;

event Tick( float DeltaTime)
{
	local float fBest;
	local NavigationPoint N, Best;
	local vector aVec, Dir, org;

	if ( Player == None )
		return;
	
	if ( (Player.pCur != none) && Player.pCur.bDirectConnect )
	{
		Dir = Vector(Player.ViewRotation);
		ForEach AllActors (class'NavigationPoint', N)
		{
			if ( N == Player.pCur )
				continue;
			aVec = Normal( N.Location - Player.pCur.Location);
			if ( VSize( aVec + Dir) > fBest )
			{
				Best = N;
				fBest = VSize( aVec + Dir);
			}
		}

		if ( Best != none )
		{
			SetLocation( Best.Location);
			bHidden = false;
		}
	}
	else
		bHidden = true;
}



defaultproperties
{
    Texture=Texture'Engine.S_ClipMarker'
    SpriteProjForward=33
    DrawScale=1.5
}
