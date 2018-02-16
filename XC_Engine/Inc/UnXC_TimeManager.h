/*=============================================================================
	Time manager to fix speed issues
=============================================================================*/

#ifndef _INC_XC_TIME
#define _INC_XC_TIME

#include "XC_CoreObj.h"

class FXC_TimeManager : public FGenericSystem
{
	public:

	INT SystemDigest[10];
	FLOAT TimeDigest[10];

	INT LastSec;
	INT LastMSec;
	INT MSecAccumulator;
	INT MSecInterval;
	INT IgnoreTimers; //Set at post map change, ignores X timers
	FLOAT Factor;
	FLOAT DeltaAcc;

	FXC_TimeManager();

	//FExec interface
	UBOOL Exec( const TCHAR* Cmd, FOutputDevice& Ar );

	//FGenericSystem interface
	INT Tick( FLOAT DeltaSeconds);
	UBOOL IsTyped( const TCHAR* Type);
};

#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
