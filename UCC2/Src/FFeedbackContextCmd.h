/*=============================================================================
	FFeedbackContextCmd.h
	Author: Fernando Velázquez
	
	Native windows command line user interface.
=============================================================================*/

#include "Cacus/Atomics.h"
#include "Cacus/CacusString.h"

#if UNICODE
	#define CacusBufferSprintf CWSprintf
#else
	#define CacusBufferSprintf CSprintf
#endif

/*-----------------------------------------------------------------------------
	FFeedbackContextCmd.
-----------------------------------------------------------------------------*/

static TCHAR SpaceText[2] = { ' ', 0};

// TODO: REWRITE COMPLETELY, IMPLEMENT LOG TO STDOUT CLEANLY
// Feedback context.
//
class FFeedbackContextCmd : public FFeedbackContext
{
public:
	// Variables.
	int32 SlowTaskCount;
	int32 WarningCount;
	FContextSupplier* Context;
	FOutputDevice* AuxOut;

protected:
	volatile int32 Lock;
	HANDLE StdIn;
	HANDLE StdOut;

public:
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

	void OffsetCursor( int32 Offset)
	{
		CONSOLE_SCREEN_BUFFER_INFO CInfo;
		GetConsoleScreenBufferInfo( StdOut, &CInfo);
		CInfo.dwCursorPosition.X += Offset;
		while ( CInfo.dwCursorPosition.X >= CInfo.dwSize.X )
		{
			CInfo.dwCursorPosition.X -= CInfo.dwSize.X;
			if ( CInfo.dwCursorPosition.Y >= CInfo.dwSize.Y )
				LocalPrint( TEXT("\n"));
			else
				CInfo.dwCursorPosition.Y++;
		}
		while ( CInfo.dwCursorPosition.X < 0 )
		{
			if ( CInfo.dwCursorPosition.Y <= 0 )
				break;
			CInfo.dwCursorPosition.X += CInfo.dwSize.X;
			CInfo.dwCursorPosition.Y--;
		}
		SetConsoleCursorPosition( StdOut, CInfo.dwCursorPosition);
	}

	// Constructor.
	FFeedbackContextCmd()
	:	SlowTaskCount( 0)
	,	WarningCount( 0)
	,	Context( nullptr)
	,	AuxOut( nullptr)
	,	Lock( 0)
	,	StdIn( INVALID_HANDLE_VALUE)
	,	StdOut( INVALID_HANDLE_VALUE)
	{}

	~FFeedbackContextCmd()
	{
		Lock = 0;
	}

	//There is no need to lock if we don't use non-lockable shared resources
	void Serialize( const TCHAR* Msg, EName Event )
	{
		guard(FFeedbackContextCmd::Serialize);

		// Filter bad parameters
		if ( !Msg || !Msg[0] )
			return;

		CSpinLock SL(&Lock);

		// Handle events
		if ( Event == NAME_Title )
			SetConsoleTitle( Msg);
		else if( Event == NAME_Progress )
		{
			LocalPrint( Msg);
			LocalPrint( TEXT("\r"));
		}
		else
		{
			// CacusBufferSprintf will return nullptr is the resulting string is larger than the buffer
			// So all we need to do is not print ModMsg if 'nullptr'
			CStringBufferInit( 16 * 1024); //Lazy init buffer (16kb)
			const TCHAR* ModMsg = nullptr; 

			// Handle events
			if ( Event == NAME_Heading )
				ModMsg = CacusBufferSprintf( TEXT("--------------------%s--------------------"), Msg);
			else if( Event==NAME_SubHeading )
				ModMsg = CacusBufferSprintf( TEXT("%s..."), Msg);
			else if( Event==NAME_Error || Event==NAME_Warning || Event==NAME_ExecWarning || Event==NAME_ScriptWarning )
			{
				if( Context )
					ModMsg = CacusBufferSprintf( TEXT("%s : %s, %s"), *Context->GetContext(), *FName(Event), Msg);
				WarningCount++;
			}

			// Use modified message if exists
			if ( ModMsg && *ModMsg )
				Msg = ModMsg;

			LocalPrint( Msg);
			LocalPrint( TEXT("\n"));

			if( GLog != this )
				GLog->Serialize( Msg, Event );
			if( AuxOut )
				AuxOut->Serialize( Msg, Event );
		}
		unguard;
	}

	// Specialized Y/N handler, waits for confirmation
	UBOOL YesNof( const TCHAR* Fmt, ... )
	{
		CSpinLock SL(&Lock);

		TCHAR TempStr[4096];
		GET_VARARGS( TempStr, ARRAY_COUNT(TempStr), Fmt );
		guard(FFeedbackContextCmd::YesNof);
		if( (GIsClient || GIsEditor) && !ParseParam(appCmdLine(),TEXT("Silent")) )//!!
		{
			LocalPrint( TempStr );
			LocalPrint( TEXT(" (Y/N): ") );

			uint32 cc;
			INPUT_RECORD irec;
			TCHAR In[2] = { '\0', '\0'};
			FlushConsoleInputBuffer(StdIn);
			for ( ; ; )
			{
				uint32 Events = 0;
				while ( !GetNumberOfConsoleInputEvents( StdIn, &Events) )
					appSleep(0.1f);

				ReadConsoleInputA( StdIn, &irec, 1, &cc);
				if( irec.EventType == KEY_EVENT && irec.Event.KeyEvent.bKeyDown	)//&& ! ((KEY_EVENT_RECORD&)irec.Event).wRepeatCount )
				{
					const TCHAR c = (TCHAR)irec.Event.KeyEvent.uChar.AsciiChar;
					if ( c == VK_RETURN )
					{
						if ( In[0]=='Y' || In[0]=='y' || In[0]=='N' || In[0]=='n' )
						{
							LocalPrint( TEXT("\n"));
							return (In[0]=='Y' || In[0]=='y');
						}
					}
					else if ( c == VK_ESCAPE || c == VK_CANCEL ) 
					{
						if ( In[0] )
							OffsetCursor( -1);
						LocalPrint( TEXT("N (esc)\n"));
						return 0;
					}
					else if ( c=='Y' || c=='y' || c=='N' || c=='n' )
					{
						if ( In[0] )
							OffsetCursor( -1);
						In[0] = (TCHAR)irec.Event.KeyEvent.uChar.AsciiChar;
						LocalPrint( In);
					}
				}
			}
		}
		else
			return 1;
		unguard;
	}
	void BeginSlowTask( const TCHAR* Task, UBOOL StatusWindow, UBOOL Cancelable )
	{
		guard(FFeedbackContextCmd::BeginSlowTask);
		GIsSlowTask = ++SlowTaskCount>0;
		unguard;
	}
	void EndSlowTask()
	{
		guard(FFeedbackContextCmd::EndSlowTask);
		check(SlowTaskCount>0);
		GIsSlowTask = --SlowTaskCount>0;
		unguard;
	}
	UBOOL VARARGS StatusUpdatef( INT Numerator, INT Denominator, const TCHAR* Fmt, ... )
	{
		guard(FFeedbackContextCmd::StatusUpdatef);
		TCHAR TempStr[4096];
		GET_VARARGS( TempStr, ARRAY_COUNT(TempStr), Fmt );
		if( GIsSlowTask )
		{
			//!!
		}
		return 1;
		unguard;
	}
	void SetContext( FContextSupplier* InSupplier )
	{
		guard(FFeedbackContextCmd::SetContext);
		Context = InSupplier;
		unguard;
	}
};



/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
