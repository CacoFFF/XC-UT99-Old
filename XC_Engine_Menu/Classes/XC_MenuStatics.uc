class XC_MenuStatics expands XC_CoreStatics
	abstract;
	
static function string StaticCall( string Cmd)
{
	class'UMenuOptionsWindow'.default.ClientClass = class'XCOptionsClientWindow';
	class'UMenuCustomizeClientWindow'.default.LocalizedKeyName[5] = "MouseX1";
	class'UMenuCustomizeClientWindow'.default.LocalizedKeyName[6] = "MouseX2";
	return "OK";
}
