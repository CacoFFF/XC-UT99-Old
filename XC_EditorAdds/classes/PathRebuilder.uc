//====================================================
// XC_Engine path rebuilder shortcut
//====================================================
class PathRebuilder expands BrushBuilder;

var() class<InventorySpot> InventorySpotClass;
var() float MaxScanRange;


event bool Build()
{
	local LevelInfo LI;
	local class<Actor> AC;
	
	ForEach class'XC_CoreStatics'.static.AllObjects( class'LevelInfo', LI)
		if ( !LI.bDeleteMe )
			break;
	
	AC = class<Actor>( DynamicLoadObject("XC_Engine.XC_PathBuilder",class'Class') );
	if ( AC == None )
		return BadParameters("Unable to load XC_Engine.XC_PathBuilder");
	
	if ( InventorySpotClass == None )
		InventorySpotClass = class'Engine.InventorySpot';
	
	LI.ConsoleCommand("set xc_pathbuilder inventoryspotclass "$InventorySpotClass.Name);
	LI.ConsoleCommand("set xc_pathbuilder maxscanrange "$MaxScanRange);
	LI.Spawn( AC);
	
	return BadParameters("Paths rebuilt [Dist="$int(MaxScanRange)$"]");
}

defaultproperties
{
	ToolTip="Path rebuilder [XC]"
	BitmapFilename="BBPathRebuilder"
	InventorySpotClass=class'Engine.InventorySpot'
	MaxScanRange=1000
}
