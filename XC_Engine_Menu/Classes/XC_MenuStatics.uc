class XC_MenuStatics expands XC_CoreStatics
	abstract;
	
static function string StaticCall( string Cmd)
{
	class'UMenuOptionsWindow'.default.ClientClass = class'XCOptionsClientWindow';
	return "OK";
}
