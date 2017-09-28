//=============================================================================
// This node controls teleporter availability
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_TeleWatcher expands Botz_NavigBase;

#exec TEXTURE IMPORT NAME=BWP_TeleWatcher FILE=..\CompileData\BWP_TeleWatcher.bmp FLAGS=2

var Teleporter Teleporters[16];
var Teleporter Destinations[16];
var int ReachSpecs[16];
var int iT;

function Setup( Botz_PathLoader Loader)
{
	local Teleporter T;
	local Actor End;
	local int rIdx, pIdx;

	MyLoader = Loader;
	iT = 0;
	ForEach Loader.NavigationActors( class'Teleporter', T, MaxDistance, Location, true)
		if ( T.URL != "" )
		{
			ForEach ConnectedDests( T, End, rIdx, pIdx)
				if ( Teleporter(End) != None && (string(End.Tag) ~= T.URL) && (iT < ArrayCount(Teleporters)) )
				{
					Teleporters[iT] = T;
					ReachSpecs[iT] = rIdx;
					Destinations[iT++] = Teleporter(End);
				}
		}
	if ( iT > 0 )
		SetTimer( 1 + FRand(), true);
}

event Timer()
{
	local int i, j, k;

	For ( i=0 ; i<iT ; i++ )
	{
		if ( Teleporters[i] == None || Teleporters[i].bDeleteMe || Destinations[i] == None )
			continue;
		if ( Teleporters[i].bEnabled )
		{
			AddPathTo( Teleporters[i], ReachSpecs[i] );
			AddUPathTo( Destinations[i], ReachSpecs[i] );
			if ( !Teleporters[i].bCollideActors )
				Teleporters[i].SetCollision( true);
		}
		else
		{
			RemovePathFrom( Teleporters[i], ReachSpecs[i] );
			RemoveUPathFrom( Destinations[i], ReachSpecs[i] );
			if ( Teleporters[i].bCollideActors )
				Teleporters[i].SetCollision( false);
		}
//		if ( Destinations[i] != None )
//			Destinations[i].ExtraCost = 10000000 * int(!Teleporters[i].bEnabled);
	}
}


function AddPathTo( NavigationPoint N, int iPath)
{
	local int i;
	
	For ( i=0 ; i<16 ; i++ )
	{
		if ( N.Paths[i] == iPath )
			break;
		if ( N.Paths[i] < 0 )
		{
			N.Paths[i] = iPath;
			break;
		}
	}
}

function AddUPathTo( NavigationPoint N, int iPath)
{
	local int i;

	For ( i=0 ; i<16 ; i++ )
	{
		if ( N.UpstreamPaths[i] == iPath )
			break;
		if ( N.UpstreamPaths[i] < 0 )
		{
			N.UpstreamPaths[i] = iPath;
			break;
		}
	}
}

function RemovePathFrom( NavigationPoint N, int iPath)
{
	local int i, k;
	For ( i=0 ; i<16 ; i++ )
	{
		if ( N.Paths[i] < 0 )
			break;
		if ( N.Paths[i] == iPath )
		{
			k=i+1;
			while ( (k<16) && (N.Paths[k] >= 0) )
				k++;
			k--; //Stop at first non-path, then go back to last path
			N.Paths[i] = N.Paths[k];
			N.Paths[k] = -1;
			break;
		}
	}
}

function RemoveUPathFrom( NavigationPoint N, int iPath)
{
	local int i, k;
	For ( i=0 ; i<16 ; i++ )
	{
		if ( N.UpstreamPaths[i] < 0 )
			break;
		if ( N.UpstreamPaths[i] == iPath )
		{
			k=i+1;
			while ( (k<16) && (N.UpstreamPaths[k] >= 0) )
				k++;
			k--; //Stop at first non-path, then go back to last path
			N.UpstreamPaths[i] = N.UpstreamPaths[k];
			N.UpstreamPaths[k] = -1;
			break;
		}
	}
}


event EPathMode IsCandidateTo( Botz_NavigBase Other)
{
	return PM_None;
}

event EPathMode OtherIsCandidate( NavigationPoint Nav)
{
	return PM_None;
}


defaultproperties
{
	FriendlyName="Teleporter conditioner"
	MaxDistance=1000
	Texture=Texture'BWP_TeleWatcher'
	DrawScale=0.75
	bLoadSpecial=True
}