#pragma once

#undef _MSC_EXTENSIONS

#define appMalloc(size)       GMalloc->Malloc(size,TEXT(""))
#define appFree(ptr)          GMalloc->Free(ptr)
#define debugf(t,...) (GLog->*Debugf)(t,__VA_ARGS__)
#define debugf_ansi(t) (GLog->*Debugf)(TEXT(t))
#define appFailAssert(a) (*AppFailAssert)(a,__FILE__,__LINE__)
#define appUnwindf(a,...) (*AppUnwindf)(a,##__VA_ARGS__)

#include "PlatformTypes.h"

extern DLLIMPORT class FMalloc* GMalloc;
extern DLLIMPORT class FOutputDevice* GLog;


//#include "Structs_UE1.h"

class  UObject;
class    AActor;
struct FVector;
struct FNameEntry;

namespace cg
{
	struct Vector;
	struct Integers;
}




#ifdef _MSC_VER
//***********************************************************************************
//Microsoft Visual C++ directives, done to avoid linking to new versions of C Runtime
//The only 'default' library to use should be VC++ 6.0 MSVCRT.LIB

extern "C" int _fltused;
extern "C" int __cdecl _purecall();

//#include <Windows.h>

extern "C" char16_t* __cdecl _itow( int32 Value, char16_t* Buf, int32 Radix);


//Import from Kernel32.dll
extern "C" void* __stdcall GetModuleHandleA( const char* lpModuleName);
extern "C" void* __stdcall GetProcAddress( void* hModule, const char* lpProcName);


#elif __MINGW32__
//***********************************************************************************
//MinGW directives, done to reduce compile times and assume conversions

extern "C" char16_t* __cdecl _itow( int32 Value, char16_t* Buf, int32 Radix);

//Import from Kernel32.dll
extern "C" void* __stdcall GetModuleHandleA( const char* lpModuleName);
extern "C" void* __stdcall GetProcAddress( void* hModule, const char* lpProcName);



#else
//***********************************************************************************
//Other directives, use standard functions

#endif




//***********************************************************************************
// Quick CheatEngine debugger helpers
class DebugToken
{
public:
	DebugToken( char C);
	~DebugToken();
};

class DebugLock
{
public:
	DebugLock( const char* Keyword, char Lock);
};

//***********************************************************************************
// Simple text parser and concatenator
class PlainText
{
	TCHAR* TAddr;
	uint32 Size;
public:
	PlainText();
	PlainText(const TCHAR* T);
	PlainText operator+ (const TCHAR* T);
	PlainText operator+ (UObject* O);
	PlainText operator+ (int32 N);
	PlainText operator+ (uint32 N);
	PlainText operator+ (float F);
	PlainText operator+ (const FVector& V);
	PlainText operator+ (const cg::Vector& V);
	PlainText operator+ (const cg::Integers& V);
	PlainText operator+ (const void* Ptr);

	const TCHAR* operator*();
	void Reset();
#if UNICODE
	char* Ansi();
#else
	char* Ansi() { return TAddr; };
#endif
};




//***********************************************************************************
//General methods
void* appMallocAligned( uint32 Size, uint32 Align);
void* appFreeAligned( void* Ptr);


enum EAlign { A_16 = 16 };
enum ESize
{	SIZE_Bytes = 0,
	SIZE_KBytes = 10,
	SIZE_MBytes = 20	};
enum EStack { E_Stack = 0 };


extern "C" void* memset ( void* ptr, int value, uint32 num );

void* operator new( uint32 Size);
void* operator new( uint32 Size, const TCHAR* Tag); //Allocate objects using UE1's allocator
void* operator new( uint32 Size, ESize Units, uint32 RealSize); //Allocate objects using additional memory (alignment optional)
void* operator new( uint32 Size, EAlign Tag );
void* operator new( uint32 Size, EAlign Tag, ESize Units, uint32 RealSize);

//Placement new
inline void* operator new( uint32 Size, void* Address, EStack Tag)
{
	return Address;
}

void CDECL operator delete(void *A);
void CDECL operator delete(void *A, unsigned int B);
void CDECL operator delete[](void *A);
void CDECL operator delete[](void *A, unsigned int B);



//Delete objects created with new(A_16)
#define Delete_A( A) if (A) { \
					A->Exit(); \
					appFreeAligned( (void*)A); \
					A = nullptr; }




//***********************************************************************************
//Unreal functions and macros 
extern bool DE LoadUE();
extern uint32 Loaded;

typedef void* (*vp_func_i) (int32);
extern vp_func_i GetIndexedObject;

typedef void (FOutputDevice::*v_foutputdevice_tcp_varg)(const TCHAR*,...);
extern v_foutputdevice_tcp_varg Debugf;

typedef void (VARARGS *v_func_acp_acp_i)(const char*, const char*, int32);
extern v_func_acp_acp_i AppFailAssert;

typedef void (VARARGS *v_func_tcp_varg)(const TCHAR* Fmt, ... );
extern v_func_tcp_varg AppUnwindf;

typedef int32 (AActor::*i_aactor_v)() const;
extern i_aactor_v IsMovingBrushFunc;

typedef FNameEntry*** fnametableppp_var;
extern FNameEntry*** Core_NameTable;


