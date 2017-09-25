#pragma once

#define STDCALL __stdcall
#define VARARGS __cdecl
#define CDECL __cdecl
#define FORCEINLINE __forceinline

// Bitfield alignment.
#define GCC_BITFIELD_MAGIC

#define DLLIMPORT __declspec(dllimport)
#define TEST_EXPORT __declspec(dllexport)
#define TEXT(str) u##str


//Unicode is set to match UE1's windows Unicode build
#if !UNICODE
	#error "DLL should have UNICODE=ON"
#endif


//Prefferably we want this compiled using an open source compiler
//Should be at least 1900 (VS 2015) if we're using Visual Studio
#ifdef _MSC_VER

	#define MS_ALIGN(n) __declspec(align(n))
	#define GCC_PACK(n)
	#define GCC_ALIGN(n)
	#define GCC_STACK_ALIGN

	#pragma warning(disable : 4100) //'[___]': unreferenced formal parameter
	#pragma warning(disable : 4201) //nonstandard extension used: nameless struct/union
	#pragma warning(disable : 4244) //'initializing': conversion from '[___]' to '[___]', possible loss of data
	#pragma warning(disable : 4324) //'[___]': structure was padded due to alignment specifier

	#define DISABLE_OPTIMIZATION optimize("",off)
	#define ENABLE_OPTIMIZATION  optimize("",on)

#elif __MINGW32__

	#define GCC_PACK(n) 
	#define GCC_ALIGN(n) __attribute__((aligned(n)))
	#define GCC_STACK_ALIGN __attribute__((force_align_arg_pointer))
	#define MS_ALIGN(n) 
	#define DISABLE_OPTIMIZATION
	#define ENABLE_OPTIMIZATION

#endif
