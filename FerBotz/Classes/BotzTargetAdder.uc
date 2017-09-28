//=============================================================================
// BotzTargetAdder.
// Esta es la entidad base de como activar el soporte de Botz en todos los
// modos de juego posibles, a traves de una funcion que evalúa el estado del
// Botz y decide lo mejor para este, en caso de estar ante una versión
// pública de internet; Para hacer función de esto, el creador de el modo
// personalizado que quiera soporte de Botz, deberá seguir las siguientes
// instrucciones:
//	- El formato de nombre de paquete y class debe ser este:
//		( GameInfoClassName )$UBZFV.( GameInfoClassName )$UBZSupport
//		por ejemplo: CTFGameUBZFV.CTFGameUBZSupport
//	- El nuevo class DEBE ser un subclass de esta misma
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================
class BotzTargetAdder expands InfoPoint;

var MasterGasterFer MyMaster;

//Extend this struct and use it for tasking purposes
struct BotzState
{
	var string BotzName; //Unique identifier
	var int BotzHealth;
	var actor BotzGoal;
	var bool bAnnounceAction;
	var byte BotzTeam;
	var name BotzOrders;
};

function Actor OldItemOfInterest( botz Interested);
function float CheckInterest( pawn CheckFor, actor CheckAt);
function name InitialOrders( Botz CheckFor);
function name ModifyState( Botz CheckFor);
function ModifyPathCosts( Botz Seeker); //Called during route-mapping, allows modification of 'Cost' in order to modify route weights
function OneTimeGoal( Botz_OneTimeGoal Other); //To be deprecated
function EnemyKilled( Botz Killer, Pawn Other);



//Called to override SetEnemy
function bool ModifyBehaviour( Botz CheckFor, out pawn Other, bool bOnlyCheck)
{
	// Setting OTHER as none makes the main SetEnemy function return FALSE instead of TRUE
	return false;
}

//Change where the bot is attracted to based on objective (good for Defering to navigation points)
function Actor ModifyAttraction( Botz Seeker, Actor PathTarget, out byte ForceTarget)
{
	return PathTarget;
}



function Actor SuggestAttack( Botz CheckFor, optional bool bOnlyTest)
{
	local bool bJustSpawned;

	//This is set to a low value everytime the bot respawns, used to detect respawns
	if ( CheckFor.RespawnTime < 5 )
	{
		CheckFor.RespawnTime = Level.TimeSeconds;
		bJustSpawned = true;
	}

	//********* Attempt to map the path network - ModifyPathCosts called during MapRoutes
	if ( !CheckFor.LocateStartAnchor() )
		return None;
	CheckFor.MapRoutes( CheckFor.StartAnchor, CheckFor.CollisionRadius, CheckFor.CollisionHeight, 0, 'GlobalModifyCost');

	//********* Validate this objective - can be modified here (kept if True)
	//********* If primary objective isn't valid, attempt to use ALT objective if there is one
	while ( CheckFor.GameTarget != None )
	{
		if ( ValidateObjective( CheckFor) )
			return CheckFor.GameTarget;
		CheckFor.GameTarget = CheckFor.GameTargetAlt;
		CheckFor.GameTargetAlt = None;
		CheckFor.ProximoCamp = None;
	}
		
	//********* Find new objectives
	return SelectObjective( CheckFor, bJustSpawned);
}

//Route should be mapped before calling this
function bool ValidateObjective( Botz CheckFor)
{
	if ( CheckFor.GameTarget == None || CheckFor.bDeleteMe )
		return false;

	if ( Inventory(CheckFor.GameTarget) != None )		return ValidateObjInventory( CheckFor, Inventory(CheckFor.GameTarget) );
	if ( NavigationPoint(CheckFor.GameTarget) != None )	return ValidateObjNavigation( CheckFor, NavigationPoint(CheckFor.GameTarget) );
	if ( Pawn(CheckFor.GameTarget) != None )			return ValidateObjPawn( CheckFor, Pawn(CheckFor.GameTarget) );

	return false; //Don't validate other objectives
}

/* Precaucion: the higher this is the more likely the bot is to take detours to find items
 - 1.0 is normal-ish behaviour
 - 0.0 means the bot will almost ignore all items 
 - 2.0 or above mean the bot will try to reach the objective with armor and more than one weapon
  */
function Actor SelectObjective( Botz CheckFor, bool bJustSpawned)
{
	local Actor Result;

	if ( bJustSpawned )
	{
		CheckFor.Precaucion = 1 - CheckFor.Aggresiveness * FRand();
		Result = FindNearbyWeapon( CheckFor, 1500);
		if ( Result != None )
			return Result;
	}

	//'Or' is a skip operator, if parameter 1 exists, paramater 2 code isn't executed so don't worry about execution speed
	if ( CheckFor.Orders == 'Attack' )
	{
		CheckFor.Precaucion = 0.6 + FRand() * 0.3;
		Result = FindNewItem(CheckFor) Or FindRandomDest(CheckFor);
	}
	else if ( CheckFor.Orders == 'Defend' )
	{
		CheckFor.Precaucion = 1.0 + FRand() - int(CheckFor.Weapon != None && CheckFor.Weapon.AiRating > 0.5);
		if ( (CheckFor.ArmaFavorita != None) && (FRand() < 0.1) && (CheckFor.FindInventoryType(CheckFor.ArmaFavorita) == None) )
			Result = FindNearestItemFamily( CheckFor, CheckFor.ArmaFavorita, 5000);
		Result = Result Or FindAmbushPoint(CheckFor) Or FindNearbyWeapon(CheckFor) Or FindNewItem(CheckFor);
	}
	else
	{
		CheckFor.Precaucion = 1.0 + FRand();
		Result = FindNewItem(CheckFor) Or FindAmbushPoint(CheckFor) Or FindRandomDest(CheckFor); 
	}

	return Result;
}

// ***********************************************************
// *************** USEFUL OBJECTIVE VALIDATORS ***************
// ***********************************************************

final function float TimeSinceTeamMessage( Botz CheckFor)
{
	return Level.TimeSeconds - CheckFor.LastMsgTime;
}

function Actor SelectGuardPointFor( Botz CheckFor, Actor GuardedPoint, optional float MaxDistance)
{
	local NavigationPoint N, Best;
	local Pawn P;
	local float Chance;
	local int i;
	local bool bRequireVisible, bOccupied;
	
	if ( GuardedPoint == None )
		return None;
	
	if ( MaxDistance <= 0 )
		MaxDistance = 1000;
	i = CheckFor.GetDefenderCount( GuardedPoint, 0, CheckFor.PlayerReplicationInfo.Team); //Find visible defenders
	bRequireVisible = (i == 0);
	MaxDistance += 160 * i;
	MaxDistance += 100 * CheckFor.GetDefenderCount( GuardedPoint, MaxDistance + 200, CheckFor.PlayerReplicationInfo.Team); //Find bystanders
		
	bRequireVisible = true;
	ForEach PawnActors( class'Pawn', P, MaxDistance, GuardedPoint.Location, true)
		if ( (P != CheckFor) && (P.PlayerReplicationInfo.Team == CheckFor.PlayerReplicationInfo.Team) && P.FastTrace(GuardedPoint.Location) )
		{
			bRequireVisible = false;
			break;
		}

	ForEach NavigationActors( class'NavigationPoint', N, MaxDistance, GuardedPoint.Location, bRequireVisible)
	{
		bOccupied = false;
		ForEach PawnActors( class'Pawn', P, 60, N.Location, true)
			if ( (P != CheckFor) && (P.PlayerReplicationInfo.Team == CheckFor.PlayerReplicationInfo.Team) )
				bOccupied = true;
		if ( !bOccupied )
		{
			//Try multiple times on good defense points
			i = int( bRequireVisible || N.FastTrace(GuardedPoint.Location) )
				+ int(N.IsA('AmbushPoint'))
				+ int(N.IsA('DefensePoint'))
				+ int(N.bDirectional);
			while ( i-- > 0 )
				if ( (FRand()*(Chance+=1) < 1) )
					Best = N;
		}
	}
	return Best;
}

function bool UpdateCamp( Botz CheckFor, Actor CampPoint, optional Actor GuardedPoint)
{
	if ( CheckFor.CampTime == 0 )
		CheckFor.CampTime = CheckFor.AvgCampTime * RandRange(0.8,1.2);
	else if ( CheckFor.CampTime > 0 )
		CheckFor.CampTime -= (Level.TimeSeconds - CheckFor.LastObjectiveCheck); //Big DeltaTime
	else
		return false;
	//Camp here
	CheckFor.SpecialPause = 1;
	CheckFor.DesiredRotation = CampPoint.Rotation;
	CheckFor.DefenseTarget = GuardedPoint;
	return true;
}

function bool ValidateObjInventory( Botz CheckFor, Inventory Inv)
{
	if ( Inv.MyMarker == None || Inv.MyMarker.VisitedWeight >= 10000000 || Inv.BotDesireability(CheckFor) <= 0)
		return false;
	if ( Inv.IsInState('Pickup') )
		return true;
	if ( Inv.IsInState('Sleeping') && (Inv.LatentFloat < 1 + Inv.MyMarker.VisitedWeight/500) ) //If going to respawn soon, keep going towards it
		return true;
	return false;
}

function bool ValidateObjNavigation( Botz CheckFor, NavigationPoint N)
{
	if ( N.VisitedWeight >= 10000000 )
		return false;
	if ( CheckFor.InRadiusEntity(N) || CheckFor.BFM.ActorsTouchingValid(CheckFor,N) )
	{
		if ( AmbushPoint(N) != None )
			return UpdateCamp( CheckFor, N);
		return false;
	}
	return true;
}

function bool ValidateObjPawn( Botz CheckFor, Pawn P)
{
	local NavigationPoint N;

	if ( P.Health <= 0 )
		return false;
	if ( P.PlayerReplicationInfo != None && P.PlayerReplicationInfo.HasFlag != None ) //Super force, don't care about navigation
	{
		if ( (TimeSinceTeamMessage( CheckFor) > 10) && (VSize(CheckFor.Location-P.Location) < 1000) && CheckFor.CanSee(P) )
			CheckFor.SendTeamMessage(None, 'OTHER', 8, 10);
		return true;
	}
	if ( CheckFor.FastTrace(P.Location) && HSize(CheckFor.Location-P.Location) < 500 )
	{
		if ( (P.PlayerReplicationInfo != None) && (P.PlayerReplicationInfo.Team == CheckFor.PlayerReplicationInfo.Team) )
		{
			if ( TimeSinceTeamMessage( CheckFor) > 30 )
			{
				if ( P.Enemy == None )
					CheckFor.SendTeamMessage( P.PlayerReplicationInfo, 'OTHER', 3, 20);
				else if ( (P.Enemy != None) && CheckFor.SetEnemy(P,true) )
					CheckFor.SendTeamMessage( P.PlayerReplicationInfo, 'OTHER', 10, 10);
			}
		}
		return false;
	}
	ForEach NavigationActors( class'NavigationPoint', N, 4000, P.Location, true)
		if ( N.VisitedWeight < 8000 )
			return true;
	return false;
}

// **********************************************************
// *************** USEFUL OBJECTIVE SELECTORS ***************
// **********************************************************

final function bool IsPickup( Botz CheckFor, Inventory Inv)
{
	if ( Inv.IsInState('Pickup') )
		return true;
	if ( Inv.IsInState('Sleeping') && (Inv.RespawnTime > 10) && (Inv.LatentFloat < FRand()*CheckFor.Skill) ) //Attempt prediction
		return CheckFor.FindInventoryType( Inv.Class) == None;
	return false;
}

function Actor FindNearbyWeapon( Botz CheckFor, optional int MaxWeight)
{
	local InventorySpot IS;
	local Actor Best;
	local float Chance;

	if ( MaxWeight <= 0 )
		MaxWeight = 1500;

	ForEach NavigationActors( class'InventorySpot', IS)
		if ( (IS.VisitedWeight < MaxWeight) && (Weapon(IS.MarkedItem) != None) && IsPickup( CheckFor, IS.MarkedItem) && (IS.MarkedItem.BotDesireability(CheckFor) > 0.5)
			&& (FRand() < 1/(Chance+=1)) )
				Best = IS.MarkedItem;
	return Best;
}

function Actor FindNewItem( Botz CheckFor, optional int MaxWeight)
{
	local InventorySpot IS;
	local Actor Best;
	local float Chance;

	if ( MaxWeight <= 0 )
		MaxWeight = 1000 + Rand(4000);

	ForEach NavigationActors( class'InventorySpot', IS)
		if ( (IS.VisitedWeight < MaxWeight) && (IS.MarkedItem != None) && IsPickup( CheckFor, IS.MarkedItem) && (CheckFor.FindInventoryType(IS.MarkedItem.Class) == None) && (IS.MarkedItem.BotDesireability(CheckFor) > 0.5)
			&& (FRand() < 1/(Chance+=1)) )
				Best = IS.MarkedItem;
	return Best;
}

function Actor FindRandomDest( Botz CheckFor, optional int MaxWeight)
{
	local NavigationPoint N, Best;
	local float Chance;

	if ( MaxWeight <= 0 )
		MaxWeight = 10000;
	
	//Find a random navigation point
	ForEach NavigationActors( class'NavigationPoint', N)
		if ( (N.VisitedWeight < MaxWeight)
			&& (FRand() < 1/(Chance+=1)) )
				Best = N;
	return Best;
}

function Actor FindNearestItemFamily( Botz CheckFor, class<Inventory> BaseItemType, optional int MaxWeight)
{
	local InventorySpot IS;
	local Actor Best;

	if ( MaxWeight <= 0 )
		MaxWeight = 10000000;

	ForEach NavigationActors( class'InventorySpot', IS)
		if ( (IS.VisitedWeight < MaxWeight) && (IS.MarkedItem != None) && ClassIsChildOf(IS.MarkedItem.Class,BaseItemType) && IsPickup( CheckFor, IS.MarkedItem) && (IS.MarkedItem.BotDesireability(CheckFor) > 0.01) )
		{
			Best = IS.MarkedItem;
			MaxWeight = IS.VisitedWeight;
		}
	return Best;
}

function Actor FindNearestItemExact( Botz CheckFor, class<Inventory> ItemType, optional int MaxWeight)
{
	local InventorySpot IS;
	local Actor Best;

	if ( MaxWeight <= 0 )
		MaxWeight = 10000000;

	ForEach NavigationActors( class'InventorySpot', IS)
		if ( (IS.VisitedWeight < MaxWeight) && (IS.MarkedItem != None) && ClassIsChildOf(IS.MarkedItem.Class,ItemType) && IsPickup( CheckFor, IS.MarkedItem) && (IS.MarkedItem.BotDesireability(CheckFor) > 0.01) )
		{
			Best = IS.MarkedItem;
			MaxWeight = IS.VisitedWeight;
		}
	return Best;
}

function Pawn SelectReachableTeamPlayer( Botz CheckFor, optional int MaxWeight)
{
	local NavigationPoint N;
	local Pawn P, Best;
	local float Chance;
	
	if ( MaxWeight <= 0 )
		MaxWeight = 10000000;

	ForEach PawnActors( class'Pawn', P,,, true)
		if ( (P.PlayerReplicationInfo.Team == CheckFor.PlayerReplicationInfo.Team) && (P != CheckFor) )
		{
			if ( (NavigationPoint(P.MoveTarget) != None) && (VSize(P.Location - P.MoveTarget.Location) < 1500) )
				N = NavigationPoint(P.MoveTarget);
			else
			{
				ForEach NavigationActors( class'NavigationPoint', N, 700, P.Location, true)
					break;
			}
			
			if ( (N != None) && (N.VisitedWeight < MaxWeight) && (FRand() < 1/(Chance+=1)) )
				Best = P;
		}

	if ( (Best != None) && (Best.Enemy != None) && (TimeSinceTeamMessage( CheckFor) > 30) )
		CheckFor.SendTeamMessage( Best.PlayerReplicationInfo, 'OTHER', 10, 10);
		
	return Best;
}

function Actor FindAmbushPoint( Botz CheckFor, optional int MaxWeight)
{
	local AmbushPoint AP, Best;
	local float Chance;
	local Weapon W;
	local class<Ammo> NeedAmmo;
	local bool bHasRifle;

	if ( MaxWeight == 0 )
		MaxWeight = 5000 * (0.5 + CheckFor.CampChance);
		
	if ( FRand() > CheckFor.CampChance + 0.05 )
		return None;
		
	ForEach InventoryActors( class'Weapon', W, true, CheckFor) //Optionally try to assess sniping capability
		if ( (InStr( Caps(W.Name), "RIFLE") != -1) && (W.AmmoType != None) )
		{
			bHasRifle = true;
			if ( W.AmmoType.AmmoAmount <= W.PickupAmmoCount )
				NeedAmmo = W.AmmoName;
			else
			{
				NeedAmmo = None;
				break;
			}
		}

	ForEach NavigationActors( class'AmbushPoint', AP)
		if ( (AP.VisitedWeight < MaxWeight) && (!AP.bSniping || bHasRifle) )
		{
			if ( FRand() < 1/(Chance+=1) )
				Best = AP;
		}
	
	if ( Best != None )
		CheckFor.CampTime = 0;

	if ( (Best != None) && Best.bSniping && NeedAmmo != None ) //Find ammo needed instead, chain to AmbushPoint
	{
		CheckFor.GameTarget = FindNearestItemFamily( CheckFor, NeedAmmo, Best.VisitedWeight);
		if ( CheckFor.GameTarget != None )
		{
			CheckFor.GameTargetAlt = Best;
			return CheckFor.GameTarget;
		}
		Best = None;
	}
		
	return Best;
}


defaultproperties
{
}
