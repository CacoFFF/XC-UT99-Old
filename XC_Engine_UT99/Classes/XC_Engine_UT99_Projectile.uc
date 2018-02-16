class XC_Engine_UT99_Projectile expands Projectile;


function BruteProjectile_BlowUp(vector HitLocation)
{
	if ( Instigator != None )
		HurtRadius(damage, 50 + instigator.skill * 45, 'exploded', MomentumTransfer, HitLocation);
	else
		HurtRadius(damage, 50, 'exploded', MomentumTransfer, HitLocation);
	MakeNoise(1.0);
	PlaySound(ImpactSound);
}
