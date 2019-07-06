//=============================================================================
// PreLoginHookXCGE
// Does basic checking of player class and name
//=============================================================================
class PreLoginHookXCGE expands PreLoginHookElement;

// Called before PreLogin
function PreLoginHook_PreProcess( string Options, string Address, out string Error, out string FailCode)
{
	local string Parm;

	if ( Error == "" )
	{
		Parm = Level.Game.ParseOption( Options, "Class");
		if ( Parm == "" || (InStr(Parm,"%") >= 0) )
		{
			Error = "XCGE Denied, invalid class:" @ Parm;
			FailCode = "BADCLASS";
			return;
		}
		Parm = Level.Game.ParseOption( Options, "Name");
		if ( Parm == "" )
		{
			Error = "XCGE Denied, invalid name";
			FailCode = "NEEDNAME";
			return;
		}
	}
}
