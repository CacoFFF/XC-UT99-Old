class XC_EngineStatics expands XC_CoreStatics
	abstract;
	
//API
struct SGTSC //Simple global time stamp counter
{
	var int Counter;
	var float TimeStamp;
};
struct SPTSB //Simple player time stamp blocker
{
	var bool bDisable;
	var int PlayerID;
	var float TimeStamp;
};
struct DPA //Dynamic player accumulator
{
	var float Accumulated;
	var int PlayerID;
};

//Status
var SPTSB Ip2C_Status[4];
var float Mutate_TimeStamp;
var array<DPA> Mutate_Status;


native(640) static final function int Array_Length_DPA( out array<DPA> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_DPA( out array<DPA> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_DPA( out array<DPA> Ar, int Offset, optional int Count );


static final function bool ResetAll()
{
	default.Mutate_TimeStamp = 0;
	Array_Length_DPA( default.Mutate_Status, 0);
}


//************************
// 

//One command per second, per player
/*static final function bool Allow_Ip2C( PlayerPawn Sender)
{
	local int i;
	if ( Sender == None || Sender.PlayerReplicationInfo == None || Sender.Level == None )
		return true;
	For ( i=0 ; i<4 ; i++ )
		if ( default.Ip2C_Status[i].bDisable )	//Cleanup old disabled entries
		{
			default.Ip2C_Status[i].bDisable = (Square(Sender.Level.TimeSeconds-default.Ip2C_Status[i].TimeStamp) <= Sender.Level.TimeDilation); 
			if ( default.Ip2C_Status[i].bDisable && (default.Ip2C_Status[i].PlayerID == Sender.PlayerReplicationInfo.PlayerID) )
				return false;
		}
	For ( i=0 ; i<4 ; i++ )
		if ( !default.Ip2C_Status[i].bDisable ) //Found clean entry
		{
			default.Ip2C_Status[i].bDisable = true;
			default.Ip2C_Status[i].PlayerID = Sender.PlayerReplicationInfo.PlayerID;
			default.Ip2C_Status[i].TimeStamp = Sender.Level.TimeSeconds;
			return true;
		}
	//Ip2C being spammed, deny
	return false;
}*/


//*********************
// Mutate anti-spam fix
static final function bool Allow_Mutate( PlayerPawn Sender)
{
	local int i, iMax;
	local float TimeStampDiff;
	
	//Compute time stamps
	TimeStampDiff = (Sender.Level.TimeSeconds - default.Mutate_TimeStamp) / Sender.Level.TimeDilation;
	default.Mutate_TimeStamp = Sender.Level.TimeSeconds;
	if (TimeStampDiff >= 1)	iMax = Array_Length_DPA( default.Mutate_Status, 0);
	else					iMax = Array_Length_DPA( default.Mutate_Status);
	
	//Compute new accumulated values and process player if found
	For ( i=iMax-1 ; i>=0 ; i-- )
		if ( ((default.Mutate_Status[i].Accumulated -= TimeStampDiff) < 0) && Array_Remove_DPA( default.Mutate_Status, i) )
			iMax--;
	//Accumulate 0.5 for caller
	For ( i=0 ; i<iMax ; i++ )		
		if ( default.Mutate_Status[i].PlayerID == Sender.PlayerReplicationInfo.PlayerID )
		{
			if ( default.Mutate_Status[i].Accumulated >= 1 )
				return false;
			default.Mutate_Status[i].Accumulated += 0.5;
			return true;
		}
	Array_Insert_DPA( default.Mutate_Status, 0);
	default.Mutate_Status[0].PlayerID = Sender.PlayerReplicationInfo.PlayerID;
	default.Mutate_Status[0].Accumulated = 0.5;
	return true;
}

//*********************************** GetCurrentPath - get bot's current NavigationPoint
static final function NavigationPoint GetCurrentPath( Pawn Other)
{
	local NavigationPoint N, BestN;
	local vector V;
	local vector Position;
	local float Weight, BestWeight;
	
	//Setup path lookup variables
	V.X = Other.CollisionRadius;
	V.Y = Other.CollisionHeight;
	V.Z = 100;
	if ( V.X < 60 ) V.X += (60 - Other.CollisionHeight) * 0.5;
	if ( V.Y < 40 ) V.Y += (40 - Other.CollisionRadius) * 0.5;
	Position = Other.Location;
	if ( (Other.Physics == PHYS_Walking) && (Other.CollisionHeight < 60) )
		Position.Z += (60 - Other.CollisionHeight) * 0.5;
	
	//Enumerate and select
	BestWeight = 99999;
	BestN = NavigationPoint(Other.MoveTarget); //Default option
	ForEach Other.NavigationActors( class'NavigationPoint', N, VSize(V), Position)
	{
		if ( (Other.Physics == PHYS_Walking) && InCylinder( N.Location - Position, V.X, V.Y) )
			Weight = HSize( N.Location - Position);
		else
			Weight = VSize( N.Location - Position);
			
		if ( Weight < BestWeight )
			BestN = N;
	}
	return BestN;
}

//*********************** NearestMoverKeyFrame - Finds nearest keyframe to a point
static final function int NearestMoverKeyFrame( Mover M, vector TargetPoint, out vector MarkerPosition)
{
	local float Dist, BestDist;
	local int i, iNearest;
	local vector MarkerOffset, MarkerPos;

	//Calculate offset of marker if present
	if ( M.myMarker != None )
		MarkerOffset = (M.myMarker.Location - M.Location) << (M.Rotation - M.BaseRot); //Return to original rotation (-delta)
	
	//First, find which keyframe is the nearest target
	BestDist = 99999;
	For ( i=0 ; i<M.NumKeys ; i++ )
	{
		MarkerPos = M.BasePos + M.KeyPos[i] + (MarkerOffset >> (M.KeyRot[i] - M.BaseRot)); //Move to modified rotation (+delta)
		Dist = VSize( MarkerPos - TargetPoint);
		if ( Dist < BestDist )
		{
			BestDist = Dist;
			MarkerPosition = MarkerPos;
			iNearest = i;
		}
	}
	return iNearest;
}

//************************ ToNearestMoverKeyFrame - DistanceThreshold adds an additional check to make sure elevator is near said target keyframe
static final function bool ToNearestMoverKeyFrame( Mover M, vector TargetPoint, optional float DistanceThreshold )
{
	local int Nearest;
	local vector MarkerPosition;

	Nearest = NearestMoverKeyFrame( M, TargetPoint, MarkerPosition);
	if ( MarkerPosition == vect(0,0,0) ) //Approximate if not present
		MarkerPosition = M.BasePos + M.KeyPos[Nearest];
	return (M.KeyNum == Nearest) && (DistanceThreshold == 0 || VSize(M.BasePos + M.KeyPos[Nearest] - M.Location) < DistanceThreshold);
}


//************************ AI_SafeToDropTo - lower objective is walkable (do Z check first!!)
static final function bool AI_SafeToDropTo( Pawn Other, Actor Target, optional bool bDamageAllowed)
{
	local vector Dest, TargetVelocity;
	local float VelocityLimit, FallVelocity;
	
	//Need native PointRegion generator!!!
	if ( !Target.Region.Zone.bWaterZone )
	{
		TargetVelocity = Phys_NetVelocity(Target);
		VelocityLimit = Other.Velocity.Z - (750 + Other.JumpZ); //Consider current fall velocity, good for air shortening
		if ( bDamageAllowed )
			VelocityLimit -= Other.Health / 2;
			
		// Terminal velocity isn't low
		if ( Target.Region.Zone.ZoneTerminalVelocity > Abs(VelocityLimit) )
		{
			Dest = Target.Location + TargetVelocity;
			FallVelocity = Phys_FreeFallVelocity( Dest.Z - Other.Location.Z, Target.Region.Zone.ZoneGravity.Z);
			
			//Falling too hard or destination going down faster than what bot can fall
			if ( (FallVelocity < VelocityLimit) || (FallVelocity > TargetVelocity.Z) || (TargetVelocity.Z >= Target.Region.Zone.ZoneTerminalVelocity) )
				return false;
		}
	}
	return true;
}

//************************** Phys_NetVelocity - estimates real velocity of a based actor
static final function vector Phys_NetVelocity( Actor A)
{
	local vector Velocity;
	local int i;
	
	while ( A!=None && i++<4 )
	{
		Velocity += A.Velocity;
		A = A.Base;
	}
	return Velocity;
}

//************************* Phys_FreeFallVelocity
static final function float Phys_FreeFallVelocity( float FallDelta, float ZGrav) //Both should have same sign
{
	local float Time;
	
	if ( FallDelta*ZGrav <= 0 ) 
		return 0;
	Time = Sqrt( (FallDelta * 2 / ZGrav) );
	return ZGrav * Time;
}

//****************** Phys_CanJumpTo
static function bool Phys_CanJumpTo( vector Origin, vector Destination, float ZGravity, float ZVel, float MaxHVel)
{
	local float DeltaT;
	local float disc;
	local float HDist, HVel;
	local vector DeltaPosition;

	if ( ZGravity >= -0.1 )
		return False;

	DeltaPosition = Destination - Origin;
	disc = ZVel*ZVel - 4 * (-DeltaPosition.Y) * (ZGravity * 0.5); //b^2 - 4*c*a
	if ( disc < 0 ) //Can't reach Z
		return False;

	disc = sqrt(disc);

	//Free fall time
	DeltaT = (-ZVel - disc) / ZGravity; //b - disc    /  2*a
	if ( DeltaT < 0 )
		return False;
	
	HDist = HSize( DeltaPosition);
	HVel = HDist / DeltaT;
	return HVel <= MaxHVel * 1.02;
}

//************************ InCylinder
static final function bool InCylinder( vector V, float EX, float EZ)
{
	return (Abs(V.Z) < EZ) && (HSize(V) < EX);
}

//************************ ActorsTouchingValid - sees if both actors are touching 
static final function bool ActorsTouchingValid( Actor A, Actor B)
{
	return (A != None) && (B != none) && A.bCollideActors && B.bCollideActors
		&& InCylinder( A.Location - B.Location, A.CollisionRadius+B.CollisionRadius, A.CollisionHeight+B.CollisionHeight);
}

//************************ MoverInOperation - mover is active (delaying or moving)
static final function bool MoverInOperation( Mover M)
{
	local EventLink EL;
	
	if ( M.bDelaying || M.bInterpolating || M.LatentFloat > 0.125 ) //DO NOT LOWER
		return true;
	if ( class'XC_Engine_Actor_CFG'.default.bEventChainAddon )
	{
		ForEach M.DynamicActors( class'EventLink', EL, M.Tag)
			if ( EL.Owner == M && EL.bLink && EL.ChainInProgress(true) )
				return true;
	}
	return false;
}

//************************ GetState - Gets state name of an actor
static final function Name GetState( Actor A)
{
	local Name StateName;
	
	StateName = A.GetStateName();
	if ( StateName == A.Class.Name || StateName == '' )
	{
		if ( A.Level.bStartup )
			StateName = A.InitialState; //auto state not implemented!!!
		else
			StateName = '';
	}
	return StateName;
}

//************************* GetNearestTrigger - Gets an Actor's nearest 'Event' trigger (prioritizes colliding actors)
static final function Actor GetNearestTrigger( Actor Other, optional name Event, optional float MaxDistance, optional bool bReachable)
{
	local float Distance;
	local Actor A, Best;
	
	Assert( Other != None );
	if ( Event == '' )
		Event = Other.Tag;
	if ( MaxDistance <= 0 )
		MaxDistance = 999999;
	if ( !Other.bIsPawn )
		bReachable = false;
		
	ForEach Other.RadiusActors( class'Actor', A, MaxDistance)
		if ( A.Event == Event )
		{
			if ( Mover(A) != None && (Mover(A).bInterpolating || Mover(A).bDelaying || Mover(A).KeyNum != 0) )
				continue;
			Distance = VSize( A.Location - Other.Location);
			if ( A.bCollideActors || A.Brush != None )
				Distance -= 1000;
			if ( Distance < MaxDistance && (!bReachable || Pawn(Other).ActorReachable(A)) || (Other.bProjTarget && Pawn(Other).LineOfSightTo(A)) )
			{
				MaxDistance = Distance;
				Best = A;
			}
		}
	return Best;
}

//************************* GetNearestTagged - Gets an Actor's nearest tagged actor
static final function Actor GetNearestTagged( Actor Other, name Tag, optional float MaxDistance, optional bool bReachable)
{
	local float Distance;
	local Actor A, Best;
	
	if ( Tag == '' )
		return None;
	
	Assert( Other != None );
	if ( MaxDistance <= 0 )
		MaxDistance = 999999;
	if ( !Other.bIsPawn )
		bReachable = false;
		
	ForEach Other.AllActors( class'Actor', A, Tag)
	{
		Distance = VSize( A.Location - Other.Location);
		if ( Distance < MaxDistance && (!bReachable || Pawn(Other).ActorReachable(A)) )
		{
			MaxDistance = Distance;
			Best = A;
		}
	}
	return Best;
}