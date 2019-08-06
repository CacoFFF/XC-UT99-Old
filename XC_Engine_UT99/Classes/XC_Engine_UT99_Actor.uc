//=============================================================================
// XC_Engine_Actor
// Automatically spawned by XC_Engine in the server/local game
//=============================================================================
class XC_Engine_UT99_Actor expands XC_Engine_Actor
	transient;

//Called from parent XCGE actor
event XC_Init()
{
	local Actor A;
	local class<Actor> AC, DGC;
	local string MapFile;

	Spawn( class'PathsEnhancer');
	
	class'XC_CoreStatics'.static.FixName( "ClearArray", true); //Fix FerBotz bind
	
	//Server-only fixes
	if ( Level.NetMode == NM_ListenServer || Level.NetMode == NM_DedicatedServer )
	{
		ConsoleCommand("set UT_ShieldBeltEffect bRelevantIfOwnerIs 1");
		ConsoleCommand("set ShieldBeltEffect bRelevantIfOwnerIs 1");
		ConsoleCommand("set TournamentPlayer MaxTimeMargin 0.5");

		//Ensure minimum memory usage by avoiding static linking of packages
		AC = class<Actor>(class'XC_CoreStatics'.static.FindObject( "UnrealShare.DripGenerator", class'Class'));
		if ( AC != None ) //DripGenerator has been lazy-loaded
			DGC = class<Actor>( DynamicLoadObject("XC_DripFix1.XC_Engine_DripGenerator", class'Class', true) );
		if ( DGC != None )
		{
			ForEach AllActors ( AC, A)
			{
				ReplaceFunction( AC, DGC, 'Timer', 'Timer', 'Dripping');
				AddToPackageMap( string(DGC.Outer.Name) );
				break;
			}
			DGC = None;
		}
	}
	
	//**************
	//Game tweaks
	if ( DeathMatchPlus(Level.Game) != None )
	{
		ReplaceFunction( class'DeathMatchPlus', class'XC_Engine_DMP', 'EndSpree', 'EndSpree');
		ReplaceFunction( class'DeathMatchPlus', class'XC_Engine_DMP', 'ScoreKill', 'ScoreKill');
		ReplaceFunction( class'DeathMatchPlus', class'XC_Engine_DMP', 'FindPlayerStart', 'FindPlayerStart');
		ReplaceFunction( class'DeathMatchPlus', class'XC_Engine_DMP', 'ChangeName', 'ChangeName');
		ReplaceFunction( class'TeamGamePlus', class'XC_Engine_TGP', 'FindPlayerStart', 'FindPlayerStart');
	//	ReplaceFunction( class'TeamGamePlus', class'XC_Engine_TGP', 'AddToTeam', 'AddToTeam'); LINUX CRASH, SEE FURTHER DETAILS IN THIS FUNCTION
	}

	//****
	//Pawn
	ReplaceFunction( class'Pawn', class'XC_Engine_ScriptedPawn', 'PickTarget', 'Pawn_PickTarget');
	
	//****************
	//TournamentPlayer
	ReplaceFunction( class'TournamentPlayer', class'XC_Engine_TournamentPlayer', 'Summon', 'Summon');
	ReplaceFunction( class'TournamentPlayer', class'XC_Engine_TournamentPlayer', 'SetMultiSkin', 'SetMultiSkin');
		
	//***
	//Bot
	ReplaceFunction( class'Bot', class'XC_Engine_Bot', 'SetOrders', 'SetOrders'); //Moved from DLL
	ReplaceFunction( class'Bot', class'XC_Engine_Bot', 'BaseChange', 'BaseChange');
	
	//******************
	//ChallengeVoicePack
	ReplaceFunction( class'ChallengeVoicePack', class'XC_Engine_CVPack', 'PlayerSpeech', 'PlayerSpeech');
	
	//*********
	//Inventory
	ReplaceFunction( class'TournamentWeapon', class'XC_Engine_TournamentWeapon', 'ClientPutDown', 'ClientPutDown');
	ReplaceFunction( class'TournamentWeapon', class'XC_Engine_TournamentWeapon', 'AnimEnd', 'AnimEnd', 'ClientDown');
	ReplaceFunction( class'UT_Invisibility', class'XC_Engine_TournamentWeapon', 'EndState', 'UT_Invisibility_EndState', 'Activated');
	ReplaceFunction( class'UT_Eightball', class'XC_Engine_8BALL', 'Tick', 'Tick', 'NormalFire'); //RocketTick fix
	ReplaceFunction( class'minigun2', class'XC_Engine_TournamentWeapon', 'RateSelf', 'Minigun2_RateSelf');
	
	//********
	//Triggers	
	ReplaceFunction( class'DistanceViewTrigger', Class, 'Trigger', 'DVT_Trigger');
	ReplaceFunction( class'Transporter', Class, 'Trigger', 'Transporter_Trigger');

	//***************
	//NavigationPoint
	ReplaceFunction( class'TranslocStart', Class, 'SpecialHandling', 'TranslocStart_SpecialHandling');
	ReplaceFunction( class'JumpSpot', class'XC_Engine_JumpSpot', 'SpecialCost', 'SpecialCost');
	if ( Assault(Level.Game) == none ) //AssaultRetardizer - avoid log spam on non-assault games
		ReplaceFunction( class'AssaultRandomizer', class'XC_Engine_AsRa', 'SpecialCost', 'SpecialCost', 'CostEnabled');

	//*****************
	//Unreal - Monsters
	ReplaceFunction( class'ScriptedPawn', class'XC_Engine_ScriptedPawn', 'AttitudeToCreature', 'AttitudeToCreature');
	ReplaceFunction( class'ScriptedPawn', class'XC_Engine_ScriptedPawn', 'AttitudeTo', 'AttitudeTo');
	ReplaceFunction( class'ScriptedPawn', class'XC_Engine_ScriptedPawn', 'SetEnemy', 'SetEnemy');
	ReplaceFunction( class'ScriptedPawn', class'XC_Engine_ScriptedPawn', 'MeleeDamageTarget', 'ScriptedPawn_MeleeDamageTarget');
	ReplaceFunction( class'ScriptedPawn', class'XC_Engine_ScriptedPawn', 'StartRoaming', 'ScriptedPawn_StartRoaming');
	ReplaceFunction( class'ScriptedPawn', class'XC_Engine_ScriptedPawn', 'SetHome', 'StartUp_SetHome', 'StartUp');
	
	//Queen Teleport AI
	ReplaceFunction( class'Queen', class'XC_Engine_Queen', 'ChooseDestination', 'QT_ChooseDestination', 'Teleporting');
	ReplaceFunction( class'Queen', class'XC_Engine_Queen', 'Tick', 'QT_Tick', 'Teleporting');

	//Other tweaks
	ReplaceFunction( class'Brute', class'XC_Engine_ScriptedPawn', 'PlayRangedAttack', 'Brute_PlayRangedAttack');
	ReplaceFunction( class'Gasbag', class'XC_Engine_ScriptedPawn', 'PlayRangedAttack', 'Gasbag_PlayRangedAttack');
	ReplaceFunction( class'Mercenary', class'XC_Engine_Mercenary', 'SprayTarget', 'Tw_SprayTarget');
	ReplaceFunction( class'NaliRabbit', class'XC_Engine_ScriptedPawn', 'PickDestination', 'NaliRabbit_PickDestination', 'Evade');
	ReplaceFunction( class'SkaarjBerserker', class'XC_Engine_ScriptedPawn', 'WhatToDoNext', 'SkaarjBerserker_WhatToDoNext');
	ReplaceFunction( class'SkaarjTrooper', class'XC_Engine_SkaarjTrooper', 'BeginState', 'Startup_BeginState', 'StartUp');
	
	ReplaceFunction( class'BruteProjectile', class'XC_Engine_UT99_Projectile', 'BlowUp', 'BruteProjectile_BlowUp', 'Flying');
	
	MapFile = String(Outer.Name);
	if ( MapFile ~= "DM-Deck16][" )
		FixDeck16();
	else if ( MapFile ~= "DOM-Bullet" )
		FixDBullet();
	else if ( MapFile ~= "DOM-Ghardhen" )
		FixGhardhen();
	else if ( MapFile ~= "DOM-Cinder" )
		FixCinder();
	else if ( MapFile ~= "DM-Bishop" )
		FixBishop();
	else if ( MapFile ~= "DM-Liandri" )
		FixLiandri();
	else if ( MapFile ~= "DM-Agony" )
		FixAgony();
	else if ( MapFile ~= "DM-ArcaneTemple" )
		FixATemple();
	else if ( MapFile ~= "DOM-Cidom" )
		FixCidom();
	else if ( MapFile ~= "DOM-Sesmar" )
		FixSesmar();
	else if ( MapFile ~= "DM-Barricade" )
		FixBarricade();
		
	Destroy();
}


//Speed opt
function DVT_Trigger( actor Other, pawn EventInstigator )
{
	local Pawn P;
	ForEach PawnActors (class'Pawn', P, CollisionHeight+CollisionRadius+50 )
		if ( (abs(Location.Z - P.Location.Z) < CollisionHeight + P.CollisionHeight)
			&& (VSize(Location - P.Location) < CollisionRadius) )
			P.Trigger(Other, EventInstigator);
}


//Fix that allows moving all other non-Unreal1 pawns
function Transporter_Trigger( Actor Other, Pawn EventInstigator )
{
	local PlayerPawn P;
	local Actor A;
	local Transporter T;

	A = self;
	T = Transporter(A); //Typecast hack!

	// Move the player instantaneously by the Offset vector
	ForEach DynamicActors( class'PlayerPawn', P)
		if( !P.SetLocation( P.Location + T.Offset ) ) //Typecast to access Offset
		{
			// The player could not be moved, probably destination is inside a wall
		}

	Disable( 'Trigger' );
}


function Actor TranslocStart_SpecialHandling(Pawn Other)
{
	local Bot B;

	if ( Other.PlayerReplicationInfo == None )
		return None;
	if ( (Other.MoveTarget == None) || (!Other.MoveTarget.IsA('TranslocDest') && (Other.MoveTarget != self)) )
		return self;
	B = Bot(Other);
	if ( B != None )
	{
		if ( (B.MyTranslocator == None) || (B.MyTranslocator.TTarget != None) )
			return None;
		B.TranslocateToTarget(self);
		return self;
	}
}

function FixLiandri()
{
	local PathNode P;
	local InventorySpot IS;
	
	ForEach NavigationActors (class'PathNode', P, 20, vect(1004,3530,1914) )
		ForEach NavigationActors (class'InventorySpot', IS, 120, P.Location)
			EzConnectNavigationPoints( P, IS);
}

function FixBishop()
{
	Spawn( class'XC_Engine_LiftCenter', self,,vect(  491, -1131,  -596) );
	Spawn( class'XC_Engine_LiftCenter', self,,vect( -914,  128,    -68) );
}

function FixAgony()
{
	local PathNode P, R;
	ForEach NavigationActors (class'PathNode', P, 160, vect(53,1027,76) )
	{
		if ( R != None )
			EzConnectNavigationPoints( P, R);
		R = P;
	}
}

function FixATemple()
{
	local PathNode P, R;
	ForEach NavigationActors (class'PathNode', P, 330, vect(-870,2,462) )
	{
		if ( R != None )
			EzConnectNavigationPoints( P, R);
		R = P;
	}
}

//Fix several navigation issues
function FixDeck16()
{
	local PathNode P, PP;
	local InventorySpot IS;
	local Teleporter T;
	local ReachSpec R;
	
	ForEach NavigationActors ( class'PathNode', P, 20, vect(1413,-927,-174) )
		if ( String(P.Name) ~= "PathNode78" )
		{
			ForEach NavigationActors ( class'PathNode', PP, 200, P.Location)
			{
				if ( String(PP.Name) ~= "PathNode79" )
				{
					R.Start = P;
					R.End = PP;
					R.CollisionHeight = 50;
					R.CollisionRadius = 35;
					R.ReachFlags = R_WALK | R_JUMP;
					R.Distance = 70;
					AddReachSpec( R, true); //Auto-append
					break;
				}
			}
			break;
		}
		
	ForEach NavigationActors ( class'InventorySpot', IS, 20, vect(880,-1420,-1220))
		if ( String(IS.Name) ~= "InventorySpot190" )
		{
			ForEach NavigationActors ( class'Teleporter', T, 250, IS.Location)
			{
				R.Start = IS;
				R.End = T;
				R.CollisionHeight = 50;
				R.CollisionRadius = 35;
				R.ReachFlags = R_WALK;
				R.Distance = 100;
				AddReachSpec( R, true); //Auto-append
				break;
			}
		}
		
		
	ForEach NavigationActors ( class'PathNode', P, 20, vect(1077,392,-1221) )
		if ( String(P.Name) ~= "PathNode145" )
		{
			ForEach NavigationActors ( class'PathNode', PP)
			{
				if ( String(PP.Name) ~= "PathNode22" )
				{
					R.Start = P;
					R.End = PP;
					R.CollisionHeight = 50;
					R.CollisionRadius = 25;
					R.ReachFlags = R_WALK | R_JUMP;
					R.Distance = 80;
					AddReachSpec( R, true); //Auto-append
					R.Start = PP;
					R.End = P;
					AddReachSpec( R, true); //Auto-append
					break;
				}
			}
			break;
		}
		
	ForEach NavigationActors ( class'PathNode', P, 20, vect(895,818,-718) )
		if ( String(P.Name) ~= "PathNode41" )
		{
			ForEach NavigationActors ( class'PathNode', PP, 300, P.Location)
			{
				if ( String(PP.Name) ~= "PathNode95" )
				{
					R.Start = P;
					R.End = PP;
					R.CollisionHeight = 50;
					R.CollisionRadius = 25;
					R.ReachFlags = R_WALK | R_JUMP;
					R.Distance = 80;
					AddReachSpec( R, true); //Auto-append
					break;
				}
			}
			break;
		}
}

//Connect a broken hallway leading to a control point
function FixDBullet()
{
	local PathNode P, PP;
	local ReachSpec R;

	ForEach NavigationActors ( class'PathNode', P, 20, vect(-504,-1229,162) )
		if ( String(P.Name) ~= "PathNode227" )
		{
			ForEach NavigationActors ( class'PathNode', PP, 300, P.Location)
			{
				if ( String(PP.Name) ~= "PathNode176" )
				{
					R.Start = P;
					R.End = PP;
					R.CollisionHeight = 50;
					R.CollisionRadius = 25;
					R.ReachFlags = R_WALK;
					R.Distance = 80;
					AddReachSpec( R, true); //Auto-append
					R.Start = PP;
					R.End = P;
					AddReachSpec( R, true); //Auto-append
					break;
				}
			}
			break;
		}
}

//Allow bots to jump into the Center control point by the side entrances
function FixGhardhen()
{
	local Name aName;
	local PathNode P;
	local InventorySpot IS[2];
	local ReachSpec R;
	local int i;
	
	if ( Level.Game.PlayerJumpZScaling() < 1.09 )
		return;

	aName = class'XC_CoreStatics'.static.StringToName("InventorySpot98");
	ForEach NavigationActors( class'InventorySpot', IS[0])
		if ( IS[0].Name == aName )
			break;
	aName = class'XC_CoreStatics'.static.StringToName("InventorySpot103");
	ForEach NavigationActors( class'InventorySpot', IS[1])
		if ( IS[1].Name == aName )
			break;

	For ( i=0 ; i<2 ; i++ )
		ForEach NavigationActors ( class'PathNode', P, 200, IS[i].Location)
		{
			if ( P.Location.Z > IS[i].Location.Z + 10 )
			{
				R.Start = IS[i];
				R.End = P;
				R.CollisionHeight = 50;
				R.CollisionRadius = 25;
				R.ReachFlags = R_WALK | R_JUMP;
				R.Distance = 80;
				AddReachSpec( R, true); //Auto-append
				break;
			}
		}
}

function FixCinder()
{
	local PathNode PA;
	local NavigationPoint N;
	local InventorySpot IS;
	local ReachSpec R;
	
	//Connect thigh pads to the world
	ForEach NavigationActors (class'PathNode', PA, 20, vect(-387,292,395) )
	{
		ForEach NavigationActors (class'NavigationPoint', N, 530, PA.Location, true)
			if ( (Abs( PA.Location.Z - N.Location.Z) < 100) && (N != PA) )
			{
				if ( N.IsA('InventorySpot') )
				{
					if ( VSize(N.Location - PA.Location) < 270 )
						EzConnectNavigationPoints( PA, N, 1, true);
					continue;
				}
				EzConnectNavigationPoints( PA, N);
			}
		break;
	}
	//Reach pulse gun from below
	ForEach NavigationActors (class'PathNode', PA, 20, vect(-853,1303,50) )
	{
		ForEach NavigationActors (class'InventorySpot', IS, 30, vect(-905,1576,117) )
		{
			EzConnectNavigationPoints( PA, IS);
			break;
		}
		break;
	}
	
	//Reach armor
	if ( Level.Game.PlayerJumpZScaling() >= 1.09 )
	{
		ForEach NavigationActors (class'InventorySpot', IS, 30, vect(-808,-1041,-11) )
		{
			ForEach NavigationActors (class'NavigationPoint', N, 200, IS.Location)
				EzConnectNavigationPoints( N, IS);
			break;
		}
	}
}

function FixCidom()
{
	local NavigationPoint N;
	local LiftExit LE, High, Low;
	local TranslocDest TD;
	local PathNode P;
	
	ForEach NavigationActors( class'TranslocDest', TD)
	{
		High = None;
		Low = None;
		ForEach NavigationActors( class'LiftExit', LE)
			if ( LE.LiftTag == TD.LiftTag )
			{
				if ( High == None )
					High = LE;
				else if ( High.Location.Z < LE.Location.Z )
				{
					Low = High;
					High = LE;
				}
				else
					Low = LE;
			}
		EzConnectNavigationPoints( High, Low, 2, true);
		ForEach NavigationActors( class'PathNode', P, 455, TD.Location, true)
		{
			EzConnectNavigationPoints( High, P, 1.2, true);
			EzConnectNavigationPoints( P, TD, 1, true);
		}
	}
}

function FixSesmar()
{
	local ControlPoint CP;
	local PathNode P;
	
	ForEach NavigationActors( class'ControlPoint', CP)
	{
		ForEach NavigationActors( class'PathNode', P, 500, CP.Location, true)
			if ( (P.Location.Z > CP.Location.Z) && (P.Location.Z < CP.Location.Z + 100) )
				EzConnectNavigationPoints( CP, P, 1.2);
	}
}

function FixBarricade()
{
	local PathNode P, PP;
	local InventorySpot IS, Redeemer;
	local JumpSpot JS;
	local XC_Engine_LiftExit LE;

	if ( Level.Game.PlayerJumpZScaling() >= 1.09 )
	{
		ForEach NavigationActors( class'InventorySpot', Redeemer, 15, vect(385,255,565))
			break;
		ForEach NavigationActors( class'PathNode', P)
		{
			if ( P.Location.Z > 1000 ) //Towers
			{
				ForEach NavigationActors( class'InventorySpot', IS, 130, P.Location) //Link items to node
					EzConnectNavigationPoints( IS, P, 2, true);
				ForEach NavigationActors( class'PathNode', PP, 700, P.Location, true) //Link to redeemer nodes
					if ( PP != P )
					{
						EzConnectNavigationPoints( P, PP, 1, true);
						EzConnectNavigationPoints( Redeemer, PP, 1.5, true);
					}
			}
		}
	}
	
	ForEach NavigationActors( class'InventorySpot', IS, 15, vect(-1430,300,373))
		ForEach NavigationActors( class'JumpSpot', JS, 15, vect(-720,255,367))
			EzConnectNavigationPoints( IS, JS, 1, true);
			
	LE = Spawn( class'XC_Engine_LiftExit', None, 'XC_Engine_LiftExit', vect(450,262,86));
	LE.LiftTag = 'hymen';
	LockToNavigationChain( LE, true);
	DefinePathsFor( LE);
	LE = Spawn( class'XC_Engine_LiftExit', None, 'XC_Engine_LiftExit', vect(440,222,404));
	LE.LiftTag = 'hymen';
	LockToNavigationChain( LE, true);
	DefinePathsFor( LE);
	Spawn( class'XC_Engine_LiftCenter', self, 'XC_Engine_LiftCenter', vect(510,256,86));
}

defaultproperties
{
     bHidden=True
	 RemoteRole=ROLE_None
}








