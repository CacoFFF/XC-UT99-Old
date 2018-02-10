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

#include <setjmp.h>
struct jmp_buf_wrapper
{
	jmp_buf buf;
};

//Import
class __Context
{
public:
	__Context() { *(jmp_buf_wrapper*)&Last = *(jmp_buf_wrapper*)&Env; }
	~__Context() { *(jmp_buf_wrapper*)&Env = *(jmp_buf_wrapper*)&Last; }
	__attribute__ ((visibility ("default"))) static jmp_buf Env __asm__("_9__Context.Env");
protected:
	jmp_buf Last;
};

#define guard(func)			{static const TCHAR __FUNC_NAME__[]=TEXT(#func); \
									__Context __LOCAL_CONTEXT__; try{ \
									if(setjmp(__Context::Env)) { throw 1; } else {
#define unguard				}}catch(char*Err){throw Err;}catch(...) \
									{appUnwindf(TEXT("%s"),__FUNC_NAME__); throw 1;}}
#define unguardf(msg)		}}catch(char*Err){throw Err;}catch(...) \
									{appUnwindf(TEXT("%s"),__FUNC_NAME__); \
									appUnwindf msg; throw;}}


