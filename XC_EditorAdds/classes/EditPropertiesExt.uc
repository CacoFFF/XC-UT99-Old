//====================================================
// XC_Engine path rebuilder shortcut
//====================================================
class EditPropertiesExt expands BrushBuilder;

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
	
	ForEach LI.AllActors( class'Actor', A)
		if ( A.bSelected )
		{
			if ( SelectedActor == None )
				SelectedActor = A;
			else
				return BadParameters("Error: more than one actor selected");
		}

	if ( SelectedActor == None )
		return BadParameters("Error: select one actor");
	SelectedActor.ConsoleCommand("EditActor name="$SelectedActor.Name);
	return false;
}

defaultproperties
{
	ToolTip="Edit extended properties"
	BitmapFilename="BBEditPropertiesExt"
}
