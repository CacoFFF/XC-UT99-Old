/*=============================================================================
	FMallocThreadedProxy.h: FMalloc interface capable of locking a thread
	This is a 100% based spinlock, avoid multiple threads in a single CPU
	This code is public domain.

	Revision history:
		* Created by Fernando Velázquez (Higor)
=============================================================================*/

#ifndef XC_MALLOC_THREADED
#define XC_MALLOC_THREADED

enum ETemporary    { E_Temporary=0 };

class FMallocThreadedProxy : public FMalloc
{
public:
	INT Signature; //Stuff
	FMalloc* MainMalloc;
	UBOOL bTemporary;
	volatile INT Lock;

	FMallocThreadedProxy( FMalloc* InMalloc=NULL );
	FMallocThreadedProxy( ETemporary); //Best used as static
	
	// FMalloc interface.
	void* Malloc( DWORD Count, const TCHAR* Tag );
	void* Realloc( void* Original, DWORD Count, const TCHAR* Tag );
	void Free( void* Original );
	void DumpAllocs();
	void HeapCheck();
	void Init();
	void Exit();
};

#endif
