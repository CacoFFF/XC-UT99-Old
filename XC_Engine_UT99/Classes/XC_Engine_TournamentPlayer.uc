class XC_Engine_TournamentPlayer expands TournamentPlayer
	abstract;


	
//***************************** << - Returns B if A doesn't exist
native (3555) static final operator(22) Object | (Object A, skip Object B);


//****************************************
// Summon extender
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


//****************************************
// SetMultiSkin extender
static function SetMultiSkin(Actor SkinActor, string SkinName, string FaceName, byte TeamNum)
{
	local string MeshName, FacePackage, SkinItem, FaceItem, SkinPackage;

	MeshName = SkinActor.GetItemName(string(SkinActor.Mesh));

	SkinItem = SkinActor.GetItemName(SkinName);
	FaceItem = SkinActor.GetItemName(FaceName);
	FacePackage = Left(FaceName, Len(FaceName) - Len(FaceItem));
	SkinPackage = Left(SkinName, Len(SkinName) - Len(SkinItem));

	if(SkinPackage == "")
	{
		SkinPackage=default.DefaultPackage;
		SkinName=SkinPackage$SkinName;
	}
	if(FacePackage == "")
	{
		FacePackage=default.DefaultPackage;
		FaceName=FacePackage$FaceName;
	}

	// Set the fixed skin element.  If it fails, go to default skin & no face.
	if(!SetSkinElement(SkinActor, default.FixedSkin, SkinName$string(default.FixedSkin+1), default.DefaultSkinName$string(default.FixedSkin+1)))
	{
		SkinName = default.DefaultSkinName;
		FaceName = "";
	}

	// Set the face - if it fails, set the default skin for that face element.
	ModifySkinItem_TP( SkinActor, default.Class, FacePackage, FaceItem, SkinItem);
	SetSkinElement(SkinActor, default.FaceSkin, FacePackage$SkinItem$String(default.FaceSkin+1)$FaceItem, SkinName$String(default.FaceSkin+1));

	// Set the team elements
	if( TeamNum != 255 )
	{
		SetSkinElement(SkinActor, default.TeamSkin1, SkinName$string(default.TeamSkin1+1)$"T_"$String(TeamNum), SkinName$string(default.TeamSkin1+1));
		SetSkinElement(SkinActor, default.TeamSkin2, SkinName$string(default.TeamSkin2+1)$"T_"$String(TeamNum), SkinName$string(default.TeamSkin2+1));
	}
	else
	{
		SetSkinElement(SkinActor, default.TeamSkin1, SkinName$string(default.TeamSkin1+1), "");
		SetSkinElement(SkinActor, default.TeamSkin2, SkinName$string(default.TeamSkin2+1), "");
	}

	// Set the talktexture
	if(Pawn(SkinActor) != None)
	{
		if(FaceName != "")
			Pawn(SkinActor).PlayerReplicationInfo.TalkTexture = Texture(DynamicLoadObject(FacePackage$SkinItem$"5"$FaceItem, class'Texture'));
		else
			Pawn(SkinActor).PlayerReplicationInfo.TalkTexture = None;
	}		
}
static final function ModifySkinItem_TP( Actor SkinActor, class<TournamentPlayer> TPInstance, string FacePackage, string FaceItem, out string SkinItem)
{
	local Package P;
	local Texture Face;
	local float F[2], Time;
	local string TextureName;
	local int FaceSkin;
	local int i;
	local array<Object> TextureList;
	
	if ( !class'XC_Engine_Actor_CFG'.default.bAnyFaceOnSkin )
		return;
		
	FaceSkin = TPInstance.default.FaceSkin + 1;
	Face = Texture( DynamicLoadObject(FacePackage$SkinItem$FaceSkin$FaceItem, class'Texture', true));
	if ( Face != None )
		return;
		
	FacePackage = Left( FacePackage, Len(FacePackage)-1);
	if ( (SkinActor.Level.NetMode == NM_DedicatedServer || SkinActor.Level.NetMode == NM_ListenServer) && !SkinActor.IsInPackageMap(FacePackage) )
		return;
		
	Clock( F);
	if ( LoadPackageContents( FacePackage, class'Texture', TextureList) )
	{
		for ( i=Array_Length(TextureList)-1 ; i>=0 ; i-- )
		{
			TextureName = string(TextureList[i].Name);
			if ( Right(TextureName,Len(FaceItem)) ~= FaceItem )
			{
				SkinItem = Left(TextureName,Len(TextureName)-Len(FaceItem)-1);
				break;
			}
		}
	}
	Time = UnClock( F);
//	Log("Texture scanner took"@Time@"seconds",'XC_Engine');
}



static function SetMultiSkin_Boss(Actor SkinActor, string SkinName, string FaceName, byte TeamNum)
{
	local string MeshName, SkinItem, SkinPackage;
	local string TeamAppend;
	local int i;

	MeshName = SkinActor.GetItemName(string(SkinActor.Mesh));

	SkinItem = SkinActor.GetItemName(SkinName);
	SkinPackage = Left(SkinName, Len(SkinName) - Len(SkinItem));

	if(SkinPackage == "")
	{
		SkinPackage="BossSkins.";
		SkinName=SkinPackage$SkinName;
	}

	if ( TeamNum != 255 )
		TeamAppend = "T_"$String(TeamNum);
		
	if ( !SetSkinElement(SkinActor, 0, SkinName$"1"$TeamAppend, default.DefaultSkinName$"1"$TeamAppend) //Try team skin
	&& (TeamAppend == "" || !SetSkinElement(SkinActor, 0, SkinName$"1", default.DefaultSkinName$"1")) ) //Try non team skin
	{
		SkinName=default.DefaultSkinName;
		SetSkinElement(SkinActor, 0, SkinName$"1"$TeamAppend, SkinName$"1"$TeamAppend);
	}
	SetSkinElement(SkinActor, 1, SkinName$"2"$TeamAppend, SkinName$"2"$TeamAppend);
	SetSkinElement(SkinActor, 2, SkinName$"3"$TeamAppend, SkinName$"3"$TeamAppend);
//	ModifySkinItem_Boss( SkinActor, FaceName, SkinPackageItem);
	SetSkinElement(SkinActor, 3, SkinName$"4"$TeamAppend, SkinName$"4"$TeamAppend);
	
	if( (Pawn(SkinActor) != None) && (Pawn(SkinActor).PlayerReplicationInfo != None) ) 
	{
		Pawn(SkinActor).PlayerReplicationInfo.TalkTexture = Texture(DynamicLoadObject(SkinName$"5Xan", class'Texture'));
	}
}

static final function ModifySkinItem_Boss( Actor SkinActor, string FaceName, out string SkinPackageItem)
{
	local Package P;
	local Texture Face;
	local float F[2], Time;
	local string FacePackage, TextureName;
	local int i;
	local array<Object> TextureList;
	
	if ( !class'XC_Engine_Actor_CFG'.default.bAnyFaceOnSkin )
		return;
		
/*	Face = Texture( DynamicLoadObject(SkinPackageItem$"4"$FaceItem, class'Texture', true));
	if ( Face != None )
		return;
		
	FacePackage = Left( FacePackage, Len(FacePackage)-1);
	if ( (SkinActor.Level.NetMode == NM_DedicatedServer || SkinActor.Level.NetMode == NM_ListenServer) && !SkinActor.IsInPackageMap(FacePackage) )
		return;
		
	Clock( F);
	if ( LoadPackageContents( FacePackage, class'Texture', TextureList) )
	{
		for ( i=Array_Length(TextureList)-1 ; i>=0 ; i-- )
		{
			TextureName = string(TextureList[i].Name);
			if ( Right(TextureName,Len(FaceItem)) ~= FaceItem )
			{
				SkinPackageItem = Left(TextureName,Len(TextureName)-Len(FaceItem)-1);
				break;
			}
		}
	}
	Time = UnClock( F);*/
//	Log("Texture scanner took"@Time@"seconds",'XC_Engine');
}
