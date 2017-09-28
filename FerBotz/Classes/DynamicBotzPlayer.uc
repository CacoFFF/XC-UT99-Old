//=============================================================================
// DynamicBotzPlayer.
// FUTURE USE: Special spot creation and dump
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class DynamicBotzPlayer expands TBoss;

#exec TEXTURE IMPORT NAME=Botz_Scope FILE=..\CompileData\Botz_Scope.bmp FLAGS=2
#exec TEXTURE IMPORT NAME=BWP_Base FILE=..\CompileData\BWP_Base.bmp FLAGS=2

const BFM = class'BotzFunctionManager';

var() texture ScopeIcon;
var BotzMutator MyMutator;
var BotzBasePointLog MyLog; //Easy BaseLevelPoint adder

var Botz_PathLoader pLoader;
var bool bPathsEdit;
var Botz_NavigBase pCur;
var NavigationPoint nCur, nCurLast;
var DynaPlayerMarker MyMarker;

native(3540) final iterator function PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional Pawn StartAt);
native(3555) static final operator(22) NavigationPoint Or (NavigationPoint A, skip NavigationPoint B);
native(3559) static final function int AppCycles();

//Modifiers:
// 0x0001:	no R_WALK routes
// 0x0002:	no R_FLY routes
// 0x0004:	no R_SWIM routes
// 0x0008:	no R_JUMP routes
// 0x0010:	no R_DOOR routes
// 0x0020:	no R_SPECIAL routes
// 0x0040:	no R_PLAYERONLY routes
// 0x0080:	soft-reset (VisitedWeight, prevOrdered) instead of hard-reset (+ cost, nextOrdered)

// When calling MapRoutes a 'hard-reset' will occur and all paths will be ready to be mapped
// PostHardResetEvent allows the user to modify NavigationPoint's cost inbetween a hard-reset and the mapping

// If you intend to change the StartAnchor after already having mapped the network,
// perform a soft-reset to avoid calculating path 'Cost' again
native final function MapRoutes( NavigationPoint StartAnchor, optional int MinWidth, optional int MinHeight, optional int Modifiers, optional name PostHardResetEvent);
native final function NavigationPoint BuildRouteCache( NavigationPoint EndPoint, out NavigationPoint CacheList[16] );


function PostBeginPlay()
{
	local Mutator TheMut;
	Super.PostBeginPlay();
	For ( TheMut=Level.Game.BaseMutator ; TheMut!=none ; TheMut=TheMut.nextMutator )
		if ( TheMut.IsA('BotzMutator') )
		{
			MyMutator = BotzMutator(TheMut);
			break;
		}
	MyMarker = Spawn(class'DynaPlayerMarker');
	MyMarker.Player = self;
	SetPropertyText("bSuperClassRelevancy","1");
}

exec function RouteTest()
{
	local int Cycles;
	local NavigationPoint Chosen;
	
	Chosen = nCur Or pCur Or nCurLast; 
	if ( Chosen == None )
		return;

	Cycles = AppCycles();
	MapRoutes( Chosen);
	Cycles = AppCycles() - Cycles;
	Log("Single mapping test: "$Cycles);
	
	Cycles = AppCycles();
	MapRoutes( Chosen);
	MapRoutes( Chosen,,,0x80);
	MapRoutes( Chosen,,,0x80);
	MapRoutes( Chosen,,,0x80);
	MapRoutes( Chosen,,,0x80);
	MapRoutes( Chosen,,,0x80);
	Cycles = AppCycles() - Cycles;
	Log("Multi mapping test: "$Cycles);
}

exec function BotState(name NewState,name NewLabel)
{
	local Pawn P;
	foreach AllActors (class'Pawn', P)
		if ( P.IsA('Botz') )
		{
			if ( NewState == '' )
				ClientMessage(P.PlayerReplicationInfo.PlayerName$" "$string(P.Name)$" esta en estado "$P.GetStateName() );
			else
			{
				P.GotoState(NewState,NewLabel);
				ClientMessage(P.PlayerReplicationInfo.PlayerName$" "$string(P.Name)$" esta en estado "$newstate$ " y en label "$NewLabel);
			}
		}
}

exec function TestWall( optional bool Reverse, optional bool bHoriz)
{
	local actor A;
	local vector HitLocation, HitNormal, EndNormal, EndPoint;
	local vector Dest, Start;
	
	Start.Z = EyeHeight;
	Start += Location;
	Dest = Start + vector(ViewRotation) * 1000;
	
	EndPoint = Dest - Start;
	if ( Reverse )		EndPoint *= -1;
	if ( Trace( HitLocation, HitNormal, Dest, Start) != none )
	{
		EndNormal = HitNormal;
		A = BFM.static.FindWallEnd( self, HitLocation + HitNormal * CollisionRadius * 1.8, EndNormal, EndPoint, 25, 25, vect(1,1,0) );
		Spawn(class'F_TempDest',,,EndPoint).LifeSpan = 5;
	}
}

exec function Comandos()
{
	ClientMessage("STARTWP, Debe ser agregado 1ro");
	ClientMessage("LINKNAMED, Debe ser agregado 2do");
	ClientMessage("CONNECTWPS, Debe ser agregado 3ro");
	ClientMessage("CHECKCONNECTIONS, checkea si hay caminos rotos");
	ClientMessage("IDENTIFYJUNC, Debe ser agregado 4to");
	ClientMessage("LINKJUNC, Debe ser agregado 5to");
	ClientMessage("SHOWPATHS 1 o 0, hace o no visibles los caminos");
	ClientMessage("FINDPATH, indica como llegar al objetivo guardado");
	ClientMessage("TARGETNONE, borra objetivo guardado");
	ClientMessage("TARGETHERE, guarda tu ubicacion como objetivo");
	ClientMessage("GETVECTOR, indica tu ubicación (util para crear WP externos)");
	ClientMessage("GETJUNCTIONS, indica las junciones mas cercanas");
	ClientMessage("APUNTAR, localizar puntos de sniper");
	ClientMessage("DUMP");
}

exec function Commands()
{
	ClientMessage("STARTLOG; boolean vars that enable spawn flags below");
	ClientMessage("ASSAULTBACKUP; 2x Size, Only delay, 25%, 50%, count ahead");
	ClientMessage("DEFENSEPOINT; team, bSniper, bDoubleTime, bAnyRange, bDoubleChance");
	ClientMessage("AUTOENEMYSNIPER; team, bOnlySniper, bUnseeableSnipers, bFerDefensePoint, bAllTeams");
	ClientMessage("ENEMYSNIPER; team, bIgnoreInTGPlus, bUnseeable");
	ClientMessage("PATHSLAYER; extra cost");
	ClientMessage("TOUCHSLAYER; only 60º, bCheckInv, bTakeThisInv, bOnlyMovetarget");
	ClientMessage("KICKSLAYER; bDestn, bIsJump, bForceFallPhys, bDoubleStr, bExtraSize");
	ClientMessage("ADDCLOSEST; select the current point's closest path (GETCLOSEST to test)");
	ClientMessage("ADDFLAGS; bTransloc, bJumpBoots");
	ClientMessage("ENDLOG");
}

function LogIncrease()
{
	local int iTest;
	local BotzBasePointLog newLog;

	if ( MyLog.CurrentPoint < 31 )
		MyLog.CurrentPoint++;
	else
	{//Generate new chained log
		MyLog.CurrentPoint = 31;
		MyLog.AddProperty("Points","Class'"$MyLog.fTmp$"."$MyLog.fTmp$"Chain"$string(MyLog.ChainedIndex+1)$"'");
		newLog = Spawn( class'BotzBasePointLog');
		newLog.StartFile( MyLog.ChainedIndex+1);
		MyLog.EndFile();
		MyLog = newLog;
	}
}

exec function TouchSlayer( bool bOnly60, bool bCheckInv, bool bTakeThisInv, bool bOnlyMovetarget)
{
	local int i;
	LogIncrease();
	ClientMessage("TouchSlayer");
	MyLog.AddProperty("Points","Class'FerBotz.Botz_TouchSlayer'");
	MyLog.AddProperty("Locations", MyLog.MakeVector( Location) );
	MyLog.AddProperty("Rotations", MyLog.MakeRotator( ViewRotation) );
	if ( bOnly60 ) i = 1;
	if ( bCheckInv ) i += 2;
	if ( bTakeThisInv ) i += 4;
	if ( bOnlyMovetarget ) i += 8;
	MyLog.AddProperty("SpawnFlags", string(i) );
}

exec function DefensePoint( byte uTeam, bool bSniper, bool bDoubleTime, bool bAnyRange, bool bDoubleChance)
{
	local int i;
	LogIncrease();
	ClientMessage("DefensePoint");
	MyLog.AddProperty("Points","Class'FerBotz.FerDefensePoint'");
	MyLog.AddProperty("Locations", MyLog.MakeVector( Location) );
	MyLog.AddProperty("Rotations", MyLog.MakeRotator( ViewRotation) );
	MyLog.AddProperty("Teams", string(uTeam) );
	if ( bSniper ) i = 1;
	if ( bDoubleTime ) i += 2;
	if ( bAnyRange ) i += 4;
	if ( bDoubleChance ) i += 8;
	MyLog.AddProperty("SpawnFlags", string(i) );
}

exec function KickSlayer( bool bDestn, bool bIsJump, bool bForceFallPhys, bool bDoubleStr, bool bExtraSize)
{
	local int i;
	LogIncrease();
	ClientMessage("KickSlayer");
	MyLog.AddProperty("Points","Class'FerBotz.Botz_KickSlayer'");
	MyLog.AddProperty("Locations", MyLog.MakeVector( Location) );
	MyLog.AddProperty("Rotations", MyLog.MakeRotator( ViewRotation) );
	if ( bDestn) i = 1;
	if ( bIsJump) i += 2;
	if ( bForceFallPhys) i += 4;
	if ( bDoubleStr) i += 8;
	if ( bExtraSize) i += 16;
	MyLog.AddProperty("SpawnFlags", string(i) );
}

exec function AssaultBackup( bool b2Size, bool bDelay, bool bQuarter, bool bHalf, bool bAhead)
{
	local int i;
	LogIncrease();
	ClientMessage("AssaultBackup");
	MyLog.AddProperty("Points","Class'FerBotz.Botz_AssaultBackup'");
	MyLog.AddProperty("Locations", MyLog.MakeVector( Location) );
	if ( b2Size ) i = 1;
	if ( bDelay ) i += 2;
	if ( bQuarter ) i += 4;
	if ( bHalf ) i += 8;
	if ( bAhead ) i += 16;
	MyLog.AddProperty("SpawnFlags", string(i) );
}

exec function EnemySniper( byte uTeam, bool bIgnoreOnTG, bool bUnseeable)
{
	local int i;
	LogIncrease();
	ClientMessage("EnemySniper");
	MyLog.AddProperty("Points","Class'FerBotz.F_EnemySniperSpot'");
	MyLog.AddProperty("Teams", string(uTeam) );
	MyLog.AddProperty("Locations", MyLog.MakeVector( Location) );
	if ( bIgnoreOnTG ) i = 1;
	if ( bUnseeable ) i += 2;
	MyLog.AddProperty("SpawnFlags", string(i) );
}

exec function AutoEnemySniper( byte uTeam, bool bOnlySniper, bool bUnseeableSnipers, bool bFerDefensePoint, bool bAllTeams)
{
	local int i;
	LogIncrease();
	ClientMessage("AutoEnemySniper");
	MyLog.AddProperty("Points","Class'FerBotz.F_AutoEnemySniper'");
	MyLog.AddProperty("Teams", string(uTeam) );
	if ( bOnlySniper )	i = 1;
	if ( bUnseeableSnipers ) i += 2;
	if ( bFerDefensePoint ) i += 4;
	if ( bAllTeams ) i += 8;
	MyLog.AddProperty("SpawnFlags", string(i) );
}

exec function StartLog()
{
	if ( MyLog != none )
		return;
	MyLog = Spawn( class'BotzBasePointLog');
	MyLog.StartFile( 0);
	ClientMessage("LogFile started");
	ConsoleCommand("Set PathNode bHidden 0");
	ConsoleCommand("Set InventorySpot bHidden 0");
	ConsoleCommand("Set LiftExit bHidden 0");
	ConsoleCommand("Set LiftCenter bHidden 0");
	ConsoleCommand("Set FortStandard bHidden 0");
}

exec function EndLog()
{
	MyLog.EndFile();
	ClientMessage("LogFile closed");
	ConsoleCommand("Set PathNode bHidden 1");
	ConsoleCommand("Set InventorySpot bHidden 1");
	ConsoleCommand("Set LiftExit bHidden 1");
	ConsoleCommand("Set LiftCenter bHidden 1");
	ConsoleCommand("Set FortStandard bHidden 1");
	MyLog = none;
}

exec function AddFlags( bool bTransloc, bool bJumpBoot)
{
	ClientMessage("Flags added: "$string(bTransloc)$", "$string(bJumpBoot) );
	if ( bTransloc )
		MyLog.AddProperty("bTransloc","1");
	if ( bJumpBoot )
		MyLog.AddProperty("bJumpBoot","1");
}

exec function GetClosest()
{
	local actor aActor;
	
	ForEach RadiusActors (class'Actor', aActor, 50) //Radius is minimal
	{
		if ( aActor != self )
		{
			ClientMessage("Adding closest actor: "$GetItemName(string(aActor)) );
			return;
		}
	}
}

exec function AddClosest()
{
	local actor aActor;
	
	ForEach RadiusActors (class'Actor', aActor, 50) //Radius is minimal
	{
		if ( aActor != self )
		{
			ClientMessage("Adding closest actor: "$GetItemName(string(aActor)) );
			MyLog.AddProperty("ClosestPath",GetItemName(string(aActor)) );
			return;
		}
	}
}

exec function Dump()
{
}


exec function ShowPaths( bool Hidepaths)
{
}

exec function GetVector()
{
	ClientMessage("Ubicacion Global:");
	ClientMessage("X es "$ int(Location.X) );
	ClientMessage("Y es "$ int(Location.Y) );
	ClientMessage("Z es "$ int(Location.Z) );
}

exec function FindInv()
{
/*	local inventory inv, Best; NO IMPLEMENTADO AUN
	local Float MaxDist;
	local float BestDist;
	local float Rating;
	local float Desire;
	local float Dist;

	ForEach VisibleCollidingActors
*/
}

event PostRender(canvas Canvas)
{
	local float Xdist, Ydist, Zdist, maxwidth;
	local int i, j, k;
	local actor TraceTest, StartActor;
	local vector HitLocation, HitNormal, Z, aVec;
	local string OtherStr;
	local NavigationPoint Nav;

	Super.PostRender(Canvas);

	//Display trace information
	Canvas.DrawColor = Col(0,255,255);
	Canvas.Font = font'MedFont';
	Canvas.SetPos( 5, 100);
	Canvas.Style = ERenderStyle.STY_Masked;
	Canvas.DrawText("MultiTrace result:");
	ForEach TraceActors ( class'Actor', TraceTest, HitLocation, HitNormal, location + vect(0,0,1) * eyeheight + vector(viewrotation) * 8000, location + vect(0,0,1) * eyeheight)
	{
		i++;
		Canvas.SetPos( 5, 100 + 8*i);
		Canvas.DrawText(  GetItemName(string(TraceTest) )$", Norm("$left(string(HitNormal.X), 6)$","$left(string(HitNormal.Y),6)$","$left(string(HitNormal.Z),6)$") D="$ int(VSize(Location - HitLocation)) );
	}

	if ( bPathsEdit )
	{
		pCur = NearestNB();

		if ( pCur != none )
		{
			i++;
			Canvas.SetPos( 5, 104 + 8*i);
			Canvas.DrawText( pCur.FriendlyName $ " MaxDist " $pCur.MaxDistance );
		}

		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( "INSERT COMMANDS:" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavBase: Inserts pathnode" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavDoor: Inserts mover ignore path (each side)" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavDoorSpecial: Inserts special mover path" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavHighJump: Inserts big jump destination" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavHighTrans: Inserts simple high Transloc dest" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavLiftCenter: Inserts Lift-Center waypoint" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavLiftExit: Inserts Lift-Exit WP, aim at LC to connect" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavLiftJump: Inserts Lift-Exit JUMP, aim at LC to connect" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavDodgeStart: Aim at jump direction" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavDodgeEnd: Simple dest marker" );
		i++;
		Canvas.SetPos( 5, 104 + 8*i);
		Canvas.DrawText( ">NavAir: Inserts basic air node" );
		i++;
		//DIRECT NODES
		Canvas.SetPos( 5, 108 + 8*i);
		Canvas.DrawText( ">NavDirectLink: Inserts direct link node" );
		i++;
		Canvas.SetPos( 5, 108 + 8*i);
		Canvas.DrawText( ">NavDirectTrans: Inserts direct Transloc dest" );
		i++;
		Canvas.SetPos( 5, 108 + 8*i);
		Canvas.DrawText( ">NavPistonLaunch: Inserts direct Piston Launch" );
		i++;
		Canvas.SetPos( 5, 108 + 8*i);
		Canvas.DrawText( ">NavPlatformBelow: Inserts direct path, activates if walkable" );
		
		//REMOVER
		i++;
		Canvas.SetPos( 5, 112 + 8*i);
		Canvas.DrawText( ">NavRemover: Removes base navigation points" );
		i++;
		Canvas.SetPos( 5, 112 + 8*i);
		Canvas.DrawText( ">NavRemoverSmart: Removes possibly redundant base navigation points" );
		i++;
		Canvas.SetPos( 5, 112 + 8*i);
		Canvas.DrawText( ">NavTeleWatcher: Makes currently disabled teleporters not usable by bots" );

	}

	i=0;
	Canvas.SetPos( Canvas.ClipX - 280, 110 );
	if ( bPathsEdit )
	{
		Canvas.DrawText("Navigation insert mode ON");
		Canvas.SetPos( Canvas.ClipX - 300, 118 );
		Canvas.DrawText(">NavToggle: Disable edit mode");
		Canvas.SetPos( Canvas.ClipX - 300, 126 );
		Canvas.DrawText(">NavSave: Save paths");
		Canvas.SetPos( Canvas.ClipX - 300, 134 );
		Canvas.DrawText(">NavDelete: Delete this");
		Canvas.SetPos( Canvas.ClipX - 300, 142 );
		Canvas.DrawText(">NavDistance (dist): Sets max distance");
		Canvas.SetPos( Canvas.ClipX - 300, 150 );
		Canvas.DrawText(">NavOneWayInc: One way incoming");
		Canvas.SetPos( Canvas.ClipX - 300, 158 );
		Canvas.DrawText(">NavOneWayOut: One way outgoing");
		Canvas.SetPos( Canvas.ClipX - 300, 166 );
		Canvas.DrawText(">NavTurn: Rotates nav to player view");
	}
	else
	{
		Canvas.DrawText("Navigation insert mode OFF");
		i++;
		Canvas.SetPos( Canvas.ClipX - 300, 110 + 8*i );
		Canvas.DrawText(">NavToggle: Enable edit mode");
		i++;
		Canvas.SetPos( Canvas.ClipX - 300, 110 + 8*i );
		Canvas.DrawText("In order to reload, restart level");
	}

	Nav = pCur;
	if ( Nav == none )
		Nav = nCur;

	if ( Nav != None )
		nCurLast = Nav;
		
	if ( bPathsEdit && nCurLast != none )
	{
		Canvas.SetPos( Canvas.ClipX - 330, 180);
		Canvas.DrawText("Dist from "$string(nCurLast.Name)$": "$string(int(VSize(Location - nCurLast.Location))) );
	}
	Canvas.Style = ERenderStyle.STY_Translucent;

	if ( Nav != none )
	{
		Canvas.DrawColor = Col(255,255,255);
		GetAxes( ViewRotation, HitLocation, HitNormal, Z);
		aVec = Location;
		aVec.Z += EyeHeight;
		maxwidth = tan((FOVAngle / 360) * pi); //1 if 90º, lower if less, bigger if more

		For ( i=0 ; i<16 ; i++ )
		{
			if ( Nav.Paths[i] == -1 )
				break;
			Nav.describeSpec( Nav.Paths[i], StartActor, TraceTest, j, k);
			if ( TraceTest != none )
			{
				Xdist = (TraceTest.Location - aVec) dot HitLocation;
				Ydist = (TraceTest.Location - aVec) dot HitNormal;
				Zdist = (TraceTest.Location - aVec) dot Z;
				if ( Xdist < 0 )
					continue;
				if ( Xdist < abs(YDist / maxwidth) )
					continue;
				Canvas.SetPos( Canvas.ClipX / 2 + ((YDist / maxwidth) / Xdist) * Canvas.ClipX / 2 - 32, Canvas.ClipY / 2 - ((ZDist / maxwidth) / Xdist) * Canvas.ClipX / 2 - 32);
				Canvas.DrawIcon( texture'BWP_Base', 1);
				Canvas.DrawText( string( int(VSize(Nav.Location - TraceTest.Location) ) ) @"("$k$")" );
			}
		}
	}
}

exec function WeaponStates()
{
	local Botz B;

	ForEach PawnActors( class'Botz', B)
		if ( B.Weapon != None )
			ClientMessage( B.PlayerReplicationInfo.PlayerName@B.Weapon.Class.Name@B.Weapon.GetStateName() );
}

exec function NavRemover( optional float Dist)
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_NavigRemover',,,,ViewRotation);
		if ( Dist > 0 )
			pCur.MaxDistance = Dist;
		pCur.bHidden = false;
	}
}

exec function NavRemoverSmart( optional float Dist)
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_NavigRemoverSmart',,,,ViewRotation);
		if ( Dist > 0 )
			pCur.MaxDistance = Dist;
		pCur.bHidden = false;
	}
}

exec function NavTeleWatcher( optional float Dist)
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_TeleWatcher',,,,ViewRotation);
		if ( Dist > 0 )
			pCur.MaxDistance = Dist;
		pCur.bHidden = false;
	}
}

exec function NavLiftExit()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_LiftExit',,,,ViewRotation);
		pCur.bHidden = false;
	}
}

exec function NavLiftJump()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_LiftJumpExit',,,,ViewRotation);
		pCur.bHidden = false;
	}
}

exec function NavDodgeStart()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_DodgeStart',,,,ViewRotation);
		pCur.bHidden = false;
	}
}

exec function NavDodgeEnd()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_DodgeEnd',,,,ViewRotation);
		pCur.bHidden = false;
	}
}

exec function NavLiftCenter()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_LiftCenter');
		pCur.bHidden = false;
	}
}

exec function NavBase()
{
	local float RealDist;
	
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_NavigNode');
		if ( nCurLast != None )
			RealDist = VSize(Location - nCurLast.Location);
		if ( (RealDist > 1 && RealDist < 1500) && FastTrace(nCurLast.Location) )
		{
			pCur.MaxDistance = fMax( pCur.MaxDistance, RealDist + 3);
			if ( (Botz_NavigBase(nCurLast) != None) && (Botz_NavigBase(nCurLast).MaxDistance < RealDist + 3) )
			{
				if ( Botz_NavigNode(nCurLast) != None )
					Botz_NavigNode(nCurLast).MaxDistance = RealDist + 3;
				else
					ClientMessage("Node "$nCurLast.Name$"needs distance "$int(RealDist + 3)$"or it won't connect!");
			}
		}
		pCur.bHidden = false;
	}
}

exec function NavAir()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_NavigAirBase');
		pCur.bHidden = false;
	}
}

exec function NavDoor()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_NavigDoor');
		pCur.bHidden = false;
	}
}

exec function NavDoorSpecial()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_NavigDoorSpecial');
		pCur.bHidden = false;
	}
}

exec function NavHighJump()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_JumpNode');
		pCur.bHidden = false;
	}
}

exec function NavHighTrans()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_SimpleTDest');
		pCur.bHidden = false;
	}
}

exec function NavDirectLink()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_DirectLink',,,,ViewRotation);
		pCur.bHidden = false;
	}
}


exec function NavDirectTrans()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_DirectTDest',,,,ViewRotation);
		pCur.bHidden = false;
	}
}

exec function NavPistonLaunch()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_DirectPistonTrans',,,,ViewRotation);
		pCur.bHidden = false;
	}
}

exec function NavPlatformBelow()
{
	if ( bPathsEdit )
	{
		pCur = Spawn(class'Botz_DirectPlatformBelow',,,,ViewRotation);
		pCur.bHidden = false;
	}
}

exec function NavOneWayOut()
{
	if ( pCur != none )
	{
		pCur.SetRotation( viewrotation);
		pCur.bOneWayOut = !pCur.bOneWayOut;
		ClientMessage("One way OUT on this path = "$pCur.bOneWayOut);
	}
}
exec function NavOneWayInc()
{
	if ( pCur != none )
	{
		pCur.SetRotation( viewrotation);
		pCur.bOneWayInc = !pCur.bOneWayInc;
		ClientMessage("One way INC on this path = "$pCur.bOneWayInc);
	}
}

exec function NavTurn()
{
	if ( pCur != none )
		pCur.SetRotation( viewrotation);
}

exec function NavDelete()
{
	if ( pCur != none )
	{
		pCur.LockActor(false); //Unlocking should destroy paths
		pCur.Destroy();
		pCur = none;
		ClientMessage("Deleted path");
	}
}

exec function NavDistance( float aDist)
{
	if ( pCur != none )
	{
		if ( aDist == 0 )
			aDist = pCur.default.MaxDistance;
		pCur.MaxDistance = aDist;
		ClientMessage("Destance set to "$aDist);
	}
}

exec function NavSave()
{
	if ( bPathsEdit && pLoader != none )
		pLoader.SaveNodes( self);
}

exec function AimWp()
{
	local vector aVec, Dir, org;
	local NavigationPoint N, Best;
	local float fBest;

	Dir = Vector( ViewRotation);

	ForEach AllActors (class'NavigationPoint', N)
	{
		aVec = Normal( N.Location - Location);
		if ( VSize( aVec + Dir) > fBest )
		{
			Best = N;
			fBest = VSize( aVec + Dir);
		}
	}
	Dir = Best.Location - Location;
	ViewRotation = Rotator( Dir);
	fBest = VSize( Dir);
	ClientMessage( "DIST IS "$string(fBest)$", POINT IS "$GetItemName(string(Best)) );
}

function Botz_NavigBase NearestNB()
{
	local float dist;
	local Botz_NavigBase NN, NB;
	local NavigationPoint Nav;
	
	ForEach RadiusActors (class'Botz_Navigbase', NN, 50)
	{
		if ( !NN.IsA('Botz_NavigRemover') && ((NB == none) || (VSize( NN.Location - Location) < dist)) )
		{
			NB = NN;
			dist = VSize(Location - NB.Location);
		}
	}

	nCur = none;
	if ( NB == None )
		ForEach RadiusActors (class'NavigationPoint', Nav, 30)
		{
			if ( (VSize(Nav.Location - Location) < 100) && (nCur == none || VSize(nCur.Location - Location) < VSize(Nav.Location - Location)) )
			{
				nCur = Nav;
				NB = Botz_NavigBase(nCur);
			}
		}
	

	return NB;
}

exec function NavToggle()
{
	local NavigationPoint N;

	if ( pLoader == none )
	{
		ForEach AllActors (class'Botz_PathLoader', pLoader )
			break;
		if ( pLoader == none )
		{
			ClientMessage("Path loader not spawned, toggling disabled");
			return;
		}
	}

	ForEach AllActors (class'NavigationPoint', N)
		N.bHidden = bPathsEdit;
	bPathsEdit = !bPathsEdit;
}

exec function GiveOrder( name iB, name Orders, name iObject)
{
	local pawn MyObject;
	local pawn aPawn;
	local pawn iPawn;
	local Botz Z;
	local int NumTries;
	local int OtherTries;
	local String B;
	local String Object;

	B = "" $iB;
	Object = "" $iObject;

	NumTries = 0;
	aPawn = Level.PawnList;
	while ( aPawn != None)
	{
		Z = botz(aPawn);
		if ( (Z != None) && (Z.PlayerReplicationInfo.PlayerName ~= B) )
		{
			aPawn = none;
		}
		else if ( NumTries >= 200 )
		{
			aPawn = none;
		}
		else
		{
			aPawn = aPawn.nextPawn;
			NumTries++;
		}
	}
	OtherTries = 0;
	iPawn = Level.PawnList;
	while ( iPawn != None)
	{
		if (iPawn.PlayerReplicationInfo.PlayerName ~= Object)
		{
			MyObject = iPawn;
			iPawn = none;
		}
		else if ( NumTries >= 200 )
		{
			iPawn = none;
		}
		else
		{
			iPawn = iPawn.nextPawn;
			NumTries++;
		}
	}
	if ( (Z != none) && (MyObject != none) )
		Z.SetOrders( Orders, MyObject, false);
	else
		ClientMessage("Error");
}

static final function Color Col(byte Red, byte Green, byte Blue)
{
	local color NewColor;

	NewColor.R = Red;
	NewColor.G = Green;
	NewColor.B = Blue;

	return (NewColor);
}

final function GetAngles(vector VTarget, out float X, out float Y)
{
	local rotator TheRot;
	local vector VOrigin;
	local float AngleScale;

	VOrigin = Location;
	VOrigin.Z += EyeHeight;
	TheRot = Rotator( VTarget - VOrigin) - ViewRotation;
	AngleScale = 65536 / 360;

	Y = (TheRot.Pitch / AngleScale) * -1;
	X = TheRot.Yaw / AngleScale;

	While ( X > 180 )
		X -= 360;
	While ( X < -180 )
		X += 360;
	While ( Y > 180 )
		Y -= 360;
	While ( Y < -180 )
		Y += 360;
}

defaultproperties
{
     ScopeIcon=Texture'FerBotz.Botz_Scope'
}
