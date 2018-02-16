//
// Get all of Unreal Engine 1's necessary imports
//

#include "API.h"

uint32 Loaded = 0;

vp_func_i                    GetIndexedObject    = nullptr;
v_foutputdevice_tcp_varg     Debugf              = nullptr;
v_func_acp_acp_i             AppFailAssert       = nullptr;
v_func_tcp_varg              AppUnwindf          = nullptr;
i_aactor_v                   IsMovingBrushFunc   = nullptr;
FNameEntry***                Core_NameTable      = nullptr;
/*
static_assert( sizeof(GetIndexedObject) == 4, "Wrong size of GetIndexedObject pointer");
static_assert( sizeof(Debugf) == 4, "Wrong size of Debugf pointer");
static_assert( sizeof(AppFailAssert) == 4, "Wrong size of AppFailAssert pointer");
static_assert( sizeof(IsMovingBrushFunc) == 4, "Wrong size of IsMovingBrushFunc pointer");
static_assert( sizeof(Core_GLog) == 4, "Wrong size of Core_GLog pointer");
static_assert( sizeof(Core_NameTable) == 4, "Wrong size of Core_NameTable pointer");
static_assert( sizeof(Core_GMalloc) == 4, "Wrong size of Debugf Core_GMalloc");
*/

//#include <Windows.h>


#ifdef __GNUC__
	#include <dlfcn.h>
#endif

// Win32 optimization: skip an unnecessary jump instruction and go to aligned memory directly
#ifdef _WINDOWS
static void SkipJump( void*& Addr) 
{
	uint8* AddrByte = (uint8*)Addr;
	if ( AddrByte++[0] == 0xE9 ) //Relative long jump
	{
		int32 Offset = *((int32*)AddrByte);
		AddrByte += 4;
		AddrByte += Offset;
		Addr = (void*)AddrByte;
	}
}
#endif

bool LoadUE()
{
#ifdef _WINDOWS
	// Usually the cast<T> macro would work...
	// But Visual Studio 2015 adds unnecessary memory assignments and breaks some of statics
	// And MinGW doesn't like intel syntax too much
	// Also, after an update VS 2015 makes member function pointers have wrong sizes
	#ifdef __MINGW32__
		#define Get(dest,module,symbol) { void* A=GetProcAddress(module,symbol); \
										__asm__ ( "mov %%eax,(%%ecx)": : "a"(A), "c"(&dest) : "memory" ); }
		#define GetF(dest,module,symbol) { void* A=GetProcAddress(module,symbol); \
										 SkipJump(A); \
										__asm__ ( "mov %%eax,(%%ecx)": : "a"(A), "c"(&dest) : "memory" ); }
	#else
		#define Get(dest,module,symbol) { void* A=GetProcAddress(module,symbol); __asm{ \
												__asm mov eax,A \
												__asm mov dest,eax } }
		#define GetF(dest,module,symbol) { void* A=GetProcAddress(module,symbol); SkipJump(A); __asm{ \
												__asm mov eax,A \
												__asm lea ecx,dest \
												__asm mov [ecx],eax } }
	#endif

	{
		void* hCore = GetModuleHandleA( "Core.dll");
		void* hEngine = GetModuleHandleA( "Engine.dll");
		GetF( GetIndexedObject , hCore  , "?GetIndexedObject@UObject@@SAPAV1@H@Z");
		GetF( Debugf           , hCore  , "?Logf@FOutputDevice@@QAAXPBGZZ"        );
		GetF( AppFailAssert    , hCore  , "?appFailAssert@@YAXPBD0H@Z"           );
		GetF( AppUnwindf       , hCore  , "?appUnwindf@@YAXPBGZZ"                );
		Get ( Core_NameTable   , hCore  , "?Names@FName@@0V?$TArray@PAUFNameEntry@@@@A");
		GetF( IsMovingBrushFunc, hEngine, "?IsMovingBrush@AActor@@QBEHXZ"        ); 
	}

#elif __GNUC__
	void* h = dlopen( nullptr, RTLD_NOW | RTLD_GLOBAL);
#define Get(dest,symbol) { void* A=dlsym(h,symbol); __asm__ ( "mov %%eax,(%%ecx)": : "a"(A), "c"(&dest) : "memory" ); }
	Get( GetIndexedObject , "GetIndexedObject__7UObjecti");
	Get( Debugf           , "Logf__13FOutputDevicePCce"  );
	Get( AppFailAssert    , "appFailAssert__FPCcT0i"     );
	Get( AppUnwindf       , "appUnwindf__FPCce"          );
	Get( Core_NameTable   , "_5FName.Names"              );
	Get( IsMovingBrushFunc, "IsMovingBrush__C6AActor"    );
#endif

	Loaded++;
	return GetIndexedObject && Debugf && AppFailAssert && AppUnwindf && Core_NameTable && IsMovingBrushFunc;
}

