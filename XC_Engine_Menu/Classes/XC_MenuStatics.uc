class XC_MenuStatics expands XC_CoreStatics
	abstract;
	
static function string StaticCall( string Cmd)
{
	class'UMenuOptionsWindow'.default.ClientClass = class'XCOptionsClientWindow';
	class'UMenuCustomizeClientWindow'.default.LocalizedKeyName[5] = "MouseX1";
	class'UMenuCustomizeClientWindow'.default.LocalizedKeyName[6] = "MouseX2";
	class'UMenuMapListBox'.default.ListClass = class'XC_MenuMapListUnsorted';
	class'UMenuMapListInclude'.default.ListClass = class'XC_MenuMapListUnsorted';
	class'UMenuMapListExclude'.default.ListClass = class'XC_MenuMapListUnsorted';
	return "OK";
}
