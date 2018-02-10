/**
	API_MSC.cpp
	Author: Fernando Velázquez

	Microsoft Visual Studio 2015 specific code.
	The purpose of this is to eliminate superfluous code,
	linking, globals and ultimately reducing DLL size.
	
	The trick consists on dynamically linking against MSVCRT.LIB
	from Microsoft Visual C++ 6 and patching any missing stuff
	the new compiler wants to add to it.
	
	The downside is that exception handlers cannot be used.
	For that reason workarounds such as using CheatEngine have
	to be used when an exception is thrown in Unreal Engine.
*/


#include "API.h"

extern "C" int _fltused = 0x9875;

extern "C" int __cdecl _purecall()
{
	return 0;
}

extern "C" void __declspec(dllimport) *__CxxFrameHandler;

extern "C" void  __declspec(naked) __CxxFrameHandler3(void)
{
	// Jump indirect: Jumps to __CxxFrameHandler
	_asm jmp __CxxFrameHandler ; Trampoline bounce
}


uint32 __stdcall DllMain( void* hinstDLL, uint32 fdwReason, void* lpReserved )
{
	// Perform actions based on the reason for calling.
/*	switch( fdwReason ) 
	{ 
	case DLL_PROCESS_ATTACH:
		// Initialize once for each new process.
		// Return FALSE to fail DLL load.
		break;

	case DLL_THREAD_ATTACH:
		// Do thread-specific initialization.
		break;

	case DLL_THREAD_DETACH:
		// Do thread-specific cleanup.
		break;

	case DLL_PROCESS_DETACH:
		// Perform any necessary cleanup.
		break;
	}
	return TRUE;  // Successful DLL_PROCESS_ATTACH.*/
	return 1;
}
