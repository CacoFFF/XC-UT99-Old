/*=============================================================================
	FMallocThreadedProxy.h: FMalloc interface capable of locking a thread
	This is a 100% based spinlock, avoid multiple threads in a single CPU
	This code is public domain.

	Revision history:
		* Created by Fernando Velázquez (Higor)
=============================================================================*/

#ifndef XC_MALLOC_THREADED
#define XC_MALLOC_THREADED

#include "Atomics.h"

class FMallocThreadedProxy : public FMalloc
{
public:
	INT Signature; //Always 1337... (gives ability to recognize this malloc within the game)
	FMalloc* MainMalloc;
	volatile INT Lock;

	// FMalloc interface.
	FMallocThreadedProxy( FMalloc* InMalloc=NULL )
	:	Signature( 1337 )
	,	MainMalloc( InMalloc )
	,	Lock(0)
	{}

	void* Malloc( DWORD Count, const TCHAR* Tag)
	{
		__SPIN_LOCK( &Lock);
		void* Result = MainMalloc->Malloc( Count, Tag);
		__SPIN_UNLOCK( &Lock);
		return Result;
	}

	void* Realloc( void* Original, DWORD Count, const TCHAR* Tag )
	{
		__SPIN_LOCK( &Lock);
		void* Result = NULL;
		if ( !Count )
			MainMalloc->Free( Original);
		else
			Result = MainMalloc->Realloc( Original, Count, Tag);
		__SPIN_UNLOCK( &Lock);
		return Result;
	}

	virtual void Free( void* Original )
	{
		__SPIN_LOCK( &Lock);
		MainMalloc->Free( Original);
		__SPIN_UNLOCK( &Lock);
	}

	virtual void DumpAllocs()
	{
		__SPIN_LOCK( &Lock);
		MainMalloc->DumpAllocs();
		__SPIN_UNLOCK( &Lock);
	}

	virtual void HeapCheck()
	{
		__SPIN_LOCK( &Lock);
		MainMalloc->HeapCheck();
		__SPIN_UNLOCK( &Lock);
	}

	void Init()
	{
		MainMalloc->Init();
	}
	void Exit()
	{
		MainMalloc->Exit();
	}

};

#endif
