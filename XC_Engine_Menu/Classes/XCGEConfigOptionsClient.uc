class XCGEConfigOptionsClient expands UMenuPageWindow;

var native XC_Engine_Actor_CFG ConfigModule;
var native XC_GameEngine Engine;

// Raw Input
var UWindowCheckbox RawInputCheck;
var localized string RawInputText;
var localized string RawInputHelp;

// Framerate limiter
var UWindowEditControl FramerateEdit;
var localized string FramerateText;
var localized string FramerateHelp;

// Lan player host
var UWindowCheckbox LanPlayerHostCheck;
var localized string LanPlayerHostText;
var localized string LanPlayerHostHelp;

// Developer logs
var UWindowCheckbox DevLogsCheck;
var localized string DevLogsText;
var localized string DevLogsHelp;

//=====================
//==== Map List Sorting

// Map list sort label
var UMenuLabelControl MapListTitle;
var localized string MapListText;

// Sort by Folder
var UWindowCheckbox MapSortFolderCheck;
var localized string MapSortFolderText;
var localized string MapSortFolderHelp;

// Sort Inverted
var UWindowCheckbox MapSortInvertCheck;
var localized string MapSortInvertText;
var localized string MapSortInvertHelp;


var float ControlOffset;

function bool GetScriptConfig()
{
	if ( ConfigModule == None )
		ConfigModule = XC_Engine_Actor_CFG( Class'XC_CoreStatics'.static.FindObject( "XC_Engine.GeneralConfig", class'XC_Engine_Actor_CFG'));
	return ConfigModule != None;
}

function SaveEngineConfig()
{
	if ( Engine == None )
		Engine = XC_GameEngine(Class'XC_CoreStatics'.static.FindObject( "XC_GameEngine0", class'XC_GameEngine'));
	Engine.SaveConfig();
}

final function string GetFramerate()
{
	local int iValue;
	
	iValue = int(GetPlayerOwner().ConsoleCommand("get XC_GameEngine ClientFramerateLimit"));
	if ( iValue < 4 || iValue > 200 )
		iValue = 200;
	return string(iValue);
}

function Created()
{
	local int ControlWidth, TitleWidth, ControlLeft, ControlRight;
	local int CenterWidth, CenterPos, i;
	local string Sens;

	Super.Created();

	ControlWidth = WinWidth/2.5;
	ControlLeft = (WinWidth/2 - ControlWidth)/2;
	ControlRight = WinWidth/2 + ControlLeft;

	CenterWidth = (WinWidth/4)*3;
	CenterPos = (WinWidth - CenterWidth)/2;
	
	ControlOffset = 40;
	
	//========
	// Client
	
	// RawInput //1L
	RawInputCheck = UWindowCheckbox(CreateControl(class'UWindowCheckbox', ControlLeft, ControlOffset, ControlWidth, 1));
	RawInputCheck.bChecked = bool(GetPlayerOwner().ConsoleCommand("get XC_GameEngine bUseRawInput"));
	RawInputCheck.SetText(RawInputText);
	RawInputCheck.SetHelpText(RawInputHelp);
	RawInputCheck.SetFont(F_Normal);
	RawInputCheck.Align = TA_Right;
	// Framerate limiter //1R
	FramerateEdit = UWindowEditControl(CreateControl(class'UWindowEditControl', ControlRight, ControlOffset, ControlWidth, 1));
	FramerateEdit.SetText(FramerateText);
	FramerateEdit.SetHelpText(FramerateHelp);
	FramerateEdit.SetFont(F_Normal);
	FramerateEdit.SetNumericOnly(True);
	FramerateEdit.SetNumericFloat(False);
	FramerateEdit.SetMaxLength(3);
	FramerateEdit.Align = TA_Right;
	FramerateEdit.SetDelayedNotify(True);
	FramerateEdit.SetValue( GetFramerate() );
	ControlOffset += 25;
	
	//========
	// Server
	ControlOffset += 10;
	
	
	// LanPlayerHost //2L
	LanPlayerHostCheck = UWindowCheckbox(CreateControl(class'UWindowCheckbox', ControlLeft, ControlOffset, ControlWidth, 1));
	if ( GetScriptConfig() )
		LanPlayerHostCheck.bChecked = ConfigModule.bListenServerPlayerRelevant;
	LanPlayerHostCheck.SetText(LanPlayerHostText);
	LanPlayerHostCheck.SetHelpText(LanPlayerHostHelp);
	LanPlayerHostCheck.SetFont(F_Normal);
	LanPlayerHostCheck.Align = TA_Right;
	// 2R = nothing here
	ControlOffset += 25;

	//=======
	// Debug
	ControlOffset += 10;

	// Developer logs //3R
	DevLogsCheck = UWindowCheckbox(CreateControl(class'UWindowCheckbox', ControlLeft, ControlOffset, ControlWidth, 1));
	DevLogsCheck.bChecked = bool(GetPlayerOwner().ConsoleCommand("get XC_GameEngine bEnableDebugLogs"));
	DevLogsCheck.SetText(DevLogsText);
	DevLogsCheck.SetHelpText(DevLogsHelp);
	DevLogsCheck.SetFont(F_Normal);
	DevLogsCheck.Align = TA_Right;
	// 3R = nothing here
	ControlOffset += 25;
	
	
	//==========
	// Map List
	ControlOffset += 10;
	MapListTitle = UMenuLabelControl(CreateControl(class'UMenuLabelControl', CenterPos, ControlOffset, CenterWidth, 1)); 
	MapListTitle.SetText(MapListText);
	MapListTitle.Align = TA_Center;
	ControlOffset += 15;
	
	// Sort by Folder //Left
	MapSortFolderCheck = UWindowCheckbox(CreateControl(class'UWindowCheckbox', ControlLeft, ControlOffset, ControlWidth, 1));
	MapSortFolderCheck.bChecked = bool(GetPlayerOwner().ConsoleCommand("get XC_GameEngine bSortMaplistByFolder"));
	MapSortFolderCheck.SetText(MapSortFolderText);
	MapSortFolderCheck.SetHelpText(MapSortFolderHelp);
	MapSortFolderCheck.SetFont(F_Normal);
	MapSortFolderCheck.Align = TA_Right;
	// Sort Inverted //Right
	MapSortInvertCheck = UWindowCheckbox(CreateControl(class'UWindowCheckbox', ControlRight, ControlOffset, ControlWidth, 1));
	MapSortInvertCheck.bChecked = bool(GetPlayerOwner().ConsoleCommand("get XC_GameEngine bSortMaplistInvert"));
	MapSortInvertCheck.SetText(MapSortInvertText);
	MapSortInvertCheck.SetHelpText(MapSortInvertHelp);
	MapSortInvertCheck.SetFont(F_Normal);
	MapSortInvertCheck.Align = TA_Right;
}

function AfterCreate()
{
	DesiredWidth = 220;
	DesiredHeight = ControlOffset;
}

function BeforePaint(Canvas C, float X, float Y)
{
	local int ControlWidth, ControlLeft, ControlRight;
	local int CenterWidth, CenterPos;

	ControlWidth = WinWidth/2.5;
	ControlLeft = (WinWidth/2 - ControlWidth)/2;
	ControlRight = WinWidth/2 + ControlLeft;

	CenterWidth = (WinWidth/4)*3;
	CenterPos = (WinWidth - CenterWidth)/2;

	FramerateEdit.SetSize(ControlWidth, 1);
	FramerateEdit.WinLeft = ControlRight;
	FramerateEdit.EditBoxWidth = 25;

	RawInputCheck.SetSize(ControlWidth, 1);
	RawInputCheck.WinLeft = ControlLeft;

	LanPlayerHostCheck.SetSize(ControlWidth, 1);
	LanPlayerHostCheck.WinLeft = ControlLeft;

	DevLogsCheck.SetSize(ControlWidth, 1);
	DevLogsCheck.WinLeft = ControlLeft;
	
	MapListTitle.SetSize(CenterWidth, 1);
	MapListTitle.WinLeft = CenterPos;
	MapSortFolderCheck.SetSize(ControlWidth, 1);
	MapSortFolderCheck.WinLeft = ControlLeft;
	MapSortInvertCheck.SetSize(ControlWidth, 1);
	MapSortInvertCheck.WinLeft = ControlRight;
}

function Notify(UWindowDialogControl C, byte E)
{
	Super.Notify(C, E);
	switch(E)
	{
	case DE_Change:
		switch(C)
		{
		case RawInputCheck:
			RawInputChecked();
			break;
		case FramerateEdit:
			FramerateChanged();
			break;
		case LanPlayerHostCheck:
			LanPlayerHostChecked();
			break;
		case DevLogsCheck:
			DevLogsChecked();
			break;
		case MapSortFolderCheck:
			MapSortFolderChecked();
			break;
		case MapSortInvertCheck:
			MapSortInvertChecked();
			break;
		}
	}
}

function RawInputChecked()
{
	GetPlayerOwner().ConsoleCommand("set XC_GameEngine bUseRawInput " $ int(RawInputCheck.bChecked));
	SaveEngineConfig();
}

function MapSortFolderChecked()
{
	GetPlayerOwner().ConsoleCommand("set XC_GameEngine bSortMaplistByFolder " $ int(MapSortFolderCheck.bChecked));
	SaveEngineConfig();
}

function MapSortInvertChecked()
{
	GetPlayerOwner().ConsoleCommand("set XC_GameEngine bSortMaplistInvert " $ int(MapSortInvertCheck.bChecked));
	SaveEngineConfig();
}

function FramerateChanged()
{
	local int NewValue;
	
	NewValue = int(FramerateEdit.EditBox.Value);
	if ( NewValue <= 0 )
		FramerateEdit.EditBox.Value = GetFramerate();
	else if ( NewValue < 4 )
		FramerateEdit.EditBox.Value = "4";
	else if ( NewValue > 200 )
		FramerateEdit.EditBox.Value = "200";
	GetPlayerOwner().ConsoleCommand("FPS" @ FramerateEdit.EditBox.Value);
}

function LanPlayerHostChecked()
{
	if ( GetScriptConfig() )
	{
		ConfigModule.bListenServerPlayerRelevant = LanPlayerHostCheck.bChecked;
		ConfigModule.SaveConfig();
	}
}

function DevLogsChecked()
{
	GetPlayerOwner().ConsoleCommand("ToggleDebugLogs");
	DevLogsCheck.bChecked = bool(GetPlayerOwner().ConsoleCommand("get XC_GameEngine bEnableDebugLogs"));
}


defaultproperties
{
	RawInputText="Raw Input"
	RawInputHelp="Enabling Raw Input will remove all mouse filtering and acceleration. You must disable DirectInput and restart the game for this setting to take effect."
	DevLogsText="Developer log"
	DevLogsHelp="If checked, XC_Engine will print additional information to the game/server log."
	LanPlayerHostText="LAN Host Skin"
	LanPlayerHostHelp="If checked, LAN games hosts will have their player, skin and voice automatically setup for download."
	FramerateText="Max Framerate"
	FramerateHelp="Sets the game's maximum framerate (4 to 200). Make sure to disable any framerate limiter in the renderer!."
	MapListText="Map List Sorting"
	MapSortFolderText="By Directory"
	MapSortFolderHelp="Sorts the map list by directories instead of globally."
	MapSortInvertText="Inverted"
	MapSortInvertHelp="Reverses the map list order."
}


