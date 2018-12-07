/*=============================================================================
	Platform.h
	Author: Fernando Velázquez
	
	Unreal platform specifier
	Define PLATFORM in order to include a header designed for a specific
	compiler
=============================================================================*/
#pragma once

#ifndef CORE_API
	#define CORE_API DLL_IMPORT
#endif

#ifndef PLATFORM
	#error "No PLATFORM defined for this build"
#endif

#define PLT_STR_HELPER(t) #t
#define PLT_STR(t) PLT_STR_HELPER(t)
#define PLATFORM_FILE PLT_STR( PLATFORM.h)

//Types should be platform specific
#include PLATFORM_FILE
