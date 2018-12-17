/*=============================================================================
	Devices.cpp:

	Multiplatform devices implementation
	- Output devices
	- Memory allocators
=============================================================================*/

#include "XC_Core.h"

XC_CORE_API extern UBOOL b440Net;
#include "UnXC_Arc.h"

#include "Devices.h"
#include "Cacus/Atomics.h"
#include "Cacus/CacusOutputDevice.h"

#ifdef __LINUX_X86__
	#include "Cacus/CacusGlobals.h"
#endif

#ifdef _WINDOWS
	UBOOL GLogUnlimitedLength = 0;
#else
	UBOOL GLogUnlimitedLength = 1;
#endif
UBOOL GMallocThreadSafe = 0;

//*************************************************
// Updated file output device
//*************************************************

FOutputDeviceFileXC::FOutputDeviceFileXC( const TCHAR* InFilename  )
{
	CacusOut = (COutputDeviceFile*)ConstructOutputDevice( COUT_File_UTF8);
	SetFilename( InFilename);
	CacusOut->AutoFlush = 0;
}

FOutputDeviceFileXC::~FOutputDeviceFileXC()
{
	DestructOutputDevice( CacusOut);
	CacusOut = NULL;
}

void FOutputDeviceFileXC::SetFilename( const TCHAR* NewFilename)
{
	if ( CacusOut )
	{
		TCharBuffer<1024,char> Buf;
#ifdef __LINUX_X86__
        if ( !ParseParam(appCmdLine(),TEXT("nohomedir")))
			Buf = CUserDir();
#endif
		Buf += TCHAR_TO_ANSI(NewFilename);
		CacusOut->SetFilename( *Buf);
	}
}

void FOutputDeviceFileXC::WriteDataToArchive(const TCHAR* Data, EName Event)
{
	if ( Event != NAME_None )
	{
		CacusOut->Serialize( FName::SafeString(Event));
		CacusOut->Serialize( ": ");
	}
	CacusOut->Serialize( Data);
	CacusOut->Serialize( "\r\n");
}

void FOutputDeviceFileXC::Serialize( const TCHAR* Data, EName Event)
{
	static UBOOL Entry = 0;
	if( !GIsCriticalError || Entry )
	{
		if( !CacusOut->Opened && !CacusOut->Dead )
		{
			// This will be the first line
			TCHAR Msg[256];
			appSprintf( Msg, TEXT("Init: Log file open, %s"), appTimestamp() );
			WriteDataToArchive( Msg, NAME_None );
		}

		if( Event != NAME_Title )
		{
			WriteDataToArchive(Data, Event);

			static UBOOL GForceLogFlush = false;
			static UBOOL GTestedCmdLine = false;
			if (!GTestedCmdLine)
			{
				GTestedCmdLine = true;
				GForceLogFlush = ParseParam( appCmdLine(), TEXT("FORCELOGFLUSH")) || ParseParam( appCmdLine(), TEXT("LOGFLUSH"));
			}
			if( GForceLogFlush )
					CacusOut->Flush();
		}
		if( GLogHook )
			GLogHook->Serialize( Data, Event );

	}
	else
	{
		Entry = 1;
		try
		{
			// Ignore errors to prevent infinite-recursive exception reporting.
			Serialize( Data, Event );
		}
		catch( ... )
		{}
		Entry = 0;
	}
}

//*************************************************
// Thread-safe Log proxy
//*************************************************

bool FLogLine::operator==( const FLogLine& O)
{
	return (O.Event == Event)
		&& (O.Msg.Len() == Msg.Len())
		&& !appStrcmp(*O.Msg,*Msg);
}

FLogLine::FLogLine()
	: Event(NAME_Log)
{}

FLogLine::FLogLine( EName InEvent, const TCHAR* InData)
	: Event( InEvent)
	, Msg( InData)
{
	if ( !GLogUnlimitedLength )
	{
		INT SafeSize = 1014-appStrlen(FName::SafeString(Event));
		if ( Msg.Len() >= SafeSize ) //Ugly, but makes both string comparers and serializers stop
			Msg.GetCharArray()(SafeSize) = '\0'; //This shouldn't break the C++ optimizer
	}
}

FOutputDeviceInterceptor::FOutputDeviceInterceptor( FOutputDevice* InNext)
	:	Next( InNext )
	,	CriticalOut(NULL)
	,	SerializeLock(0)
	,	Repeater(NAME_Log)
	,	CriticalSet(0)
{
	ClearRepeater();
}

FOutputDeviceInterceptor::~FOutputDeviceInterceptor()
{
	CriticalSet = true;
	if ( CriticalOut )
	{
		DestructOutputDevice( CriticalOut);
		CriticalOut = NULL;
	}
	if ( Next )
		delete Next;
}

void FOutputDeviceInterceptor::SetRepeaterText( TCHAR* Text)
{
	FName NewRepeater( Text, FNAME_Intrinsic);
	Repeater = (EName)NewRepeater.GetIndex();
}

void FOutputDeviceInterceptor::Serialize( const TCHAR* Msg, EName Event )
{
	guard(FOutputDeviceInterceptor::Serialize)
	if ( ProcessLock ) //Fugly hack to prevent deadlock
		return;
	if ( Msg && Msg[0] ) //No empty output or infinite loop
	{
		FLogLine Line( Event, Msg);
		ProcessMessage( Line);
	}
	unguard;
}

void FOutputDeviceInterceptor::ProcessMessage( FLogLine& Line)
{
	CSpinLock Lock(&ProcessLock);
	UBOOL bDoLog = true;
	if ( GIsCriticalError && !CriticalSet ) //Flush all saved lines if we're printing a crash log
	{
		FlushRepeater();
		CriticalSet = true;
	}

	if ( Line.Event == NAME_Critical )
	{
		if ( !CriticalOut )
		{
			INT Year, Month, DayOfWeek, Day, Hour, Min, Sec, MSec;
			appSystemTime( Year, Month, DayOfWeek, Day, Hour, Min, Sec, MSec );
			CriticalOut = (COutputDeviceFile*)ConstructOutputDevice( COUT_File_UTF8);
			CriticalOut->SetFilename( CSprintf("Crash__%i-%02d-%02d__%02d-%02d.log", Year, Month, Day, Hour, Min) );
			CriticalOut->AutoFlush = 1;
		}
		CriticalOut->Serialize( FName::SafeString(NAME_Critical) );
		CriticalOut->Serialize( ": " );
		CriticalOut->Serialize( *Line.Msg);
		CriticalOut->Serialize( "\r\n");
	}
	else if ( Line.Event != NAME_Title )
	{
		if ( RepeatCount == 0 ) //Try to setup repeater
		{
			for ( INT i=0 ; i<OLD_LINES ; i++ )
			{
				DWORD Idx = (CurCmp-i) % OLD_LINES;
				if ( MessageBuffer[Idx] == Line )
				{
					bDoLog = false;
					StartCmp = Idx;
					LastCmp = StartCmp+(i!=0); //Multi line comparison means we checked first line
					RepeatCount = 1+(i==0); //Single line comparison already means a full repetition
					break;
				}
			}
		}
		else //Repeater already up
		{
			if ( MessageBuffer[LastCmp] == Line )
			{
				bDoLog = false;
				if ( LastCmp == CurCmp )
				{
					LastCmp = StartCmp;
					RepeatCount++;
				}
				else
					LastCmp = (LastCmp + 1) % OLD_LINES;
			}
			else
				FlushRepeater();
		}
	}

	if ( bDoLog )
	{
		CurCmp = (CurCmp + 1) % OLD_LINES;
		SerializeNext( *Line.Msg, Line.Event);
		appMemswap( &MessageBuffer[CurCmp], &Line, sizeof(FLogLine)); //Destroy old message and keep 'line' in buffer
//		MessageBuffer[CurCmp] = Line;
	}
}

void FOutputDeviceInterceptor::FlushRepeater()
{
	if ( RepeatCount == 0 )
		return;
	if ( RepeatCount > 1 )
	{
		TCHAR Ch[128];
		if ( CurCmp == StartCmp ) //One line
			appSprintf( Ch, TEXT("=== Last line repeats %i times."), RepeatCount);
		else
			appSprintf( Ch, TEXT("=== Last %i lines repeat %i times."), (CurCmp-StartCmp)%OLD_LINES + 1, RepeatCount);
		SerializeNext( Ch, Repeater);
	
		if ( StartCmp != CurCmp ) //Multi-line, there may be lines that didn't fully complete a repetition cycle, post them
			while ( LastCmp != StartCmp )
			{
				SerializeNext( *MessageBuffer[LastCmp].Msg, MessageBuffer[LastCmp].Event);
				LastCmp = (LastCmp - 1) % OLD_LINES;
			}
	}
	ClearRepeater();
}

void FOutputDeviceInterceptor::ClearRepeater()
{
	for ( DWORD i=0 ; i<OLD_LINES ; i++ )
		MessageBuffer[i].Msg.Empty(); //Should use safe-empty
	RepeatCount = 0;
	StartCmp = 0;
	LastCmp = 0;
	CurCmp = 0;
}

void FOutputDeviceInterceptor::SerializeNext( const TCHAR* Text, EName Event)
{
	CSpinLock Lock(&SerializeLock);
	Next->Serialize( Text, Event);
}