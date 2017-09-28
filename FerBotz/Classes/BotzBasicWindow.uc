//=============================================================================
// BotzBasicWindow.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BotzBasicWindow
	expands UMenuDialogClientWindow
	config(BotzDefault);

var BotzMenuInfo MyInfoOwner;
var() int ControlOffset;
var() int TextX;
var() int OptionsOffset;
var() int Intermedio;
var() int BaseY;

var class<Pawn> NewBotzClass;
var() string MeshName;
var bool Initialized;
var bool bCurrentlyLoading;
var bool bRaizOne;
var bool bRaizTwo;
var() string BotzBaseClass;


var config string LastName;
var config string LastTeam;
var config string LastClass;
var config string LastSkin;
var config string LastFace;
var config string LastSkill;
var config string LastVoice;
var config string LastWeapon;
var config string LastAcc;
var config string LastCTime;
var config string LastCChance;


// BotzName Name
var UWindowEditControl NameEdit;
var() string NameText;

// Team Combo
var UWindowComboControl TeamCombo;
var() string TeamText;
var() string Teams[4];
var() string NoTeam;

// Mesh Combo
var UWindowComboControl ClassCombo;
var() string ClassText;

// Skin Combo
var UWindowComboControl SkinCombo;
var() string SkinText;

// Face Combo
var UWindowComboControl FaceCombo;
var() string FaceText;

// Skill Slider
var UWindowHSliderControl SkillSlider;
var() string SkillText;

// Voice Combo
var UWindowComboControl VoicePackCombo;
var() string VoicePackText;

// ArmaFavorita Combo
var UWindowComboControl FavoriteWeaponCombo;
var() string FavoriteWeaponText;
var() string NoFavoriteWeapon;

// Accuracy Slider
var UWindowHSliderControl AccuracySlider;
var() string AccuracyText;

// Camp Slider and Timer
var UWindowHSliderControl CampingSlider;
var() string CampingText;
var UWindowEditControl CampTime;
var() string CampTimeText;

var UWindowCheckbox CreatefButton;
var() string CreatefText;

function Created()
{
	local string SkinName, FaceName;

	local int ControlWidth, ControlLeft, ControlRight;
	local int CenterWidth, CenterPos;
	local int I;

	local BotzMenuInfo fffg;

	Super.Created();

	ForEach GetPlayerOwner().AllActors (class'BotzMenuInfo', fffg)
		if ( GetPlayerOwner() == PlayerPawn(fffg.Owner) )
			MyInfoOwner = fffg;

	ControlWidth = WinWidth/2.5;
	ControlLeft = (WinWidth/2 - ControlWidth)/2;
	ControlRight = WinWidth/2 + ControlLeft;

	CenterWidth = (WinWidth/4)*3;
	CenterPos = (WinWidth - CenterWidth)/2;

	NewBotzClass = class'Botz';

	// Player Name
	NameEdit = UWindowEditControl(CreateControl(class'UWindowEditControl', CenterPos, ControlOffset, CenterWidth, 1));
	NameEdit.SetText(NameText);
	NameEdit.SetHelpText("Si se usa Aleatorio como nombre, se eligirá uno predeterminado");
	NameEdit.SetFont(F_Normal);
	NameEdit.SetNumericOnly(False);
	NameEdit.SetMaxLength(22);

	// Team
	ControlOffset += Intermedio;
	TeamCombo = UWindowComboControl(CreateControl(class'UWindowComboControl', CenterPos, ControlOffset, CenterWidth, 1));
	TeamCombo.SetText(TeamText);
	TeamCombo.SetHelpText("");
	TeamCombo.SetFont(F_Normal);
	TeamCombo.SetEditable(False);
	for (I=0; I<4; I++)
		TeamCombo.AddItem(Teams[I], String(i));
	TeamCombo.AddItem("Aleatorio", "100");
	TeamCombo.AddItem(NoTeam, String(255));
	TeamCombo.SetSelectedIndex(5);

	ControlOffset += Intermedio;
	// Load Classes
	ClassCombo = UWindowComboControl(CreateControl(class'UWindowComboControl', CenterPos, ControlOffset, CenterWidth, 1));
	ClassCombo.SetText(ClassText);
	ClassCombo.SetHelpText("Boss por defecto");
	ClassCombo.SetEditable(False);
	ClassCombo.SetFont(F_Normal);

	// Skin
	ControlOffset += Intermedio;
	SkinCombo = UWindowComboControl(CreateControl(class'UWindowComboControl', CenterPos, ControlOffset, CenterWidth, 1));
	SkinCombo.SetText(SkinText);
	SkinCombo.SetHelpText("");
	SkinCombo.SetFont(F_Normal);
	SkinCombo.SetEditable(False);


	// Face
	ControlOffset += Intermedio;
	FaceCombo = UWindowComboControl(CreateControl(class'UWindowComboControl', CenterPos, ControlOffset, CenterWidth, 1));
	FaceCombo.SetText(FaceText);
	FaceCombo.SetHelpText("");
	FaceCombo.SetFont(F_Normal);
	FaceCombo.SetEditable(False);

	// Voice
	ControlOffset += Intermedio;
	VoicePackCombo = UWindowComboControl(CreateControl(class'UWindowComboControl', CenterPos, ControlOffset, CenterWidth, 1));
	VoicePackCombo.SetText(VoicePackText);
	VoicePackCombo.SetHelpText("");
	VoicePackCombo.SetFont(F_Normal);
	VoicePackCombo.SetEditable(False);

	// Skill Slider
	ControlOffset += Intermedio;
	SkillSlider = UWindowHSliderControl(CreateControl(class'UWindowHSliderControl', CenterPos, ControlOffset, CenterWidth, 1));
	SkillSlider.SetText(SkillText);
	SkillSlider.SetHelpText("");
	SkillSlider.SetFont(F_Normal);
	SkillSlider.SetRange(0, 70, 1);

	// Weapon Combo
	ControlOffset += Intermedio;
	FavoriteWeaponCombo = UWindowComboControl(CreateControl(class'UWindowComboControl', CenterPos, ControlOffset, CenterWidth, 1));
	FavoriteWeaponCombo.SetText(FavoriteWeaponText);
	FavoriteWeaponCombo.SetHelpText("");
	FavoriteWeaponCombo.SetFont(F_Normal);
	FavoriteWeaponCombo.SetEditable(False);
	LoadWeapons();

	// Accuracy Slider
	ControlOffset += Intermedio;
	AccuracySlider = UWindowHSliderControl(CreateControl(class'UWindowHSliderControl', CenterPos, ControlOffset, CenterWidth, 1));
	AccuracySlider.SetRange(0, 200, 10);
	AccuracySlider.SetText(AccuracyText);
	AccuracySlider.SetHelpText("");
	AccuracySlider.SetFont(F_Normal);

	// Camping Slider
	ControlOffset += Intermedio;
	CampingSlider = UWindowHSliderControl(CreateControl(class'UWindowHSliderControl', CenterPos, ControlOffset, CenterWidth, 1));
	CampingSlider.SetRange(0, 100, 5);
	CampingSlider.SetText(CampingText);
	CampingSlider.SetHelpText("");
	CampingSlider.SetFont(F_Normal);

	// CampTime Edit
	ControlOffset += Intermedio;
	CampTime = UWindowEditControl(CreateControl(class'UWindowEditControl', CenterPos, ControlOffset, CenterWidth, 1));
	CampTime.SetNumericOnly(True);
	CampTime.SetText(CampTimeText);
	CampTime.SetHelpText("Tiempo aproximado de camping");
	CampTime.SetFont(F_Normal);

	// Create Bot Button
	ControlOffset += Intermedio;
	CreatefButton = UWindowCheckbox(CreateControl(class'UWindowCheckbox', CenterPos, ControlOffset, CenterWidth, 1));
	CreatefButton.SetText(CreatefText);
	CreatefButton.SetFont(F_Normal);
	CreatefButton.SetHelpText("En caso de estar conectado, el server tendrá que autorizarlo");

	LoadClasses();
}

function ApplyConfigs()
{
	NameEdit.SetValue( LastName);
//	TeamCombo.SetSelectedIndex(Max(TeamCombo.FindItemIndex2( LastTeam), 0));
	TeamCombo.SetSelectedIndex( TeamCombo.FindItemIndex2( LastTeam) );
	Log("SELECTING CLASS: "$LastClass);
	ClassCombo.SetSelectedIndex(Max(ClassCombo.FindItemIndex2( LastClass, True), 0));
	ClassChanged(); //TESTING PURPOSES
	IterateSkins();
	SkinCombo.SetSelectedIndex(Max(SkinCombo.FindItemIndex2( LastSkin, True), 0));
	IterateFaces( LastSkin);
	FaceCombo.SetSelectedIndex(Max(FaceCombo.FindItemIndex2( LastFace, True), 0));
	IterateVoices();
	VoicePackCombo.SetSelectedIndex(Max(VoicePackCombo.FindItemIndex2( LastVoice, True), 0));
	SkillSlider.SetValue( int(LastSkill) );
	CampingSlider.SetValue( int(LastCChance) );
	AccuracySlider.SetValue( int(LastAcc) );
	CampTime.SetValue( LastCTime);
	FavoriteWeaponCombo.SetSelectedIndex(Max( FavoriteWeaponCombo.FindItemIndex2(LastWeapon, True), 0));
}

// ============================================ Importante
function Notify(UWindowDialogControl C, byte E)
{
//	Super.Notify(C, E);

	switch(E)
	{
	case DE_Change:
		switch(C)
		{
			case NameEdit:
				NameChanged();
				break;
			case TeamCombo:
				TeamChanged();
				break;
			case SkinCombo:
				SkinChanged();
				break;
			case ClassCombo:
				ClassChanged();
				break;
			case FaceCombo:
				FaceChanged();
				break;
			case VoicePackCombo:
				VoiceChanged();
				break;
			case FavoriteWeaponCombo:
				WeaponChanged();
				break;
			case SkillSlider:
				SkillChanged();
				break;
			case AccuracySlider:
				AccuracyChanged();
				break;
			case CampingSlider:
				CampingChanged();
				break;
			case CampTime:
				CTimeChanged();
				break;
			case CreatefButton:
				MyInfoOwner.AskToServer();
				GetPlayerOwner().ClientMessage("Se trató de agregar un bot");
		}
	}
}

function AfterCreate()
{
	Super.AfterCreate();

	DesiredWidth = 220;
	DesiredHeight = ControlOffset + Intermedio;

	Initialized = True;

	bCurrentlyLoading = True;
	ApplyConfigs();
	bCurrentlyLoading = False;
}

function LoadClasses()
{
	local int NumPlayerClasses;
	local string NextPlayer, NextDesc;
	local int SortWeight;

	GetPlayerOwner().GetNextIntDesc(BotzBaseClass, 0, NextPlayer, NextDesc);
	while( (NextPlayer != "") && (NumPlayerClasses < 64) )
	{
		ClassCombo.AddItem(NextDesc, NextPlayer, SortWeight);
		NumPlayerClasses++;
		GetPlayerOwner().GetNextIntDesc(BotzBaseClass, NumPlayerClasses, NextPlayer, NextDesc);
	}
	ClassCombo.Sort();
}

function LoadWeapons()
{
	local int NumWeaponClasses;
	local string NextWeapon, NextDesc;
	local string WeaponBaseClass;

	WeaponBaseClass = "TournamentWeapon";

	FavoriteWeaponCombo.AddItem(NoFavoriteWeapon, "None");
	FavoriteWeaponCombo.AddItem("Aleatorio", "SET_RandomWeapon");

	GetPlayerOwner().GetNextIntDesc(WeaponBaseClass, 0, NextWeapon, NextDesc);
	while( (NextWeapon != "") && (NumWeaponClasses < 64) )
	{
		FavoriteWeaponCombo.AddItem(NextDesc, NextWeapon);
		NumWeaponClasses++;
		GetPlayerOwner().GetNextIntDesc(WeaponBaseClass, NumWeaponClasses, NextWeapon, NextDesc);
	}
	FavoriteWeaponCombo.Sort();
}

// ===================== Si algo cambia
function NameChanged()
{
	local string N;

	N = NameEdit.GetValue();

	if ( InStr( N, " ") != -1)
	{
		ReplaceText(N, " ", "_");
		NameEdit.SetValue(N);
	}

	MyInfoOwner.CurrentBot.BotName = N;
	LastName = N;
	SaveConfig();
}

function CTimeChanged()
{
	local string N;
	local int N2;

	N = CampTime.GetValue();


	N2 = int(N);
	if ( N2 < 5 )
		N2 = 5;
	if ( N2 > 100 )
		N2 = 100;

	MyInfoOwner.CurrentBot.CampTime = N2;
	LastCTime = N;
	SaveConfig();
}

function AccuracyChanged()
{
	MyInfoOwner.CurrentBot.Punteria = AccuracySlider.GetValue();
	LastAcc = String( AccuracySlider.GetValue() );
	SaveConfig();
}

function SkillChanged()
{
	MyInfoOwner.CurrentBot.Skill = SkillSlider.GetValue();
	LastSkill = String( SkillSlider.GetValue() );
	SaveConfig();
}


function CampingChanged()
{
	MyInfoOwner.CurrentBot.CampChance = CampingSlider.GetValue();
	LastCChance = String( CampingSlider.GetValue() );
	SaveConfig();
}

function TeamChanged()
{
	local string T;

	T = TeamCombo.GetValue2();
	MyInfoOwner.CurrentBot.Team = int(T);
	LastTeam = T;
	SaveConfig();
}

function WeaponChanged()
{
	local string WeaponText;
	WeaponText = FavoriteWeaponCombo.GetValue2();

	if (Caps(WeaponText) == "NONE")
	{
		MyInfoOwner.CurrentBot.ArmaFavorita = none;
		MyInfoOwner.CurrentBot.RandomWeapon = false;
	}
	else if (WeaponText == "SET_RandomWeapon")
	{
		MyInfoOwner.CurrentBot.ArmaFavorita = none;
		MyInfoOwner.CurrentBot.RandomWeapon = true;
	}
	else
	{
		MyInfoOwner.CurrentBot.ArmaFavorita = class<Weapon>( DynamicLoadObject( WeaponText, class'class'));
		MyInfoOwner.CurrentBot.RandomWeapon = False;
	}
	LastWeapon = WeaponText;
	SaveConfig();
}

function SkinChanged()
{
	local bool OldInitialized;

	if ( bCurrentlyLoading )
		return;

	OldInitialized = Initialized;
	Initialized = False;
	IterateFaces(SkinCombo.GetValue2());
	FaceCombo.SetSelectedIndex(0);
	Initialized = OldInitialized;

	MyInfoOwner.CurrentBot.BotSkin = SkinCombo.GetValue2();
	LastSkin = SkinCombo.GetValue2();
	SaveConfig();
}

function FaceChanged()
{
	if ( bCurrentlyLoading )
		return;

	MyInfoOwner.CurrentBot.Face = FaceCombo.GetValue2();
	LastFace = FaceCombo.GetValue2();
	SaveConfig();
}

function VoiceChanged()
{
	MyInfoOwner.CurrentBot.VoiceBot = class<ChallengeVoicePack>( DynamicLoadObject( VoicePackCombo.GetValue2(), class'Class') );
	LastVoice = VoicePackCombo.GetValue2();
	SaveConfig();
}

function ClassChanged()
{
	local string SkinName, SkinDesc;
	local bool OldInitialized;

	// Get the class.
	NewBotzClass = class<Pawn>(DynamicLoadObject(ClassCombo.GetValue2(), class'Class'));
	MyInfoOwner.CurrentBot.SimulatedPP = class<PlayerPawn>(NewBotzClass);

	// Get the meshname
	MeshName = GetPlayerOwner().GetItemName(String(NewBotzClass.Default.Mesh));
	MyInfoOwner.CurrentBot.BotMesh = NewBotzClass.Default.Mesh;

	OldInitialized = Initialized;
	Initialized = False;

	if ( bCurrentlyLoading )
		return;

	IterateSkins();
	SkinCombo.SetSelectedIndex(0);
	IterateFaces(SkinCombo.GetValue2());
	FaceCombo.SetSelectedIndex(0);
	Initialized = OldInitialized;

	if(ClassIsChildOf(NewBotzClass, class'TournamentPlayer'))
	{
		if(Initialized)
		{
			IterateVoices();
			VoicePackCombo.SetSelectedIndex(Max(VoicePackCombo.FindItemIndex2(class<TournamentPlayer>(NewBotzClass).default.VoiceType, True), 0));
		}
		VoicePackCombo.ShowWindow();
	}
	else
	{
		VoicePackCombo.HideWindow();
	}
	LastClass = ClassCombo.GetValue2();
	SaveConfig();
}

function IterateVoices()
{
	local int NumVoices;
	local string NextVoice, NextDesc;
	local string VoicepackMetaClass;
	local bool OldInitialized;

	OldInitialized = Initialized;
	Initialized = False;
	VoicePackCombo.Clear();
	Initialized = OldInitialized;

	if(ClassIsChildOf(NewBotzClass, class'TournamentPlayer'))
		VoicePackMetaClass = class<TournamentPlayer>(NewBotzClass).default.VoicePackMetaClass;
	else
		VoicePackMetaClass = "Botpack.ChallengeVoicePack";

	// Load the base class into memory to prevent GetNextIntDesc crashing as the class isn't loadded.
	DynamicLoadObject(VoicePackMetaClass, class'Class');

	GetPlayerOwner().GetNextIntDesc(VoicePackMetaClass, 0, NextVoice, NextDesc);
	while( (NextVoice != "") && (NumVoices < 64) )
	{
		VoicePackCombo.AddItem(NextDesc, NextVoice, 0); //FIXZ mio, VoiceBoss siempre permitido

		NumVoices++;
		GetPlayerOwner().GetNextIntDesc(VoicePackMetaClass, NumVoices, NextVoice, NextDesc);
	}

	VoicePackCombo.Sort();
}

// ============================== Funciones graficas
function BeforePaint(Canvas C, float X, float Y)
{
	local int ControlWidth, ControlLeft, ControlRight;
	local int CenterWidth, CenterPos;
	local float W;

	W = Min(WinWidth, 220);

	ControlWidth = W/3;
	ControlLeft = (W/2 - ControlWidth)/2;
	ControlRight = W/2 + ControlLeft;

	CenterWidth = (W/7)*6;
	CenterPos = (W - CenterWidth)/2;

	NameEdit.SetSize(CenterWidth, 1);
	NameEdit.WinLeft = CenterPos;
	NameEdit.EditBoxWidth = 105;

	TeamCombo.SetSize(CenterWidth, 1);
	TeamCombo.WinLeft = CenterPos;
	TeamCombo.EditBoxWidth = 105;

	SkinCombo.SetSize(CenterWidth, 1);
	SkinCombo.WinLeft = CenterPos;
	SkinCombo.EditBoxWidth = 105;

	FaceCombo.SetSize(CenterWidth, 1);
	FaceCombo.WinLeft = CenterPos;
	FaceCombo.EditBoxWidth = 105;


	ClassCombo.SetSize(CenterWidth, 1);
	ClassCombo.WinLeft = CenterPos;
	ClassCombo.EditBoxWidth = 105;


	VoicePackCombo.SetSize(CenterWidth, 1);
	VoicePackCombo.WinLeft = CenterPos;
	VoicePackCombo.EditBoxWidth = 105;


	FavoriteWeaponCombo.SetSize(CenterWidth, 1);
	FavoriteWeaponCombo.WinLeft = CenterPos;
	FavoriteWeaponCombo.EditBoxWidth = 105;


	AccuracySlider.SetSize(CenterWidth, 1);
	AccuracySlider.WinLeft = CenterPos;
	AccuracySlider.SliderWidth = 105;


	SkillSlider.SetSize(CenterWidth, 1);
	SkillSlider.WinLeft = CenterPos;
	SkillSlider.SliderWidth = 105;

	CampingSlider.SetSize(CenterWidth, 1);
	CampingSlider.WinLeft = CenterPos;
	CampingSlider.SliderWidth = 105;

	CampTime.SetSize(CenterWidth, 1);
	CampTime.WinLeft = CenterPos;
	CampTime.EditBoxWidth = 105;

	CreatefButton.SetSize(CenterWidth-105+16, 1);
	CreatefButton.WinLeft = CenterPos;
}



function IterateSkins()
{
	local string SkinName, SkinDesc, TestName, Temp, FaceName;
	local int i;
	local bool bNewFormat;

	SkinCombo.Clear();

	if( ClassIsChildOf(NewBotzClass, class'Spectator') )
	{
		SkinCombo.HideWindow();
		return;
	}
	else
		SkinCombo.ShowWindow();

	bNewFormat = NewBotzClass.default.bIsMultiSkinned;

	SkinName = "None";
	TestName = "";
	while ( True )
	{
		GetPlayerOwner().GetNextSkin(MeshName, SkinName, 1, SkinName, SkinDesc);

		if( SkinName == TestName )
			break;

		if( TestName == "" )
			TestName = SkinName;

		if( !bNewFormat )
		{
			Temp = GetPlayerOwner().GetItemName(SkinName);
			if( Left(Temp, 2) != "T_" )
				SkinCombo.AddItem(Temp, SkinName);
		}
		else
		{
			// Multiskin format
			if( SkinDesc != "")
			{			
				Temp = GetPlayerOwner().GetItemName(SkinName);
				if(Mid(Temp, 5, 64) == "")
					// This is a skin
					SkinCombo.AddItem(SkinDesc, Left(SkinName, Len(SkinName) - Len(Temp)) $ Left(Temp, 4));			
			}
		}
	}
	SkinCombo.Sort();
}

function IterateFaces(string InSkinName)
{
	local string SkinName, SkinDesc, TestName, Temp, FaceName;
	local bool bNewFormat;

	FaceCombo.Clear();

	// New format only
	if( !NewBotzClass.default.bIsMultiSkinned )
	{
		FaceCombo.HideWindow();
		return;
	}
	else
		FaceCombo.ShowWindow();


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
			if(Mid(Temp, 5) != "" && Left(Temp, 4) == GetPlayerOwner().GetItemName(InSkinName))
				FaceCombo.AddItem(SkinDesc, Left(SkinName, Len(SkinName) - Len(Temp)) $ Mid(Temp, 5));
		}
	}
	FaceCombo.Sort();
}

defaultproperties
{
     ControlOffset=5
     TextX=25
     Intermedio=25
     BaseY=20
     BotzBaseClass="BotPack.TournamentPlayer"
     LastName="Half-Laif"
     LastTeam="255"
     LastClass="Gordon.Gordan"
     LastSkin="gordonSkins.gord"
     LastFace="gordonSkins.gordon"
     LastSkill="46.000000"
     LastVoice="BotPack.VoiceMaleOne"
     LastWeapon="BotPack.SniperRifle"
     LastAcc="140.000000"
     LastCTime="50"
     LastCChance="10.000000"
     NameText="Nombre"
     TeamText="Equipo"
     Teams(0)="Rojo"
     Teams(1)="Azul"
     Teams(2)="Verde"
     Teams(3)="Amarillo"
     NoTeam="Ninguno"
     ClassText="Forma"
     SkinText="Skin"
     FaceText="Cara"
     SkillText="Dificultad"
     VoicePackText="Voz"
     FavoriteWeaponText="Arma Favorita"
     NoFavoriteWeapon="Ninguna"
     AccuracyText="Puntería"
     CampingText="Chance Camping"
     CampTimeText="Duracion Camping"
     CreatefText="Crear Bot"
}
