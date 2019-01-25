//====================================================
// XC_Engine path rebuilder shortcut
//====================================================
class PathRebuilder expands BrushBuilder;

var() name ReferenceTag;
var() bool bBuildAir;


event bool Build()
{
	local LevelInfo LI;
	local class<Actor> AC;
	local Pawn P, ScoutReference;
	
	ForEach class'XC_CoreStatics'.static.AllObjects( class'LevelInfo', LI)
		if ( !LI.bDeleteMe )
			break;
	
	if ( ReferenceTag != '' )
		ForEach LI.AllActors( class'Pawn', P, ReferenceTag)
		{
			ScoutReference = P;
			break;
		}
	
	return BadParameters( class'XC_CoreStatics'.static.PathsRebuild( LI.XLevel, ScoutReference, bBuildAir));
}

defaultproperties
{
	ToolTip="Path rebuilder [XC]"
	BitmapFilename="BBPathRebuilder"
	ReferenceTag=PathRebuilder
}
