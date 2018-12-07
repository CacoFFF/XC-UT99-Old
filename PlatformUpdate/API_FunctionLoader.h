/*=============================================================================
	API_FunctionLoader.h:
	Library loader helpers.
=============================================================================*/

#ifdef __GNUC__
	#include <dlfcn.h>
#endif

// Usually the cast<T> macro would work...
// But Visual Studio 2015 adds unnecessary memory assignments and breaks some of statics
// And MinGW doesn't like intel syntax too much
// Also, after an update VS 2015 makes member function pointers have wrong sizes

#ifdef _WINDOWS
	#ifdef __MINGW32__
		#define Get(dest,module,symbol) { void* A=GetProcAddress(module,symbol); \
										__asm__ ( "mov %%eax,(%%ecx)": : "a"(A), "c"(&dest) : "memory" ); }
	#else
		#define Get(dest,module,symbol) { void* A=GetProcAddress(module,symbol); __asm{ \
												__asm mov eax,A \
												__asm mov dest,eax } }
	#endif
#elif __GNUC__
	#define Get(dest,module,symbol) { void* A=dlsym(module,symbol); __asm__ ( "mov %%eax,(%%ecx)": : "a"(A), "c"(&dest) : "memory" ); }
#endif
