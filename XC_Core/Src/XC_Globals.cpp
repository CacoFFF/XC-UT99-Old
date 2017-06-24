/*=============================================================================
	XC_Globals.cpp: 
	Implementation of some globals
=============================================================================*/

#include "XC_Core.h"
#include "XC_CoreGlobals.h"
#include "Atomics.h"

XC_CORE_API FMemStack GXCMem;

//*************************************************
// Pathing in both platforms
//*************************************************
XC_CORE_API void FixFilename( const TCHAR* Filename )
{
	TCHAR* Cur;
	for( Cur = (TCHAR*)Filename; *Cur != '\0'; Cur++ )
#ifdef __LINUX_X86__
		if( *Cur == '\\' )
			*Cur = '/';
#else
		if( *Cur == '/' )
			*Cur = '\\';
#endif
}


//*************************************************
// Name case fixing
// Makes sure that a name has proper casing
// Helps preventing DLL bind failures
//*************************************************
XC_CORE_API UBOOL FixNameCase( const TCHAR* NameToFix)
{
	FName AName( NameToFix, FNAME_Find);
	if ( AName != NAME_None )
	{
		TCHAR* Ch = (TCHAR*) *AName;
		for ( INT i=0 ; i<63 && Ch[i] ; i++ )
			Ch[i] = NameToFix[i];
	}
	return AName != NAME_None;
}


//*************************************************
// Globals initialization
// DeInit must be called always after init
// This helps running the globals in commandlets
// and other objects that aren't controlled by a 
// main engine like XC_Engine
//*************************************************

XC_CORE_API void InitXCGlobals()
{
	guard( XC_Core::InitXCGlobals);
	
	guard( InitMem )
	GXCMem.Init( 65536 );
	unguard;

	unguard;
}

XC_CORE_API void DeInitXCGlobals()
{
	guard( XC_Core::DeInitXCGlobals);
	
	guard( DeInitMem )
	GXCMem.Exit();
	unguard;

	unguard;
}


//*************************************************
// High resolution timers stuff
//*************************************************
XC_CORE_API DOUBLE GXStartTime = 0;
XC_CORE_API DOUBLE GXSecondsPerCycle = 0;

XC_CORE_API void XC_InitTiming(void)
{
#ifdef __LINUX_X86__
	GXSecondsPerCycle = 1.0 / 1000000.0;
#elif _MSC_VER
	LARGE_INTEGER Frequency;
	check( QueryPerformanceFrequency(&Frequency) );
	GXSecondsPerCycle = 1.0 / Frequency.QuadPart;
#endif
	GXStartTime = appSecondsXC();
	debugf( TEXT("XC_InitTiming called: %f"), 1.0 / GXSecondsPerCycle);
}



//*************************************************
// Script stuff
// Finds a (non-state) function in a struct
// Finds a variable in a struct, increments *Found
//*************************************************
XC_CORE_API UFunction* FindBaseFunction( UStruct* InStruct, const TCHAR* FuncName)
{
	FName NAME_FuncName = FName( FuncName, FNAME_Find);
	if ( NAME_FuncName != NAME_None )
	{
		for( TFieldIterator<UFunction> Func( InStruct ); Func; ++Func )
			if( Func->GetFName() == NAME_FuncName )
				return (UFunction*) *Func;
	}
	return NULL;	
}

XC_CORE_API UProperty* FindScriptVariable( UStruct* InStruct, const TCHAR* PropName, INT* Found)
{
	FName NAME_PropName = FName( PropName, FNAME_Find);
	if ( NAME_PropName != NAME_None )
	{
		for( TFieldIterator<UProperty> Prop( InStruct ); Prop; ++Prop )
			if( Prop->GetFName() == NAME_PropName )
			{
				if ( Found )
					(*Found)++;
				return (UProperty*) *Prop;
			}
	}
	return NULL;	
}


//*************************************************
// String table sorting
//*************************************************
//Caching OList generates 3 more instructions at start
//But also removes two instructions on the appStricmp call

//Dynamic array
XC_CORE_API void SortStringsA( TArray<FString>* List)
{
	SortStringsSA( (FString*) List->GetData(), List->Num() );
}

//Static array, although not fully optimized for speed
XC_CORE_API void SortStringsSA( FString* List, INT ArrayMax)
{
	INT iTop=1;
	for ( INT i=1 ; i<ArrayMax ; i=++iTop )
/*	{
		//Optimized for long sorts, test later
		while ( appStricmp( *List[iTop], *List[i-1]) < 0 )
			if ( --i == 0 )
				break;
		if ( i != iTop )
		{
			INT* Ptr = (INT*) &List[iTop];
			INT Buffer[3] = { Ptr[0], Ptr[1], Ptr[2] };
			appMemmove( List + i + 1, List + i, (iTop-i)*3 );
			Ptr = (INT*) &List[i];
			Ptr[0] = Buffer[0];
			Ptr[1] = Buffer[1];
			Ptr[2] = Buffer[2];
		}
	}*/
	//Optimized for short sorts
		while ( appStricmp( *List[i], *List[i-1]) < 0 )
		{
			//Atomically swap data (no FArray reallocs)
			//Compiler does a nice job here
			INT* Ptr = (INT*) &List[i];
			INT iStore = *Ptr;
			*Ptr = *(Ptr-3);
			*(Ptr-3) = iStore;
			iStore = *(Ptr+1);
			*(Ptr+1) = *(Ptr-2);
			*(Ptr-2) = iStore;
			iStore = *(Ptr+2);
			*(Ptr+2) = *(Ptr-1);
			*(Ptr-1) = iStore;
			//Bottom index, forced leave
			if ( i == 1 )
				break;
			i--;
		}
}


//*************************************************
// Multi-threaded log
// Worker thread stores messages in memory
// Main thread flushes messages into log
//*************************************************

#define THREADED_LOG_SPIN_MAX 500
struct FThreadSafeLogEntry
{
	volatile FThreadSafeLogEntry* Next;
	EName NameIndex;
	TCHAR RawLog[800];

	FThreadSafeLogEntry( EName InName, const TCHAR* InStrLog);
	~FThreadSafeLogEntry() {};
};

static volatile FThreadSafeLogEntry* ThreadedLogs = NULL;
static volatile FThreadSafeLogEntry* ThreadedLogsLast = NULL;
static volatile UBOOL bHandlingEntries = 0; //This is our lock

XC_CORE_API void ThreadedLog( EName InName, const TCHAR* InStrLog)
{
	if ( !InStrLog[0] )
		return;
	new FThreadSafeLogEntry( InName, InStrLog);
}

XC_CORE_API void ThreadedLogFlush()
{
	guard( ThreadedLogFlush );
	INT SpinCount = THREADED_LOG_SPIN_MAX * 2;

	UBOOL bLockAcquired = 0;
	while ( !bLockAcquired )
	{
		if ( FPlatformAtomics::InterlockedCompareExchange( &bHandlingEntries, 1, 0) == 0 )
			bLockAcquired = 1; 		//Nobody's handling entries, let's flush
		else
		{
			if ( SpinCount % 20 == 1 )	appSleep( 0.f ); //Critical
			if ( SpinCount-- <= 0 ) //Don't flush
			{
				FPlatformAtomics::InterlockedExchange( &bHandlingEntries, 0); //Dangerous
				return;
			}
		}
	}

	FThreadSafeLogEntry* Link = (FThreadSafeLogEntry*) FPlatformAtomics::InterlockedCompareExchange( (volatile INT*)&ThreadedLogs, 0, 0);
	while ( Link )
	{
		debugf( Link->NameIndex, (const TCHAR*) Link->RawLog);	
		FThreadSafeLogEntry* Temp = Link;
		Link = (FThreadSafeLogEntry*) Link->Next;
		delete Temp;
	}

	FPlatformAtomics::InterlockedExchange( &bHandlingEntries, 0); //Release the lock
	FPlatformAtomics::InterlockedExchange( (volatile INT*)&ThreadedLogs, 0);
	FPlatformAtomics::InterlockedExchange( (volatile INT*)&ThreadedLogsLast, 0);
	unguard;
}

FThreadSafeLogEntry::FThreadSafeLogEntry( EName InName, const TCHAR* InStrLog)
	: Next(NULL) , NameIndex(InName)
{
	appStrncpy( RawLog, InStrLog, 799 );

	//Attach to global threaded log
	volatile INT SpinCount = THREADED_LOG_SPIN_MAX;
	while ( true )
	{
		//Nobody's handling entries, insert ourselves in the chain
		if ( FPlatformAtomics::InterlockedCompareExchange( &bHandlingEntries, 1, 0) == 0 )
		{
			// If we're not first in line, add to last in line
			if ( FPlatformAtomics::InterlockedCompareExchange( (volatile INT*) &ThreadedLogs, (INT)this, 0) != 0 )
				FPlatformAtomics::InterlockedExchangePtr( (volatile void**) &(ThreadedLogsLast->Next), this);
			FPlatformAtomics::InterlockedExchangePtr( (volatile void**) &ThreadedLogsLast, this);
			FPlatformAtomics::InterlockedExchange( &bHandlingEntries, 0); //Release the lock
			return;
		}
		if ( SpinCount == 1 )
			appSleep( 0.f ); //Critical, last resort
		if ( SpinCount-- <= 0 )
		{
			delete this;
			return;
		}
	}

}