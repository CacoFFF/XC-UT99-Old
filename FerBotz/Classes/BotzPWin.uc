//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org

class BotzPWin expands UMenuPlayerWindow;

function BeginPlay() 
{
	Super.BeginPlay();

	WindowTitle = "Menu de Botz";
	ClientClass = class'BotzBasicWindow';
	bSizable = true;
}

function SetSizePos()
{
	SetSize(310, 520);

	WinLeft = Int((Root.WinWidth - WinWidth) / 2);
	WinTop = Int((Root.WinHeight - WinHeight) / 2);
}

defaultproperties
{
}
