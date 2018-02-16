class XC_Engine_Weapon expands Weapon
	abstract;

function ForceFire()
{
	Fire(0);
}

function ForceAltFire()
{
	AltFire(0);
}

//Fix message spam
function Weapon WeaponChange( byte F )
{	
	local Weapon newWeapon;
	 
	if ( InventoryGroup == F )
	{
		if ( (AmmoType != None) && (AmmoType.AmmoAmount <= 0) )
		{
			if ( Inventory != None ) //newWeapon always NULL before this
				newWeapon = Inventory.WeaponChange(F);
			if ( newWeapon == None )
			{
				if ( class'XC_Engine_PlayerPawn'.default.GW_TimeSeconds != Level.TimeSeconds ) //Antispam, fixes bandwidth exploit
				{
					class'XC_Engine_PlayerPawn'.default.GW_TimeSeconds = Level.TimeSeconds;
					class'XC_Engine_PlayerPawn'.default.GW_Counter = 0;
				}
				if ( class'XC_Engine_PlayerPawn'.default.GW_Counter++ < 3 )
					Pawn(Owner).ClientMessage( ItemName$MessageNoAmmo );		
			}
			return newWeapon;
		}		
		return self;
	}
	if ( Inventory != None )
		return Inventory.WeaponChange(F);
	//Implicity NULL return
}

// set which hand is holding weapon
// Fix a shoot/draw offset exploit
function setHand(float Hand)
{
	if ( Hand == 2 )
	{
		PlayerViewOffset.Y = 0;
		FireOffset.Y = 0;
		bHideWeapon = true;
		return;
	}
	else
		bHideWeapon = false;

	Hand = fClamp( Hand, -1.2, 1.2);
	if ( Hand == 0 )
	{
		PlayerViewOffset.X = Default.PlayerViewOffset.X * 0.88;
		PlayerViewOffset.Y = -0.2 * Default.PlayerViewOffset.Y;
		PlayerViewOffset.Z = Default.PlayerViewOffset.Z * 1.12;
	}
	else
	{
		PlayerViewOffset.X = Default.PlayerViewOffset.X;
		PlayerViewOffset.Y = Default.PlayerViewOffset.Y * Hand;
		PlayerViewOffset.Z = Default.PlayerViewOffset.Z;
	}
	PlayerViewOffset *= 100; //scale since network passes vector components as ints
	FireOffset.Y = Default.FireOffset.Y * Hand;
}


function Inventory Weapon_SpawnCopy( pawn Other )
{
	local Weapon Copy;

	if( Level.Game.ShouldRespawn(self) )
	{
		Copy = spawn(Class,Other,,,rot(0,0,0));
		Copy.Tag           = Tag;
		Copy.Event         = Event;
		Copy.PickupAmmoCount = PickupAmmoCount;
		if ( AmmoName != None )
			Copy.AmmoName = AmmoName;
		if ( !bWeaponStay )
			GotoState('Sleeping');
	}
	else
		Copy = self;

	Copy.RespawnTime = 0.0;
	Copy.bHeldItem = true;
	Copy.bTossedOut = false;
	Copy.GiveTo( Other );
	Copy.Instigator = Other;
	Copy.GiveAmmo(Other);
	Copy.SetSwitchPriority(Other);
	if ( !Other.bNeverSwitchOnPickup )
		Copy.WeaponSet(Other);
	Copy.AmbientGlow = 0;
	return Copy;
}

function CheckVisibility()
{
	local Pawn PawnOwner;

	PawnOwner = Pawn(Owner);
	if (PawnOwner != None && PawnOwner.Health > 0)
	{
		if( PawnOwner.bHidden && (PawnOwner.Visibility < PawnOwner.Default.Visibility) )
		{
			PawnOwner.bHidden = false;
			PawnOwner.Visibility = PawnOwner.Default.Visibility;
		}
	}
}
