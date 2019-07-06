class XC_Engine_PlayerPawn expands PlayerPawn
	abstract;

var float GW_TimeSeconds;
var int GW_Counter;

//*******************************
// Native viewclass!!!
exec native function ViewClass( class<actor> aClass, optional bool bQuiet );
native event PlayerCalcView( out Actor ViewActor, out vector CameraLocation, out rotator CameraRotation);


native(3540) final iterator function PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional Pawn StartAt);
native(3541) final iterator function NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint P, optional float Distance, optional vector VOrigin, optional bool bVisible);
native(3542) final iterator function InventoryActors( class<Inventory> InvClass, out Inventory Inv, optional bool bSubclasses, optional Actor StartFrom); 
native(3552) final iterator function CollidingActors( class<actor> BaseClass, out actor Actor, float Radius, optional vector Loc);
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );
//native(3555) static final operator(22) Object | (Object A, skip Object B);
native(3571) static final function float HSize( vector A);
native(3572) static final function float InvSqrt( float C);


final function bool CanGWSpam()
{
	if ( class'XC_Engine_PlayerPawn'.default.GW_TimeSeconds != Level.TimeSeconds ) //Antispam, fixes bandwidth exploit
	{
		class'XC_Engine_PlayerPawn'.default.GW_TimeSeconds = Level.TimeSeconds;
		class'XC_Engine_PlayerPawn'.default.GW_Counter = 0;
	}
	return ( class'XC_Engine_PlayerPawn'.default.GW_Counter++ < 3 );
}


//=================
// Admin login hook
native(3551) static final function bool AdminLoginHook( PlayerPawn Other);
exec function AdminLogin( string Password )
{
	if ( AdminLoginHook( self) )
		Level.Game.AdminLogin( Self, Password );
}


//==================
// TeamSay extension
final function string TeamSayFilter( string Msg)
{
	local int i, j, k, Armor;
	local string Proc, Morph;
	local Inventory Inv;
	
	//Filter up to 6 occurences
	For ( i=0 ; i<6 ; i++ )
	{
		if ( Len(Msg) + Len(Proc) > 420 ) //weed
			break;
		//Find a command char
		j = InStr( Msg, "%");
		if ( (j == -1) || (Len(Msg)-j < 2) )//Make sure this is a two-char command
			break;
		//Split
		Proc = Proc $ Left(Msg,j);
		Morph = Mid(Msg,j,2);
		Msg = Mid(Msg,j+2);

		assert( Len(Morph) == 2 );
		k = Asc( Mid(Morph,1) ); //See what's after it

		switch ( k )
		{
			case 72: //H
				Morph = string(Health) @ "health";
				break;
			case 104: //h
				Morph = string(Health) $ "hp";
				break;
			case 65: //A
			case 97: //a
				Armor = 0;
				ForEach InventoryActors ( class'Inventory', Inv, true)
					if ( Inv.bIsAnArmor )
						Armor += Inv.Charge;
				if ( k == 65 )	Morph = string(Armor) @ "armor";
				else			Morph = string(Armor) $ "a";
				break;
			case 90: //Z
			case 122: //z
				if ( Region.Zone == None )
					Morph = "";
				else if ( PlayerReplicationInfo != None && PlayerReplicationInfo.PlayerLocation != None )
					Morph = PlayerReplicationInfo.PlayerLocation.LocationName;
				else
					Morph = Region.Zone.ZoneName;
				if ( Morph == "" )
					Morph = "Zone ["$Region.ZoneNumber$"]";
				break;
			case 87:
			case 119:
				if ( Weapon == None )	Morph = "[]";
				else					Morph = Weapon.GetHumanName();
			default:
				break;
		}
		Proc = Proc $ Morph;
	}
	return Proc $ Msg;
}

final function TeamSayInternal( string Msg)
{
	local PlayerPawn P;
	
	if ( Level.Game.AllowsBroadcast(self, Len(Msg)) )
		ForEach PawnActors ( class'PlayerPawn', P,,,true)
			if( P.PlayerReplicationInfo.Team == PlayerReplicationInfo.Team )
			{
				if ( (Level.Game != None) && (Level.Game.MessageMutator != None) )
				{
					if ( Level.Game.MessageMutator.MutatorTeamMessage(Self, P, PlayerReplicationInfo, Msg, 'TeamSay', true) )
						P.TeamMessage( PlayerReplicationInfo, Msg, 'TeamSay', true );
				} else
					P.TeamMessage( PlayerReplicationInfo, Msg, 'TeamSay', true );
			}
}

exec function TeamSay( string Msg )
{
	local Pawn P;

	if ( !Level.Game.bTeamGame )
	{
		Say(Msg);
		return;
	}
	if ( Msg ~= "Help" )
	{
		CallForHelp();
		return;
	}		
	TeamSayInternal( TeamSayFilter( Msg) );
}
//==============================================
// CheatFlying spectator goes through teleporter
final function bool IsTouchingInternal( Actor Other)
{
	local vector V;
	V = Other.Location - Location;
	return (HSize(V) < CollisionRadius+Other.CollisionRadius) && (Abs(V.Z) < CollisionHeight+Other.CollisionHeight);
}
final function PlayerTick_CF_SpecTeleInternal()
{
	local Teleporter T, TDest, TBest;
	local vector V;
	local name N;
	local int i;
	local bool bSpecTele;

	if ( (Teleporter(MoveTarget) != None) && !IsTouchingInternal(MoveTarget) )
		MoveTarget = None;
	ForEach CollidingActors (class'Teleporter', T, CollisionRadius+CollisionHeight+30)
	{
		if ( (T != MoveTarget) && IsTouchingInternal(T) && (T.URL != "") )
		{
			if ( (InStr( T.URL, "/" ) >= 0) || (InStr( T.URL, "#" ) >= 0) ) //Do not switch levels
				continue;

			N = class'XC_CoreStatics'.static.StringToName(T.URL); //Optimization, no need for URL check
			if ( N != '' )
				ForEach AllActors( class'Teleporter', TDest, N)
					if ( (TDest != T) && (Rand(++i) == 0) )
						TBest = TDest;

			if ( (TBest != None) && TBest.Accept( self, T) )
				MoveTarget = TBest;
			else
				MoveTarget = T;
			return;
		}
	}
}
event PlayerTick_CF( float DeltaTime )
{
	if ( !bCollideActors && IsA('Spectator') && FRand() < 0.5 && !IsA('bbCHSpectator') ) //Not all frames
		PlayerTick_CF_SpecTeleInternal();

	if ( bUpdatePosition )
		ClientUpdatePosition();

	PlayerMove(DeltaTime);
}


//=============================
// Feign death multigunning fix
function PlayerMove(float DeltaTime); //Will this work?
event PlayerTick_FD( float DeltaTime )
{
	if ( bFire + bAltFire == 0 )
		Weapon = None;
	if ( bUpdatePosition )
		ClientUpdatePosition();
	PlayerMove(DeltaTime);
}

//=========================
// Feign death log spam fix
function AnimEnd_FD()
{
	if ( Role < ROLE_Authority )
		return;
	if ( Health <= 0 )
	{
		GotoState('Dying');
		return;
	}
	GotoState('PlayerWalking');
	if ( PendingWeapon != None ) //Sanity check
	{
		if ( Weapon == None )
		{
			PendingWeapon.SetDefaultDisplayProperties();
			ChangedWeapon();
		}
		else if ( Weapon == PendingWeapon )
			PendingWeapon = None;
	}
}

//=================
// Mutate anti-spam
exec function Mutate(string MutateString)
{
	if( Level.NetMode == NM_Client )
		return;
	if ( bAdmin || PlayerReplicationInfo == None || class'XC_EngineStatics'.static.Allow_Mutate(Self) )
		Level.Game.BaseMutator.Mutate(MutateString, Self);
}


//============================================
// The original GetWeapon hook, improved a bit
final function bool SelectPendingInner( Weapon NewPendingWeapon)
{
	if ( (NewPendingWeapon.AmmoType != none) && (NewPendingWeapon.AmmoType.AmmoAmount <= 0) )
	{
		if ( CanGWSpam() )
			ClientMessage( NewPendingWeapon.ItemName$NewPendingWeapon.MessageNoAmmo );
	}
	else
	{
		PendingWeapon = NewPendingWeapon;
		if ( Weapon != none )
			Weapon.PutDown();
		else
		{
			Weapon = PendingWeapon;
			PendingWeapon = none;
			Weapon.BringUp();
		}
		return true;
	}
}

final function GetWeaponInner( class<Weapon> NewWeaponClass)
{
	local Weapon Weap, StartFrom;
	
	if ( (Weapon != None) && Weapon.IsA(NewWeaponClass.Name) )
		StartFrom = Weapon;

	ForEach InventoryActors ( class'Weapon', Weap, true, StartFrom)
		if ( Weap.IsA( NewWeaponClass.Name) && SelectPendingInner(Weap) )
			return;
		
	if ( StartFrom != None ) //Our weapon is already of said type, cycle
	{
		ForEach InventoryActors ( class'Weapon', Weap, true)
			if ( Weap == Weapon || (Weap.IsA( NewWeaponClass.Name) && SelectPendingInner(Weap)) )
				return;
	}
}

exec function GetWeapon(class<Weapon> NewWeaponClass )
{
	local Inventory Inv;
	if ( (Inventory == None) || (NewWeaponClass == None) )
		return;
	GetWeaponInner( NewWeaponClass);
}

// =====================
// Fix message spam AIDS
exec function PrevItem()
{
	local Inventory Inv, LastItem;

	if ( bShowMenu || Level.Pauser!="" || Inventory == None )
		return;
	if ( SelectedItem == None )
	{
		SelectedItem = Inventory.SelectNext();
		return;
	}
	if ( SelectedItem.Inventory != None )
	{	For( Inv=SelectedItem.Inventory; Inv!=None; Inv=Inv.Inventory )
			if (Inv.bActivatable)
				LastItem=Inv; }

	For( Inv=Inventory; Inv!=SelectedItem && Inv!=None; Inv=Inv.Inventory )
		if (Inv.bActivatable)
			LastItem=Inv;

	if (LastItem!=None)
	{
		SelectedItem = LastItem;
		if ( CanGWSpam() )
			ClientMessage(SelectedItem.ItemName$SelectedItem.M_Selected);
	}
}


//==============
// Navigation AIDS given by client to server
// Prevent lag exploit
exec function ShowPath()
{
	local Actor node;

	if ( !bAdmin )
		return;
	node = FindPathTo(Destination);
	if (node != None)
	{
		log("found path: "$node.Name);
		Spawn(class 'WayBeacon', self, '', node.location);
	}
	else
		log("didn't find path");
}

//==============
// Prevent clients from slowing down servers and filling their logs
exec function ShowInventory()
{
	local Inventory Inv;

	if ( !bAdmin )
		return;
	
	if( Weapon!=None )
		log( "   Weapon: " $ Weapon.Class );
	for( Inv=Inventory; Inv!=None; Inv=Inv.Inventory ) 
		log( "Inv: "$Inv $ " state "$Inv.GetStateName());
	if ( SelectedItem != None )
		log( "Selected Item"@SelectedItem@"Charge"@SelectedItem.Charge );
}

//==============
// More easily find players
exec function ViewPlayer_Fast( string S)
{
	local Pawn P;
	
	S = Caps(S);
	ForEach PawnActors ( class'Pawn', P,,, true)
	{
		if ( P.PlayerReplicationInfo.PlayerName ~= S  )
			break;
		P = None;
	}

	if ( P == None )
		ForEach PawnActors ( class'Pawn', P,,, true)
		{
			if ( InStr( Caps(P.PlayerReplicationInfo.PlayerName), S) >= 0 )
				break;
			P = None;
		}
		
	if ( (P != None) && Level.Game.CanSpectate(self, P) )
	{
		ClientMessage(ViewingFrom@P.PlayerReplicationInfo.PlayerName, 'Event', true);
		if ( P == self)
			ViewTarget = None;
		else
			ViewTarget = P;
	}
	else
		ClientMessage(FailedView);

	bBehindView = ( ViewTarget != None );
	if ( bBehindView )
		ViewTarget.BecomeViewTarget();
}

//==============
// ViewPlayerNum AIDS given by client to server
// Prevent lag exploit and enhance Spectator experience

//Needs 'final' modifier to compile a non-virtual call
//This one does not target PRI-less monsters
final function Actor XC_CyclePlayer()
{
	local Pawn P;
	local PlayerReplicationInfo PRI;
	
	P = Pawn(ViewTarget);
	//Find player using DynamicActors
	if ( P == None || (P.PlayerReplicationInfo == None) )
	{
RESTART_SEARCH:
		ForEach DynamicActors ( class'PlayerReplicationInfo', PRI)
		{
			P = Pawn(PRI.Owner);
			if ( (P != None) && !PRI.bIsSpectator && (P != self) && Level.Game.CanSpectate( self, P) )
				return P;
		}
	}
	else
	{
		ForEach DynamicActors ( class'PlayerReplicationInfo', PRI)
		{
			if ( P == None ) //This means we found our current viewtarget's position
			{
				if ( (Pawn(PRI.Owner) != None) && !PRI.bIsSpectator && (PRI.Owner != self) && Level.Game.CanSpectate( self, Pawn(PRI.Owner)) )
					return PRI.Owner;
			}
			else if ( P.PlayerReplicationInfo == PRI ) //Finding our viewtarget!
				P = None;
		}
		Goto RESTART_SEARCH;
	}
}

exec function ViewPlayerNum_Fast(optional int num)
{
	local Pawn P;

	if ( PlayerReplicationInfo == None || Level.Game == None )
		return;
	if ( !PlayerReplicationInfo.bIsSpectator && !Level.Game.bTeamGame )
		return;
	if ( num >= 0 )
	{
		P = Pawn(ViewTarget);

		//UTPure style ViewPlayerNum, get players using their PlayerID!
		if ( PlayerReplicationInfo.bIsSpectator )
		{
			if ( ((P != None) && (P.PlayerReplicationInfo != None) && (P.PlayerReplicationInfo.PlayerID == num)) || (PlayerReplicationInfo.PlayerID == num) )
			{
				ViewTarget = None;
				bBehindView = False;
			}
			else
			{
				ForEach PawnActors (class'Pawn',P,,,true) //Guaranteed not self
					if ( !P.PlayerReplicationInfo.bIsSpectator && P.PlayerReplicationInfo.PlayerID == num )
					{
						ViewTarget = P;
						bBehindView = true;
						break;
					}
			}
			return;
		}

		//Normal style
		if ( ((P != None) && (P.PlayerReplicationInfo != None) && (P.PlayerReplicationInfo.TeamID == num)) || (PlayerReplicationInfo.TeamID == num) )
		{
			ViewTarget = None;
			bBehindView = false;
		}
		else
		{
			ForEach PawnActors ( class'Pawn',P,,,true)
				if ( (P.PlayerReplicationInfo.Team == PlayerReplicationInfo.Team) && !P.PlayerReplicationInfo.bIsSpectator && (P.PlayerReplicationInfo.TeamID == num) )
				{
					ViewTarget = P;
					bBehindView = true;
					break;
				}
		}
		return;
	}
	if ( Role == ROLE_Authority )
	{
		ViewTarget = XC_CyclePlayer(); //Maximum 2 iterators max
		if ( ViewTarget != None )
			ClientMessage(ViewingFrom@Pawn(ViewTarget).PlayerReplicationInfo.PlayerName, 'Event', true);
		else
			ClientMessage(ViewingFrom@OwnCamera, 'Event', true);
	}
}


//==============
//

//
// Client wants to send us an update, handle it the XCGE way
// 
function ServerMove
(
	float TimeStamp, 
	vector InAccel, 
	vector ClientLoc,
	bool NewbRun,
	bool NewbDuck,
	bool NewbJumpStatus, 
	bool bFired,
	bool bAltFired,
	bool bForceFire,
	bool bForceAltFire,
	eDodgeDir DodgeMove, 
	byte ClientRoll, 
	int View,
	optional byte OldTimeDelta,
	optional int OldAccel
)
{
	local float DeltaTime, clientErr, OldTimeStamp;
	local rotator DeltaRot, Rot;
	local vector Accel, LocDiff;
	local int maxPitch, ViewPitch, ViewYaw;
	local actor OldBase;
	local bool NewbPressedJump, OldbRun, OldbDuck;
	local eDodgeDir OldDodgeMove;

	// If this move is outdated, discard it.
	if ( CurrentTimeStamp >= TimeStamp )
		return;

	// if OldTimeDelta corresponds to a lost packet, process it first
	if (  OldTimeDelta != 0 )
	{
		OldTimeStamp = TimeStamp - float(OldTimeDelta)/500 - 0.001;
		if ( CurrentTimeStamp < OldTimeStamp - 0.001 )
		{
			// split out components of lost move (approx)
			Accel.X = OldAccel >>> 23;
			if ( Accel.X > 127 )
				Accel.X = -1 * (Accel.X - 128);
			Accel.Y = (OldAccel >>> 15) & 255;
			if ( Accel.Y > 127 )
				Accel.Y = -1 * (Accel.Y - 128);
			Accel.Z = (OldAccel >>> 7) & 255;
			if ( Accel.Z > 127 )
				Accel.Z = -1 * (Accel.Z - 128);
			Accel *= 20;
			
			OldbRun = ( (OldAccel & 64) != 0 );
			OldbDuck = ( (OldAccel & 32) != 0 );
			NewbPressedJump = ( (OldAccel & 16) != 0 );
			if ( NewbPressedJump )
				bJumpStatus = NewbJumpStatus;

			switch (OldAccel & 7)
			{
				case 0:
					OldDodgeMove = DODGE_None;
					break;
				case 1:
					OldDodgeMove = DODGE_Left;
					break;
				case 2:
					OldDodgeMove = DODGE_Right;
					break;
				case 3:
					OldDodgeMove = DODGE_Forward;
					break;
				case 4:
					OldDodgeMove = DODGE_Back;
					break;
			}
			//log("Recovered move from "$OldTimeStamp$" acceleration "$Accel$" from "$OldAccel);
			MoveAutonomous(OldTimeStamp - CurrentTimeStamp, OldbRun, OldbDuck, NewbPressedJump, OldDodgeMove, Accel, rot(0,0,0));
			CurrentTimeStamp = OldTimeStamp;
		}
	}		

	// View components
	ViewPitch = View/32768;
	ViewYaw = 2 * (View - 32768 * ViewPitch);
	ViewPitch *= 2;
	// Make acceleration.
	Accel = InAccel/10;

	NewbPressedJump = (bJumpStatus != NewbJumpStatus);
	bJumpStatus = NewbJumpStatus;

	// handle firing and alt-firing
	if ( bFired )
	{
		if ( bForceFire && (Weapon != None) )
			Weapon.ForceFire();
		else if ( bFire == 0 )
			Fire(0);
		bFire = 1;
	}
	else
		bFire = 0;


	if ( bAltFired )
	{
		if ( bForceAltFire && (Weapon != None) )
			Weapon.ForceAltFire();
		else if ( bAltFire == 0 )
			AltFire(0);
		bAltFire = 1;
	}
	else
		bAltFire = 0;

	// Save move parameters.
	DeltaTime = TimeStamp - CurrentTimeStamp;
	if ( ServerTimeStamp > 0 )
	{
		// allow 1% error
		TimeMargin += DeltaTime - 1.01 * (Level.TimeSeconds - ServerTimeStamp);
		if ( TimeMargin > MaxTimeMargin )
		{
			// player is too far ahead
			TimeMargin -= DeltaTime;
			if ( TimeMargin < 0.5 )
				MaxTimeMargin = Default.MaxTimeMargin;
			else
				MaxTimeMargin = 0.5;
			DeltaTime = 0;
		}
		else if ( TimeMargin < -0.5f ) //HIGOR: Patch speed-hack turbocharge exploit
			TimeMargin = -0.5f;
	}

	CurrentTimeStamp = TimeStamp;
	ServerTimeStamp = Level.TimeSeconds;
	Rot.Roll = 256 * ClientRoll;
	Rot.Yaw = ViewYaw;
	if ( (Physics == PHYS_Swimming) || (Physics == PHYS_Flying) )
		maxPitch = 2;
	else
		maxPitch = 1;
	If ( (ViewPitch > maxPitch * RotationRate.Pitch) && (ViewPitch < 65536 - maxPitch * RotationRate.Pitch) )
	{
		If (ViewPitch < 32768) 
			Rot.Pitch = maxPitch * RotationRate.Pitch;
		else
			Rot.Pitch = 65536 - maxPitch * RotationRate.Pitch;
	}
	else
		Rot.Pitch = ViewPitch;
	DeltaRot = (Rotation - Rot);
	ViewRotation.Pitch = ViewPitch;
	ViewRotation.Yaw = ViewYaw;
	ViewRotation.Roll = 0;
	SetRotation(Rot);

	OldBase = Base;

	// Perform actual movement.
	if ( (Level.Pauser == "") && (DeltaTime > 0) )
		MoveAutonomous(DeltaTime, NewbRun, NewbDuck, NewbPressedJump, DodgeMove, Accel, DeltaRot);

	// Accumulate movement error.
	// Higor: game speed fix, mandatory update takes twice as long, netspeed effect capped to 10000
	DeltaTime = (Level.TimeSeconds - LastUpdateTime) / Level.TimeDilation;
	if ( DeltaTime > 1000.0/FMin(Player.CurrentNetSpeed,10000) )
		ClientErr = 10000;
	else if ( DeltaTime > 180.0/FMin(Player.CurrentNetSpeed,10000) )
	{
		LocDiff = Location - ClientLoc;
		ClientErr = LocDiff Dot LocDiff;
	}

	// If client has accumulated a noticeable positional error, correct him.
	if ( ClientErr > 3 )
	{
		if ( Mover(Base) != None )
			ClientLoc = Location - Base.Location;
		else
			ClientLoc = Location;
		//log("Client Error at "$TimeStamp$" is "$ClientErr$" with acceleration "$Accel$" LocDiff "$LocDiff$" Physics "$Physics);
		LastUpdateTime = Level.TimeSeconds;
		ClientAdjustPosition
		(
			TimeStamp, 
			GetStateName(), 
			Physics, 
			ClientLoc.X, 
			ClientLoc.Y, 
			ClientLoc.Z, 
			Velocity.X, 
			Velocity.Y, 
			Velocity.Z,
			Base
		);
	}
}


