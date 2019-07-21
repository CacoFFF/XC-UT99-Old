class EL_Kicker expands EL_GenericToucher;

//Actor can initiate event chain by interacting with owner
function bool CanFireEvent( Actor Other)
{
	local Kicker K;

	K = Kicker(Owner);
	return bRoot && (K != None) && (K.KickedClasses != '') && Other.IsA( K.KickedClasses);
}
