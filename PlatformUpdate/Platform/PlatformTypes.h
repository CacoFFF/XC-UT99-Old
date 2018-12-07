/*=============================================================================
	PlatformTypes.h
	Author: Fernando Velázquez
	
	Unreal defines for new datatypes.
	Designed to make UE4 code and ports work without edition.
=============================================================================*/

#pragma once

#undef BYTE
#undef WORD
#undef DWORD
#undef INT
#undef FLOAT
#undef MAXBYTE
#undef MAXWORD
#undef MAXDWORD
#undef MAXINT
#undef VOID
#undef CDECL

// Unsigned base types.
typedef unsigned char 		uint8;		// 8-bit  unsigned.
typedef unsigned short		uint16;		// 16-bit unsigned.
typedef unsigned long		uint32;		// 32-bit unsigned.
typedef unsigned long long	uint64;		// 64-bit unsigned.

// Signed base types.
typedef	signed char			int8;		// 8-bit  signed.
typedef signed short int	int16;		// 16-bit signed.
typedef signed int	 		int32;		// 32-bit signed.
typedef signed long long	int64;		// 64-bit signed.

// Unreal specific types
typedef int32				UBOOL;		// Unreal Boolean
typedef uint32				BITFIELD;	// Unreal packed boolean
typedef uint32				SIZE_T;

typedef char ANSICHAR;
typedef uint16 UNICHAR;

enum {MAXBYTE		= 0xff       };
enum {MAXWORD		= 0xffffU    };
enum {MAXDWORD		= 0xffffffffU};
enum {MAXSBYTE		= 0x7f       };
enum {MAXSWORD		= 0x7fff     };
enum {MAXINT		= 0x7fffffff };

#undef TEXT
#if UNICODE
	typedef UNICHAR TCHAR;
	#define TEXT(str) L##str
	inline TCHAR    FromAnsi   ( ANSICHAR In ) { return (uint8)In;                                    }
	inline TCHAR    FromUnicode( UNICHAR In  ) { return In;                                           }
	inline ANSICHAR ToAnsi     ( TCHAR In    ) { return (uint16)In<0x100 ? (char)In : (char)MAXSBYTE; }
	inline UNICHAR  ToUnicode  ( TCHAR In    ) { return In;                                           }
#else
	typedef ANSICHAR TCHAR;
	#define TEXT(str) str
	inline TCHAR    FromAnsi   ( ANSICHAR In ) { return In;                               }
	inline TCHAR    FromUnicode( UNICHAR  In ) { return (uint16)In<0x100 ? In : MAXSBYTE; }
	inline ANSICHAR ToAnsi     ( TCHAR In    ) { return (uint16)In<0x100 ? In : MAXSBYTE; }
	inline UNICHAR  ToUnicode  ( TCHAR In    ) { return (uint8)In;                        }
#endif

#define USE_BACKPORT
#include "PlatformBackportTypes.h"
#undef USE_BACKPORT