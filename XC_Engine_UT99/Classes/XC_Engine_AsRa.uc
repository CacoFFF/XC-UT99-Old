class XC_Engine_AsRa expands AssaultRandomizer
	abstract;
	
event int SpecialCost(Pawn Seeker)
{
	if ( !Seeker.bIsPlayer )
		return 0;
	return ToggledCost;
}
