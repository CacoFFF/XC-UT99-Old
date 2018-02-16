class XC_Engine_JumpSpot expands JumpSpot
	abstract;

event int SpecialCost(Pawn Seeker)
{
	local Bot B;

	if ( Seeker.PlayerReplicationInfo == None )
		return 100000000;
	B = Bot(Seeker);
	if ( B == None )
		return 100;
	if ( B.bCanTranslocate || (B.JumpZ > 1.5 * B.Default.JumpZ) 
		|| (B.Region.Zone.ZoneGravity.Z >= 0.8 * B.Region.Zone.Default.ZoneGravity.Z) )
		return 300;
	if ( bImpactJump && B.bHasImpactHammer && (B.Health > 85) && (!B.bNovice || (B.Skill > 2.5)) 
		&& (B.DamageScaling < 1.4) )
		return 1100;
	return 100000000;
}
