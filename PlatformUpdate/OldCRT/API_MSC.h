/**
	API_MSC.h
	Author: Fernando Velázquez

	Microsoft Visual Studio 2015 specific code.
	The purpose of this is to eliminate superfluous code,
	linking, globals and ultimately reducing DLL size.
	
	The trick consists on dynamically linking against MSVCRT.LIB
	from Microsoft Visual C++ 6 and patching any missing stuff
	the new compiler wants to add to it.

	This file must be included once.
*/

#pragma comment (lib, "..\\PlatformUpdate\\OldCRT\\MSVCRT.LIB")
#pragma comment (linker, "/NODEFAULTLIB:msvcrt.lib")
#pragma comment (linker, "/merge:.CRT=.rdata")

extern "C"
{

/*int __cdecl _purecall()
{
	return 0;
}*/


void __declspec(dllimport) *__CxxFrameHandler;
void  __declspec(naked) __CxxFrameHandler3(void)
{
	// Jump indirect: Jumps to __CxxFrameHandler
	_asm jmp __CxxFrameHandler ; Trampoline bounce
}

#if defined(_INC_STDIO) && defined(_NO_CRT_STDIO_INLINE)
	#undef stdin
	#undef stdout
	#undef stderr
	extern FILE *_imp___iob;
	#define stdin  (&_imp___iob[0])
	#define stdout (&_imp___iob[1])
	#define stderr (&_imp___iob[2]) 
#endif

//Conversion of double to int64 >> hardcoded by compiler
void __declspec(naked) _ftol2_sse()
{
	__asm
	{
		push    ebp
		mov     ebp, esp
		sub     esp, 8
		and     esp, 0FFFFFFF8h
		fstp    [esp]
		cvttsd2si eax, [esp]
		leave
		retn
	}
}

void __declspec(naked) _ftol2()
{
	__asm jmp _ftol2_sse ; //Bounce
}


/*
double __declspec(naked) _ltod3( __int64 v)
{
	__asm
	{
		xorps    xmm1, xmm1
		cvtsi2sd xmm1, edx
		xorps   xmm0, xmm0
		cvtsi2sd xmm0, ecx
		shr     ecx, 1Fh
		mulsd   xmm1, DP2to32
		addsd   xmm0, ds:_Int32ToUInt32[ecx*8]
		addsd   xmm0, xmm1
		retn
	}
}
*/

}