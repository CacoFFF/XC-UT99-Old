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

