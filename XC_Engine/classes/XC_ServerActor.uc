//=============================================================================
// XC_ServerActor.
//=============================================================================
class XC_ServerActor expands Actor
	config(XC_Engine);

struct LoginInfo
{
	var() PlayerPawn Player;
	var() float DenyUntil;
	var() int BadLoginCount;
};

var() config int MaxBadLoginAttempts;
var() config float LoginTryAgainTime;
var() config bool bKickAfterMaxLogin;
var() config bool bNexgenAdminLogin;

var array<LoginInfo> LInfos;

//Gain access to these XC_GameEngine opcodes
native(640) static final function int Array_Length_LI( out array<LoginInfo> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_LI( out array<LoginInfo> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_LI( out array<LoginInfo> Ar, int Offset, optional int Count );
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );


//Prevent duplicates
event PostBeginPlay()
{
	local XC_ServerActor Other;
	ForEach DynamicActors( class'XC_ServerActor', Other)
		if ( Other != self )
		{
			Destroy();
			return;
		}
}


auto state Init
{
Begin:
	Sleep(0);
	//Become the primary AdminLoginHook (replaces previous ones if defined)
	//Will fail if named actor doesn't have
	//event bool AdminLoginHook( PlayerPawn P)
	ConsoleCommand( "AdminLoginHook "$Name);
	//Warning, SaveConfig() will be called for this actor by XC_GameEngine once map ends!!!
}

//Return true if player is allowed to AdminLogin
event bool AdminLoginHook( PlayerPawn P)
{
	local int i, iP;
	local info NexgenClient;

	iP = Array_Length_LI( LInfos);
	while ( i<iP )
	{
		if ( LInfos[i].Player == none || LInfos[i].Player.bDeleteMe )
		{
			Array_Remove_LI( LInfos, i);
			iP--;
			continue;
		}
		if ( LInfos[i].Player == P )
		{
			if ( (Level.TimeSeconds < LInfos[i].DenyUntil) || (LInfos[i].BadLoginCount > MaxBadLoginAttempts) ) //This player is spamming the login
			{
				if ( LInfos[i].BadLoginCount++ > MaxBadLoginAttempts && bKickAfterMaxLogin )
				{
					P.ClientMessage("Kicked due to excessive AdminLogin attempts("$MaxBadLoginAttempts$")");
					if ( ViewPort(P.Player) == none ) //Never destroy local player
						P.Destroy();
					Array_Remove_LI( LInfos, i);
					iP--;
					return false;
				}
				LInfos[i].DenyUntil += LoginTryAgainTime * Level.TimeDilation * 0.1;
				return false;
			}
			iP = i;
			Goto POSITIVE_RETURN;
		}
		i++;
	}
	Array_Insert_LI( LInfos, iP);
	LInfos[iP].Player = P;

	POSITIVE_RETURN:
	LInfos[iP].DenyUntil = Level.TimeSeconds + LoginTryAgainTime * Level.TimeDilation;
	if ( bNexgenAdminLogin ) //Must be done here to prevent lag exploits
	{
		NexgenClient = FindNexgenClient( P);
		if ( NexgenClient != none && (InStr(NexGenClient.GetPropertyText("rights"),"L") >= 0) ) //L is server admin
		{
			Log("Administrator logged in using Nexgen (XC_ServerActor): "$P.PlayerReplicationInfo.PlayerName);
			P.bAdmin = True;
			P.PlayerReplicationInfo.bAdmin = P.bAdmin;
			BroadcastMessage( P.PlayerReplicationInfo.PlayerName@"became a server administrator." );
			return false; //Handle myself
		}
	}
	return true;
}


static function Info FindNexgenClient( PlayerPawn Player)
{
	local Info aInfo;
	ForEach Player.ChildActors (class'Info', aInfo)
		if ( aInfo.IsA('NexgenClient') )
			return aInfo;
}

defaultproperties
{
     MaxBadLoginAttempts=100
     LoginTryAgainTime=4
     bKickAfterMaxLogin=false
     bNexgenAdminLogin=True
     bHidden=True
}
