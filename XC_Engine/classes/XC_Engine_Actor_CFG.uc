class XC_Engine_Actor_CFG expands XC_CoreStatics
	perobjectconfig
	transient;

var() config string XCGE_Actors_Description[8];
var() config array<string> XCGE_Actors;
var() config bool bFixBroadcastMessage;
var() config bool bSpectatorHitsTeleporters;
var() config bool bListenServerPlayerRelevant;
var() config bool bPatchUdpServerQuery;
var() config bool bSpawnServerActor;
var() config bool bFixMoverTimeMP; //Fix mover times in multiplayer
var() config int LastVersion;

native(640) static final function int Array_Length_Str( out array<string> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_Str( out array<string> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_Str( out array<string> Ar, int Offset, optional int Count );

/*=============== Setup begin ===============*/
//
// Entry point, checks conditions and spawns XC_Engine_Actor mods
//
function Setup( XC_Engine_Actor Other)
{
	local int i, k, ACount;
	local string Parsed;
	local class<XC_Engine_Actor> aClass;
	local Actor A;
	local name ClassName;

	UpgradeVersion();
	
	ACount = Array_Length_Str( XCGE_Actors);
	for ( i=0 ; i<ACount ; i++ )
	{
		ClassName = '';
		Parsed = XCGE_Actors[i];
		// Attempt to find a package in memory
		if ( Left( Parsed, 8) ~= "PACKAGE:" )
		{
			Parsed = Mid( Parsed, 8);
			k = InStr( Parsed, ":");
			if ( (k != -1) && (FindObject( Left(Parsed,k), class'Package') != None) )
				Parsed = Mid( Parsed, k+1);
			else
				Parsed = "";
		}
		// Attempt to find a class in memory
		else if ( Left( Parsed, 6) ~= "CLASS:" )
		{
			Parsed = Mid( Parsed, 6);
			k = InStr( Parsed, ":");
			if ( (k != -1) && (FindObject( Left(Parsed,k), class'Class') != None) )
				Parsed = Mid( Parsed, k+1);
			else
				Parsed = "";
		}
		// Attempt to find actor in level
		else if ( Left( Parsed, 11) ~= "ACTORCLASS:" )
		{
			Parsed = Mid( Parsed, 11);
			k = InStr( Parsed, ":");
			if ( k != -1 )
			{
				ClassName = StringToName( Left(Parsed,k) );
				Parsed = Mid( Parsed, k+1);
				k = -1;
				if ( ClassName != '' )
				{
					ForEach Other.AllActors( class'Actor', A)
						if ( A.IsA( ClassName) )
						{
							k = 0;
							break;
						}
				}
			}
			if ( k == -1 ) // Actor not found
				Parsed = "";
		}
		// See if the Game is of a specific type
		else if ( Left( Parsed, 10) ~= "GAMECLASS:" )
		{
			Parsed = Mid( Parsed, 10);
			k = InStr( Parsed, ":");
			if ( k != -1 )
			{
				ClassName = StringToName( Left(Parsed,k) );
				if ( (Other.Level.Game != None) && Other.Level.Game.IsA( ClassName) )
					Parsed = Mid( Parsed, k+1);
				else
					k = -1;
			}
			if ( k == -1 ) // Actor not found
				Parsed = "";
		}
		

		// Spawn the actor
		if ( Parsed != "" )
		{
			aClass = class<XC_Engine_Actor>( DynamicLoadObject( Parsed, class'class'));
			if ( aClass != None && (aClass != Other.Class) )
				Other.Spawn(aClass).XC_Init();
		}
	}
	SaveConfig();
}
/*=============== Setup end ===============*/



/*=============== UpgradeVersion begin ===============*/
//
// Automatically sets up config on first use and version change.
//
function UpgradeVersion()
{
	local string Str;
	local int i, Size;

	if ( Len(XCGE_Actors_Description[3]) <= 0 )
	{
		XCGE_Actors_Description[0] = "This list contains subclasses of XC_Engine.XC_Engine_Actor to be spawned";
		XCGE_Actors_Description[1] = "The main XC_Engine_Actor will call XC_Init() on these actors before InitGame()";
		XCGE_Actors_Description[2] = "Condition types and corresponding parameter:";
		XCGE_Actors_Description[3] = "- ACTOR >> Always spawn this actor.";
		XCGE_Actors_Description[4] = "- PACKAGE:PACKAGENAME:ACTOR >> Spawn if package is loaded.";
		XCGE_Actors_Description[5] = "- CLASS:CLASSNAME:ACTOR >> Spawn if class is loaded.";
		XCGE_Actors_Description[6] = "- ACTORCLASS:CLASSNAME:ACTOR >> Spawn if level has actor of this class (IsA) /slow!!/.";
		XCGE_Actors_Description[7] = "- GAMECLASS:CLASSNAME:ACTOR >> Spawn if GameInfo is of this class (IsA).";
	}
	
	if ( LastVersion < 22 )
	{
		Array_Length_Str( XCGE_Actors, 0);
		AddConditionUnique( "PACKAGE:Unreali:XC_Engine_UT99.XC_Engine_UT99_Actor");
		AddConditionUnique( "PACKAGE:s_SWAT:XC_Engine_TOs.XC_Engine_TOs_Actor");
		AddConditionUnique( "CLASS:SCFActor:XC_Engine.SCF_Disabler");
	}
	
	LastVersion = 22;
	
}
/*=============== UpgradeVersion end ===============*/



/*=============== AddConditionUnique begin ===============*/
//
// Adds a condition for XC_Engine_Actor derivates if missing
//
function AddConditionUnique( string Condition)
{
	local int i, Size;
	
	Size = Array_Length_Str( XCGE_Actors);
	for ( i=0 ; i<Size ; i++ )
		if ( XCGE_Actors[i] == Condition )
			return;
	Array_Insert_Str( XCGE_Actors, i, 1);
	XCGE_Actors[i] = Condition;
}
/*=============== AddConditionUnique end ===============*/


defaultproperties
{
	bFixBroadcastMessage=True
	bSpectatorHitsTeleporters=True
	bListenServerPlayerRelevant=True
	bPatchUdpServerQuery=True
	bSpawnServerActor=True
	bFixMoverTimeMP=True
	LastVersion=21
}
