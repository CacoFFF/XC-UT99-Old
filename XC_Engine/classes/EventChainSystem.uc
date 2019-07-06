class EventChainSystem expands FV_Addons
	abstract;


	
static final function StaticInit( XC_Engine_Actor XCGEA)
{
	local EventLink E;

	ForEach XCGEA.DynamicActors( class'EventLink', E)
	{
		E.Update();
		if ( !E.bDeleteMe )
			E.AnalyzedBy( none);
	}
}