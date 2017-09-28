/*=============================================================================
Stuff
=============================================================================*/

#define P_GET_CLASS(var)				P_GET_OBJECT(UClass,var)
#define P_GET_INPUT_REF(var)				P_GET_OBJECT_REF(UInput,var)
#define P_GET_PAWN_REF(var)				P_GET_OBJECT_REF(APawn,var)
#define P_GET_NAVIG(var)				P_GET_OBJECT(ANavigationPoint,var)
#define P_GET_NAVIG_OPTX(var,def)				P_GET_OBJECT_OPTX(ANavigationPoint,var,def)
#define P_GET_NAVIG_REF(var)				P_GET_OBJECT_REF(ANavigationPoint,var)

#ifndef __LINUX_X86__
	#define CORE_API DLL_IMPORT
	#define FERBOTZ_API DLL_EXPORT
	typedef char CHAR;
#else
	#define DO_GUARD 0
	#include <unistd.h>	
#endif



// Unreal engine includes.
#include "Engine.h"

//Forward declarations (for gcc)
class FPrunedComp;
class FNavPoint;

#include "FerBotzClasses.h"


#ifdef __LINUX_X86__
	#undef CPP_PROPERTY
	#define CPP_PROPERTY(name) \
		EC_CppProperty, (BYTE*)&((ThisClass*)1)->name - (BYTE*)1
#endif


/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
