/*=============================================================================
	FMallocThreadedProxy.h:
	Author: Fernando Velázquez

	Simple proxy that prevents concurrent access to the game's allocator.
=============================================================================*/

#ifndef INC_MALLOC_TH
#define INC_MALLOC_TH

#include "Cacus/Atomics.h"

class FMallocThreadedProxy : public FMalloc
{
	FMalloc* MainMalloc;
	volatile int32 Lock;

#ifndef DISABLE_CPP11
	FMallocThreadedProxy( FMallocThreadedProxy&& Other); //Hide Copy constructor
#endif
public:
	FMallocThreadedProxy( FMalloc* InMalloc=NULL);

	FMalloc* GetMain() const;

	// FMalloc interface.
	void* Malloc( DWORD Count, const TCHAR* Tag );
	void* Realloc( void* Original, DWORD Count, const TCHAR* Tag );
	void Free( void* Original );
	void DumpAllocs();
	void HeapCheck();
	void Init();
	void Exit();
};

//*************************************************
// Thread-safe Malloc proxy implementation
//*************************************************

inline FMallocThreadedProxy::FMallocThreadedProxy( FMalloc* InMalloc )
	:	MainMalloc( InMalloc )
	,	Lock(0)
{}

inline FMalloc* FMallocThreadedProxy::GetMain() const
{
	return MainMalloc;
}

inline void* FMallocThreadedProxy::Malloc( DWORD Count, const TCHAR* Tag)
{
	CSpinLock Lock( &Lock);
	return MainMalloc->Malloc( Count, Tag);
}

inline void* FMallocThreadedProxy::Realloc( void* Original, DWORD Count, const TCHAR* Tag )
{
	CSpinLock Lock( &Lock);
	void* Result = NULL;
	if ( !Count )
		MainMalloc->Free( Original);
	else
		Result = MainMalloc->Realloc( Original, Count, Tag);
	return Result;
}

inline void FMallocThreadedProxy::Free( void* Original )
{
	CSpinLock Lock( &Lock);
	if ( Original )
		MainMalloc->Free( Original);
}

inline void FMallocThreadedProxy::DumpAllocs()
{
	CSpinLock Lock( &Lock);
	MainMalloc->DumpAllocs();
}

inline void FMallocThreadedProxy::HeapCheck()
{
	CSpinLock Lock( &Lock);
	MainMalloc->HeapCheck();
}

inline void FMallocThreadedProxy::Init()
{
	CSpinLock Lock( &Lock);
	if ( MainMalloc )
		MainMalloc->Init();
}
inline void FMallocThreadedProxy::Exit()
{
	CSpinLock Lock( &Lock);
	if ( MainMalloc )
		MainMalloc->Exit();
}

#endif