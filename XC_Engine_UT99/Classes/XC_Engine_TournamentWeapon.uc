class XC_Engine_TournamentWeapon expands TournamentWeapon
	abstract;

simulated function ClientPutDown(weapon NextWeapon)
{
	if ( Level.NetMode == NM_Client )
	{
		bCanClientFire = false;
		bMuzzleFlash = 0;
		TweenDown();
		if ( TournamentPlayer(Owner) != None )
			TournamentPlayer(Owner).ClientPending = NextWeapon;
		if ( IsA('TournamentWeapon') )
			GotoState('ClientDown');
	}
}

simulated function AnimEnd()
{
	local TournamentPlayer T;

	T = TournamentPlayer(Owner);
	if ( T != None && T.Weapon != None )
	{
		if ( (T.ClientPending != None) && (T.ClientPending.Owner == Owner) )
		{
			T.Weapon = T.ClientPending;
			if ( T.Weapon.IsA('TournamentWeapon') )
				T.Weapon.GotoState('ClientActive');
			T.ClientPending = None;
			GotoState('');
		}
		else
		{
			Enable('Tick');
			T.NeedActivate();
		}
	}
}

function UT_Invisibility_EndState()
{
	local Inventory S;

	bActive = false;		
	PlaySound(DeActivateSound);

	if ( Pawn(Owner) == none )
		return;
	
	Owner.SetDefaultDisplayProperties();
	Pawn(Owner).Visibility = Pawn(Owner).default.Visibility; //Fix bots not seeing players after item expires
	S = Pawn(Owner).FindInventoryType(class'UT_ShieldBelt');
	if ( (S != None) && (UT_Shieldbelt(S).MyEffect != None) )
		UT_Shieldbelt(S).MyEffect.bHidden = false;
}

//**********************************************
// Minigun AI improvement + log spam fix on bots
// Creature size now a factor in alt-firing and weapon recommendation
function float Minigun2_RateSelf( out int bUseAltMode )
{
	local float dist;
	local float scale;
	local Pawn Enemy;

	scale = 1;
	if ( AmmoType != None && AmmoType.AmmoAmount < 50 )
		scale = (scale * float(AmmoType.AmmoAmount)) * 0.02; //Same as X/50
	if ( scale <= 0 )
		return -2;

	Enemy = Pawn(Owner).Enemy;
	if ( Enemy == None )
		bUseAltMode = 0;
	else
	{
		dist = VSize(Enemy.Location - Owner.Location) * 19 / FMax(Enemy.CollisionRadius,5); //Larger enemy, more ALT
		scale *= FMin(Enemy.CollisionRadius,5) * 0.2; //Smaller enemy, dont recommend minigun
		bUseAltMode = int(dist <= 1700);
		AIRating *= FMin(Pawn(Owner).DamageScaling, 1.5);
		if ( dist > 1200 )
			AIRating += FMin(0.0001 * dist, 0.3); 
	}
	return AIRating * scale;
}

