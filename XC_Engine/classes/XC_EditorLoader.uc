//=============================================================================
// XC_EditorLoader.
// Extended editor code.
//=============================================================================
class XC_EditorLoader expands Object
	native;

//*********************************************
// Array opcodes
native(640) static final function int Array_Length_Obj( out array<Object> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_Obj( out array<Object> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_Obj( out array<Object> Ar, int Offset, optional int Count );

native(640) static final function int Array_Length_Int( out array<int> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_Int( out array<int> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_Int( out array<int> Ar, int Offset, optional int Count );

native(640) static final function int Array_Length_Float( out array<float> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_Float( out array<float> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_Float( out array<float> Ar, int Offset, optional int Count );

native(640) static final function int Array_Length_Byte( out array<byte> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_Byte( out array<byte> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_Byte( out array<byte> Ar, int Offset, optional int Count );

native(640) static final function int Array_Length_Class( out array<class> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_Class( out array<class> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_Class( out array<class> Ar, int Offset, optional int Count );


//********************************************
// XC_Core opcodes
native(192) static final function Color MakeColor( byte R, byte G, byte B, optional byte A);
native(238) static final function string Locs( string InStr );
native(391) static final function name StringToName( string S );
native(600) static final function Object FindObject( string ObjectName, class ObjectClass, optional Object ObjOuter ); //ObjOuter param incompatible with 227!!!
native(601) static final function Class<Object> GetParentClass( Class<Object> ObjClass );
native(602) static final iterator function AllObjects( class<Object> BaseClass, out Object Obj );
native(643) static final function float AppSeconds();

//SDK copy opcodes (originally 2xxx)
native(3014) static final function bool HasFunction(name FunctionName, optional Object ObjToSearch); //Defaults to caller

native(3555) static final operator(22) Object | (Object A, skip Object B);
native(3555) static final operator(22) Object | (Actor A, skip Actor B);
native(3556) static final function Clock( out float C[2]);
native(3557) static final function float UnClock( out float C[2]);
native(3559) static final function int AppCycles();
native(3558) static final function name FixName( string InName, optional bool bCreate); //Fixes name case, optionally create if not there

native(3570) static final function vector HNormal( vector A);
native(3571) static final function float HSize( vector A);
native(3572) static final function float InvSqrt( float C);

native(3538) final function NavigationPoint MapRoutes( Pawn Seeker, optional NavigationPoint StartAnchors[16], optional name RouteMapperEvent);
native(3539) static final function Actor BuildRouteCache( NavigationPoint EndPoint, out NavigationPoint CacheList[16], optional Pawn HandleSpecial);


defaultproperties
{
}
