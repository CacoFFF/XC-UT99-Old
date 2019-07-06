class EL_Kicker expands EL_GenericPropagator;

function Update()
{
	// Is this propagator still relevant?
	if ( Owner == None )
	{
		Destroy();
		return;
	}
		
	bRoot = Owner.bCollideActors;
	bActive = Owner.bCollideActors;
	bInProgress = false;
}

//Actor can initiate event chain by interacting with owner
function bool CanFireEvent( Actor Other)
{
	local Kicker K;

	K = Kicker(Owner);
	return bRoot && (K != None) && (K.KickedClasses != '') && Other.IsA( K.KickedClasses);
}
