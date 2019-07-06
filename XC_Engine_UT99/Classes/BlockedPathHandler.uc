//=============================================================================
// BlockedPathHandler
//
// This handler will create attempt to create attractors towards actors that
// may unlock said blocked paths.
//=============================================================================
class BlockedPathHandler expands EventChainHandler;


event InitializeHandler()
{
	local BlockedPath P;
		
	ForEach NavigationActors( class'BlockedPath', P)
		AddEvent( Spawn(class'EL_BlockedPath', P, P.Tag, P.Location));
}
