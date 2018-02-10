/*=============================================================================
	Devices.cpp:

	Multiplatform devices implementation
	- Output devices
	- Memory allocators
=============================================================================*/

#include "XC_Core.h"

XC_CORE_API extern UBOOL b440Net;
#include "UnXC_Arc.h"

#include "Atomics.h"
#include "Devices.h"


//*************************************************
// Updated file output device
//*************************************************

FOutputDeviceFileXC::FOutputDeviceFileXC( const TCHAR* InFilename  )
:	LogAr( NULL ),
	Opened( 0 ),
	Dead( 0 )
{
	if( InFilename )
		appStrcpy( Filename, InFilename);
	else
		Filename[0]	= 0;
}

FOutputDeviceFileXC::~FOutputDeviceFileXC()
{
	TearDown();
}

void FOutputDeviceFileXC::SetFilename(const TCHAR* InFilename)
{
	// Close any existing file.
	TearDown();
	appStrcpy( Filename, InFilename);
}

void FOutputDeviceFileXC::TearDown()
{
	if( LogAr )
	{
		Logf( TEXT("Log file closed, %s"), appTimestamp() );
		Flush();
		ARCHIVE_DELETE(LogAr);
	}
}

void FOutputDeviceFileXC::Flush()
{
	if( LogAr )
		((FArchive_Proxy*)LogAr)->Flush();
}

FArchive* FOutputDeviceFileXC::CreateArchive( DWORD MaxAttempts)
{
	DWORD WriteFlags = FILEWRITE_AllowRead | (Opened ? FILEWRITE_Append : 0);

	FString FilenamePart = FString( appBaseDir() );
	FString ExtensionPart = FString( TEXT(".log") );
	if ( Filename[0] )
	{
		FilenamePart += Filename;
		INT ExtIdx = FilenamePart.InStr( TEXT("."), true);
		if ( (ExtIdx >= 0) && (FilenamePart.Len() - ExtIdx > 1) ) //Extract extension
		{
			ExtensionPart = FilenamePart.Mid( ExtIdx);
			FilenamePart = FilenamePart.Left( ExtIdx);
		}
	}
	else
		FilenamePart += appPackage();

	FArchive* Result = GFileManager->CreateFileWriter( *(FilenamePart+ExtensionPart), WriteFlags);
	if ( !Result) //Add _2 if necessary
	{
		FString FinalFilename;
		DWORD FileIndex = 2;
		do
		{
			FinalFilename = FString::Printf( TEXT("%s_%i%s"), *FilenamePart, FileIndex++, *ExtensionPart);
			Result = GFileManager->CreateFileWriter( *FinalFilename, WriteFlags);
		} while ( !Result && FileIndex < MaxAttempts );
	}

	return Result;
}

void FOutputDeviceFileXC::Write( const TCHAR* Data)
{
#if UNICODE
	INT CR = appStrlen(Data);
	INT CS = 0;
	BYTE Buffer[256];
	while ( CS < CR  )
	{
		INT CW = Min(CR-CS,256);
		for ( INT i=0 ; i<CW ; i++ )
			Buffer[i] = (BYTE)Data[CS+i];
		((FArchive_Proxy*)LogAr)->Serialize( Buffer, CW);
		CS += CW;
	}
#else
	LogAr->Serialize( (void*)Data, appStrlen(Data) );
#endif
}

void FOutputDeviceFileXC::WriteDataToArchive(const TCHAR* Data, EName Event)
{
	if ( Event != NAME_None )
	{
		Write( FName::SafeString(Event));
		Write( TEXT(": "));
	}
	Write( Data);
	ANSICHAR WindowsTerminator[] = { '\r', '\n' };
	((FArchive_Proxy*)LogAr)->Serialize(WindowsTerminator, sizeof(WindowsTerminator));
}

void FOutputDeviceFileXC::Serialize( const TCHAR* Data, EName Event)
{
	static UBOOL Entry = 0;
	if( !GIsCriticalError || Entry )
	{
		if( !LogAr && !Dead )
		{
			// Open log file.
			LogAr = CreateArchive();
			if( LogAr )
			{
				Opened = 1;
				TCHAR Msg[256];
				appSprintf( Msg, TEXT("Init: Log file open, %s"), appTimestamp() );
				WriteDataToArchive( Msg, NAME_None );
			}
			else 
				Dead = true;
		}

		if( LogAr && (Event != NAME_Title) )
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
				Flush();
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
// Thread-safe Malloc proxy
//*************************************************

FMallocThreadedProxy::FMallocThreadedProxy()
	:	Signature( 1337)
	,	MainMalloc( NULL )
	,	NoAttachOperations(0)
	,	Lock(0)
{}


FMallocThreadedProxy::FMallocThreadedProxy( FMalloc* InMalloc )
	:	Signature( 1337 )
	,	MainMalloc( InMalloc )
	,	NoAttachOperations(0)
	,	Lock(0)
{}


void* FMallocThreadedProxy::Malloc( DWORD Count, const TCHAR* Tag)
{
	FSpinLock Lock( &Lock);
	void* Result = MainMalloc->Malloc( Count, Tag);
	return Result;
}

void* FMallocThreadedProxy::Realloc( void* Original, DWORD Count, const TCHAR* Tag )
{
	FSpinLock Lock( &Lock);
	void* Result = NULL;
	if ( !Count )
		MainMalloc->Free( Original);
	else
		Result = MainMalloc->Realloc( Original, Count, Tag);
	return Result;
}

void FMallocThreadedProxy::Free( void* Original )
{
	FSpinLock Lock( &Lock);
	if ( Original )
		MainMalloc->Free( Original);
}

void FMallocThreadedProxy::DumpAllocs()
{
	FSpinLock Lock( &Lock);
	MainMalloc->DumpAllocs();
}

void FMallocThreadedProxy::HeapCheck()
{
	FSpinLock Lock( &Lock);
	MainMalloc->HeapCheck();
}

void FMallocThreadedProxy::Init()
{
	if ( MainMalloc )
		MainMalloc->Init();
}
void FMallocThreadedProxy::Exit()
{
	if ( MainMalloc )
		MainMalloc->Exit();
}

FMallocThreadedProxy* FMallocThreadedProxy::Singleton = NULL;
FMallocThreadedProxy* FMallocThreadedProxy::GetInstance()
{
	if ( !FMallocThreadedProxy::Singleton )
		FMallocThreadedProxy::Singleton = new FMallocThreadedProxy();
	return Singleton;
}

void FMallocThreadedProxy::SetSingleton( FMallocThreadedProxy* NewSingleton)
{
	Singleton = NewSingleton;
}

void FMallocThreadedProxy::Attach()
{
	if ( NoAttachOperations )
		return;
	if ( IsAttached() )
		appErrorf( TEXT("FMallocThreadedProxy::Attach -> proxy already in attached state") );
	else if ( GMalloc != this )
	{
		MainMalloc = GMalloc;
		GMalloc = this;
	}
}

void FMallocThreadedProxy::Detach()
{
	if ( NoAttachOperations )
		return;
	if ( !IsAttached() )
		appErrorf( TEXT("FMallocThreadedProxy::Detach -> proxy already in detached state") );
	else if ( GMalloc == this )
	{
		GMalloc = MainMalloc;
		MainMalloc = NULL;
	}
}

UBOOL FMallocThreadedProxy::IsAttached()
{
	return !NoAttachOperations && MainMalloc != NULL;
}

//*************************************************
// Thread-safe Log proxy
//*************************************************

FOutputDeviceInterceptor::FOutputDeviceInterceptor( FOutputDevice* InNext)
	:	Next( InNext )
	,	LogCritical(NULL)
	,	SerializeLock(0)
	,	Repeater(NAME_Log)
	,	CriticalSet(0)
{
	ClearRepeater();
}

FOutputDeviceInterceptor::~FOutputDeviceInterceptor()
{
	CriticalSet = true;
	if ( LogCritical )
		ARCHIVE_DELETE(LogCritical);
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
	if ( Msg && Msg[0] ) //No empty output or infinite loop
	{
		FLogLine Line;
		Line.Event = Event;
		Line.Len = Min( appStrlen( Msg), 1014-appStrlen(FName::SafeString(Event)) );
		appMemcpy( Line.Msg, Msg, Line.Len * sizeof(TCHAR) );
		Line.Msg[Line.Len] = 0;
		FSpinLock Lock(&SerializeLock);
		ProcessMessage( Line);
	}
	unguard;
}

void FOutputDeviceInterceptor::ProcessMessage( const FLogLine& Line)
{
	if ( GIsCriticalError && !CriticalSet ) //Flush all saved lines if we're printing a crash log
	{
		FlushRepeater();
		CriticalSet = true;
	}

	UBOOL bDoLog = true;
	if ( Line.Event == NAME_Critical )
	{
		if ( !LogCritical )
		{
			TCHAR FileName[128] = {0};
			INT Year, Month, DayOfWeek, Day, Hour, Min, Sec, MSec;
			appSystemTime( Year, Month, DayOfWeek, Day, Hour, Min, Sec, MSec );
			appSprintf( FileName, TEXT("Crash__%i-%02d-%02d__%02d-%02d.log"), Year, Month, Day, Hour, Min);
			LogCritical = (FArchive_Proxy*)GFileManager->CreateFileWriter( FileName);
		}
		LogCritical->Serialize( (void*)TEXT("Critical: "), 10 * sizeof(TCHAR) );
		LogCritical->Serialize( (void*)Line.Msg, Line.Len * sizeof(TCHAR) );
		LogCritical->Serialize( (void*)LINE_TERMINATOR, appStrlen(LINE_TERMINATOR) * sizeof(TCHAR) );
		LogCritical->Flush();
	}
	else if ( Line.Event != NAME_Title )
	{
		if ( RepeatCount == 0 ) //Try to setup repeater
		{
			for ( INT i=0 ; i<OLD_LINES ; i++ )
			{
				DWORD Idx = (CurCmp-i) % OLD_LINES;
				if ( MessageBuffer[Idx].Matches(Line) )
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
			if ( MessageBuffer[LastCmp].Matches(Line) )
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
		appMemcpy( &MessageBuffer[CurCmp], &Line, sizeof(INT)*2 + sizeof(TCHAR)*(Line.Len+1));
		Next->Serialize( Line.Msg, Line.Event);
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
		Next->Serialize( Ch, Repeater);
	
		if ( StartCmp != CurCmp ) //Multi-line, there may be lines that didn't fully complete a repetition cycle, post them
			while ( LastCmp != StartCmp )
			{
				Next->Serialize( MessageBuffer[LastCmp].Msg, MessageBuffer[LastCmp].Event);
				LastCmp = (LastCmp - 1) % OLD_LINES;
			}
	}
	ClearRepeater();
}

void FOutputDeviceInterceptor::ClearRepeater()
{
	for ( DWORD i=0 ; i<OLD_LINES ; i++ )
		MessageBuffer[i].Len = 0; //Prevents matches
	RepeatCount = 0;
	StartCmp = 0;
	LastCmp = 0;
	CurCmp = 0;
}
