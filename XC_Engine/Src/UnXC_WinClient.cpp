
#include "XC_Engine.h"
#include "Cacus/CacusString.h"

#ifndef HID_USAGE_PAGE_GENERIC
	#define HID_USAGE_PAGE_GENERIC         ((USHORT) 0x01)
#endif
#ifndef HID_USAGE_GENERIC_MOUSE
	#define HID_USAGE_GENERIC_MOUSE        ((USHORT) 0x02)
#endif

static UXC_GameEngine* GEngine = nullptr;

static HMODULE hWinDrv = 0;
typedef LONG (UViewport::*ProcFunc)(UINT,UINT,LONG);
static ProcFunc hViewportWndProc = 0;



//This object appears to be a window that references the Windows Viewport
class DLL_EXPORT WWindowsViewportWindow_Hack : public WWindow
{
	W_DECLARE_CLASS(WWindowsViewportWindow_Hack,WWindow,CLASS_Transient)
	DECLARE_WINDOWCLASS(WWindowsViewportWindow_Hack,WWindow,Window)
	UViewport* Viewport;

	WWindowsViewportWindow_Hack()	{}

	virtual LONG WndProc( UINT Message, UINT wParam, LONG lParam )
	{
		//If this value is 0xFFFFFFFF, then capture is off (per WinViewport)
		//Disassembler marked it as X, next as Y... is it mouse coordinates?
		uint32 CaptureSwitch = *(uint32*)(((uint8*)Viewport) + 0x1C0);
		bool IsCaptured = CaptureSwitch != 0xFFFFFFFF;

		//Raw input capture ignores normal mouse movement
		if ( IsCaptured && (Message == WM_MOUSEMOVE) )
			return 0;

		//Raw input message
		if ( Message == WM_INPUT )
		{
			static RAWINPUT raw;
			uint32 dwSize = sizeof(raw);

			GetRawInputData((HRAWINPUT)lParam, RID_INPUT, &raw, (unsigned int*)&dwSize, sizeof(RAWINPUTHEADER));
			if ( raw.header.dwType == RIM_TYPEMOUSE )
			{
				if ( IsCaptured )
				{
					GEngine->MouseDelta( Viewport, raw.data.mouse.ulRawButtons, raw.data.mouse.lLastX, -raw.data.mouse.lLastY);
					if ( raw.data.mouse.lLastX )
						GEngine->InputEvent( Viewport, IK_MouseX, IST_Axis, raw.data.mouse.lLastX);
					if ( raw.data.mouse.lLastY )
						GEngine->InputEvent( Viewport, IK_MouseY, IST_Axis, -raw.data.mouse.lLastY);
				}
				if ( raw.data.mouse.ulButtons )
				{
					if ( raw.data.mouse.ulButtons & 64 ) //Back button press
						GEngine->InputEvent( Viewport, IK_Unknown05, IST_Press);
					if ( raw.data.mouse.ulButtons & 128 ) //Back button release
						GEngine->InputEvent( Viewport, IK_Unknown05, IST_Release);
					if ( raw.data.mouse.ulButtons & 256 ) //Forward button press
						GEngine->InputEvent( Viewport, IK_Unknown06, IST_Press);
					if ( raw.data.mouse.ulButtons & 512 ) //Forward button release
						GEngine->InputEvent( Viewport, IK_Unknown06, IST_Release);
				}
			}
			return 1;
		}

		//Normal code path
		return (Viewport->*hViewportWndProc)( Message, wParam, lParam );
	}
};

// Win32 optimization: skip an unnecessary jump instruction and go to aligned memory directly
static void SkipJump( void*& Addr) 
{
	uint8* AddrByte = (uint8*)Addr;
	if ( AddrByte++[0] == 0xE9 ) //Relative long jump
	{
		int32 Offset = *((int32*)AddrByte);
		AddrByte += 4;
		AddrByte += Offset;
		Addr = (void*)AddrByte;
	}
}

#define Get(dest,module,symbol) { void* A=GetProcAddress(module,symbol); SkipJump(A); __asm{ \
												__asm mov eax,A \
												__asm lea ecx,dest \
												__asm mov [ecx],eax } }

void LoadViewportHack( UXC_GameEngine* InEngine)
{
	debugf( NAME_Init, TEXT("Applying raw input hook..."));
	GEngine = InEngine;

	guard(GetHandles)
		hWinDrv = LoadLibraryA("WinDrv.dll");
		check(hWinDrv);
		Get( hViewportWndProc, hWinDrv, "?ViewportWndProc@UWindowsViewport@@QAEJIIJ@Z");
		check(hViewportWndProc);
	unguard

	WWindowsViewportWindow_Hack WndTest;
	HWND WindowHandle = 0;
	guard(GetViewport)
		TCHAR NameBuffer[256];
		for ( INT i=0 ; i<WWindow::_Windows.Num() ; i++ )
		{
			WWindow* W = WWindow::_Windows(i);
			W->GetWindowClassName( NameBuffer);
//			debugf( NAME_Init, TEXT("Found window: %s"), NameBuffer);
			if ( CStrstr( NameBuffer, TEXT("WWindowsViewportWindow")) ) //Wtf is wrong with appStrfind?
			{
				((size_t*)W)[0] = ((size_t*)&WndTest)[0];
				WindowHandle = W->hWnd;
				break;
			}
		}
		check(WindowHandle);
	unguard

	guard(RegisterRawDevice)
		RAWINPUTDEVICE rDevices[1];
		rDevices[0].usUsagePage = HID_USAGE_PAGE_GENERIC;
		rDevices[0].usUsage     = HID_USAGE_GENERIC_MOUSE;
		rDevices[0].dwFlags     = RIDEV_INPUTSINK;
		rDevices[0].hwndTarget  = WindowHandle;
		RegisterRawInputDevices( rDevices, 1, sizeof(rDevices[0]) );
	unguard
}
