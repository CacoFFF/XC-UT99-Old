/*=============================================================================
	PlatformBackportTypes.h
	Author: Fernando Velázquez
	
	Unreal backport defines for datatypes.
	Designed to make old code function with new platform code.
=============================================================================*/

#pragma once

// Unsigned base types.
typedef uint8  BYTE;	// 8-bit  unsigned.
typedef uint16 _WORD;	// 16-bit unsigned.
typedef uint32 DWORD;	// 32-bit unsigned.
typedef uint64 QWORD;	// 64-bit unsigned.
 
// Signed base types.
typedef	int8  SBYTE;	// 8-bit  signed.
typedef int16 SWORD;	// 16-bit signed.
typedef int32 INT;		// 32-bit signed.
typedef int64 SQWORD;	// 64-bit signed.

typedef float FLOAT;
typedef double DOUBLE;