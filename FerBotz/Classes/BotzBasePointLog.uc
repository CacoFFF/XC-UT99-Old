//===============================================================================
// BotzBasePointLog
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//===============================================================================
class BotzBasePointLog expands StatLogFile;

var int CurrentPoint;
var int ChainedIndex;
var string fTmp;

function StartFile( int ChainedOrder)
{
	local string FileName;
	local string AbsoluteTime;

	fTmp = Left( string(self), inStr( string(self),".") );

	fTmp = ReplaceText(fTmp, "-", "");
	fTmp = ReplaceText(fTmp, "]", "_1");
	fTmp = ReplaceText(fTmp, "[", "_2");
	fTmp = ReplaceText(fTmp, "|", "_3");

	FileName = "..\\"$fTmp$"Botz\\classes\\"$fTmp$"Spawn";
	
	if ( ChainedOrder > 0 )
	{
		ChainedIndex = ChainedOrder;
		FileName = "..\\"$fTmp$"Botz\\classes\\"$fTmp$"Chain"$string(ChainedOrder);
	}

	StatLogFile = FileName$".tmp";
	StatLogFinal = FileName$".uc";
	CurrentPoint = -1;

	OpenLog();
	if ( ChainedOrder > 0 )
		AddString("Class "$fTmp$"Chain"$string(ChainedOrder)$" extends BaseSpawner;");
	else
		AddString("Class "$fTmp$"Spawn extends BaseSpawner;");
	AddString("");
	AddString("defaultproperties");
	AddString("{");
}

function string MakeVector( vector vTemp)
{
	return "(X="$string(vTemp.X)$",Y="$string(vTemp.Y)$",Z="$string(vTemp.Z)$")";
}

function string MakeRotator( rotator rTemp)
{
	return "(Pitch="$string(rTemp.Pitch)$",Yaw="$string(rTemp.Yaw)$",Roll="$string(rTemp.Roll)$")";
}

function AddProperty( string PropertyName, string PropertyValue)
{
	AddString( "    "$PropertyName$"("$string(CurrentPoint)$")="$PropertyValue );
}

function EndFile()
{
	AddString( "}");
	CloseLog();
}

function AddString( string EventString )
{
	FileLog( EventString );
	FlushLog();
}

function BeginPlay()
{
}

function string ReplaceText( string Text, string Replace, string With)
{
	local int i;
	local string Input;
		
	Input = Text;
	Text = "";
	i = InStr(Input, Replace);
	while(i != -1)
	{	
		Text = Text $ Left(Input, i) $ With;
		Input = Mid(Input, i + Len(Replace));	
		i = InStr(Input, Replace);
	}
	return Text $ Input;
}