// XC_LZMA.cpp
// This code loads the LZMA library and prepares the compression/decompression environments
// By Higor

#include "XC_Core.h"
#include "XC_LZMA.h"



//Archive hack for Linux
XC_CORE_API extern UBOOL b440Net;
#include "UnXC_Arc.h"

#ifdef __LINUX_X86__
	#include <stddef.h>
#endif

typedef size_t SizeT;
typedef int (STDCALL *XCFN_LZMA_Compress)(unsigned char *dest, size_t *destLen, const unsigned char *src, size_t srcLen,
  unsigned char *outProps, size_t *outPropsSize, /* *outPropsSize must be = 5 */
  int level,      /* 0 <= level <= 9, default = 5 */
  unsigned dictSize,  /* default = (1 << 24) */
  int lc,        /* 0 <= lc <= 8, default = 3  */
  int lp,        /* 0 <= lp <= 4, default = 0  */
  int pb,        /* 0 <= pb <= 4, default = 2  */
  int fb,        /* 5 <= fb <= 273, default = 32 */
  int numThreads /* 1 or 2, default = 2 */
  );

//Dictionary size changed from 16mb to 4mb to easy memory usage, besides we're only compressing small files
static INT lzma_treads = 1;
#define DEFAULT_LZMA_PARMS 5, (1<<22), 3, 0, 2, 32, lzma_treads
  
typedef int (STDCALL *XCFN_LZMA_Uncompress) (unsigned char *dest, size_t *destLen, const unsigned char *src, SizeT *srcLen,
  const unsigned char *props, size_t propsSize);

#ifdef _MSC_VER
	static HMODULE hLZMA = 0;
#elif __LINUX_X86__
	static void* hLZMA = 0;
#endif

static XCFN_LZMA_Compress LzmaCompressFunc = 0;
static XCFN_LZMA_Uncompress LzmaDecompressFunc = 0;

#include "API_FunctionLoader.h"

//Load LZMA
static UBOOL GetHandles()
{
#ifdef _MSC_VER
	if ( !hLZMA )
		hLZMA = LoadLibrary(TEXT("LZMA.dll"));
#elif __LINUX_X86__
	if ( !hLZMA )
		hLZMA = dlopen( TEXT("LZMA.so"), RTLD_NOW|RTLD_LOCAL);
#endif
	if ( hLZMA && (!LzmaCompressFunc || !LzmaDecompressFunc) ) //Load the functions
	{
		Get(LzmaCompressFunc,hLZMA,"LzmaCompress");
		Get(LzmaDecompressFunc,hLZMA,"LzmaUncompress");
	}
	return hLZMA && LzmaCompressFunc && LzmaDecompressFunc;
}
/*
static void FreeHandles()
{
#ifdef _MSC_VER
	if ( hLZMA )
	{
		if ( FreeLibrary(hLZMA) )
			hLZMA = 0;
	}
#endif
}
*/

/*-----------------------------------------------------------------------------
	ULZMACompressCommandlet.
-----------------------------------------------------------------------------*/
INT ULZMACompressCommandlet::Main( const TCHAR* Parms )
{
	FString Wildcard;
	TCHAR Error[256] = {0};
	if( !ParseToken(Parms,Wildcard,0) )
		appErrorf(TEXT("Source file(s) not specified"));
#ifdef _MSC_VER
	lzma_treads = 2;
#endif
	FixFilename( Parms);
	do
	{
        // skip "-nohomedir", etc... --ryan.
        if ((Wildcard.Len() > 0) && ( (*Wildcard)[0] == '-'))
            continue;

		FString Dir;
		INT i = Wildcard.InStr( PATH_SEPARATOR, 1 );
		if( i != -1 )
			Dir = Wildcard.Left( i+1 );
		TArray<FString> Files = GFileManager->FindFiles( *Wildcard, 1, 0 );
		if( !Files.Num() )
			appErrorf(TEXT("Source %s not found"), *Wildcard);
		for( INT j=0;j<Files.Num();j++)
		{
			FString Src = Dir + Files(j);
			FString End = Src + COMPRESSED_EXTENSION;
			FTime StartTime = appSeconds();
			LzmaCompress( *Src, *End, Error);
			
			if ( Error[0] )
				warnf( Error);
			else
			{
				INT SrcSize = GFileManager->FileSize(*Src);
				INT DstSize = GFileManager->FileSize(*(Src+COMPRESSED_EXTENSION));
				warnf(TEXT("Compressed %s -> %s%s (%d%%). Time: %03.1f"), *Src, *Src, COMPRESSED_EXTENSION, 100*DstSize / SrcSize, appSeconds() - StartTime);
			}
		}
	}
	while( ParseToken(Parms,Wildcard,0) );
	return 0;
}
IMPLEMENT_CLASS(ULZMACompressCommandlet)
/*-----------------------------------------------------------------------------
	ULZMADecompressCommandlet.
-----------------------------------------------------------------------------*/

INT ULZMADecompressCommandlet::Main( const TCHAR* Parms )
{
	FString Src;
	TCHAR Error[256] = { 0 };
	if( !ParseToken(Parms,Src,0) )
		appErrorf(TEXT("Compressed file not specified"));
	FString Dest;
    if( Src.Right(appStrlen(COMPRESSED_EXTENSION)) == COMPRESSED_EXTENSION )
		Dest = Src.Left( Src.Len() - appStrlen(COMPRESSED_EXTENSION) );
	else
		appErrorf(TEXT("Compressed files must end in %s"), COMPRESSED_EXTENSION);

	FixFilename( *Src);
	if ( LzmaDecompress( *Src, *Dest, Error) )
		warnf(TEXT("Decompressed %s -> %s"), *Src, *Dest);
	else
		appErrorf( Error );
	return 0;
}
IMPLEMENT_CLASS(ULZMADecompressCommandlet)

/*-----------------------------------------------------------------------------
	LZMA Unreal externals
-----------------------------------------------------------------------------*/

#define LZMA_PROPS_SIZE 5

static TCHAR* TranslateLzmaError( INT ErrorCode)
{
	switch ( ErrorCode )
	{
		case 0:		return NULL;
		case 1:		return TEXT("Data error");
		case 2:		return TEXT("Memory allocation error");
		case 4:		return TEXT("Unsupported properties");
		case 5:		return TEXT("Incorrect parameter");
		case 6:		return TEXT("Insufficient bytes in input buffer");
		case 7:		return TEXT("Output buffer overflow");
		case 12:	return TEXT("Errors in multithreading functions");
		default:	return TEXT("Undocumented error code");
	}
}

#define lzPrintError( a) { appSprintf( Error, a); return 0; }
#define lzPrintErrorD( a, b) { appSprintf( Error, a, b); return 0; }

XC_CORE_API UBOOL LzmaCompress( const TCHAR* Src, const TCHAR* Dest, TCHAR* Error)
{
	//Check LZMA library
	Error[0] = 0;
	if ( !GetHandles() )
		lzPrintError( TEXT("LzmaCompress: Unable to load LZMA library.") );
		
	//Check that file exists
	FArchive_Proxy* SrcFile = (FArchive_Proxy*) GFileManager->CreateFileReader( Src, 0);
	if ( !SrcFile )
		lzPrintErrorD( TEXT("LzmaCompress: Unable to load file %s."), Src );
	
	//Allocate memory and fill it with the source file's contents
	INT SrcSize = SrcFile->TotalSize();
	BYTE* SrcData = SrcSize ? (BYTE*)malloc( SrcSize ) : NULL;

	//Copy to memory and close source file
	if ( SrcData )
		SrcFile->Serialize( SrcData, SrcSize );
	SrcFile->Close();
	ARCHIVE_DELETE(SrcFile);
	if ( !SrcData )
		lzPrintErrorD( TEXT("LzmaCompress: Out of memory (%i kbytes requested for source file)."), SrcSize / 1024 );
	
	//Allocate destination memory, reserve extra space to avoid nasty surprises
	INT RequestedData = SrcSize + SrcSize / 64 + 1024;
	BYTE* DestData = (BYTE*)malloc( RequestedData );
	if ( !DestData )
		lzPrintErrorD( TEXT("LzmaCompress: Out of memory (%i kbytes requested for compression template)."), RequestedData / 1024 );
	
	//Compress and free source data
	BYTE Header[LZMA_PROPS_SIZE + 8];
	INT OutPropSize = LZMA_PROPS_SIZE;
	INT CmpRet = (*LzmaCompressFunc)( DestData, (unsigned int*)&RequestedData, SrcData, SrcSize, Header, (unsigned int*)&OutPropSize, DEFAULT_LZMA_PARMS);
	free( SrcData);
	
	TCHAR* ErrorT = TranslateLzmaError( CmpRet);
	if ( ErrorT ) //Got error
	{
		free(DestData);
		lzPrintErrorD( TEXT("LzmaCompress: %s."), ErrorT);
	}

	//No compression error, write header (13 bytes) and encoded data
	FArchive_Proxy* DestFile = (FArchive_Proxy*) GFileManager->CreateFileWriter( Dest, 0);
	if ( !DestFile )
	{
		free( DestData);
		lzPrintErrorD( TEXT("LzmaCompress: Unable to create destination file %s."), Dest);
	}
	for ( INT i=0; i<8; i++)
		Header[OutPropSize++] = (BYTE)((QWORD)SrcSize >> (8 * i));
	DestFile->Serialize( Header, OutPropSize);
	DestFile->Serialize( DestData, RequestedData);
	DestFile->Close();
	ARCHIVE_DELETE(DestFile);
	free( DestData);
	return 1;
}


XC_CORE_API UBOOL LzmaDecompress( const TCHAR* Src, const TCHAR* Dest, TCHAR* Error)
{
	//Check that file exists, load and move to other method
	FArchive_Proxy* SrcFile = (FArchive_Proxy*) GFileManager->CreateFileReader( Src, 0);
	Error[0] = 0;
	if ( !SrcFile )
		lzPrintErrorD( TEXT("LzmaDecompress: Unable to load file %s."), Src );
	UBOOL Result = LzmaDecompress( (FArchive*)SrcFile, Dest, Error);
	ARCHIVE_DELETE(SrcFile);
	return Result;
}

//From old version, kept as an internal/compatibility part of the main LzmaDecompress
XC_CORE_API UBOOL LzmaDecompress( FArchive* _SrcFile, const TCHAR* Dest, TCHAR* Error)
{
	try
	{
	//Validate
	Error[0] = 0;
	if ( !_SrcFile )
		lzPrintError( TEXT("LzmaDecompress: No source file specified") );
	FArchive_Proxy* SrcFile = (FArchive_Proxy*)_SrcFile; //Moot in win32
	if ( !GetHandles() )
		lzPrintError( TEXT("LzmaDecompress: Unable to load LZMA library.") );

	BYTE header[ LZMA_PROPS_SIZE + 8];
	SrcFile->Serialize( &header, LZMA_PROPS_SIZE + 8);
	QWORD unpackSize = *(QWORD*) &header[LZMA_PROPS_SIZE];

	//Allocate memory and fill it with the source file's contents
	INT SrcSize = SrcFile->TotalSize() - SrcFile->Tell();
	BYTE* SrcData = (SrcSize>0) ? (BYTE*)malloc( SrcSize ) : NULL;
	if ( !SrcData )
		lzPrintErrorD( TEXT("LzmaDecompress: Out of memory (%i kbytes requested for source file)."), SrcSize / 1024 );
	SrcFile->Serialize( SrcData, SrcSize);
	
	//Allocate destination memory, reserve extra space to avoid nasty surprises
	INT DestSize = (INT)unpackSize;
	BYTE* DestData = (BYTE*)malloc( DestSize);
	if ( !DestData )
	{
		free( SrcData);
		lzPrintErrorD( TEXT("LzmaDecompress: Out of memory (%i kbytes requested for decompressed stream)."), DestSize / 1024 );
	}

	INT DcmpRet = LzmaDecompressFunc( DestData, (unsigned int*)&DestSize, SrcData, (unsigned int*)&SrcSize, header, LZMA_PROPS_SIZE);
	free( SrcData);
	
	TCHAR* ErrorT = TranslateLzmaError( DcmpRet);
	if ( ErrorT ) //Got error
	{
		free(DestData);
		lzPrintErrorD( TEXT("LzmaDecompress: %s."), ErrorT);
	}
	
	//No decompression error, write data stream into file
	FArchive_Proxy* DestFile = (FArchive_Proxy*) GFileManager->CreateFileWriter( Dest, FILEWRITE_EvenIfReadOnly);
	if ( !DestFile )
	{
		free( DestData);
		lzPrintErrorD( TEXT("LzmaDecompress: Unable to create destination file %s."), Dest);
	}
	DestFile->Serialize( DestData, DestSize);
	DestFile->Close();
	ARCHIVE_DELETE(DestFile);
	free( DestData);
	return 1;
	}catch(...) {}
}
