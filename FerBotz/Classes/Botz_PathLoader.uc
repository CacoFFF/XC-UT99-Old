//=============================================================================
// The navigation point serializer
//
// Navigation Point serializer, as of release 20 file format will be changed
// XC_Core will be exclusively used and the old format will be supported in
// load operations for compatibility reasons
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class Botz_PathLoader expands XC_Engine_Actor;

	//This class should become a XC_Engine_Actor type
	
#exec OBJ LOAD FILE=..\System\XC_Core.u

//Size = 36 bytes
struct NavPoint
{
	var() byte PathClass;	//O=0
	var() vector PLoc;		//O=4
	var() rotator PRot;		//O=16
	var() float MaxDist;	//O=28
	var() byte OtherFlags;	//O=32 //byte 0 is OneWayIncoming, byte 1 is OneWayOutgoing
};

var bool bOldLoaded;
var bool bEditMode;
var NavPoint CurNav;
var MasterGasterFer MasterG;
var ReachSpec TempReach; //To be used as external buffer!
var class<Botz_NavigBase> NBaseList[32];

var BinarySerializer Serializer;
var int FileVersion; //Set during load
var array<int> PrunedPaths;


/** New save format, specification
- File header [5 bytes]: BOTZ + format (1 to 255)
- Directives: read incrementally
-- DS chars [2]: indicator of new directive
-- End Position [4]: where to seek if we can't interpret this directive
-- Directive type [1]: what kind of directive we're applying
-- Directive data [x]: see below
*/

/** Directive types
01: path
- Type [1]
- Loc [12]
- Rot [6] >>> 16 bit COMPRESSED!
- MaxDist [4]
- Custom flag interpreter [x] >>> Path will take charge of doing this
02: condition
03: forced link
*/



function SaveNodes( pawn Sender)
{
	SaveNodes_v1( Sender);
}

function SaveNodes_v1( pawn Sender)
{
	local Botz_NavigBase WP;
	local int i;
	local byte B;

	ForEach AllActors (class'Botz_NavigBase', WP)
		if ( ClassIdentifier( WP.Class) != 255 )
			i++;
			
	if ( i == 0 )
	{
		Sender.ClientMessage("No custom path nodes saved");
		return;
	}
	
	if ( !OpenSerializer( true) )
	{
		Sender.ClientMessage("Failed to save to file");
		return;
	}

	//Compact index, not more than 8000 paths
	B = i & 0x3f;
	if ( i >= 0x40 )
	{
		B = B + 0x40;
		Serializer.SerializeByte( B);
		B = (i >>> 6) & 0x7f;
	}
	Serializer.SerializeByte( B);
		
	
	//Double pass save, to ensure proper connections
	ForEach AllActors (class'Botz_NavigBase', WP)
		if ( !WP.bPushSave && PathToNav(WP) )
		{
			Serializer.SerializeByte( CurNav.PathClass);
			Serializer.SerializeVector( CurNav.PLoc);
			Serializer.SerializeRotator( CurNav.PRot);
			Serializer.SerializeFloat( CurNav.MaxDist);
			Serializer.SerializeByte( CurNav.OtherFlags);
		}
		
	ForEach AllActors (class'Botz_NavigBase', WP)
		if ( WP.bPushSave && PathToNav(WP) )
		{
			Serializer.SerializeByte( CurNav.PathClass);
			Serializer.SerializeVector( CurNav.PLoc);
			Serializer.SerializeRotator( CurNav.PRot);
			Serializer.SerializeFloat( CurNav.MaxDist);
			Serializer.SerializeByte( CurNav.OtherFlags);
		}
	Serializer.CloseFile();
	Sender.ClientMessage("File saved");
}

function LoadNodes()
{
	local int i, NumDirectives;
	local Botz_PathLoader aNew;
	local string PathName, PathDelimiter;
	local Botz_NavigBase aNavig;
	local Botz_NavigDoorSpecial dsNavig;
	local byte Header[5];

	bEditMode = CheckEditMode();
	if ( !OpenSerializer( false) )
	{
		Log("BOTZ > Map doesn't contain additional navigation points");
		return;
	}


	//Attempt to serialize the header byte by byte
	For ( i=0 ; i<5 ; i++ )
		Serializer.SerializeByte( Header[i]);

	//BOTZ - new file format
	if ( Header[0] == 66 && Header[1] == 79 && Header[2] == 84 && Header[3] == 90 )
	{
		FileVersion = Header[4];
		//Not yet done
		return;
	}
	
	//===========================
	//Old file format (version 0)
	//===========================
	FileVersion = 0;
	NumDirectives = DecodeCompact( Header, i);
	Log("BOTZ > File format 0 > Found "$NumDirectives$" Botz_NavigBase points");
	if ( NumDirectives < 1 )
		return;
		
	//Reload file (we can't seek!)
	OpenSerializer( false);
	while ( i-- > 0 )
		Serializer.SerializeByte( Header[i] ); //Nothing changes, but we get to the position we want
	
	//Get each old NavPoint
	For ( i=0 ; i<NumDirectives ; i++ )
	{
		if ( Serializer.Position() >= Serializer.TotalSize() )
			break;
		Serializer.SerializeByte( CurNav.PathClass);
		Serializer.SerializeVector( CurNav.PLoc);
		Serializer.SerializeRotator( CurNav.PRot);
		Serializer.SerializeFloat( CurNav.MaxDist);
		Serializer.SerializeByte( CurNav.OtherFlags);
		PathFromNav();
	}
	Serializer.CloseFile();

	//Path Standard nodes
	ForEach NavigationActors( class'Botz_NavigBase', aNavig)
		if ( !aNavig.bLoadSpecial ) //Prevents autopathing from special nodes
			aNavig.PathCandidates(); //Path after everything's been created

	//Path special door nodes
	ForEach NavigationActors( class'Botz_NavigDoorSpecial', dsNavig)
		dsNavig.PathCandidates();
}

/*
function ListPrunedPaths()
{
	local ReachSpec R;
	local int i, j;
	ForEach AllReachSpecs( R, i); //Idx can actually modify the starting index!!!
		if ( R.bPruned != 0 )
			PrunedPaths[j++] = i;
}
*/


// FCompactIndex decoder.
function int DecodeCompact( byte B[5], out int Count )
{
	local int Value;

	Count = 1;
	if( (B[0] & 0x40) != 0 )
	{
		Count++;
		if( (B[1] & 0x80) != 0 )
		{
			Count++;
			if( (B[2] & 0x80) != 0 )
			{
				Count++;
				if( (B[3] & 0x80) != 0 )
				{
					Count++;
					Value = B[4];
				}
				Value = (Value << 7) + (B[3] & 0x7f);
			}
			Value = (Value << 7) + (B[2] & 0x7f);
		}
		Value = (Value << 7) + (B[1] & 0x7f);
	}
	Value = (Value << 6) + (B[0] & 0x3f);
	if( (B[0] & 0x80) != 0 )
		Value = -Value;
	return Value;
}

function bool PathToNav( Botz_NavigBase Cur)
{
	CurNav.PathClass = ClassIdentifier( Cur.Class);
	if ( CurNav.PathClass == 255 )
		return false;
	CurNav.PLoc = Cur.Location;
	CurNav.PRot = Cur.Rotation;
	CurNav.OtherFlags = 0;
	if ( Cur.bOneWayInc )
		CurNav.OtherFlags = 1;
	if ( Cur.bOneWayOut )
		CurNav.OtherFlags += 2;
	CurNav.MaxDist = Cur.MaxDistance;
	return true;
}

function PathFromNav()
{
	local class<Botz_NavigBase> newClass;
	local Botz_NavigBase newPath;
	
	newClass = IdentifyClass( CurNav.PathClass);
	if ( newClass == none )
	{
		Log("BOTZ > Unknown path identifier: "$CurNav.PathClass );
		return;
	}
	newPath = Spawn( newClass,,,CurNav.PLoc, CurNav.PRot); //Answer my call!
	newPath.MaxDistance = CurNav.MaxDist;

	if ( Botz_NavigRemover(newPath) != none )
	{
		Botz_NavigRemover(newPath).RemovePaths( self);
		if ( !bEditMode )
			newPath.Destroy();
		return;
	}
	if ( Botz_TeleWatcher(newPath) != none )
	{
		Botz_TeleWatcher(newPath).Setup( self);
		return;
	}

	newPath.bOneWayInc = (CurNav.OtherFlags & 1) > 0;
	newPath.bOneWayOut = (CurNav.OtherFlags & 2) > 0;
	newPath.MyLoader = self;
	newPath.LockActor( true); //Put in NavigationPointList and prevent deletion
}



static function byte ClassIdentifier( class<Botz_NavigBase> aClass)
{
	local int i;
	For ( i=0 ; i<19 ; i++ )
		if ( aClass == default.NBaseList[i] )
			return i;
	return 255;
}

static function class<Botz_NavigBase> IdentifyClass( byte cId)
{
	return default.NBaseList[cId];
}

function bool OpenSerializer( bool bSave)
{
	local string PathName, PathDelimiter;
	
	if ( Serializer == None )
		Serializer = new(self,'PathSerializer') class'BinarySerializer';
	else if ( Serializer.Archive != 0 )
		Serializer.CloseFile();
		
	PathDelimiter = "/"; //BinarySerializer fixes on Linux
	PathName = ".." $ PathDelimiter $ "System" $ PathDelimiter $ "Botz" $ PathDelimiter $ string(Outer.Name);

	if ( bSave )
	{
		//Add no-paths check here
		if ( bOldLoaded )	PathName = PathName $ "_botz";
		else				PathName = PathName $ ".botz";
		return Serializer.OpenFileWrite( PathName);
	}
	else
	{
		bOldLoaded = Serializer.OpenFileRead( PathName $ "_botz");
		if ( !bOldLoaded )
			Serializer.OpenFileRead( PathName $ ".botz");
		return Serializer.Archive != 0;
	}
}

function bool CheckEditMode()
{
	if ( Level.NetMode == NM_DedicatedServer )
		return false;
	//Try to get the playerpawn type in URL, because local player may not have logged in yet
	return true;
}


final function AddPrune(NavigationPoint A, NavigationPoint B)
{
	local ReachSpec R;
	local int i, j;
	
	R.Start = A;
	R.End = B;
	R.Distance = VSize(A.Location - B.Location);
	R.CollisionRadius = 40;
	R.CollisionHeight = 60;
	R.ReachFlags = R_WALK | R_JUMP; //Ugh
	R.bPruned = 1;
	i = FindReachSpec( None, None);
	if ( i == -1 )
		AddReachSpec( R, false);
	else
		SetReachSpec( R, i, false);
		
	For ( j=8*int(A.PrunedPaths[7] != -1) ; j<16 ; j++ ) //Can save 8 iterations
		if ( A.PrunedPaths[j] == -1 )
		{
			A.PrunedPaths[j] = i;
			break;
		}
}


final function bool IsPruned( NavigationPoint A, NavigationPoint B)
{
	local ReachSpec R;
	local int i;
	
	i = -1;
	i = FindReachSpec( A, B);
	if ( i != -1 )
	{
		GetReachSpec( R, i);
		return R.bPruned > 0;
	}
}


/*
//Reach flags used in navigation
const R_WALK       = 0x00000001; //walking required
const R_FLY        = 0x00000002; //flying required 
const R_SWIM       = 0x00000004; //swimming required
const R_JUMP       = 0x00000008; //jumping required
const R_DOOR       = 0x00000010;
const R_SPECIAL    = 0x00000020;
const R_PLAYERONLY = 0x00000040;
	
struct ReachSpec
{
	var() int Distance; 
	var() Actor Start;
	var() Actor End;
	var() int CollisionRadius; 
    var() int CollisionHeight; 
	var() int ReachFlags;
	var() byte bPruned;
};


//Natives that are exclusive to this actor type and are safe to call in clients.
native final function bool GetReachSpec( out ReachSpec R, int Idx);
native final function bool SetReachSpec( ReachSpec R, int Idx, optional bool bAutoSet);
native final function int ReachSpecCount();
native final function int AddReachSpec( ReachSpec R, optional bool bAutoSet); //Returns index of newle created ReachSpec
native final function int FindReachSpec( Actor Start, Actor End); //-1 if not found, useful for finding unused specs (actor = none)
native final function CompactPathList( NavigationPoint N); //Also cleans up invalid paths (Start or End = NONE)
native final function LockToNavigationChain( NavigationPoint N, bool bLock);
native final function iterator AllReachSpecs( out ReachSpec R, out int Idx); //Idx can actually modify the starting index!!!
*/


defaultproperties
{
	bHidden=True
	NBaseList(0)=class'Botz_NavigBase'
	NBaseList(1)=class'Botz_NavigNode'
	NBaseList(2)=class'Botz_JumpNode'
	NBaseList(3)=class'Botz_SimpleTDest'
	NBaseList(4)=class'Botz_NavigDoor'
	NBaseList(5)=class'Botz_LiftCenter'
	NBaseList(6)=class'Botz_LiftExit'
	NBaseList(7)=class'Botz_NavigDoorSpecial'
	NBaseList(8)=class'Botz_DodgeStart'
	NBaseList(9)=class'Botz_DodgeEnd'
	NBaseList(10)=class'Botz_NavigAirBase'
	NBaseList(11)=class'Botz_NavigRemover'
	NBaseList(12)=class'Botz_DirectLink'
	NBaseList(13)=class'Botz_DirectTDest'
	NBaseList(14)=class'Botz_LiftJumpExit'
	NBaseList(15)=class'Botz_DirectPistonTrans'
	NBaseList(16)=class'Botz_DirectPlatformBelow'
	NBaseList(17)=class'Botz_TeleWatcher'.
	NBaseList(18)=class'Botz_NavigRemoverSmart'
}