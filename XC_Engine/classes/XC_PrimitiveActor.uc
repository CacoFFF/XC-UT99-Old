//***********************************************************
/**
	Base XC_Engine primitive actor

Extended collision rules to be used in conjunction with the
collision hash replacement, this works as an extra pass to
traces, allowing said rules to pass or discard the hit, while
modifying the HitLocation, HitNormal results.

Encroachment checks will need a custom function between two
primitives, one per type, including oneself.

Extent traces will all be treated as cylinders due to how
FCollisionHashBase methods are defined, so if you intend to
create a complex, moving decoration with these rules, you'll
need to use a Mover subclass to allow encroachment based
collision.

*/

class XC_PrimitiveActor expands Actor
	native
	abstract;

//bBackTrace is the only boolean that affects trace code before a cylinder hit is registered
//All other flags affect traces either before or during primitive check code
var(Primitive) bool bNoLineCheck;
var(Primitive) bool bNoPointCheck;
var(Primitive) bool bNoEncroachmentCheck;
var(Primitive) bool bNoExtentCheck; //Encroachment checks are extent checks!
var(Primitive) bool bForceZeroExtent; //Cool for volumes
var(Primitive) bool bFallBackToCylinder; //When disregarding a check, still consider a hit using the cylinder
var(Primitive) bool bBackTrace; //Consider traces away from cylinder as hits

var native const editconst int ActorChannel; //Set at replication time for each client


//Do not use SetBase on these actors!!!!
//Call Attach and Detach directly and let XC_Engine do it's job

event Attach( Actor Other)
{
	if ( Other != self && Other.HitActor != self )
	{
		Other.HitActor = self;
		HitActor = Other;
		NetUpdateFrequency = Other.NetUpdateFrequency * 0.5;
		if ( !Other.bStatic && !Other.bNoDelete )
			RemoteRole = ROLE_DumbProxy;
	}
	if ( bCollideActors )
		SetCollision( false);
}

event Detach( Actor Other)
{
	if ( Other.HitActor == self )
		Other.HitActor = none;
	HitActor = none;
	if ( bCollideActors )
		SetCollision( false);
	Destroy(); //Do not reutilize
}

defaultproperties
{
	DrawType=DT_None
	bCollideActors=False
	bCollideWorld=False
	bCollideWhenPlacing=False
	RemoteRole=ROLE_None
	bBackTrace=True
}
