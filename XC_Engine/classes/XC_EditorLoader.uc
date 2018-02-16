//=============================================================================
// XC_EditorLoader.
// Editor entry point for XC_Engine.
//=============================================================================
class XC_EditorLoader expands Object
	native;


//////////////////////////////////////////////////////////
/*  XC_Engine specific UnrealScript features.
//////////////////////////////////////////////////////////

=================
Native functions.
Your class/package doesn't need to be native to be able to use these opcodes.
You may define these opcodes anywhere in your classes, just declare the functions you want to use.
On the Array_ opcodes, you may replace 'Type' with absolutely ANY datatype of your choice.

If you want to make your code compatible with both UT99 modes, add IF checks that allow the game to
differ when to call the slow function and when to use the native opcodes.
Differing between 227 and UT99 (with and without XCGE) takes a whole different check set I won't address here.

Just a reminder, excepting Linux builds, these opcodes won't be availabe during online play,
so attempting to run said code while connected to a server using a Windows UT will cause a crash.

***** XC_GameEngine only opcodes
- (3550) PreLoginHook. For internal use, do not call.
- (3551) AdminLoginHook. For internal use, do not call.
- native(3552) final iterator function CollidingActors( class<actor> BaseClass, out actor Actor, float Radius, optional vector Loc)

***** 227 Based opcodes
***** Compiled code with these opcodes is compatible with Unreal 227 and vice-versa.
- (10) Dynamic Array accessor [], doesn't need to be predefined.
- native(198) static final function color MakeColor( byte R, byte G, byte B, optional byte A );
- native(640) static final function int Array_Length_Type( out array<Type> Ar, optional int SetSize);
- native(641) static final function bool Array_Insert_Type( out array<Type> Ar, int Offset, optional int Count );
- native(642) static final function bool Array_Remove_Type( out array<Type> Ar, int Offset, optional int Count );
- native(643) static final function float AppSeconds();
- native(1718) final function bool AddToPackageMap( optional string PkgName);
- native(1719) final function bool IsInPackageMap( optional string PkgName, optional bool bServerPackagesOnly); //Second parameter doesn't exist in 227!

-------
-- PROFILING A LONG CHUNK OF CODE
var float Clock;
...
	//Start profiling here
	Clock = AppSeconds();
...
	//End profiling here
	Clock = AppSeconds() - Clock;
	Log("Time needed to execute: "$Clock);
-------
-------
-- ADDING PACKAGES TO SERVER PACKAGEMAP DYNAMICALLY
	//Before the first tick
	//Check the proper XC_GE is running (old and new methods, use both):
	if ( int(ConsoleCommand("Get ini:Engine.Engine.GameEngine XC_Version")) >= 11
		|| int(ConsoleCommand("XC_Engine")) >= 11 )
	{
		AddToPackageMap(); //Adds package I reside in
		AddToPackageMap("MyCustomMod"); //Adds this package
	}
-------

=================
Extra properties:

* Class			PropertyName	(Property Type)	(Property Flags)

- GameEngine	Level			(Level)			(const, editconst)
- GameEngine	Entry			(Level)			(const, editconst)

- DemoRecDriver	DemoFileName	(string)		(const, editconst)

- LevelBase		NetDriver		(NetDriver)		(const, editconst)
- LevelBase		DemoRecDriver	(NetDriver)		(const, editconst)
- LevelBase		Engine			(Engine)		(const, editconst)
- LevelBase		URL_Protocol	(string)		(const, editconst)
- LevelBase		URL_Host		(string)		(const, editconst)
- LevelBase		URL_Port		(int)			(const, editconst)
- LevelBase		URL_Map			(string)		(const, editconst)
- LevelBase		URL_Options		(array<string>)	(const, editconst)
- LevelBase		URL_Portal		(string) 		(const, editconst)
- LevelBase		ActorListSize	(int)			(const, editconst)
- Level		iFirstNetRelevantActor	(int)		(const, editconst)
- Level		iFirstDynamicActor		(int)		(const, editconst)

- NetDriver		ClientConnections	(array<NetConnection>)	(const, editconst)
- NetDriver		ServerConnection	(NetConnection)	(const, editconst)

Referencing these properties directly will prevent the package from being loadable.
Use GetPropertyText("PropName") to access these.
*/

defaultproperties
{
}
