class XC_Engine_Actor_CFG expands Object
	perobjectconfig
	transient;

var() config string XCGE_Actors_Description[3];
var() config array<string> XCGE_Actors;
var() config bool bFixBroadcastMessage;
var() config bool bSpectatorHitsTeleporters;
var() config bool bListenServerPlayerRelevant;
var() config bool bPatchUdpServerQuery;

native(640) static final function int Array_Length_Str( out array<string> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_Str( out array<string> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_Str( out array<string> Ar, int Offset, optional int Count );


function Setup( XC_Engine_Actor Other)
{
	local int i, k, ACount;
	local string Parsed;
	local class<XC_Engine_Actor> aClass;
	
	if ( Len(XCGE_Actors_Description[0]) <= 0 )
	{
		XCGE_Actors_Description[0] = "This list contains subclasses of XC_Engine.XC_Engine_Actor to be spawned";
		XCGE_Actors_Description[1] = "The main XC_Engine_Actor will call XC_Init() on these actors before InitGame()";
		XCGE_Actors_Description[2] = "The : symbol indicates that a certain package has to be loaded as condition";
		Array_Insert_Str( XCGE_Actors, 0, 2);
		XCGE_Actors[0] = "Unreali:XC_Engine_UT99.XC_Engine_UT99_Actor";
		XCGE_Actors[1] = "s_SWAT:XC_Engine_TOs.XC_Engine_TOs_Actor";
	}
	
	ACount = Array_Length_Str( XCGE_Actors);
	for ( i=0 ; i<ACount ; i++ )
	{
		Parsed = XCGE_Actors[i];
		k = InStr( Parsed, ":");
		if ( k != -1 )
		{
			if ( class'XC_CoreStatics'.static.FindObject( Left(Parsed,k), class'Package') == None )
				continue;
			Parsed = Mid( Parsed, k+1);
		}
		aClass = class<XC_Engine_Actor>( DynamicLoadObject( Parsed, class'class'));
		if ( aClass != None && (aClass != Other.Class) )
			Other.Spawn(aClass).XC_Init();
	}
	SaveConfig();
}

defaultproperties
{
	bFixBroadcastMessage=True
	bSpectatorHitsTeleporters=True
	bListenServerPlayerRelevant=True
	bPatchUdpServerQuery=True
}
