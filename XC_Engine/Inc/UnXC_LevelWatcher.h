/*=============================================================================
	Prevents a level from creating too many actor names
=============================================================================*/

#ifndef _INC_XC_LEVELWATCHER
#define _INC_XC_LEVELWATCHER

#include "XC_CoreObj.h"
#include "XC_Networking.h"

class FXC_LevelWatcher : public FGenericSystem
{
	public:

	UXC_GameEngine* Engine;
	ULevel* Level;
	INT OldACUnique;
	INT CurActorNameIdx;
	DWORD TickCount;
	
	FXC_LevelWatcher();

	//FGenericSystem interface
	UBOOL Init();
	INT Tick( FLOAT DeltaSeconds);
	UBOOL IsTyped( const TCHAR* Type);
};

#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
