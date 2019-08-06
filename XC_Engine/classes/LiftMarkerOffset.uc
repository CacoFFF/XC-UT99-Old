//=============================================================================
// LiftMarkerOffset.
//
// Attracts a pawn towards this point without using Pawn.Destination variable.
// Not serialized for savegames.
//=============================================================================
class LiftMarkerOffset expands XC_Engine_Actor
	transient;

var NavigationPoint Marker;
var Pawn Attract;
var vector Offset;

static function LiftMarkerOffset Setup( NavigationPoint Marker, Pawn Attract, vector Offset)
{
	local LiftMarkerOffset LMO;
	
	ForEach Marker.DynamicActors( class'LiftMarkerOffset', LMO, Attract.Name)
		if ( (LMO.Marker == Marker) && (LMO.Attract == Attract) )
		{
			LMO.Offset = Offset;
			LMO.LifeSpan = LMO.default.LifeSpan;
			return LMO;
		}

	LMO = Marker.Spawn( class'LiftMarkerOffset', None, Attract.Name, Marker.Location + Offset);
	LMO.SetBase( Marker);
	return LMO;
}




defaultproperties
{
     LifeSpan=5
}
