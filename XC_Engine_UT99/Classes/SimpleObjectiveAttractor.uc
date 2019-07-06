//=============================================================================
// SimpleObjectiveAttractor.
//
// This will attract bots and make them wait here.
//=============================================================================
class SimpleObjectiveAttractor expands XC_NavigationPoint;

var Actor AttractTo;


function Actor SpecialHandling( Pawn Other)
{
	if ( (AttractTo != None) && (HSize(Other.Location - Location) < 10) && (AttractTo.Brush != None || AttractTo.bCollideActors) )
		return AttractTo;
	Other.SpecialGoal = Other;
	Other.SpecialPause = 1;
	return Other;
}

defaultproperties
{
     bPlayerOnly=True
}