//=============================================================================
// XC_UPakPredator
// Restores missing UPak native AI to Predator
//=============================================================================
class XC_UPakPredator expands XC_Engine_Actor
	transient;

const XCP = class'XC_UPakPredator';
const PNI_XC = class'PathNodeIterator_XCGE';
const PNI_Old = class'PathNodeIterator';

native(15) static final operator(34) object ForceSet ( out object A, object B );

native(3538) final function NavigationPoint MapRoutes_PNI( Pawn Seeker, optional NavigationPoint StartAnchor, optional name RouteMapperEvent);
native(3539) final function NavigationPoint BuildRouteCache_PNI( NavigationPoint EndPoint, out NavigationPoint NodeList[64]);

//Called from parent XCGE actor
event XC_Init()
{
	//Route mapper not implemented in earlier versions
	if ( class'XC_CoreStatics'.default.XC_Core_Version >= 10 )
	{
		ReplaceFunction( PNI_Old, PNI_XC, 'BuildPath'  , 'BuildPath_XC');
		ReplaceFunction( PNI_Old, PNI_XC, 'GetFirst'   , 'GetFirst_XC');
		ReplaceFunction( PNI_Old, PNI_XC, 'GetLast'    , 'GetLast_XC');
		ReplaceFunction( PNI_Old, PNI_XC, 'GetPrevious', 'GetPrevious_XC');
		ReplaceFunction( PNI_Old, PNI_XC, 'GetNext'    , 'GetNext_XC');
		ReplaceFunction( PNI_Old, PNI_XC, 'GetCurrent' , 'GetCurrent_XC');
	}
}


//
// Called by MapRoutes before the mapping process.
// Used to mark the predator's home as EndPoint
//
event SetEndPoint( Pawn Seeker)
{
	if ( (Predator(Seeker) != None) && (Predator(Seeker).Home != None) )
		Predator(Seeker).Home.bEndPoint = true;
}


defaultproperties
{
     bHidden=True
	 RemoteRole=ROLE_None
}








