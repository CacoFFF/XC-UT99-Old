/*=============================================================================
	CacusLibCompat.cpp: 

	Implementation of some globals, because GCC2 linker doesn't properly
	link the Cacus.so and XC_Core.so ends up failing to load.

	XC_Core will load and unload the library manually here.
	It will also export the needed symbols to XC_Engine and others.
=============================================================================*/
#include <dlfcn.h>
#include <stdio.h>

#define EXTDEF_1(ext) extern void* ext; void* ext = 0;
#define EXTDEF_2(ext,sym) extern void* ext __asm__(sym); void* ext = 0;
#define GetV(dest,module,symbol) dest = dlsym(module,symbol);

extern void* hCacus;
void* hCacus = 0;

//DID SOMEONE SAY... TRAMPOLINE JUMPS !1!11?!?!1!?!!

static void* InitTiming_Func = 0;
__asm__(".global InitTiming__13FPlatformTime\n"	"InitTiming__13FPlatformTime:\n" "jmp *InitTiming_Func");

static void* OSpath_Func = 0;
__asm__(".global OSpath\n" "OSpath:\n" "jmp *OSpath_Func");

static void* CUserDir_Func = 0;
__asm__(".global CUserDir\n" "CUserDir:\n" "jmp *CUserDir_Func");

static void* CStrcpy8_s_Func = 0;
__asm__(".global CStrcpy8_s\n" "CStrcpy8_s:\n" "jmp *CStrcpy8_s_Func");

static void* CStrcat8_s_Func = 0;
__asm__(".global CStrcat8_s\n" "CStrcat8_s:\n" "jmp *CStrcat8_s_Func");

static void* CStringBufferInit_Func = 0;
__asm__(".global CStringBufferInit\n" "CStringBufferInit:\n" "jmp *CStringBufferInit_Func");

static void* CSprintf_Func = 0;
__asm__(".global CSprintf\n" "CSprintf:\n" "jmp *CSprintf_Func");

static void* ConstructOutputDevice_Func = 0;
__asm__(".global ConstructOutputDevice\n" "ConstructOutputDevice:\n" "jmp *ConstructOutputDevice_Func");

static void* DestructOutputDevice_Func = 0;
__asm__(".global DestructOutputDevice\n" "DestructOutputDevice:\n" "jmp *DestructOutputDevice_Func");

static void* CThread_Cons = 0;
__asm__(".global __7CThreadPFPv_UiPvUi\n" "__7CThreadPFPv_UiPvUi:\n" "jmp *CThread_Cons");

static void* CThread_Run2 = 0;
__asm__(".global Run__7CThreadPFPv_UiPv\n" "Run__7CThreadPFPv_UiPv:\n" "jmp *CThread_Run2");

static void* CThread_Dest = 0;
__asm__(".global _._7CThread\n" "_._7CThread:\n" "jmp *CThread_Dest");

static void* CThread_Detach = 0;
__asm__(".global Detach__7CThread\n" "Detach__7CThread:\n" "jmp *CThread_Detach");

static void* CThread_WaitFinish = 0;
__asm__(".global WaitFinish__7CThreadf\n" "WaitFinish__7CThreadf:\n" "jmp *CThread_WaitFinish");



//TODO:
EXTDEF_2(COut_Flush,"Flush__17COutputDeviceFile")
EXTDEF_2(COut_SetFilename,"SetFilename__17COutputDeviceFilePCc")

//Horrible hack, but a necessary one
extern double CacusTime_SecondsPerCycle;
double CacusTime_SecondsPerCycle = 1.0 / 1000000.0;


static void SetupCacus()
{
	hCacus = dlopen( "Cacus.so", RTLD_NOW|RTLD_GLOBAL);
	if ( !hCacus )
		throw "Failed to load Cacus.so";
	GetV( InitTiming_Func, hCacus, "_ZN13FPlatformTime10InitTimingEv");
	GetV( OSpath_Func, hCacus, "OSpath");
//	printf("%i\n",CUserDir_Func);
	GetV( CUserDir_Func, hCacus, "CUserDir");
//	printf("%i\n",CUserDir_Func);
	GetV( CStrcpy8_s_Func, hCacus, "CStrcpy8_s");
	GetV( CStrcat8_s_Func, hCacus, "CStrcat8_s");
	GetV( CStringBufferInit_Func, hCacus, "CStringBufferInit");
	GetV( CSprintf_Func, hCacus, "CSprintf");
	GetV( ConstructOutputDevice_Func, hCacus, "ConstructOutputDevice");
	GetV( DestructOutputDevice_Func, hCacus, "DestructOutputDevice");
	GetV( CThread_Cons, hCacus, "_ZN7CThreadC2EPFmPvES0_m");
	GetV( CThread_Run2, hCacus, "_ZN7CThread3RunEPFmPvES0_");
	GetV( CThread_Dest, hCacus, "_ZN7CThreadD2Ev");
	GetV( CThread_Detach, hCacus, "_ZN7CThread6DetachEv");
	GetV( CThread_WaitFinish, hCacus, "_ZN7CThread10WaitFinishEf");
//	printf("%s FUG\n",CUserDir());
}
static void ShutdownCacus()
{
	if ( hCacus )
	{
		dlclose( hCacus);
		hCacus = 0;
	}
}
struct Loader
{
	Loader()  { SetupCacus(); }
	~Loader() { ShutdownCacus(); }
};
static Loader StaticLoader;


