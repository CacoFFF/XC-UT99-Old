/*=============================================================================
	FOutputDeviceThreadedProxy.h:
	This is a 100% based spinlock, avoid multiple threads in a single CPU
	This code is public domain.

	Revision history:
		* Created by Fernando Velázquez (Higor)
=============================================================================*/

#ifndef XC_FOUT_THREADED
#define XC_FOUT_THREADED

#include "Atomics.h"

class FOutputDeviceThreadedProxy : public FOutputDevice
{
public:
	INT Signature; //Always 1337... (gives ability to recognize this output device within the game)
	FOutputDevice* MainOutputDevice;
	volatile INT Lock;

	// FMalloc interface.
	FOutputDeviceThreadedProxy( FOutputDevice* InOutputDevice=NULL )
	:	Signature( 1337 )
	,	MainOutputDevice( InOutputDevice )
	,	Lock(0)
	{}

	void Serialize( const TCHAR* V, EName Event )
	{
		__SPIN_LOCK( &Lock);
		MainOutputDevice->Serialize( V, Event);
		__SPIN_UNLOCK( &Lock);
	}
};

#endif
