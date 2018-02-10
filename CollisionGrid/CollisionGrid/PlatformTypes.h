#pragma once


#if 0
	#define UE_DEV_THROW(n,t)
	#define UE_DEV_LOG(t,...) 
	#define UE_DEV_LOG_ANSI(t) 
#else
	#define UE_DEV_THROW(n,t) if(n) { appFailAssert(t); }
	#define UE_DEV_LOG(t,...) debugf(t,__VA_ARGS__)
	#define UE_DEV_LOG_ANSI(t) debugf_ansi(t)
#endif

// Unsigned base types.
typedef unsigned char 		uint8;		// 8-bit  unsigned.
typedef unsigned short int	uint16;		// 16-bit unsigned.
typedef unsigned int		uint32;		// 32-bit unsigned.
typedef unsigned long long	uint64;		// 64-bit unsigned.

// Signed base types.
typedef	signed char			int8;		// 8-bit  signed.
typedef signed short int	int16;		// 16-bit signed.
typedef signed int	 		int32;		// 32-bit signed.
typedef signed long long	int64;		// 64-bit signed.

// Unreal specific types
typedef int32				UBOOL;		// Unreal Boolean
typedef int32				INT;		// Unreal Integer
typedef uint32				BITFIELD;	// Unreal packed boolean

typedef int32 FName; //Temporary
typedef int32 EName;

enum { INDEX_NONE = -1 };


#if UNICODE
	typedef char16_t TCHAR;
#else
	typedef char TCHAR;
#endif

//Export symbols to make disassembling easier
#if 0
	#define DE TEST_EXPORT
#else
	#define DE 
#endif


#ifdef _WINDOWS 
	#include "PlatformWindows.h"
#elif __GNUC__
	#include "PlatformLinux.h"
#endif
