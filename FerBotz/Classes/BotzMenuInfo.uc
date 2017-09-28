//=============================================================================
// BotzMenuInfo.
// Se agrega uno a cada jugador humano a excepción de los espectadores
// Principalmente para que estos puedan agregar botz desde cualquier maquina
// Esto también permite que el admin, o el server ambos puedan agregar botz
//   libremente o permitir a otros que lo hagan (controladores)
// Funciona haciendo aparecer una ventana como la de elegir al personaje
// Un controlador con una de estas ventanas abiertas enviadas por el cliente,
//   recibe 10% de daño bajo ese estado, evitar que los clientes lo hagan intencionalmente
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BotzMenuInfo expands InfoPoint;


var SBotzInfo CurrentBot;

var ServerBotzManager MyManager;
var bool bClientAsking;
var bool bServerResponsing;
var int aPing;	//Medir velocidades entre clientes y servers
var int sPing;
var bool bPendingAsk;
var bool bPendingWait;
var bool bAlreadyPatched;
var int aTicking;

var() class <UWindowWindow> WindowClass;
var() int WinLeft,WinTop,WinWidth,WinHeight;

var UWindowWindow TheWindow;

replication
{	//Cosas que el server envía a todos los jugadores
	reliable if (ROLE == ROLE_Authority && bNetOwner)
		bServerResponsing, bClientAsking;
	reliable if (ROLE == ROLE_Authority && bNetOwner)
		ClientReceive;

	reliable if (ROLE < ROLE_Authority)
		AskToServer;
}

simulated function PostBeginPlay()
{
	local ChallengeTeamHUD existingHUDs;
	if ( PlayerPawn(Owner).PlayerReplicationInfo.VoiceType != none )
	{
		class<ChallengeVoicePack>(PlayerPawn(Owner).PlayerReplicationInfo.VoiceType).Default.OrderString[5] = "Patrulla este punto";
		class<ChallengeVoicePack>(PlayerPawn(Owner).PlayerReplicationInfo.VoiceType).Default.OrderAbbrev[5] = "Patrullar";
		class'ChallengeTeamHUD'.default.OrderNames[5] = 'Patrol';
		class'ChallengeTeamHUD'.Default.NumOrders++;
	}
	ForEach AllActors (class'ChallengeTeamHUD', existingHUDs )
	{
		existingHUDs.OrderNames[5] = 'Patrol';
		existingHUDs.NumOrders++;
	}
	bAlreadyPatched = True;
}

simulated function PostNetBeginPlay()	//Client-Side functions
{
	local ChallengeTeamHUD existingHUDs;

	if (bAlreadyPatched)
		return;
	if ( PlayerPawn(Owner).PlayerReplicationInfo.VoiceType != none )
	{
		class<ChallengeVoicePack>(PlayerPawn(Owner).PlayerReplicationInfo.VoiceType).Default.OrderString[5] = "Patrulla este punto";
		class<ChallengeVoicePack>(PlayerPawn(Owner).PlayerReplicationInfo.VoiceType).Default.OrderAbbrev[5] = "Patrullar";
		class'ChallengeTeamHUD'.default.OrderNames[5] = 'Patrol';
		class'ChallengeTeamHUD'.Default.NumOrders++;
	}
	ForEach AllActors (class'ChallengeTeamHUD', existingHUDs )
	{
		existingHUDs.OrderNames[5] = 'Patrol';
		existingHUDs.NumOrders++;
	}
}

simulated function AskToServer()
{
	if (Level.Netmode == NM_StandAlone)
	{
		MyManager.ServerAddBot( CurrentBot);
		return;
	}

	if (MyManager.LocalPlayer == PlayerPawn(Owner) )
	{
		MyManager.ServerAddBot( CurrentBot);
		return;
	}
	if ( PlayerPawn(Owner).bAdmin )
	{
		MyManager.ClientAddBot( CurrentBot);
		return;
	}

}

simulated function SetupWindow()
{
	local WindowConsole C;

	C = WindowConsole(PlayerPawn(Owner).Player.Console);

	if (!C.bCreatedRoot || C.Root==None)
	{
		// Tell the console to create the root
		C.CreateRootWindow(None);
	}

	C.bQuickKeyEnable = True;
	C.LaunchUWindow();

	aTicking = 0;
	PlayerPawn(Owner).ClientMessage("Ventana debería estar abierta");
}

simulated event Tick( float Deltatime)
{
	if ( aTicking < 0 )
		return;
	aTicking++;
	if ( aTicking >= 1)
	{
		ShowTheWindow();
		aTicking = -1;
	}
}

simulated function ShowTheWindow()
{
	local WindowConsole C;

	C = WindowConsole(PlayerPawn(Owner).Player.Console);

	TheWindow = C.Root.CreateWindow(WindowClass, WinLeft, WinTop, WinWidth, WinHeight);

	if (TheWindow==None)
	{
		Log("#### -- CreateWindow Failed");
		return;
	}
	if ( C.bShowConsole )
		C.HideConsole();

	// Make it show even when everything else is hidden through bQuickKeyEnable
	TheWindow.bLeaveOnScreen = True;

	// Show the window
	TheWindow.ShowWindow();
	TheWindow.FocusWindow();
}

simulated function ClientReceive( bool AcceptRequest)
{
	TheWindow.Close();

	if (AcceptRequest)
		MyManager.ClientAddBot( CurrentBot);
}

final function bool MachinePlayer( playerPawn Test)
{
	return ( (Test != none) && (Test.Player != none) && (Test.Player.Console != none) );
}

defaultproperties
{
     WindowClass=Class'FerBotz.BotzPWin'
     WinLeft=100
     WinTop=100
     WinWidth=300
     WinHeight=500
     RemoteRole=ROLE_SimulatedProxy
}
