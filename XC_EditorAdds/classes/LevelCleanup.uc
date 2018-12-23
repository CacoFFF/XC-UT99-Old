//====================================================
// XC_Core level cleanup utility
//
// This will unreference any texture off brush faces
// that aren't visible due to BSP rebuild.
//
// It'll also shrink the Actor list.
//====================================================
class LevelCleanup expands BrushBuilder;

event bool Build()
{
	local LevelInfo LI;
	local Actor A, SelectedActor;
	local Camera C;
	local float CDist;
	local string Output, CRLF;
	local vector Delta;
	
	ForEach class'XC_CoreStatics'.static.AllObjects( class'LevelInfo', LI)
		if ( !LI.bDeleteMe )
			break;
			
	return BadParameters( class'XC_CoreStatics'.static.CleanupLevel(LI.XLevel) );
}

defaultproperties
{
	ToolTip="Cleanup Level"
	BitmapFilename="BBLevelCleanup"
}
