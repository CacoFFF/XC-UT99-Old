/*=============================================================================
	Ticker.cpp
	Author: Fernando Velázquez

	Advanced game tick controller.

	This game tick controller has been designed to take advantage of the
	system's timer resolution while minimizing resource usage.

	This controller knows when the next system timer will hit and will use one
	or more of the necessary sleeping methods to reach the next timer.
=============================================================================*/

#include "XC_Core.h"
#include "CTickerEngine.h"

#include "Cacus/AppTime.h"

#ifdef _WINDOWS
	#pragma comment( lib, "../lib/ntdll.lib")
	extern "C"
	{
		NTSYSAPI ULONG NTAPI NtGetTickCount();
		NTSYSAPI NTSTATUS NTAPI NtQueryTimerResolution( PULONG MinimumResolution, PULONG MaximumResolution, PULONG ActualResolution);
		NTSYSAPI NTSTATUS NTAPI NtSetTimerResolution( ULONG DesiredResolution, BOOLEAN SetResolution, PULONG CurrentResolution);
	};
#endif


#define MSEC(n) ((n) / 1000.0)

#ifdef _WINDOWS
	#define MIN_GRANULARITY MSEC(1.0)
#elif __LINUX_X86__
	#define MIN_GRANULARITY MSEC(1.0) //FIX
#endif





//============== Sleep implementation, no zero case
//
void CTickerEngine::NativeSleep( double Time)
{
#ifdef _WINDOWS
	int32 SleepTime = appFloor( (float)Time * 1000.f);
	if ( SleepTime <= 0 )
		SleepTime = 1;
	Sleep( SleepTime);
#elif __GNUC__
	useconds_t SleepTime = appFloor( Time * 1000000.0);
	if ( SleepTime <= 0 )
		SleepTime = 1;
	usleep( SleepTime);
#endif
	LastSleepExitTime = FPlatformTime::Seconds();
//	debugf( TEXT("NATIVESLEEP %i"), SleepTime);
}

//============== Yield implementation, zero case of sleep
//
void CTickerEngine::NativeYield()
{
#ifdef _WINDOWS
	Sleep( 0);
#elif __GNUC__
	usleep( 0);
#endif
}

//============== Fix native timer and function if needed
//
void CTickerEngine::FixState( double& EndTime, double CurrentTime)
{
	if ( CurrentTime < EndTime - 20000 ) //Looks reasonable
	{
		EndTime = CurrentTime;
		ResetState();
	}
}


//============== Resets sleeper state
//
void CTickerEngine::ResetState()
{
	LastSleepExitTime = 0;
}



// Performance
static double GenericTimerPrecision()
{
	// Current point, skip until we get a fresh new start point
	uint32 Cycles = FPlatformTime::Cycles();
	uint32 NewCycles;
	do { NewCycles = FPlatformTime::Cycles(); } while ( NewCycles == Cycles);

	//Now go past start point and compare
	Cycles = NewCycles;
	do { NewCycles = FPlatformTime::Cycles(); } while ( NewCycles == Cycles);
	return FPlatformTime::ToSeconds( NewCycles - Cycles);
}

void CTickerEngine::UpdateTimerResolution()
{
	TimeStampResolution = GenericTimerPrecision();

#ifdef _WINDOWS
	uint32 Min, Max, Cur;
	Cur = 0;
	NtQueryTimerResolution( &Min, &Max, &Cur);
	SleepResolution = (double)Cur / 10000000.0;
#elif __LINUX_X86__
	// See https://cyberglory.wordpress.com/2011/08/21/jiffies-in-linux-kernel/
#endif

	if ( SleepResolution <= 0.0 )
	{
		NativeSleep(MIN_GRANULARITY);
		uint64 Cycles = FPlatformTime::Cycles64();
		NativeSleep(MIN_GRANULARITY);
		Cycles = FPlatformTime::Cycles64() - Cycles;
		SleepResolution = FPlatformTime::ToSeconds( (uint32)Cycles);
	}

	if ( SleepResolution < MIN_GRANULARITY )
	{
		int Factor = 2;
		double TimeFraction = SleepResolution - TimeStampResolution;
		while ( Factor < 1000 && SleepResolution < MIN_GRANULARITY )
		{
			SleepResolution = TimeFraction * (double)Factor;
			Factor++;
		}
	}

	debugf( NAME_Init, TEXT("SleepResolution %fms, TimeStampResolution %fms"), SleepResolution * 1000, TimeStampResolution * 1000);
}



double CTickerEngine::TickNow()
{
	TickCount++;
	double CurrentTimeStamp = FPlatformTime::Seconds();
	double DeltaTime = CurrentTimeStamp - LastTickTimestamp;
	LastTickTimestamp = CurrentTimeStamp;
	return DeltaTime;
}

double CTickerEngine::TickAbsolute( double EndTime)
{
	double CurrentTimeStamp = FPlatformTime::Seconds();
	FixState( EndTime, CurrentTimeStamp);
	EndTime -= TimeStampResolution / 2;
	while ( CurrentTimeStamp < EndTime )
	{
		double LastSleepExitDelta = CurrentTimeStamp - LastSleepExitTime;
		if ( LastSleepExitDelta > 0.5 ) //Can't accurately predict next Native sleep exit
			ResetState();

		double SleepTime = 0;

		//No state, sleep if possible to set an Exit point
		if ( LastSleepExitTime == 0 ) 
			SleepTime = (EndTime - CurrentTimeStamp) - (MSEC(1.0) + TimeStampResolution);

		//See if we should native sleep
		else
		{
			//Push forward native sleep
			int Factor = appFloor((CurrentTimeStamp - LastSleepExitTime) / SleepResolution);
			if ( Factor >= 0 )
				LastSleepExitTime += SleepResolution * (double)(Factor+1);
			SleepTime = (EndTime - LastSleepExitTime) - (MIN_GRANULARITY + TimeStampResolution); //Minus 1ms and time error
		}

		if ( (SleepTime > MIN_GRANULARITY * 1.01) && (SleepTime > SleepResolution) ) //Prevent over-sleep
		{
//			uint32 Cycles = FPlatformTime::Cycles();
			NativeSleep( SleepTime);
//			Cycles = FPlatformTime::Cycles() - Cycles;
//			double RealSleep = FPlatformTime::ToSeconds(Cycles);
//			if ( RealSleep > SleepTime * 3 )
//				debugf( TEXT("SLEEP ABNORMALITY %f / %f"), RealSleep, SleepTime);
//			debugf( TEXT("WANTED %f, GOT %f"), SleepTime * 1000, RealSleep * 1000 );
			CurrentTimeStamp = FPlatformTime::Seconds();
		}

		//Yield CPU, high Yield systems must stop earlier
		double YieldFactor = 3.0;
		while ( EndTime - CurrentTimeStamp > TimeStampResolution * YieldFactor )
		{
			double OldTimeStamp = CurrentTimeStamp;
			NativeYield();
			CurrentTimeStamp = FPlatformTime::Seconds();
			YieldFactor = 0.5 + (CurrentTimeStamp - OldTimeStamp) / TimeStampResolution;
		}

		//Spin to win
		do
		{
			CurrentTimeStamp = FPlatformTime::Seconds();
		} while ( CurrentTimeStamp < EndTime );
//		debugf( TEXT("OFFSET FROM END (MS) = %f"), (CurrentTimeStamp - EndTime)*1000 );
	}

	TickCount++;
	double DeltaTime = CurrentTimeStamp - LastTickTimestamp;
	LastTickTimestamp = CurrentTimeStamp;
	return DeltaTime;
}

double CTickerEngine::TickInterval( double Interval, double ResetInterval, double AllowedError)
{
	double CurrentTime = FPlatformTime::Seconds();
	if ( LastInterval == Interval ) //Allow 10% error
	{
		if ( (LastAdjustedInterval <= Interval + AllowedError) && (LastAdjustedInterval >= Interval - AllowedError) )
			Interval = Interval * 2 - LastAdjustedInterval;
	}
	else
		LastInterval = Interval;
	LastAdjustedInterval = Interval;
	double EndTick = LastTickTimestamp + Interval;

	// The system took longer than interval to do internal processing, skip frame
	double Result;
	if ( CurrentTime > EndTick )
	{
		// Reset sleep state if took too long
		if ( (ResetInterval > 0) && (CurrentTime - LastTickTimestamp > ResetInterval) )
			ResetState();
		Result = TickNow();
	}
	else
		Result = TickAbsolute( EndTick);
//	debugf( TEXT("Expected %f, Got %f"), Interval, Result);
	return Result;
}



