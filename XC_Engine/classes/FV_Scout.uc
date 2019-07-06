//=============================================================================
// FV_Scout.
// Taken from Gunloc
//=============================================================================
class FV_Scout expands Scout;

const R_WALK       =  1;
const R_FLY        =  2;
const R_SWIM       =  4;
const R_JUMP       =  8;
const R_DOOR       = 16;
const R_SPECIAL    = 32;
const R_PLAYERONLY = 64;

var() float Radiuses[5];
var() float Heights[5];

event PreBeginPlay()
{
	bHidden = true;
	bCanJump = true;
	bCanWalk = true;
	bCanSwim = true;
	bCanFly = false;
	bCanOpenDoors = true;
	bCanDoSpecial = true;
	LifeSpan = 0.01;
}

event PostBeginPlay()
{
}

event Destroyed()
{
}

function bool CheckReachability( NavigationPoint Start, NavigationPoint End, out int Radius, out int Height, out int Flags)
{
	local int ShrinkIdx;
	local bool bJumped;

	Flags = 0;
	Shrink(ShrinkIdx);
	bCollideWorld = true;
	bCollideWhenPlacing = true;
	while ( !SetLocation(Start.Location) )
		if ( !Shrink(ShrinkIdx) )
			return false;

	if ( Region.Zone.bWaterZone )
		SetPhysics( PHYS_Swimming);
	else
	{
		Move( vect(0,0,-1) * CollisionHeight);
		SetPhysics( PHYS_Walking);
	}
	
	Flags = Flags | (int( Start.Region.Zone.bWaterZone ||  End.Region.Zone.bWaterZone) * R_SWIM);
	Flags = Flags | (int(!Start.Region.Zone.bWaterZone || !End.Region.Zone.bWaterZone) * R_WALK);

	while ( true )
	{
		bCanJump = False;
		if ( PointReachable(End.Location) )
			break;
		bCanJump = True;
		if ( PointReachable(End.Location) )
			break;
		if ( !Shrink(ShrinkIdx) )
			return false;
	}
	Flags = Flags | (int(bCanJump) * R_JUMP);
	Radius = int(CollisionRadius);
	Height = int(CollisionHeight);
	return true;
}

event FellOutOfWorld()
{
}

function bool Shrink( out int ShrinkInto)
{
	local float OldHeight;
	
	if ( ShrinkInto >= ArrayCount(Radiuses) )
		return false;
	OldHeight = CollisionHeight;
	SetCollisionSize( Radiuses[ShrinkInto], Heights[ShrinkInto]);
	if ( !Region.Zone.bWaterZone && (ShrinkInto != 0) )
		Move( vect(0,0,-1.2) * Abs(OldHeight-CollisionHeight));
	ShrinkInto++;
	return true;
}

defaultproperties
{
    Heights(0)=70
    Heights(1)=65
    Heights(2)=52
    Heights(3)=48
    Heights(4)=39
    Radiuses(0)=70
    Radiuses(1)=52
    Radiuses(2)=40
    Radiuses(3)=28
    Radiuses(4)=17
    RemoteRole=ROLE_None
    Visibility=0
	bCollideActors=False
	bBlockPlayers=False
	bBlockActors=False
	CollisionHeight=37
	CollisionRadius=19
	bGameRelevant=True
}
