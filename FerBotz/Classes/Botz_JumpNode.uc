//=============================================================================
// High jump destination
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_JumpNode expands Botz_NavigBase;

var NavigationPoint NearestFlat;

#exec TEXTURE IMPORT NAME=BWP_Goal FILE=..\CompileData\BWP_Goal.bmp FLAGS=2

//Called after botZ decides this is the path to take
function bool PostPathEvaluate( botz other)
{
	if ( !other.PointReachable(Location) )
	{
		if ( other.bCanTranslocate )
			Other.TranslocateToTarget(self);
		else
			Other.HighJump(self);
		return true;
	}
	return false;
}

function EPathMode IsCandidateTo( Botz_NavigBase Other)
{
	local EPathMode eResult;

	if ( Other.IsA('Botz_JumpNode') )
		return PM_None;

	eResult = Super.IsCandidateTo(Other);
	if ( eResult > 0 )
	{
		if ( (abs(Normal( Location - Other.Location).Z) < 0.17) || (VSize(Location - Other.Location) < 50) )  //Flat point or very close
		{
			if ( (NearestFlat == none) || (VSize(NearestFlat.Location - Location) > VSize(Location - Other.Location)) )
			{
				NearestFlat = Other;
				return PM_None; //Do not path, leave for end
			}
		}
		else if ( Normal( Other.Location - Location).Z < -0.3 ) //Low points
		{
			if ( UpstreamPaths[14] != -1 || Paths[14] != -1 ) //Leave room for the flat Node
				return PM_None;
			return eResult;
		}
	}
	return PM_None;
}

function EPathMode OtherIsCandidate( NavigationPoint Nav)
{
	local EPathMode eResult;

	if ( Nav.IsA('Teleporter') )
		return PM_None;
	eResult = Super.OtherIsCandidate(Nav);
	if ( eResult > 0 )
	{
		if ( (abs(Normal( Location - Nav.Location).Z) < 0.17) || (VSize(Location - Nav.Location) < 50) ) //Flat point or very close
		{
			if ( (NearestFlat == none) || (VSize(NearestFlat.Location - Location) > VSize(Location - Nav.Location)) )
			{
				NearestFlat = Nav;
				return PM_None; //Do not path, leave for end
			}
		}
		else if ( Normal( Nav.Location - Location).Z < -0.3 ) //Low points
		{
			if ( UpstreamPaths[14] != -1 || Paths[14] != -1 ) //Leave room for the flat Node
				return PM_None;
			return eResult;
		}
	}
	return PM_None;
}

//** This event will alter the ReachFlags between self and Dest
// If Dest is self then this is an incoming reachspec
event int ModifyFlags( NavigationPoint Dest, int CurFlags)
{
	return CurFlags | 32; //RS_SPECIAL
}

//Add force flag when i'm the once connecting
event AddPathHere( NavigationPoint Start, NavigationPoint End, bool bForce, optional bool bOneWay)
{
	if ( !bForce && Start == self )
		bForce = true;
	Super.AddPathHere( Start, End, bForce);
}

//Create links from lower paths to here, then move falling links to flat points
event FinishedPathing()
{
	local Actor AA;
	local int iReachS, i;
	local bool bNoConnectFlat;

	Super.FinishedPathing();
	
	if ( NearestFlat != none )
	{
		ForEach ConnectedDests( self, AA, iReachS, i) //Find all paths i go to
		{
			if ( AA == NearestFlat )
			{
				bNoConnectFlat = true;
				if ( IsConnectedTo( NearestFlat, self, false) < 0 )
					AddPathHere( NearestFlat, self, true);
				continue;
			}
			if ( IsConnectedTo( NearestFlat, NavigationPoint(AA)) >= 0 ) //Already connected, clear
			{
				EditReachSpec( iReachS, none, none);
				Paths[i] = -1;
				continue;
			}
			if ( FreePathSlot(NearestFlat) >= 0 ) //We got slots on NearestFlat, redirect such path towards it
			{
				NearestFlat.Paths[ FreePathSlot(NearestFlat)] = iReachS; //Link nearest to old links => jump down
				EditReachSpec( iReachS, NearestFlat, AA);
				Paths[i] = -1;
			}
			if ( IsConnectedTo( NavigationPoint(AA), self) < 0 )
				AddPathHere( NavigationPoint(AA), self, true);
		}
		if ( !bNoConnectFlat )
		{
			AddPathHere( self, NearestFlat, true);
			AddPathHere( NearestFlat, self, true);
		}

		COMPACT_AGAIN:
		iReachS = FreePathSlot(self);
		if ( iReachS >= 0 )
			For ( i=iReachS+1 ; i<16 ; i++ )
				if ( Paths[i] >= 0 )
				{
					Paths[iReachS] = Paths[i];
					Paths[i] = -1;
					Goto COMPACT_AGAIN;
				}
	}
	else
	{
		ForEach ConnectedDests( self, AA, iReachS, i) //Find all paths i go to
		{
			if ( IsConnectedTo( NavigationPoint(AA), self) < 0 )
				AddPathHere( NavigationPoint(AA), self, true);
		}
	}

}

event int SpecialCost(Pawn Seeker)
{
	local Bot B;
	local Botz A;

	if ( (Seeker.JumpZ > MaxDistance*1.5) || Region.Zone.ZoneGravity.Z > -650 ) //Dynamic condition
		return 100;

	if ( Seeker.GetPropertyText("bCanTranslocate") ~= "True" )
		return 150;

	return 100000000;
}

defaultproperties
{
	FriendlyName="Big jump destination"
	MaxDistance=480
	Texture=Texture'FerBotz.BWP_Goal'
	bSpecialCost=true
	bPushSave=True
	bCustomFlags=True
}