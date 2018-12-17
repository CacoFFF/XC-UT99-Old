/*=============================================================================
	WLog2.h: 

	Altering the behaviour of log window so it uses cache instead of file
=============================================================================*/

#include "Cacus/Atomics.h"

class WLog2 : public WTerminal
{
//	W_DECLARE_CLASS(WLog2,WTerminal,CLASS_Transient);
//	DECLARE_WINDOWCLASS(WLog2,WTerminal,Window)
public:
	// Variables.
	UINT NidMessage;

	FString MessageCache[256];
	INT CacheStart, CacheCount;
	volatile INT Lock;

	// Functions.
	WLog2()
	{
		InitMessageCache();
	}
	WLog2( FName InPersistentName, WWindow* InOwnerWindow=NULL )
	: WTerminal( InPersistentName, InOwnerWindow )
	, NidMessage( RegisterWindowMessageX( TEXT("UnrealNidMessage")) )
	{
		InitMessageCache();
	}

	void InitMessageCache()
	{
		Lock = 0;
		appMemzero( &MessageCache, sizeof(MessageCache));
		CacheStart = CacheCount = 0;
	}

	// FOutputDevice interface.
	void Serialize( const TCHAR* Data, EName MsgType )
	{
		guard(WTerminal::Serialize);
		CSpinLock SL(&Lock);
		if( MsgType==NAME_Title )
		{
			SetText( Data );
			return;
		}

		TCHAR Temp[1024]=TEXT("");
		appStrncat( Temp, *FName(MsgType), ARRAY_COUNT(Temp) );
		appStrncat( Temp, TEXT(": "), ARRAY_COUNT(Temp) );
		appStrncat( Temp, (TCHAR*)Data, ARRAY_COUNT(Temp) );
		appStrncat( Temp, TEXT("\r\n"), ARRAY_COUNT(Temp) );
		INT NextCache = (CacheStart+1) & 255;
		if ( CacheCount == 0 )
			NextCache = 0;
		MessageCache[NextCache] = Temp;
		CacheStart = NextCache;
		CacheCount = Min( CacheCount+1, 192);

		if( Shown )
			ShowNewLines();
		unguard;
	}

	void ShowNewLines()
	{
		if ( CacheCount <= 0 )
			return;
		Display.SetRedraw( 0 );
		INT LineCount = Display.GetLineCount();
		if ( LineCount + CacheCount > MaxLines )
		{
			INT NewLineCount = Clamp( LineCount-(SlackLines+CacheCount), 0, MaxLines);
			INT Index = Display.GetLineIndex( LineCount-NewLineCount );
			Display.SetSelection( 0, Index );
			Display.SetSelectedText( TEXT("") );
			INT Length = Display.GetLength();
			Display.SetSelection( Length, Length );
			Display.ScrollCaret();
		}
		//Create a unified text buffer with a single allocation
		INT i;
		INT Start = (CacheStart + 1 - CacheCount) & 255;
		INT TotalAllocChars = 1024; //Extra size just in case
		for ( i=0 ; i<CacheCount ; i++ )
			TotalAllocChars += MessageCache[(Start + i) & 255].Len();
		TotalAllocChars += appStrlen( Typing);
		TCHAR* Text = (TCHAR*) appMalloc(TotalAllocChars*sizeof(TCHAR), TEXT("LogWindowCache"));
		INT curText = 0;
		for ( i=0 ; i<CacheCount ; i++ )
		{
			INT idx = (Start + i) & 255;
			appMemcpy( &Text[curText], *MessageCache[idx], MessageCache[idx].Len()*sizeof(TCHAR) );
			curText += MessageCache[idx].Len();
		}
		appStrcpy( &Text[curText], Typing);
		SelectTyping();
		Display.SetRedraw( 1 );
		Display.SetSelectedText( Text );
		CacheCount = 0;
		appFree( Text);
	}

	void OnCreate()
	{
		guard(WTerminal::OnCreate);
		WWindow::OnCreate();
		Display.OpenWindow( 1, 1, 1 );
		Display.SetFont( (HFONT)GetStockObject(ANSI_FIXED_FONT) );
		Display.SetText( Typing );
		unguard;
	}
	void SetText( const TCHAR* Text )
	{
		guard(WLog::SetText);
		WWindow::SetText( Text );
		if( GNotify )
		{
#if UNICODE
			if( GUnicode && !GUnicodeOS )
			{
				appMemcpy( NIDA.szTip, TCHAR_TO_ANSI(Text), Min<INT>(ARRAY_COUNT(NIDA.szTip),appStrlen(Text)+1) );
				NIDA.szTip[ARRAY_COUNT(NIDA.szTip)-1]=0;
				Shell_NotifyIconA( NIM_MODIFY, &NIDA );
			}
			else
#endif
			{
				appStrncpy( NID.szTip, Text, ARRAY_COUNT(NID.szTip) );
#if UNICODE
				Shell_NotifyIconWX(NIM_MODIFY,&NID);
#else
				Shell_NotifyIconA(NIM_MODIFY,&NID);
#endif
			}
		}
		unguard;
	}
	void OnShowWindow( UBOOL bShow )
	{
		guard(WLog::OnShowWindow);
		WTerminal::OnShowWindow( bShow );
		if( bShow )
			ShowNewLines();
		unguard;
	}
	void OpenWindow( UBOOL bShow, UBOOL bMdi )
	{
		guard(WLog::OpenWindow);

		WTerminal::OpenWindow( bMdi, 0 );
		Show( bShow );
		UpdateWindow( *this );
		GLogHook = this;

		// Show dedicated server in tray.
		if( !GIsClient && !GIsEditor )
		{
			NID.cbSize           = sizeof(NID);
			NID.hWnd             = hWnd;
			NID.uID              = 0;
			NID.uFlags           = NIF_ICON | NIF_TIP | NIF_MESSAGE;
			NID.uCallbackMessage = NidMessage;
			NID.hIcon            = LoadIconIdX(hInstanceWindow,(GIsEditor?IDICON_Editor:IDICON_Mainframe));
			NID.szTip[0]         = 0;
#if UNICODE
			if( GUnicode && !GUnicodeOS )
			{
				NIDA.cbSize           = sizeof(NIDA);
				NIDA.hWnd             = hWnd;
				NIDA.uID              = 0;
				NIDA.uFlags           = NIF_ICON | NIF_TIP | NIF_MESSAGE;
				NIDA.uCallbackMessage = NidMessage;
				NIDA.hIcon            = LoadIconIdX(hInstanceWindow,(GIsEditor?IDICON_Editor:IDICON_Mainframe));
				NIDA.szTip[0]         = 0;
				Shell_NotifyIconA(NIM_ADD,&NIDA);
			}
			else
#endif
			{
#if UNICODE
				Shell_NotifyIconWX(NIM_ADD,&NID);
#else
				Shell_NotifyIconA(NIM_ADD,&NID);
#endif
			}
			GNotify = 1;
			atexit( GNotifyExit );
		}

		unguard;
	}
	void OnDestroy()
	{
		guard(WLog::OnDestroy);

		GLogHook = NULL;
		WTerminal::OnDestroy();

		unguard;
	}
	void OnCopyData( HWND hWndSender, COPYDATASTRUCT* CD )
	{
		guard(OnCopyData);
		if( Exec )
		{
			debugf( TEXT("WM_COPYDATA: %s"), (TCHAR*)CD->lpData );
			Exec->Exec( TEXT("TakeFocus"), *GLogWindow );
			TCHAR NewURL[1024];
			if
			(	ParseToken( (const TCHAR *&) *(TCHAR**)&CD->lpData,&NewURL[0], (INT)ARRAY_COUNT(NewURL),0)
			&&	NewURL[0]!='-')
				Exec->Exec( *(US+TEXT("Open ")+NewURL),*GLogWindow );
		}
		unguard;
	}
	void OnClose()
	{
		guard(WLog::OnClose);
		Show( 0 );
		throw TEXT("NoRoute");
		unguard;
	}
	void OnCommand( INT Command )
	{
		guard(WLog::OnCommand);
		if( Command==ID_LogFileExit || Command==ID_NotifyExit )
		{
			// Exit.
			debugf( TEXT("WLog::OnCommand %s"), Command==ID_LogFileExit ? TEXT("ID_LogFileExit") : TEXT("ID_NotifyExit") );
			appRequestExit( 0 );
		}
		else if( Command==ID_LogAdvancedOptions || Command==ID_NotifyAdvancedOptions )
		{
			// Advanced options.
			if( Exec )
				Exec->Exec( TEXT("PREFERENCES"), *GLogWindow );
		}
		else if( Command==ID_NotifyShowLog )
		{
			// Show log window.
			ShowWindow( hWnd, SW_SHOWNORMAL );
			SetForegroundWindow( hWnd );
		}
		unguard;
	}
	LONG WndProc( UINT Message, UINT wParam, LONG lParam )
	{
		guard(WLog::WndProc);
		if( Message==NidMessage )
		{
			if( lParam==WM_RBUTTONDOWN || lParam==WM_LBUTTONDOWN )
			{
				// Options.
				POINT P;
				::GetCursorPos( &P );
				HMENU hMenu = LoadLocalizedMenu( hInstanceWindow, IDMENU_NotifyIcon, TEXT("IDMENU_NotifyIcon"), TEXT("Window") );
				SetForegroundWindow( hWnd );
				TrackPopupMenu( GetSubMenu(hMenu,0), lParam==WM_LBUTTONDOWN ? TPM_LEFTBUTTON : TPM_RIGHTBUTTON, P.x, P.y, 0, hWnd, NULL );
				PostMessageX( hWnd, WM_NULL, 0, 0 );
			}
			return 1;
		}
		else return WWindow::WndProc( Message, wParam, lParam );
		unguard;
	}
};