/*=============================================================================
	LinuxGCC.h
	Author: Fernando Velázquez
	
	Platform header for Linux GCC.
	This is designed to make packages built using this compiler to be
	compatible with old GCC 2.9 builds.
	If the target is a game built using GCC >= 3 then use another header.
=============================================================================*/

#pragma once

#define __LINUX_X86__ 1

#define __UNIX__  1
#define __LINUX__ 1
#define __INTEL__ 1
#define __INTEL_BYTE_ORDER__ 1
#undef ASM
#undef ASM3DNOW
#undef ASMKNI
#define ASMLINUX 1

#include "PlatformTypes.h"

//Naming convention fix
#if __GNUC__ >= 3
	#define LINUX_SYMBOL(t) __asm__(#t)
#else
	#define LINUX_SYMBOL(t)  
#endif

#if __GNUC__ >= 4
	#define DLL_IMPORT	__attribute__ ((visibility ("default")))
	#define DLL_EXPORT	extern "C" __attribute__ ((visibility ("default"))) 
#else
	#define DLL_IMPORT 
	#define DLL_EXPORT	extern "C"
#endif

// Stack control.
#include <sys/wait.h>
#include <signal.h>
#include <setjmp.h>

struct jmp_buf_wrapper
{
	jmp_buf buf;
};

class __Context
{
public:
	__Context()
	{
		*(jmp_buf_wrapper*)&Last = *(jmp_buf_wrapper*)&Env;
	}

	~__Context()
	{
		*(jmp_buf_wrapper*)&Env = *(jmp_buf_wrapper*)&Last;
	}

	static DLL_IMPORT void StaticInit()       LINUX_SYMBOL(StaticInit__9__Context);
	static DLL_IMPORT jmp_buf Env             LINUX_SYMBOL(_9__Context.Env);

protected:
	static void HandleSignal( int Sig )      LINUX_SYMBOL(HandleSignal__9__Contexti);
	static struct sigaction Act_SIGHUP       LINUX_SYMBOL(_9__Context.Act_SIGHUP);
	static struct sigaction Act_SIGQUIT      LINUX_SYMBOL(_9__Context.Act_SIGQUIT);
	static struct sigaction Act_SIGILL       LINUX_SYMBOL(_9__Context.Act_SIGILL);
	static struct sigaction Act_SIGTRAP      LINUX_SYMBOL(_9__Context.Act_SIGTRAP);
	static struct sigaction Act_SIGIOT       LINUX_SYMBOL(_9__Context.Act_SIGIOT);
	static struct sigaction Act_SIGBUS       LINUX_SYMBOL(_9__Context.Act_SIGBUS);
	static struct sigaction Act_SIGFPE       LINUX_SYMBOL(_9__Context.Act_SIGFPE);
	static struct sigaction Act_SIGSEGV      LINUX_SYMBOL(_9__Context.Act_SIGSEGV);
	static struct sigaction Act_SIGTERM      LINUX_SYMBOL(_9__Context.Act_SIGTERM);
	jmp_buf Last;
};

class UClass;
#define STATIC_CLASS(class) &class##_StaticClass
DLL_IMPORT UClass UObject_StaticClass LINUX_SYMBOL(_7UObject.PrivateStaticClass);


// Sizes.
enum { DEFAULT_ALIGNMENT = 8 }; // Default boundary to align memory allocations on.
enum { CACHE_LINE_SIZE = 32 }; // Cache line size.

//#define GCC_PACK(n)  __attribute__((packed,aligned(n)))
#define GCC_PACK(n) 
#define GCC_ALIGN(n) __attribute__((aligned(n)))
#define MS_ALIGN(n) 
#define GCC_STACK_ALIGN __attribute__((force_align_arg_pointer))

// Optimization macros
#define DISABLE_OPTIMIZATION
#define ENABLE_OPTIMIZATION
 
 // Function type macros.
#define DLL_EXPORT_CLASS
#define VARARGS
#define CDECL
#define STDCALL
#define FORCEINLINE /* Force code to be inline */
#define ZEROARRAY 0 /* Zero-length arrays in structs */
#define __cdecl

#if UNICODE
	#error "SO should have UNICODE=OFF"
#endif

// Variable arguments.
#define GET_VARARGS(msg,len,fmt)	\
{	\
	va_list ArgPtr;	\
	va_start( ArgPtr, fmt );	\
	vsprintf( msg, fmt, ArgPtr );	\
	va_end( ArgPtr );	\
}
 
#define GET_VARARGS_RESULT(msg,len,fmt,result)	\
{	\
	va_list ArgPtr;	\
	va_start( ArgPtr, fmt );	\
	result = vsprintf( msg, fmt, ArgPtr );	\
	va_end( ArgPtr );	\
}
 
// Compiler name.
#define COMPILER "Compiled with GNU g++ (" __VERSION__ ")"

// Make sure characters are unsigned.
#ifdef __CHAR_UNSIGNED__
	#error "Bad compiler option: Characters must be signed"
#endif
 
// Strings.
#if __UNIX__
#define LINE_TERMINATOR TEXT("\n")
#define PATH_SEPARATOR TEXT("/")
#define DLLEXT TEXT(".so")
#else
#define LINE_TERMINATOR TEXT("\r\n")
#define PATH_SEPARATOR TEXT("\\")
#define DLLEXT TEXT(".dll")
#endif
 
// NULL.
#undef NULL
#define NULL 0
 
// Package implementation.
#define IMPLEMENT_PACKAGE_PLATFORM(pkgname) \
	extern "C" {void* hInstance;} \
	BYTE GLoaded##pkgname;
 
// Platform support options.
#define PLATFORM_NEEDS_ARRAY_NEW 1
#define FORCE_ANSI_LOG           0
 
// OS unicode function calling.
#define TCHAR_CALL_OS(funcW,funcA) (funcA)
#define TCHAR_TO_ANSI(str) str
#define ANSI_TO_TCHAR(str) str
 
// !! Fixme: This is a workaround.
#define GCC_OPT_INLINE
 
// Memory
#define appAlloca(size) alloca((size+7)&~7)
 
extern CORE_API UBOOL GTimestamp;
CORE_API extern	FLOAT GSecondsPerCycle;
CORE_API FTime appSecondsSlow();
 
//
// Round a floating point number to an integer.
// Note that (int+.5) is rounded to (int+1).
//
#define DEFINED_appRound 1
inline INT appRound( FLOAT F )
{
	return (INT)(F);
}
 
//
// Converts to integer equal to or less than.
//
#define DEFINED_appFloor 1
inline INT appFloor( FLOAT F )
{
	static FLOAT Half=0.5;
	return (INT)(F - Half);
}
 
//
// CPU cycles, related to GSecondsPerCycle.
// //DEPRECATE THIS ASAP
#define DEFINED_appCycles 1
inline DWORD appCycles()
{
	DWORD r = 0;
	asm("rdtsc" : "=a" (r) : "d" (r));
	return r;
}

#if ASMLINUX
#define DEFINED_appSeconds 1
inline FTime appSeconds()
{
	if ( GTimestamp )
	{
		DWORD L, H;
		asm("rdtsc" : "=a" (L), "=d" (H));
		return ((double)L + 4294967296.0 * (double)H) * GSecondsPerCycle;
	}
	else
		return appSecondsSlow();
}
#endif

//
// Memory copy.
//
#define DEFINED_appMemcpy 1
inline void appMemcpy( void* Dest, const void* Src, INT Count )
{
	asm volatile(
		"pushl %%ebx \n"
		"pushl %%ecx \n"
		"pushl %%esi \n"
		"pushl %%edi \n"
		"mov %%ecx, %%ebx \n"
		"shr $2, %%ecx \n"
		"and $3, %%ebx \n"
		"rep \n"
		"movsl \n"
		"mov %%ebx, %%ecx \n"
		"rep \n"
		"movsb \n"
		"popl %%edi \n"
		"popl %%esi \n"
		"popl %%ecx \n"
		"popl %%ebx \n"
	:
	: "S" (Src),
	  "D" (Dest),
	  "c" (Count)
	);
}
 
//
// Memory zero.
//
#define DEFINED_appMemzero 1
inline void appMemzero( void* Dest, INT Count )
{
	asm volatile(
		"pushl %%ebx \n"
		"pushl %%ecx \n"
		"pushl %%eax \n"
		"pushl %%edi \n"
		"xor %%eax,%%eax \n"
		"mov %%ecx, %%ebx \n"
		"shr $2, %%ecx \n"
		"and $3, %%ebx \n"
		"rep \n"
		"stosl \n"
		"mov %%ebx, %%ecx \n"
		"rep \n"
		"stosb \n"
		"popl %%edi \n"
		"popl %%eax \n"
		"popl %%ecx \n"
		"popl %%ebx \n"
	:
	: "D" (Dest),
	  "c" (Count)
	);

//	memset( Dest, 0, Count );
}

/*----------------------------------------------------------------------------
	Fix for VTables in Linux.
----------------------------------------------------------------------------*/

#define VIRTUAL_DESTRUCTOR(n) virtual void SimulatedDestructor()
#define UOBJECT_DESTRUCT ((UObject*)Object)->SimulatedDestructor();
#define GNU_VTABLE_FIX : public GNUFix 
class GNUFix
{
	virtual void vPad1() {};
	virtual void vPad2() {};
};

/*----------------------------------------------------------------------------
	Globals.
----------------------------------------------------------------------------*/
 
// System identification.
extern "C"
{
	extern void*      hInstance;
	extern CORE_API UBOOL GIsMMX;
	extern CORE_API UBOOL GIsPentiumPro;
	extern CORE_API UBOOL GIsKatmai;
	extern CORE_API UBOOL GIsK6;
	extern CORE_API UBOOL GIs3DNow;
}
 
// Module name
extern ANSICHAR GModule[32];
 
/*----------------------------------------------------------------------------
 
	The End.
----------------------------------------------------------------------------*/


/*
#define guard(func)			{static const TCHAR __FUNC_NAME__[]=TEXT(#func); \
									__Context __LOCAL_CONTEXT__; try{ \
									if(setjmp(__Context::Env)) { throw 1; } else {
#define unguard				}}catch(char*Err){throw Err;}catch(...) \
									{appUnwindf(TEXT("%s"),__FUNC_NAME__); throw 1;}}
#define unguardf(msg)		}}catch(char*Err){throw Err;}catch(...) \
									{appUnwindf(TEXT("%s"),__FUNC_NAME__); \
									appUnwindf msg; throw;}}

*/
