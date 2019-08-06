//=============================================================================
// NexgenXCGE_PreLogin.
// PreLogin hook actor to deny players from joining a server before they login
// By Higor
// 
// Adapted to XC_Engine version 24.
//=============================================================================
class NexgenXCGE_PreLogin expands PreLoginHookElement;

// Called after PreLogin (only if passes PreLogin)
function PreLoginHook_PostProcess( string Options, string Address, out string Error, out string FailCode)
{
	local Info I;
	local int j, maxLoop;
	if ( Error != "" )
		return;

	j = InStr( Address, ":");
	if ( j > 0 )
		Address = Left( Address, j);

	ForEach DynamicActors(class'Info', I)
	{
		if ( I.IsA('NexgenABMConfig') )
			maxLoop = 256;
		else if ( I.IsA('NexgenConfig') )
			maxLoop = 128;
		else
			maxLoop = 0;

		For ( j=0 ; j<maxLoop ; j++ )
		{
			if ( ConsoleCommand("GET "$GetItemName(string(I.Class))$" bannedName "$j) == "" )
				break;
			if ( ConsoleCommand("GET "$GetItemName(string(I.Class))$" banPeriod "$j) == "M0" )
				continue;
			if ( AddressInChunk( Address, ConsoleCommand("GET "$GetItemName(string(I.Class))$" bannedIPs "$j)) )
			{
				Error = "Banned: "$ConsoleCommand("GET "$GetItemName(string(I.Class))$" banReason "$j);
				return;
			}
		}
	}
}

function bool AddressInChunk( string Address, string Chunk)
{
	local int i;
	AGAIN:
	i = InStr( Chunk, Address);
	if ( i >= 0 )
	{
		Chunk = Mid( Chunk, i + Len(Address) );
		if ( (Chunk == "") || (Left(Chunk,1) == "," ) ) //Nothing after, or a delimiter
		{
			Log("Found ban!");
			return true;
		}
		if ( Chunk != "" )
			Goto AGAIN;
	}
}
