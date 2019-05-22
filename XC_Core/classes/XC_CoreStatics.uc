//====================================================
// XC_CoreStatics
// Utils for UnrealScript usage, build 6
//
// You may code this in two different ways, be it via
// directly referencing this object, or by using a
// trick to avoid package dependancy.
//
// If the mod really requires these natives, then it's
// best to simply reference this object and use it's
// functions the old fashioned way.
//
// If the mod optionally uses this code, then using
// the XC_Engine workarounds is best, check XC_Engine
// documentation on how to add XC_Engine functionality
// without creating package dependancy.
//
//====================================================
class XC_CoreStatics expands Object
	abstract
	native;

#exec _cpptext void StaticConstructor();

var() transient const editconst bool bGNatives; //True if commented out opcodes can be called directly
var() transient const editconst int XC_Core_Version;
var() transient const editconst int XC_Engine_Version; //Only set if XC_Engine is running
var() transient float iC[2]; //If you want to internally clock

//227 compatible opcodes
native /* (192)*/ static final function Color MakeColor( byte R, byte G, byte B, optional byte A);
native /* (238)*/ static final function string Locs( string InStr );
native /* (257)*/ static final function bool LoadPackageContents( string PackageName, class<Object> ListType, out array<Object> PckContents );
native /* (391)*/ static final function name StringToName( string S );
native /* (600)*/ static final function Object FindObject( string ObjectName, class ObjectClass, optional Object ObjOuter ); //ObjOuter param incompatible with 227!!!
native /* (601)*/ static final function Class<Object> GetParentClass( Class<Object> ObjClass );
native /* (602)*/ static final iterator function AllObjects( class<Object> BaseClass, out Object Obj );
native /* (643)*/ static final function float AppSeconds();

//SDK copy opcodes (originally 2xxx)
native /*(3014)*/ static final function bool HasFunction(name FunctionName, optional Object ObjToSearch); //Defaults to caller

//XC opcodes
native /*(3554)*/ static final function iterator ConnectedDests( NavigationPoint Start, out Actor End, out int ReachSpecIdx, out int PathArrayIdx);

//***************************** << - Returns B if A doesn't exist
native /*(3555)*/ static final operator(22) Object | (Object A, skip Object B);

//Ultra precise clocking, for checking small pieces of code
native /*(3556)*/ static final function Clock( out float C[2]);
native /*(3557)*/ static final function float UnClock( out float C[2]);
native /*(3559)*/ static final function int AppCycles();

native /*(3558)*/ static final function name FixName( string InName, optional bool bCreate); //Fixes name case, optionally create if not there

native /*(3570)*/ static final function vector HNormal( vector A);
native /*(3571)*/ static final function float HSize( vector A);
native /*(3572)*/ static final function float InvSqrt( float C);

//********************************
// *********** Route mapper
//
// Pass a list of Start Anchors (or autogenerate one based on 'Reference' position if not passed)
// - Start Anchors must have VisitedWeight preset to a value that indicates initial route cost (if you're not sure set to 0)
// - The list of anchors can be of any size!!
// Pass an event that optionally modifies the behaviour of the route mapper (base Cost set, bEndPoint marking)
//
// When the optional event is called, all path nodes have:
// - bEndPoint = false
// - StartPath = none
// -** StartAnchors special case: StartAnchor.StartPath = StartAnchor
// - Cost = (ExtraCost/SpecialCost)
// - VisitedWeight = Initial_Route_Cost (StartAnchor only) 
//
// Setting bEndPoint=True forces the route mapper to end if a short route has been found from start to end (not full mapping).
// Setting Cost alters the weight of this path node.
// Setting initial VisitedWeight (on StartAnchor) will give additional starting weight/cost to the whole route starting from this point.
//
// When the mapping has finished:
// - The return value of the function is the nearest bEndPoint=True path (if provided)
//
// On path nodes after finished:
// - StartPath     = StartAnchor corresponding to this route (none means unreachable)
// ** If StartPath isn't none:
// -- VisitedWeight = 'distance' from nearest StartAnchor.
// -- PrevOrdered   = Previous path node in this route
//
//********************************
//
// When BuildRouteCache is given a HandleSpecial pawn, the 'SpecialHandling' events are called on the next path(s)
// The return value is the next path (can be altered by SpecialHandling)
//
native /*(3538)*/ final function NavigationPoint MapRoutes( Pawn Seeker, optional NavigationPoint StartAnchors[16], optional name RouteMapperEvent);
native /*(3539)*/ static final function Actor BuildRouteCache( NavigationPoint EndPoint, out NavigationPoint CacheList[16], optional Pawn HandleSpecial);

//These variations work too, StartAnchor/CacheList can have array dim 1-256
//native (3538) final function NavigationPoint MapRoutes( Pawn Seeker, optional NavigationPoint StartAnchor, optional name RouteMapperEvent);
//native (3539) final function Actor BuildRouteCache( NavigationPoint EndPoint, out array<NavigationPoint> CacheList, optional Pawn HandleSpecial);


// These are the event templates (must be located at Caller class):
event MapRouteEvent_1();
event MapRouteEvent_2( Pawn Seeker);
event MapRouteEvent_3( Pawn Seeker, array<NavigationPoint> StartAnchors);


//Fixes
native static final function Object DynamicLoadObject_Fix( string ObjectName, class ObjectClass, optional bool MayFail );

//Editor-only
native static final function Mesh BrushToMesh( Actor Brush, name InPkg, name InName, optional int InFlags);
native static final function string CleanupLevel( Level Level);
native static final function string PathsRebuild( Level Level, optional Pawn ScoutReference, optional bool bBuildAir);

//For use with subclasses
static function string StaticCall( string Code);

static function TestClock()
{
	local float Timer;
	Clock( default.iC );
	//Do something
	Timer = UnClock( default.iC );
	Log("Inner clock test, time measured: "$Timer);
}

static function TestCycles()
{
	local int CycleCounter;
	local float Seconds;

	CycleCounter = AppCycles();
	CycleCounter = AppCycles() - CycleCounter;
	Log("Inner cycle test[1]:"@CycleCounter);
	CycleCounter = AppCycles();
	Seconds = AppSeconds();
	CycleCounter = AppCycles() - CycleCounter;
	Log("Inner cycle test[1]:"@CycleCounter@"sec:"@Seconds);
}

defaultproperties
{
}
