#pragma once

#define STDCALL
#define VARARGS
#define CDECL
#define FORCEINLINE


// Sizes.
enum { DEFAULT_ALIGNMENT = 8 }; // Default boundary to align memory allocations on.
enum { CACHE_LINE_SIZE = 32 }; // Cache line size.
#define GCC_PACK(n) 
//__attribute__((packed,aligned(n)))
#define GCC_ALIGN(n) __attribute__((aligned(n)))
#define MS_ALIGN(n) 
#define GCC_STACK_ALIGN __attribute__((force_align_arg_pointer))

#if __GNUC__ >= 4
	#define DLLIMPORT	__attribute__ ((visibility ("default")))
	#define TEST_EXPORT	extern "C" __attribute__ ((visibility ("default"))) 
#else
	#define DLLIMPORT 
	#define TEST_EXPORT	extern "C"
#endif
#define TEXT(str) str

#define DISABLE_OPTIMIZATION
#define ENABLE_OPTIMIZATION

#if UNICODE
	#error "SO should have UNICODE=OFF"
#endif
