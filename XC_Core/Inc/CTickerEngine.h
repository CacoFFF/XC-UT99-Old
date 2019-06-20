/*=============================================================================
	CTickerEngine.h
	Author: Fernando Velázquez

	Advanced game tick controller.

	This game tick controller has been designed to take advantage of the
	system's timer resolution while minimizing resource usage.

	This controller knows when the next system timer will hit and will use one
	or more of the necessary sleeping methods to reach the next timer.
=============================================================================*/

#ifndef USES_CACUS_TICKER
#define USES_CACUS_TICKER

typedef int (*TickerCallback)(class CTickerEngine* Ticker);

class CTickerEngine
{
protected:
	double LastSleepExitTime; //Time at which native sleep ended
	double SleepResolution; //Native sleep timer resolution
	double TimeStampResolution; //Time between high precision timer updates

	double LastTickTimestamp;
	double LastInterval;
	double LastAdjustedInterval;
	uint64 TickCount;

public:
	TickerCallback Callback;

public:
	CTickerEngine();

	double GetSleepResolution() const;
	double GetTimeStampResolution() const;
	double GetLastTickTimestamp() const;
	uint64 GetTickCount() const;

	void NativeSleep( double Time);
	void NativeYield();
	void FixState( double& EndTime, double CurrentTime); //Needed in case time goes around boundaries
	void ResetState();
	void UpdateTimerResolution();

	double TickNow(); //Tick [Immediate]
	double TickAbsolute( double EndTime); //Tick [Absolute], ends on [EndTime]
	double TickInterval( double Interval, double ResetInterval=0, double AllowedError=0); //Tick [Interval], ends on [LastTickTimestamp + Interval], optional reset state
};





inline CTickerEngine::CTickerEngine()
{
	memset(this,0,sizeof(*this));
}

inline double CTickerEngine::GetSleepResolution() const
{
	return SleepResolution;
}

inline double CTickerEngine::GetTimeStampResolution() const
{
	return TimeStampResolution;
}

inline double CTickerEngine::GetLastTickTimestamp() const
{
	return LastTickTimestamp;
}

inline uint64 CTickerEngine::GetTickCount() const
{
	return TickCount;
}



#endif