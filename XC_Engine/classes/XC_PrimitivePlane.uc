// This plane will be computed within the cylinder it's contained on
// Best used to block stuff coming from one side
// Make the base actor bDirectional!!!

class XC_PrimitivePlane expands XC_PrimitiveActor
	native;

var(Primitive) bool bBlockOutgoing; //Same direction as arrow
var(Primitive) bool bBlockIncoming; //Opposite direction as arrow
var(Primitive) bool bUseMyLocation; //Use my Location as plane center
var(Primitive) bool bUseMyRotation; //Use my Rotation as plane normal
var(Primitive) bool bSolidifyBehindPlane; //Full solid collision behind this plane
var plane iPlane; //HitActor.Location is center, HitActor.Rotation is normal
var float iHAxis; //Horizontal axis (X,Y) for cylinder extent checks
var vector CachedLocation;
var rotator CachedRotation;

defaultproperties
{
    bBlockOutgoing=True
	bBlockIncoming=True
	bDirectional=True
}
