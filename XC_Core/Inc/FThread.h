/*=============================================================================
	API_Thread.h:
	Thread abstractions.
=============================================================================*/

//Move to CPP
#ifdef __UNIX__
	#define ENTRY_DECL(func) void *(*func)(void *)
#elif _WINDOWS
	#define ENTRY_DECL(func) LPTHREAD_START_ROUTINE func
#endif

/////////////////////
// Generic thread template
/////////////////////
struct XC_CORE_API FThread
{
	volatile DWORD	tId;
#if __UNIX__
	pthread_t		Handle;
#elif _WINDOWS
	HANDLE			Handle;
#else
	#error THREADING NOT IMPLEMENTED IN THIS PLATFORM
#endif
	FThread()
	: tId(0), Handle(0)	{}

	UBOOL RunThread( ENTRY_DECL(ThreadEntry), void* Arg=NULL);
	UBOOL ThreadWaitFinish( FLOAT MaxWait);

	//Call after entry point returns (manual kill automatically does this)
	void ThreadEnded();
};



// Priority thread entrypoint.
#if _WINDOWS
	#define THREAD_ENTRY(entryfunc,arg) DWORD STDCALL entryfunc(void* arg)
#else
	#define THREAD_ENTRY(entryfunc,arg) void* entryfunc(void* arg)
#endif

