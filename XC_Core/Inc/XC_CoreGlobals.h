/*=============================================================================
	XC_CoreGlobals.h: Public globals for XC_Core and extensions
=============================================================================*/

#ifndef _INC_XC_COREGLOBALS
#define _INC_XC_COREGLOBALS


XC_CORE_API extern FMemStack		GXCMem; //For XC_Engine/Commandlet usage only

XC_CORE_API void XCCNatives( UBOOL bEnable); //Enables the commented out opcodes in XC_CoreStatics, careful when using this online

XC_CORE_API void InitXCGlobals();
XC_CORE_API void DeInitXCGlobals();

XC_CORE_API void FixFilename( const TCHAR* Filename ); //Fixes platform specific paths
XC_CORE_API UBOOL FixNameCase( const TCHAR* NameToFix); //Only if name is found

XC_CORE_API UFunction* FindBaseFunction( UStruct* InStruct, const TCHAR* FuncName);
XC_CORE_API UProperty* FindScriptVariable( UStruct* InStruct, const TCHAR* PropName, INT* Found);

XC_CORE_API void SortStringsA( TArray<FString>* List);
XC_CORE_API void SortStringsSA( FString* List, INT ArrayMax);

XC_CORE_API void ThreadedLog( EName InName, const TCHAR* InStrLog); //Use this from a worker thread
XC_CORE_API void ThreadedLogFlush(); //Use this from main thread to print other threads' logs



enum EBrushToMeshFlags
{
	BM_MergeAll			= 0x00000001,	// Merge all vertices
	BM_MergeNone		= 0x00000002,	// Do not merge vertices
	BM_Flip			 	= 0x00000004,	// Reverse vertex order (turns front to back)
	BM_TileTextures		= 0x00000008,	// Brush faces are subdivided into texture-sized squares
};

XC_CORE_API void BrushToMesh( class ABrush* Brush, class UMesh* ApplyTo, DWORD Flags); //Mesh must be empty
/*-----------------------------------------------------------------------------
	Hi-res timers
-----------------------------------------------------------------------------*/

XC_CORE_API extern DOUBLE GXSecondsPerCycle;
XC_CORE_API extern DOUBLE GXStartTime;

XC_CORE_API extern void XC_InitTiming(void);

#ifdef __LINUX_X86__
	#include <sys/time.h>
	inline DOUBLE appSecondsXC()
	{
		struct timeval time;
		gettimeofday(&time, NULL);
		return (DOUBLE)time.tv_usec * 0.000001 + (DOUBLE)time.tv_sec;
	}
	inline DWORD appCyclesXC()
	{
		struct timeval time;
		gettimeofday(&time, NULL);
		return time.tv_usec + time.tv_sec * 1000000;
	}
	inline SQWORD appCyclesSqXC()
	{
		struct timeval time;
		gettimeofday(&time, NULL);
		return SQWORD(time.tv_usec) + SQWORD(time.tv_sec) * 1000000;
	}
#elif _MSC_VER
	inline DOUBLE appSecondsXC()
	{
		LARGE_INTEGER Cycles;
		QueryPerformanceCounter(&Cycles);
		return (DOUBLE)Cycles.QuadPart * GXSecondsPerCycle + 16777216.0;
	}
	inline DWORD appCyclesXC()
	{
		LARGE_INTEGER Cycles;
		QueryPerformanceCounter(&Cycles);
		return Cycles.LowPart;
	}
	inline SQWORD appCyclesSqXC()
	{
		LARGE_INTEGER Cycles;
		QueryPerformanceCounter(&Cycles);
		return Cycles.QuadPart;
	}
#else
	#define appSecondsXC appSeconds
	#define appCyclesXC appCycles
	#define appCyclesSqXC appCycles
#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/

#endif
