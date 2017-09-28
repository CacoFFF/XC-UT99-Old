//=============================================================================
// F_TempDest.
// Temporarily alter a destination
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class F_TempDest expands InfoPoint;

var Actor SavedDest;
var MasterGasterFer Master;
var F_TempDest NextDest;
var float PostSpecialPause;
var bool bDisableJump;
var Botz B;


function Reset()
{
	SavedDest = None;
	PostSpecialPause = 0;
	bDisableJump = true;
	B = None;
}

//During movement
function F_TempDest Setup( Botz newB, Actor newSD, float ExpireTime, vector Position)
{
	B = newB;
	bHidden = !B.DebugMode;
	SavedDest = newSD;
	SetTimer( ExpireTime, false);
	SetLocation( Position);
	B.LifeSignal( ExpireTime);
	if ( B.SpecialMoveTarget == none )
		B.SwitchToUnstate();
	B.SpecialMoveTarget = self;
	return self;
}

//Before movement, doesn't set variables on bot
//Cannot apply post-reach effects!
function F_TempDest PassiveSetup( Botz newB, Actor newSD, float ExpireTime, vector Position)
{
	B = newB;
	bHidden = !B.DebugMode;
	SavedDest = newSD;
	SetTimer( ExpireTime, false);
	SetLocation( Position);
	B.LifeSignal( ExpireTime);
	return self;
}

function F_TempDest PauseAfter( float PauseTime)
{
	PostSpecialPause = PauseTime;
}

function F_TempDest LockToGround()
{
	B.bCanJump = false;
	bDisableJump = true;
	return self;
}

function F_TempDest SetupMidPoint( F_TempDest Start, float ExpireTime, vector Position)
{
	if ( Start == None )
	{
		SetTimer( 0.1, false);
		return None;
	}
	B = Start.B;
	SavedDest = Start.SavedDest;
	Start.SavedDest = self;
	bHidden = !B.DebugMode;
	SetTimer( ExpireTime, false);
	SetLocation( Position);
	B.LifeSignal( ExpireTime);
	return self;
}


event Timer()
{
	Expire();
}

function ReachedByBot()
{
	Expire();
	if ( PostSpecialPause != 0 )
		B.SpecialPause = PostSpecialPause;
}

function Expire()
{
	SetTimer(0, false);
	if ( B != none )
	{
		if ( bDisableJump )
			B.bCanJump = true;
		if ( B.SpecialMoveTarget == self )
		{
			B.SpecialMoveTarget = SavedDest;
			B.LifeSignal(1);
		}
	}
	Reset();
	NextDest = Master.PoolDests;
	Master.PoolDests = self;
}

defaultproperties
{
    bHidden=True
}