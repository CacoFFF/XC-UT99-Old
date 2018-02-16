class XC_Engine_TournamentPlayer expands TournamentPlayer
	abstract;

//***************************** << - Returns B if A doesn't exist
native (3555) static final operator(22) Object | (Object A, skip Object B);


final function string PkgN( Object Other)
{
	return Left( String(Other), InStr( String(Other), ".")+1);
}

final function SummonInternal( string ClassName)
{
	local class<Actor> NewClass;
	local Actor NewActor;
	local string Params;
	local int i;
	local BoolProperty bP;
	local class PPClass;
	

	While ( Asc(ClassName) == 32 || Asc(ClassName) == 46 ) //Space or Dot
		ClassName = Mid(ClassName,1);

	if ( ClassName == "" )
	{
		ClientMessage("XC_Engine enhanced Summon command, formatted as follows:");
		ClientMessage("SUMMON CLASSNAME prop=value prop=value boolprop...etc");
		ClientMessage("If no package is specified for CLASSNAME it'll attempt to load from known/common packages");
		ClientMessage("Naming a boolean property is enough to set it to True when spawning the new actor");
		return;
	}
		
	i = InStr(ClassName," ");
	if ( i > 0 )
	{
		Params = Mid( ClassName, i+1);
		ClassName = Left(ClassName,i);
	}
		
	if ( InStr(ClassName,".") != -1 )
		NewClass = class<actor>( DynamicLoadObject( ClassName, class'Class' ) );
	else
		NewClass = class<Actor>(	DynamicLoadObject( "Botpack."				$ ClassName, class'Class', true) |
									DynamicLoadObject( "UnrealI."				$ ClassName, class'Class', true) |
									DynamicLoadObject( "Engine."				$ ClassName, class'Class', true) |
									DynamicLoadObject( PkgN(Level.Game.Class)	$ ClassName, class'Class', true) |
									DynamicLoadObject( PkgN(Self)				$ ClassName, class'Class', true) |
									DynamicLoadObject( PkgN(Class)				$ ClassName, class'Class', true) );
	if( NewClass != None )
		NewActor = Spawn( NewClass,,,Location + (72 + NewClass.Default.CollisionRadius*0.2) * Vector(ViewRotation) + vect(0,0,1) * 15 );

	if ( PlayerReplicationInfo != None )
	{
		if ( NewActor != None )
			log( "Fabricate" @ ClassName @ "by" @ PlayerReplicationInfo.PlayerName $ ": SUCCESS ("$PkgN(NewClass)$")" );
		else
			log( "Fabricate" @ ClassName @ "by" @ PlayerReplicationInfo.PlayerName $ ": FAILURE");
	}
	
	if ( NewActor != None )
	{
NEXT_PARAM:
		While ( Asc(Params) == 32 ) //Get rid of spaces
			Params = Mid(Params,1);
		if ( Len(Params) > 0 )
		{
			i = InStr(Params," ");
			if ( i == -1 )
			{
				ClassName = Params;
				Params = "";
			}
			else
			{
				ClassName = Left(Params,i);
				Params = Mid(Params,i+1);
			}
			i = InStr(ClassName,"=");
			if ( i > 0 )
				NewActor.SetPropertyText(Left(ClassName,i),Mid(ClassName,i+1));
			else
			{
				For ( PPClass=Newclass ; PPClass!=None ; PPClass=class'XC_CoreStatics'.static.GetParentClass(PPClass) )
					if ( class'XC_CoreStatics'.static.FindObject(ClassName, class'BoolProperty', PPClass) != None )
					{
						NewActor.SetPropertyText(ClassName,"1");
						break;
					}
			}
			goto NEXT_PARAM;
		}
	}
}

exec function Summon( string ClassName )
{
	local class<actor> NewClass;
	if( !bCheatsEnabled )
		return;
	if( !bAdmin && (Level.Netmode != NM_Standalone) )
		return;
	if ( Len(ClassName) > 1024 ) //Safeguard
		return;
	SummonInternal( ClassName);
}

