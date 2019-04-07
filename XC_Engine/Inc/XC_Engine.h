//=============================================================================
//=============================================================================

//Visual Studio 2015 directives
#pragma warning (disable : 4458) //Allow functions to override global variable names
#pragma warning (disable : 4459) //Allow functions to override global variable names
#pragma warning (disable : 4243) //Allow derivate natives from protected class to be used in master class
#pragma warning (disable : 4297) //Constructors and destructors allowed to throw
#define _CRT_SECURE_NO_WARNINGS //Because older string methods are no longer used

#ifndef _INC_XC_ENGINE
#define _INC_XC_ENGINE


#define XC_CORE_API DLL_IMPORT

#ifndef __LINUX_X86__
	#define CORE_API DLL_IMPORT
	#define XC_ENGINE_API DLL_EXPORT
	#define _WIN32_WINNT 0x0501
	#include <windows.h>
	#include <shlobj.h>
#else
	//If we don't disable this, v436 std (some builds) won't be able to run this mod
//	#define DO_GUARD 0
	#include <unistd.h>	
#endif


//Disablers, used for debugging and fast builds
//#define DISABLE_COLLISION
//#define DISABLE_PROPERTIES
//#define DISABLE_SCRIPT
//#define DISABLE_STATICS
#define XC_RENDER_API 0


//Safely empty a dynamic array on UT v451
#define SafeEmpty( A) if (A.GetData()) A.Empty()
#define SafeEmptyR( A) if (A->GetData()) A->Empty()


//Engine includes
#include "Engine.h"

#ifndef __LINUX_X86__
	#include "..\..\Window\inc\Window.h"
//	#include "Window_reduced.h" //Less data to process
#endif


//class UXC_GameEngine;
class FXC_TravelManager;
class FXC_TimeManager;
#ifndef DISABLE_COLLISION
	class FCollisionCacus;
	class FNodeGrid3;
#endif

//Script
#define warnf GWarn->Logf
#define debugf GLog->Logf
#define NAME_XC_Engine (EName)XC_ENGINE_XC_Engine.GetIndex()
#undef clock
#undef unclock
#define clock(Timer) { Timer -= FPlatformTime::Cycles(); }
#define unclock(Timer) { Timer += FPlatformTime::Cycles(); }

//Cacus
#include "Cacus/CacusPlatform.h"

//XC_Core
#include "UnXC_Math.h"
#include "MEMCPY_AMD.h" //Should be better than the default appMemcpy

//Classes here
#include "UnXC_Game.h"		// Engine Engine edited
#include "XC_Inlines.h"

#ifdef __LINUX_X86__
	#undef CPP_PROPERTY
	#define CPP_PROPERTY(name) \
		EC_CppProperty, (BYTE*)&((ThisClass*)1)->name - (BYTE*)1
#endif

#ifdef _WINDOWS
	void LoadViewportHack( UXC_GameEngine* InEngine);
#endif

#endif
