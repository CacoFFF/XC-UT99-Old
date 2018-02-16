///////////////////////////////////////////////////////////
// Generic collision adder

class XC_CollisionMutator expands Mutator;

function AddMutator(Mutator M)
{
	if ( M == none || M == self || M.bDeleteMe )
		return;

	if ( NextMutator == None )
		NextMutator = M;
	else
		NextMutator.AddMutator(M);
}

