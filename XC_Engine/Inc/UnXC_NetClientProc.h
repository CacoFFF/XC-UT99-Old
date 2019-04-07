/*=============================================================================
	UnXC_NetClientProc.h
	Author: Fernando Velázquez

	Additional processing for a net client
=============================================================================*/

#ifndef _INC_XC_NETCLIENTPROC
#define _INC_XC_NETCLIENTPROC

class FXC_NetClientProc : public FGenericSystem
{
public:
	UXC_GameEngine* Engine;
	ULevel* Level;
	INT XCGE_Server_Ver;
	INT TickRate;
	FTime LastTickRateTime;

	URenderDevice* RenDev;
	INT* RenDevTickRate;

	FXC_NetClientProc();

	// FGenericSystem interface
	INT Tick( FLOAT DeltaSeconds);
	UBOOL IsTyped( const TCHAR* Type);

	// FXC_NetClientProc
	void ChangedLevel();
};

#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/