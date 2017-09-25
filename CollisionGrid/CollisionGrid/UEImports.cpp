//
// Get all of Unreal Engine 1's necessary imports
//

#include "API.h"

uint32 Loaded = 0;

vp_func_i                    GetIndexedObject    = nullptr;
v_foutputdevice_func_tcp     Debugf              = nullptr;
v_func_acp_acp_i             AppFailAssert       = nullptr;
i_aactor_v                   IsMovingBrushFunc   = nullptr;
FOutputDevice**              Core_GLog           = nullptr;
FNameEntry***                Core_NameTable      = nullptr;
FMalloc**                    Core_GMalloc        = nullptr;

typedef FMalloc** fmallocpp_var;

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
												__asm mov dest,eax } }
	#endif

	{
		void* hCore = GetModuleHandleA( "Core.dll");
		void* hEngine = GetModuleHandleA( "Engine.dll");
		GetF( GetIndexedObject , hCore  , "?GetIndexedObject@UObject@@SAPAV1@H@Z");
		GetF( Debugf           , hCore  , "?Log@FOutputDevice@@QAEXPBG@Z"        );
		Get ( Core_GLog        , hCore  , "?GLog@@3PAVFOutputDevice@@A"          );
		GetF( AppFailAssert    , hCore  , "?appFailAssert@@YAXPBD0H@Z"           );
		Get ( Core_NameTable   , hCore  , "?Names@FName@@0V?$TArray@PAUFNameEntry@@@@A");
		Get ( Core_GMalloc     , hCore  , "?GMalloc@@3PAVFMalloc@@A"             );
		GetF( IsMovingBrushFunc, hEngine, "?IsMovingBrush@AActor@@QBEHXZ"        ); 
	}

#elif __GNUC__
	void* h = dlopen( nullptr, RTLD_NOW | RTLD_GLOBAL);
#define Get(dest,symbol) { void* A=dlsym(h,symbol); __asm__ ( "mov %%eax,(%%ecx)": : "a"(A), "c"(&dest) : "memory" ); }
	Get( Core_GLog        , "GLog"                       );
	Get( GetIndexedObject , "GetIndexedObject__7UObjecti");
	Get( Debugf           , "Log__13FOutputDevicePCc"    );
	Get( AppFailAssert    , "appFailAssert__FPCcT0i"     );
	Get( Core_NameTable   , "_5FName.Names"              );
	Get( Core_GMalloc     , "GMalloc"                    );
	Get( IsMovingBrushFunc, "IsMovingBrush__C6AActor"    );
#endif

	Loaded++;
	return GetIndexedObject && Debugf && Core_GLog && AppFailAssert && Core_NameTable && Core_GMalloc && IsMovingBrushFunc;
}

