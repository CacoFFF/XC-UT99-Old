//=============================================================================
// XC_SetupCommandlet.
//=============================================================================
class XC_SetupCommandlet expands Commandlet;

var class<Object> TestCls;
var Engine XCGE;
var Actor Actor;

enum EAction
{
	ACT_Info,
	ACT_Add,
	ACT_Remove
};

//These natives only work if XC_Engine is loaded in UCC/Editor environment
native(3530) final function bool GetConfigStr( string Section, string Key, out string Value, optional string FileName);
native(3534) final function SetConfigStr( string Section, string Key, string Value, optional string FileName);


event int Main( string Parms )
{
	local string CParms, NextParam, Command;
	local EAction Action;
	local int i;

	if ( !LoadEnvironment() )
	{
		Log("Failed to load environment, make sure this is a Unreal Tournament client or server installation");
		return 0;
	}
	Log("Environment succesfully loaded...");
	Log(" ");
	CParms = Caps(Parms);

AGAIN:
	NextParam = GetNextParam(Parms);
	if ( NextParam == "" )
	{
		XCGE = none;
		Actor = none;
		return 1;
	}
	i = Asc(NextParam);
	switch ( i )
	{
		case 42: // [*]
			Action = ACT_Info;
			break;
		case 43: // [+]
			Action = ACT_Add;
			break;
		case 45: // [-]
			Action = ACT_Remove;
			break;
		default:
			goto BAD_PARAMETER;
	}

	Command = Caps(Mid( NextParam, 1));
	switch ( Command )
	{
		case "ENGINE":
			ProcessEngineGeneric( Action,"GameEngine","XC_Engine.XC_GameEngine","Engine.GameEngine","XC Engine");
			break;
		case "NETDRIVER":
			ProcessEngineGeneric( Action,"NetworkDevice","XC_IpDrv.XC_TcpNetDriver","IpDrv.TcpNetDriver","XC TCP driver");
			break;
		case "EDITOR":
			ProcessEditorAddons( Action);
			break;
		default:
			goto BAD_PARAMETER;
	}
	goto AGAIN;

BAD_PARAMETER:
	if ( !(Left(NextParam,5) ~= "-ini=") )
		Log("XC_Setup: Bad parameter "$NextParam);
	goto AGAIN;
}

function ProcessEditorAddons( EAction Action)
{
	local class<Engine> EditorCls;
	local string ObjectTitle, PackageList, Pkg;
	local int iSet;
	
	EditorCls = class<Engine>( DynamicLoadObject("Editor.EditorEngine",class'Class') );
	if ( EditorCls == None )
	{
		Log("This setup doesn't have Editor support");
		return;
	}
	PackageList = Actor.ConsoleCommand("get ini:engine.engine.editorengine EditPackages");
	Pkg = "," $ Chr(34) $ "XC_EditorAdds" $ Chr(34);
	iSet = InStr(PackageList,Pkg);
	ObjectTitle = "Editor addon";
	
	if ( Action == ACT_Info )
		Log( ObjectTitle@"status:"@EnabledDisabled(iSet!=-1));
	else if ( Action == ACT_Add )
	{
		if ( iSet != -1 )
			Log( ObjectTitle@"already enabled");
		else
		{
			PackageList = Left(PackageList,Len(PackageList)-1) $ Pkg $ ")";
			Actor.ConsoleCommand("set ini:engine.engine.editorengine EditPackages"@PackageList);
			Log( ObjectTitle@"has been enabled");
		}
	}
	else if ( Action == ACT_Remove )
	{
		if ( iSet == -1 )
			Log( ObjectTitle@"already disabled");
		else
		{
			PackageList = Left(PackageList,iSet) $ Mid(PackageList,iSet+Len(Pkg));
			Actor.ConsoleCommand("set ini:engine.engine.editorengine EditPackages"@PackageList);
			Log( ObjectTitle@"has been disabled");
		}
	}
}

function ProcessEngineGeneric( EAction Action, string ConfigName, string ObjectName, string DefaultObjectName, string ObjectTitle)
{
	local string CurSetting;
	local bool bSet;
	local Object GenericObject;
	
	GetConfigStr( "Engine.Engine", ConfigName, CurSetting);
	bSet = CurSetting ~= ObjectName;
	
	if ( Action == ACT_Info )
		Log( ObjectTitle@"status:"@EnabledDisabled(bSet));
	else if ( Action == ACT_Add )
	{
		if ( bSet )
			Log( ObjectTitle@"already enabled");
		else
		{
			SetConfigStr( "Engine.Engine", ConfigName, ObjectName);
			(new class<Object>(DynamicLoadObject(ObjectName,class'Class'))).SaveConfig();
			Log( ObjectTitle@"has been enabled, config saved");
		}
	}
	else if ( Action == ACT_Remove )
	{
		if ( !bSet )
			Log( ObjectTitle@"already disabled");
		else
		{
			SetConfigStr( "Engine.Engine", ConfigName, DefaultObjectName);
			Log( ObjectTitle@"has been disabled");
		}
	}
}

final function string EnabledDisabled( bool b)
{
	if ( b )
		return "ENABLED";
	else
		return "DISABLED";
}

final function bool LoadEnvironment()
{
	local Level Level;
	local class<Engine> XCGEc;
	
	SetPropertyText("XCGE","XC_GameEngine0");
	if ( XCGE != none )
		return false;
	XCGEc = class<Engine>( DynamicLoadObject("XC_Engine.XC_GameEngine",class'Class'));
	if ( XCGEc == None )
		return false;
	XCGE = new XCGEc;
	Level = Level( DynamicLoadObject("Entry.MyLevel",class'Level'));
	if ( Level == none )
		return false; //Entry level not present
	ForEach class'XC_CoreStatics'.static.AllObjects( class'Actor', Actor)
		break;
	Level.SetPropertyText("Engine","XC_GameEngine0");
	if ( Actor == none || Level.GetPropertyText("Engine") == "" ) //Only XCGE v21 can do this
		return false; //Cannot enable ConsoleCommand
	return true;
}

function string GetNextParam( out string Parms)
{
	local int i, Pos[3], iBest;
	local string Search[3];

	if ( Len(Parms) <= 0 )
		return "";
	Search[0] = "+";
	Search[1] = "-";
	Search[2] = "*";
	iBest = 9999;
	for ( i=0 ; i<3 ; i++ )
	{
		Pos[i] = InStr(Parms,Search[i]);
		if ( Pos[i] >= 0 && Pos[i] < iBest )
			iBest = Pos[i];
	}
	if ( iBest >= Len(Parms) )
		return "";
	Parms = Mid( Parms, iBest);

	i = InStr( Parms, " ");
	if ( i == -1 )
		i = Len(Parms);
	Search[0] = Left( Parms, i);
	Parms = Mid( Parms, i+1 );
	return Search[0];
}


defaultproperties
{
    HelpCmd="xc_setup"
	HelpOneLiner="Installs/uninstalls XC components"
	HelpUsage="ucc xc_setup +add -remove *status"
	HelpParm(0)="engine"
	HelpDesc(0)="Game Engine update"
	HelpParm(1)="netdriver"
	HelpDesc(1)="Net Driver update"
	HelpParm(2)="editor"
	HelpDesc(2)="Editor addons"
	LogToStdout=true
	ShowBanner=false
	LazyLoad=true
	IsServer=false
	IsClient=false
	IsEditor=true
}