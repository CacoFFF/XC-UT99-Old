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
	
var transient const editconst bool bGNatives; //True if commented out opcodes can be called directly
var const editconst int XC_Core_Version;	//Hardcoded, set by DLL
var const editconst int XC_Engine_Version; //Only set if XC_Engine is running
var transient float iC[2]; //If you want to internally clock

//227 compatible opcodes
native /* (192)*/ static final function Color MakeColor( byte R, byte G, byte B, optional byte A);
native /* (238)*/ static final function string Locs( string InStr );
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

//Fixes
native static final function object DynamicLoadObject_Fix( string ObjectName, class ObjectClass, optional bool MayFail );

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
	XC_Core_Version=7
}
