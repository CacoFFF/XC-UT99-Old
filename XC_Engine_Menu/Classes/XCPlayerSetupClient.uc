class XCPlayerSetupClient expands UTPlayerSetupClient;

var native XC_Engine_Actor_CFG ConfigModule;

// Any face on skin
var UWindowCheckbox AnyFaceOnSkinCheck;
var localized string AnyFaceOnSkinText;
var localized string AnyFaceOnSkinHelp;


function bool GetScriptConfig()
{
	if ( ConfigModule == None )
		ConfigModule = XC_Engine_Actor_CFG( Class'XC_CoreStatics'.static.FindObject( "XC_Engine.GeneralConfig", class'XC_Engine_Actor_CFG'));
	return ConfigModule != None;
}

function Created()
{
	local int ControlWidth, ControlLeft, ControlRight;
	local int CenterWidth, CenterPos;
	local int I, Num;

	Super.Created();

	ControlWidth = WinWidth/2.5;
	ControlLeft = (WinWidth/2 - ControlWidth)/2;
	ControlRight = WinWidth/2 + ControlLeft;

	CenterWidth = (WinWidth/4)*3;
	CenterPos = (WinWidth - CenterWidth)/2;

	ControlOffset += 25;
	AnyFaceOnSkinCheck = UWindowCheckbox(CreateControl(class'UWindowCheckbox', CenterPos, ControlOffset, CenterWidth, 1));
	AnyFaceOnSkinCheck.SetText(AnyFaceOnSkinText);
	AnyFaceOnSkinCheck.SetHelpText(AnyFaceOnSkinHelp);
	AnyFaceOnSkinCheck.SetFont(F_Normal);
	AnyFaceOnSkinCheck.Align = TA_Left;
	if ( GetScriptConfig() )
		AnyFaceOnSkinCheck.bChecked = ConfigModule.bAnyFaceOnSkin;

}

function BeforePaint(Canvas C, float X, float Y)
{
	Super.BeforePaint(C, X, Y);

	AnyFaceOnSkinCheck.SetSize( SpectatorCheck.WinWidth, SpectatorCheck.WinHeight); 
	AnyFaceOnSkinCheck.WinLeft = SpectatorCheck.WinLeft;
}



function IterateFaces(string InSkinName)
{
	local string SkinName, SkinDesc, TestName, Temp, FaceName;
	local bool bAnyFace;
	
	FaceCombo.Clear();

	// New format only
	if( !NewPlayerClass.default.bIsMultiSkinned )
	{
		FaceCombo.HideWindow();
		return;
	}
	FaceCombo.ShowWindow();

	bAnyFace = GetScriptConfig() && ConfigModule.bAnyFaceOnSkin;
	SkinName = "None";
	TestName = "";
	while ( True )
	{
		GetPlayerOwner().GetNextSkin(MeshName, SkinName, 1, SkinName, SkinDesc);

		if( SkinName == TestName )
			break;

		if( TestName == "" )
			TestName = SkinName;

		// Multiskin format
		if( SkinDesc != "")
		{			
			Temp = GetPlayerOwner().GetItemName(SkinName);
			if(Mid(Temp, 5) != "" && (bAnyFace || Left(Temp, 4) == GetPlayerOwner().GetItemName(InSkinName)))
				FaceCombo.AddItem(SkinDesc, Left(SkinName, Len(SkinName) - Len(Temp)) $ Mid(Temp, 5));
		}
	}
	FaceCombo.Sort();
}



function Notify(UWindowDialogControl C, byte E)
{
	Super.Notify(C, E);

	switch(E)
	{
	case DE_Change:
		switch(C)
		{
		case AnyFaceOnSkinCheck:
			AnyFaceOnSkinChecked();
			break;
		}
		break;
	}
}


function AnyFaceOnSkinChecked()
{
	if ( GetScriptConfig() )
	{
		ConfigModule.bAnyFaceOnSkin = AnyFaceOnSkinCheck.bChecked;
		ConfigModule.SaveConfig();
	}
}


defaultproperties
{
	AnyFaceOnSkinText="Allow all faces"
	AnyFaceOnSkinHelp="If checked, it'll be possible to select any compatible face on a given skin."
}

