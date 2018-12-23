/*=============================================================================
	FOutputDeviceCmdError.h
	Author: Fernando Velázquez

	Native windows command line error interface.
=============================================================================*/

//
// ANSI stdout output device.
//
class FOutputDeviceCmdError : public FOutputDeviceError
{
protected:
	INT ErrorPos;
	EName ErrorType;

	volatile int32 Lock;
	HANDLE StdIn;
	HANDLE StdOut;

	// Lazy init
	bool StdInit()
	{
		if ( (StdIn == INVALID_HANDLE_VALUE) || (StdOut == INVALID_HANDLE_VALUE) )
		{
			StdIn  = GetStdHandle( STD_INPUT_HANDLE );
			StdOut = GetStdHandle( STD_OUTPUT_HANDLE );
			return (StdIn != INVALID_HANDLE_VALUE) && (StdOut != INVALID_HANDLE_VALUE);
		}
		return true;
	}

	// Local functions.
	void LocalPrint( const TCHAR* Str )
	{
		if ( StdInit() )
			WriteConsole( StdOut, Str, appStrlen(Str), nullptr, nullptr);
	}


public:
	FOutputDeviceCmdError()
	:	ErrorPos( 0)
	,	ErrorType( NAME_None)
	,	Lock( 0)
	,	StdIn( INVALID_HANDLE_VALUE)
	,	StdOut( INVALID_HANDLE_VALUE)
	{}

	~FOutputDeviceCmdError()
	{
		Lock = 0;
	}

	void Serialize( const TCHAR* Msg, enum EName Event )
	{
		CSpinLock SL(&Lock);

		if( !GIsCriticalError )
		{
			// First appError.
			GIsCriticalError = 1;
			ErrorType        = Event;
			debugf( NAME_Critical, TEXT("appError called:") );
			debugf( NAME_Critical, Msg );

			// Shut down.
			UObject::StaticShutdownAfterError();
			appStrncpy( GErrorHist, Msg, ARRAY_COUNT(GErrorHist) );
			appStrncat( GErrorHist, TEXT("\r\n\r\n"), ARRAY_COUNT(GErrorHist) );
			ErrorPos = appStrlen(GErrorHist);
			if( GIsGuarded )
			{
				appStrncat( GErrorHist, LocalizeError("History",TEXT("Core")), ARRAY_COUNT(GErrorHist) );
				appStrncat( GErrorHist, TEXT(": "), ARRAY_COUNT(GErrorHist) );
			}
			else
			{
				HandleError();
			}
		}
		else
			debugf( NAME_Critical, TEXT("Error reentered: %s"), Msg );

		// Propagate the error or exit.
		if( GIsGuarded )
			throw( 1 );
		else
			appRequestExit( 1 );
	}
	void HandleError()
	{
		try
		{
			GIsGuarded       = 0;
			GIsRunning       = 0;
			GIsCriticalError = 1;
			GLogHook         = NULL;
			UObject::StaticShutdownAfterError();
			GErrorHist[ErrorType==NAME_FriendlyError ? ErrorPos : ARRAY_COUNT(GErrorHist)-1]=0;
			LocalPrint( GErrorHist );
			LocalPrint( TEXT("\n\nExiting due to error\n") );
		}
		catch( ... )
		{}
	}
};

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
