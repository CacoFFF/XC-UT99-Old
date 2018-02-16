//====================================================
// XC_Engine path rebuilder shortcut
//====================================================
class MeasureDistance expands BrushBuilder;


event bool Build()
{
	local LevelInfo LI;
	local Actor A, A1, A2;
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
			if ( A1 == None )
				A1 = A;
			else if ( A2 == None )
				A2 = A;
			else
				return BadParameters("Error: more than 2 actors selected");
		}

	if ( A1 == None )
		return BadParameters("Error: select at least one actor");
	Output = "Distance between"@A1.Name@"and";
	if ( A2 == None ) //If only one actor selected, find nearest camera
	{
		CDist = 99999;
		ForEach LI.AllActors ( class'Camera', C)
			if ( VSize(C.Location - A1.Location) < CDist )
			{
				A2 = C;
				CDist = VSize(C.Location - A1.Location);
			}
		if ( A2 == None )
			return BadParameters("Error");
		Output = Output@"nearest camera";
	}
	else
		Output = Output@A2.Name;
	
	CRLF = Chr(13)$Chr(10);
	Delta = A1.Location - A2.Location;
	Output = Output $CRLF$"Total ="@VSize(Delta)$CRLF$"H ="@class'XC_CoreStatics'.static.HSize(Delta)$CRLF$"V ="@abs(Delta.Z);
	return BadParameters(Output);
}

defaultproperties
{
	ToolTip="Measure Distance"
	BitmapFilename="BBMeasureDistance"
}
