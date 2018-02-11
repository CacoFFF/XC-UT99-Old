/*=============================================================================
	Launch.cpp: Game launcher.
	Copyright 1997-1999 Epic Games, Inc. All Rights Reserved.

Revision history:
	* Created by Tim Sweeney.
	* Modified for XC_Launch by Higor
=============================================================================*/



#include "LaunchPrivate.h"
#include "UnXC_EngineWin.h"

/*-----------------------------------------------------------------------------
	Global variables.
-----------------------------------------------------------------------------*/

// General.
extern "C" {HINSTANCE hInstance;}
extern "C" {TCHAR GPackage[64]=TEXT("XC_Launch");}

//Import
#define XC_CORE_API DLL_IMPORT
#define CUSTOM_MALLOC_SINGLETON 1
#include "Devices.h"
#include "Atomics.h"
#include "WLog2.h"

// Memory allocator.
#ifdef _DEBUG
	#include "FMallocDebug.h"
	FMallocDebug Malloc;
#else
	#include "FMallocWindows.h"
	FMallocWindows Malloc;
#endif

// Log file.
FOutputDeviceFileXC Log;
FMallocThreadedProxy ThMalloc(&Malloc);

// Error handler.
#include "FOutputDeviceWindowsError.h"
FOutputDeviceWindowsError Error;

// Feedback.
#include "FFeedbackContextWindows.h"
FFeedbackContextWindows Warn;

// File manager.
#include "FFileManagerWindows.h"
FFileManagerWindows FileManager;

// Config.
#include "FConfigCacheIni.h"

TCHAR* MakeLogFilename( const TCHAR* CmdLine)
{
	TCHAR* Filename = appStaticString1024();
	Filename[0] = 0;
	if
	(	!Parse(CmdLine, TEXT("LOG="), Filename+appStrlen(Filename), 1024-appStrlen(Filename) )
	&&	!Parse(CmdLine, TEXT("ABSLOG="), Filename, 1024 ) )
	{
		appStrcat( Filename, GPackage );
		appStrcat( Filename, TEXT(".log") );
	}
	return Filename;
}

/*-----------------------------------------------------------------------------
	WinMain.
-----------------------------------------------------------------------------*/

//
// Main entry point.
// This is an example of how to initialize and launch the engine.
//
INT WINAPI WinMain( HINSTANCE hInInstance, HINSTANCE hPrevInstance, char*, INT nCmdShow )
{
	// Remember instance.
	INT ErrorLevel = 0;
	GIsStarted     = 1;
	hInstance      = hInInstance;
	const TCHAR* CmdLine = GetCommandLine();
	appStrcpy( GPackage, appPackage() );
	if ( !appStricmp( GPackage, TEXT("XC_Launch")) )
		appStrcpy( GPackage, TEXT("UnrealTournament"));

	Log.SetFilename( MakeLogFilename(CmdLine));

	// See if this should be passed to another instances.
	if
	(	!appStrfind(CmdLine,TEXT("Server"))
	&&	!appStrfind(CmdLine,TEXT("NewWindow"))
	&&	!appStrfind(CmdLine,TEXT("changevideo"))
	&&	!appStrfind(CmdLine,TEXT("TestRenDev")) )
	{
		TCHAR ClassName[256];
		MakeWindowClassName(ClassName,TEXT("WLog"));
		for( HWND hWnd=NULL; ; )
		{
			hWnd = TCHAR_CALL_OS(FindWindowExW(hWnd,NULL,ClassName,NULL),FindWindowExA(hWnd,NULL,TCHAR_TO_ANSI(ClassName),NULL));
			if( !hWnd )
				break;
			if( GetPropX(hWnd,TEXT("IsBrowser")) )
			{
				while( *CmdLine && *CmdLine!=' ' )
					CmdLine++;
				if( *CmdLine==' ' )
					CmdLine++;
				COPYDATASTRUCT CD;
				DWORD Result;
				CD.dwData = WindowMessageOpen;
				CD.cbData = (appStrlen(CmdLine)+1)*sizeof(TCHAR*);
				CD.lpData = const_cast<TCHAR*>( CmdLine );
				SendMessageTimeout( hWnd, WM_COPYDATA, (WPARAM)NULL, (LPARAM)&CD, SMTO_ABORTIFHUNG|SMTO_BLOCK, 30000, &Result );
				GIsStarted = 0;
				return 0;
			}
		}
	}

	// Begin guarded code.
#ifndef _DEBUG
	try
	{
#endif
		// Init core.
		GIsClient = GIsGuarded = 1;
		appInit( GPackage, CmdLine, &ThMalloc, &Log, &Error, &Warn, &FileManager, FConfigCacheIni::Factory, 1 );

		// Init mode.
		GIsServer     = 1;
		GIsClient     = !ParseParam(appCmdLine(),TEXT("SERVER"));
		GIsEditor     = 0;
		GIsScriptable = 1;
		GLazyLoad     = !GIsClient || ParseParam(appCmdLine(),TEXT("LAZY"));

		FMallocThreadedProxy::SetSingleton(&ThMalloc);

		// Figure out whether to show log or splash screen.
		UBOOL ShowLog = ParseParam(CmdLine,TEXT("LOG"));
		FString Filename = FString(TEXT("..\\Help")) * GPackage + TEXT("Logo.bmp");
		if( GFileManager->FileSize(*Filename)<0 )
			Filename = TEXT("..\\Help\\Logo.bmp");
		appStrcpy( GPackage, appPackage() );
		if( !ShowLog && !ParseParam(CmdLine,TEXT("server")) && !appStrfind(CmdLine,TEXT("TestRenDev")) )
			InitSplash( *Filename );

		// Init windowing.
		InitWindowing();

		// Create log window, but only show it if ShowLog.
		GLogWindow = (WLog*) new WLog2( TEXT("GameLog") );
		GLogWindow->OpenWindow( ShowLog, 0 );
		GLogWindow->Log( NAME_Title, LocalizeGeneral("Start") );
		if( GIsClient )
			SetPropX( *GLogWindow, TEXT("IsBrowser"), (HANDLE)1 );

		// Ugly resolution overriding code.
		FString ScreenWidth;
		FString ScreenHeight;
		UBOOL	OverrideResolution = false;

		if( ParseParam( CmdLine,TEXT("320x240")) )
		{
			ScreenWidth			= TEXT("320");
			ScreenHeight		= TEXT("240");
			OverrideResolution	= 1;
		}
		if( ParseParam( CmdLine,TEXT("512x384")) )
		{
			ScreenWidth			= TEXT("512");
			ScreenHeight		= TEXT("384");
			OverrideResolution	= 1;
		}
		if( ParseParam( CmdLine,TEXT("640x480")) )
		{
			ScreenWidth			= TEXT("640");
			ScreenHeight		= TEXT("480");
			OverrideResolution	= 1;
		}
		if( ParseParam( CmdLine,TEXT("800x600")) )
		{
			ScreenWidth			= TEXT("800");
			ScreenHeight		= TEXT("600");
			OverrideResolution	= 1;
		}
		if( ParseParam( CmdLine,TEXT("1024x768")) )
		{
			ScreenWidth			= TEXT("1024");
			ScreenHeight		= TEXT("768");
			OverrideResolution	= 1;
		}
		if( ParseParam( CmdLine,TEXT("1280x960")) )
		{
			ScreenWidth			= TEXT("1280");
			ScreenHeight		= TEXT("960");
			OverrideResolution	= 1;
		}
		if( ParseParam( CmdLine,TEXT("1280x1024")) )
		{
			ScreenWidth			= TEXT("1280");
			ScreenHeight		= TEXT("1024");
			OverrideResolution	= 1;
		}
		if( ParseParam( CmdLine,TEXT("1600x1200")) )
		{
			ScreenWidth			= TEXT("1600");
			ScreenHeight		= TEXT("1200");
			OverrideResolution	= 1;
		}
		if( ParseParam( CmdLine,TEXT("1920x1080")) )
		{
			ScreenWidth			= TEXT("1920");
			ScreenHeight		= TEXT("1080");
			OverrideResolution	= 1;
		}
	
		if( OverrideResolution )
		{
			GConfig->SetString( TEXT("WinDrv.WindowsClient"), TEXT("FullscreenViewportX"), *ScreenWidth  );
			GConfig->SetString( TEXT("WinDrv.WindowsClient"), TEXT("FullscreenViewportY"), *ScreenHeight );
		}
		
		// Init engine.
		UEngine* Engine = InitEngine();
		if( Engine )
		{
			GLogWindow->Log( NAME_Title, LocalizeGeneral("Run") );

			// Hide splash screen.
			ExitSplash();

			// Optionally Exec an exec file
			FString Temp;
			if( Parse(CmdLine, TEXT("EXEC="), Temp) )
			{
				Temp = FString(TEXT("exec ")) + Temp;
				if( Engine->Client && Engine->Client->Viewports.Num() && Engine->Client->Viewports(0) )
					Engine->Client->Viewports(0)->Exec( *Temp, *GLogWindow );
			}

			// Start main engine loop, including the Windows message pump.
			if( !GIsRequestingExit )
				MainLoop( Engine );
		}

		// Clean shutdown.
		GFileManager->Delete(TEXT("Running.ini"),0,0);
		RemovePropX( *GLogWindow, TEXT("IsBrowser") );
		GLogWindow->Log( NAME_Title, LocalizeGeneral("Exit") );
		GLogHook = NULL; //Prevents GPF due to alien log window class
		delete (WLog2*)GLogWindow;
		appPreExit();
		GIsGuarded = 0;
#ifndef _DEBUG
	}
	catch( ... )
	{
		// Crashed.
		ErrorLevel = 1;
		Error.HandleError();
	}
#endif

	// Final shut down.
	appExit();
	GIsStarted = 0;
	GLogHook = NULL;
	return ErrorLevel;
}

//*************************************************
// Thread-safe Malloc proxy
//*************************************************

FMallocThreadedProxy::FMallocThreadedProxy()
	:	Signature( 1337)
	,	MainMalloc( NULL )
	,	NoAttachOperations(1)
	,	Lock(0)
{}


FMallocThreadedProxy::FMallocThreadedProxy( FMalloc* InMalloc )
	:	Signature( 1337 )
	,	MainMalloc( InMalloc )
	,	NoAttachOperations(1)
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


/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
