//=============================================================================
// UT99AddonsPack
//=============================================================================
class UT99AddonsPack expands EventChainPack;

// Spawn event chain handlers here
function SpawnHandlers()
{
	Spawn( class'BlockedPathHandler');
}
