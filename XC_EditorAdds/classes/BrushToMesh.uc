//====================================================
// Brush to Mesh converter
//
// Turns a brush into a mesh and spawns an instance
// nearby the brush
//
//====================================================
class BrushToMesh expands BrushBuilder;

var() class<Actor> ActorInstance;
var() name PackageName;
var() name MeshName;
var() enum EVertexMerge
{
	VM_None,
	VM_60Deg,
	VM_All
} VertexMerge;
var() bool bFlipFaces;
var() bool bTileTextures;

event bool Build()
{
	local Actor A;
	local Brush B, Sel;
	local LevelInfo LI;
	local int Flags;
	
	if ( PackageName == '' )
		PackageName = 'MyLevel';
	if ( MeshName == '' )
		return BadParameters("Specify Mesh name");
	
	ForEach class'XC_CoreStatics'.static.AllObjects( class'LevelInfo', LI)
		if ( !LI.bDeleteMe )
			break;
	
	ForEach LI.AllActors( class'Brush', B)
		if ( B.bSelected )
		{
			if ( Sel != none )
				return BadParameters("More than one brush selected");
			else
				Sel = B;
		}
	if ( Sel == none )
		return BadParameters("Select one brush");
	
	if ( ActorInstance == none )
		ActorInstance = class<Actor>( DynamicLoadObject("UnrealShare.Knife",class'class'));
	A = Sel.Spawn( ActorInstance, , , Sel.Location, Sel.Rotation);
	if ( A == none )
		return BadParameters("Failed to spawn actor");
		
	if ( VertexMerge == VM_None )
		Flags = 0x00000002;
	else if ( VertexMerge == VM_All )
		Flags = 0x00000001;
	if ( bFlipFaces )
		Flags = Flags | 0x00000004;
	if ( bTileTextures )
		Flags = Flags | 0x00000008;
		
	A.Mesh = class'XC_CoreStatics'.static.BrushToMesh( Sel, PackageName, MeshName, Flags);
	if ( A.Mesh == none )
	{
		A.Destroy();
		return BadParameters("Failed to convert brush");
	}
	
	return BadParameters("Conversion success");
}

defaultproperties
{
	ToolTip="Brush to Mesh"
	BitmapFilename="BBBrushToMesh"
	VertexMerge=VM_60Deg
}
