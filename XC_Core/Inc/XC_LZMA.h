/*=============================================================================
	Public LZMA header for XC_Core and other extensions
=============================================================================*/

#include "XC_CoreGlobals.h"
#define COMPRESSED_EXTENSION TEXT(".lzma")

XC_CORE_API UBOOL LzmaCompress( const TCHAR* Src, const TCHAR* Dest, TCHAR* Error); //Define at least 128 chars for Error
XC_CORE_API UBOOL LzmaDecompress( const TCHAR* Src, const TCHAR* Dest, TCHAR* Error); 
XC_CORE_API UBOOL LzmaDecompress( FArchive* SrcFile, const TCHAR* Dest, TCHAR* Error); //OLDVER

class XC_CORE_API ULZMACompressCommandlet : public UCommandlet
{
	DECLARE_CLASS(ULZMACompressCommandlet,UCommandlet,CLASS_Transient,XC_Core);
	INT Main( const TCHAR* Parms );
};

class XC_CORE_API ULZMADecompressCommandlet : public UCommandlet
{
	DECLARE_CLASS(ULZMADecompressCommandlet,UCommandlet,CLASS_Transient,XC_Core);
	INT Main( const TCHAR* Parms );
};

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
