/*=============================================================================
	WindowsVC140.h
	Author: Fernando Velázquez
	
	Platform header for Visual C++ 2015 (may work for other versions).
=============================================================================*/

#define __WIN32__				1
#define __INTEL__				1
#define __INTEL_BYTE_ORDER__	1

#ifndef _WINDOWS
	#define _WINDOWS 1
#endif

#if !UNICODE
	#error "DLL should have UNICODE=ON"
#endif

#include <windows.h>


#include "PlatformTypes.h"

// Sizes.
enum {DEFAULT_ALIGNMENT = 8 }; // Default boundary to align memory allocations on.
enum {CACHE_LINE_SIZE   = 32}; // Cache line size.

// Optimization macros (preceeded by #pragma).
#define DISABLE_OPTIMIZATION optimize("",off)
#define ENABLE_OPTIMIZATION  optimize("",on)

// Function type macros.
#define DLL_IMPORT	__declspec(dllimport)	/* Import function from DLL */
#define DLL_EXPORT  __declspec(dllexport)	/* Export function to DLL */
#define DLL_EXPORT_CLASS	__declspec(dllexport)	/* Export class to DLL */
#define VARARGS     __cdecl					/* Functions with variable arguments */
#define CDECL	    __cdecl					/* Standard C function */
#define STDCALL		__stdcall				/* Standard calling convention */
#define FORCEINLINE __forceinline			/* Force code to be inline */
#define ZEROARRAY                           /* Zero-length arrays in structs */

// Variable arguments.
#define GET_VARARGS(msg,len,fmt) appGetVarArgs(msg,len,fmt)

// Compiler name.
#ifdef _DEBUG
	#define COMPILER "Compiled with Visual C++ Debug"
#else
	#define COMPILER "Compiled with Visual C++"
#endif

// Unwanted VC++ level 4 warnings to disable.
#pragma warning(disable : 4305) /* truncation from 'const double' to 'float'                            */
#pragma warning(disable : 4244) /* conversion to float, possible loss of data							*/
#pragma warning(disable : 4699) /* creating precompiled header											*/
#pragma warning(disable : 4200) /* Zero-length array item at end of structure, a VC-specific extension	*/
#pragma warning(disable : 4100) /* unreferenced formal parameter										*/
#pragma warning(disable : 4514) /* unreferenced inline function has been removed						*/
#pragma warning(disable : 4201) /* nonstandard extension used : nameless struct/union					*/
#pragma warning(disable : 4710) /* inline function not expanded											*/
#pragma warning(disable : 4702) /* unreachable code in inline expanded function							*/
#pragma warning(disable : 4711) /* function selected for autmatic inlining								*/
#pragma warning(disable : 4725) /* Pentium fdiv bug														*/
#pragma warning(disable : 4127) /* Conditional expression is constant									*/
#pragma warning(disable : 4512) /* assignment operator could not be generated                           */
#pragma warning(disable : 4530) /* C++ exception handler used, but unwind semantics are not enabled     */
#pragma warning(disable : 4245) /* conversion from 'enum ' to 'unsigned long', signed/unsigned mismatch */
#pragma warning(disable : 4238) /* nonstandard extension used : class rvalue used as lvalue             */
#pragma warning(disable : 4251) /* needs to have dll-interface to be used by clients of class 'ULinker' */
#pragma warning(disable : 4275) /* non dll-interface class used as base for dll-interface class         */
#pragma warning(disable : 4511) /* copy constructor could not be generated                              */
#pragma warning(disable : 4284) /* return type is not a UDT or reference to a UDT                       */
#pragma warning(disable : 4355) /* this used in base initializer list                                   */
#pragma warning(disable : 4097) /* typedef-name '' used as synonym for class-name ''                    */
#pragma warning(disable : 4291) /* typedef-name '' used as synonym for class-name ''                    */

//Visual Studio 2015 directives (Higor)
#pragma warning (disable : 4595) //Allow inline constructors and destructors (VS2015 update 2 bug)
#pragma warning (disable : 4456) //Allow functions to override global variable names
#pragma warning (disable : 4457) //Allow functions to override global variable names
#pragma warning (disable : 4458) //Allow functions to override global variable names
#pragma warning (disable : 4459) //Allow functions to override global variable names
#pragma warning (disable : 4297) //Constructors and destructors allowed to throw
#define _CRT_SECURE_NO_WARNINGS //Because older string methods are no longer used

#pragma warning (disable : 4714) //Allow forceinline to fail
#pragma warning (disable : 4706) //Allow assignment within conditional expression

// If C++ exception handling is disabled, force guarding to be off.
#ifndef _CPPUNWIND
	#if _MSC_VER < 1300
		#error "Bad VCC option: C++ exception handling must be enabled"
	#endif
#endif

// Make sure characters are unsigned.
#ifdef _CHAR_UNSIGNED
	#error "Bad VC++ option: Characters must be signed"
#endif
#ifndef _M_IX86
	#error "Bad VCC option: target must be x86"
#endif

// Strings.
#define LINE_TERMINATOR TEXT("\r\n")
#define PATH_SEPARATOR TEXT("\\")

// DLL file extension.
#define DLLEXT TEXT(".dll")

// Pathnames.
#define PATH(s) s

// NULL.
#define NULL 0

// Package implementation.
#define IMPLEMENT_PACKAGE_PLATFORM(pkgname) \
	extern "C" {HINSTANCE hInstance;} \
	INT DLL_EXPORT STDCALL DllMain( HINSTANCE hInInstance, DWORD Reason, void* Reserved ) \
	{ hInstance = hInInstance; return 1; }

// Platform support options.
#define PLATFORM_NEEDS_ARRAY_NEW 1
#define FORCE_ANSI_LOG           1

// OS unicode function calling.
CORE_API ANSICHAR* winToANSI( ANSICHAR* ACh, const UNICHAR* InUCh, INT Count );
CORE_API INT winGetSizeANSI( const UNICHAR* InUCh );
CORE_API UNICHAR* winToUNICODE( UNICHAR* Ch, const ANSICHAR* InUCh, INT Count );
CORE_API INT winGetSizeUNICODE( const ANSICHAR* InACh );
#define TCHAR_CALL_OS(funcW,funcA) (GUnicodeOS ? (funcW) : (funcA))
//#define TCHAR_TO_ANSI(str) winToANSI((char*)appAlloca(winGetSizeANSI(str)),str,winGetSizeANSI(str))
#define TCHAR_TO_OEM(str) winToOEM((char*)appAlloca(winGetSizeANSI(str)),str,winGetSizeANSI(str))
//#define ANSI_TO_TCHAR(str) winToUNICODE((TCHAR*)appAlloca(winGetSizeUNICODE(str)*sizeof(TCHAR)),str,winGetSizeUNICODE(str))

// Bitfield alignment.
#define GCC_PACK(n)
#define GCC_ALIGN(n)
#define GCC_BITFIELD_MAGIC
#define MS_ALIGN(n) __declspec(align(n))
#define GCC_STACK_ALIGN
#define LINUX_SYMBOL(t) 

/*----------------------------------------------------------------------------
	Globals.
----------------------------------------------------------------------------*/

// System identification.
extern "C"
{
	extern HINSTANCE      hInstance;
	extern CORE_API UBOOL GIsMMX;
	extern CORE_API UBOOL GIsPentiumPro;
	extern CORE_API UBOOL GIsKatmai;
	extern CORE_API UBOOL GIsK6;
	extern CORE_API UBOOL GIs3DNow;
	extern CORE_API UBOOL GTimestamp;
}

/*----------------------------------------------------------------------------
	Functions.
----------------------------------------------------------------------------*/

#include "Cacus/CacusString.h"

// Cacus unicode handlers
inline ANSICHAR* TCHAR_TO_ANSI( const TCHAR* Src)
{
	size_t Len = CStrlen(Src);
	ANSICHAR* Result = CharBuffer<ANSICHAR>( Len+1);
	CStrcpy_s( Result, Len+1, Src);
	return Result;
}
inline TCHAR* ANSI_TO_TCHAR( const ANSICHAR* Src)
{
	size_t Len = CStrlen(Src);
	TCHAR* Result = CharBuffer<TCHAR>( Len+1);
	CStrcpy_s( Result, Len+1, Src);
	return Result;
}


#define DEFINED_appRound 1
inline int32 appRound( float F )
{
	__asm cvtss2si eax,[F]
	// return value in eax.
}
inline int32 appRound( double F )
{
	__asm cvtsd2si eax,[F]
		// return value in eax.
}

#define DEFINED_appFloor 1
inline int32 appFloor( float F )
{
	const uint32 mxcsr_floor = 0x00003f80;
	const uint32 mxcsr_default = 0x00001f80;

	__asm ldmxcsr [mxcsr_floor]		// Round toward -infinity.
	__asm cvtss2si eax,[F]
	__asm ldmxcsr [mxcsr_default]	// Round to nearest
	// return value in eax.
}

//
// Seconds, arbitrarily based.
// Cycles
//
#define DEFINED_appSeconds 1
#define DEFINED_appCycles 1

#pragma warning (push)
#pragma warning (disable : 4035)
#pragma warning (disable : 4715)
extern CORE_API FLOAT GSecondsPerCycle;
inline double appSeconds()
{
	uint32 L,H;
	__asm
	{
		rdtsc				// RDTSC  -  Pentium+ time stamp register to EDX:EAX.
		mov   [L],eax		// Save low value.
		mov   [H],edx		// Save high value.
	}
	return ((double)L +  4294967296.0 * (double)H) * GSecondsPerCycle;
}
inline DWORD appCycles() { __asm { rdtsc } }
#pragma warning (pop)


#define DEFINED_appMemcpy
inline void appMemcpy( void* Dest, const void* Src, INT Count )
{	
	__asm
	{
		mov		ecx, Count
		mov		esi, Src
		mov		edi, Dest
		mov     ebx, ecx
		shr     ecx, 2
		and     ebx, 3
		rep     movsd
		mov     ecx, ebx
		rep     movsb
	}
}

#define DEFINED_appMemzero
inline void appMemzero( void* Dest, INT Count )
{	
	__asm
	{
		mov		ecx, [Count]
		mov		edi, [Dest]
		xor     eax, eax
		mov		ebx, ecx
		shr		ecx, 2
		and		ebx, 3
		rep     stosd
		mov     ecx, ebx
		rep     stosb
	}
}

#if ASM3DNOW
inline void DoFemms()
{
	__asm _emit 0x0f
	__asm _emit 0x0e
}
#endif

extern "C" void* __cdecl _alloca(size_t);
//#define appAlloca(size) _alloca((size+7)&~7)
#define appAlloca(size) ((size==0) ? 0 : _alloca((size+7)&~7))
