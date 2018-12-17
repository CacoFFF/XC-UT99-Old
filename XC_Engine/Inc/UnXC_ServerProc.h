/*=============================================================================
	Additional processing for a net server
=============================================================================*/

#ifndef _INC_XC_SERVERPROC
#define _INC_XC_SERVERPROC

class FXC_ServerProc : public FGenericSystem
{
public:
	UXC_GameEngine* Engine;

	FXC_ServerProc();

	//FGenericSystem interface
	INT Tick( FLOAT DeltaSeconds);
	UBOOL IsTyped( const TCHAR* Type);
};

#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/