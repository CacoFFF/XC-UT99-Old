/*=============================================================================
	XC_Globals.cpp: 
	Implementation of some globals
=============================================================================*/

#include "XC_Core.h"
#include "XC_CoreGlobals.h"
XC_CORE_API extern UBOOL b440Net;
#include "UnXC_Arc.h"
#include "FPackageFileSummary.h"
//#include "FThread.h"

XC_CORE_API FMemStack GXCMem;

//*************************************************
// Pathing in both platforms
//*************************************************
XC_CORE_API void FixFilename( const TCHAR* Filename )
{
	TCHAR* Cur;
	for( Cur = (TCHAR*)Filename; *Cur != '\0'; Cur++ )
#ifdef __LINUX_X86__
		if( *Cur == '\\' )
			*Cur = '/';
#else
		if( *Cur == '/' )
			*Cur = '\\';
#endif
}


//*************************************************
// Name case fixing
// Makes sure that a name has proper casing
// Helps preventing DLL bind failures
//*************************************************
XC_CORE_API UBOOL FixNameCase( const TCHAR* NameToFix)
{
	FName AName( NameToFix, FNAME_Find);
	if ( AName != NAME_None )
	{
		TCHAR* Ch = (TCHAR*) *AName;
		for ( INT i=0 ; i<63 && Ch[i] ; i++ )
			Ch[i] = NameToFix[i];
	}
	return AName != NAME_None;
}


//*************************************************
// Globals initialization
// DeInit must be called always after init
// This helps running the globals in commandlets
// and other objects that aren't controlled by a 
// main engine like XC_Engine
//*************************************************

XC_CORE_API void InitXCGlobals()
{
	guard( XC_Core::InitXCGlobals);
	
	guard( InitMem )
	GXCMem.Init( 65536 );
	unguard;

	unguard;
}

XC_CORE_API void DeInitXCGlobals()
{
	guard( XC_Core::DeInitXCGlobals);
	
	guard( DeInitMem )
	GXCMem.Exit();
	unguard;

	unguard;
}


//*************************************************
// High resolution timers stuff
//*************************************************
XC_CORE_API DOUBLE GXStartTime = 0;
XC_CORE_API DOUBLE GXSecondsPerCycle = 0;
static UBOOL GXTimeInitialized = 0;

XC_CORE_API void XC_InitTiming(void)
{
	if ( GXTimeInitialized++ != 0)
		return;
#ifdef __LINUX_X86__
	GXSecondsPerCycle = 1.0 / 1000000.0;
#elif _MSC_VER
	LARGE_INTEGER Frequency;
	check( QueryPerformanceFrequency(&Frequency) );
	GXSecondsPerCycle = 1.0 / Frequency.QuadPart;
#endif
	GXStartTime = appSecondsXC();
	debugf( TEXT("XC_InitTiming called: %f"), 1.0 / GXSecondsPerCycle);
}



//*************************************************
// Script stuff
// Finds a (non-state) function in a struct
// Finds a variable in a struct, increments *Found
//*************************************************
XC_CORE_API UFunction* FindBaseFunction( UStruct* InStruct, const TCHAR* FuncName)
{
	FName NAME_FuncName = FName( FuncName, FNAME_Find);
	if ( NAME_FuncName != NAME_None )
	{
		for( TFieldIterator<UFunction> Func( InStruct ); Func; ++Func )
			if( Func->GetFName() == NAME_FuncName )
				return (UFunction*) *Func;
	}
	return NULL;	
}

XC_CORE_API UProperty* FindScriptVariable( UStruct* InStruct, const TCHAR* PropName, INT* Found)
{
	FName NAME_PropName = FName( PropName, FNAME_Find);
	if ( NAME_PropName != NAME_None )
	{
		for( TFieldIterator<UProperty> Prop( InStruct ); Prop; ++Prop )
			if( Prop->GetFName() == NAME_PropName )
			{
				if ( Found )
					(*Found)++;
				return (UProperty*) *Prop;
			}
	}
	return NULL;	
}


//*************************************************
// String table sorting
//*************************************************
//Caching OList generates 3 more instructions at start
//But also removes two instructions on the appStricmp call

//Dynamic array
XC_CORE_API void SortStringsA( TArray<FString>* List)
{
	SortStringsSA( (FString*) List->GetData(), List->Num() );
}

//Static array, although not fully optimized for speed
XC_CORE_API void SortStringsSA( FString* List, INT ArrayMax)
{
	INT iTop=1;
	for ( INT i=1 ; i<ArrayMax ; i=++iTop )
/*	{
		//Optimized for long sorts, test later
		while ( appStricmp( *List[iTop], *List[i-1]) < 0 )
			if ( --i == 0 )
				break;
		if ( i != iTop )
		{
			INT* Ptr = (INT*) &List[iTop];
			INT Buffer[3] = { Ptr[0], Ptr[1], Ptr[2] };
			appMemmove( List + i + 1, List + i, (iTop-i)*3 );
			Ptr = (INT*) &List[i];
			Ptr[0] = Buffer[0];
			Ptr[1] = Buffer[1];
			Ptr[2] = Buffer[2];
		}
	}*/
	//Optimized for short sorts
		while ( appStricmp( *List[i], *List[i-1]) < 0 )
		{
			//Atomically swap data (no FArray reallocs)
			//Compiler does a nice job here
			INT* Ptr = (INT*) &List[i];
			INT iStore = *Ptr;
			*Ptr = *(Ptr-3);
			*(Ptr-3) = iStore;
			iStore = *(Ptr+1);
			*(Ptr+1) = *(Ptr-2);
			*(Ptr-2) = iStore;
			iStore = *(Ptr+2);
			*(Ptr+2) = *(Ptr-1);
			*(Ptr-1) = iStore;
			//Bottom index, forced leave
			if ( i == 1 )
				break;
			i--;
		}
}


//*************************************************
// Enhanced package file finder
// Strict loading by Name/GUID combo for net games
//*************************************************

FPackageFileSummary::FPackageFileSummary()
{
	appMemzero( this, sizeof(FPackageFileSummary));
}

	// Serializer.
XC_CORE_API FArchive_Proxy& operator<<( FArchive_Proxy& Ar, FPackageFileSummary& Sum )
{
	guard(FPackageFileSummary<<);

	Ar << Sum.Tag;
	Ar << Sum.FileVersion;
	Ar << Sum.PackageFlags;
	Ar << Sum.NameCount     << Sum.NameOffset;
	Ar << Sum.ExportCount   << Sum.ExportOffset;
	Ar << Sum.ImportCount   << Sum.ImportOffset;
	if( Sum.GetFileVersion()>=68 )
	{
		INT GenerationCount = Sum.Generations.Num();
		Ar << Sum.Guid.A << Sum.Guid.B << Sum.Guid.C << Sum.Guid.D << GenerationCount;
		if( Ar.IsLoading() )
			Sum.Generations = TArray<FGenerationInfo>( GenerationCount );
		for( INT i=0; i<GenerationCount; i++ )
			Ar << Sum.Generations(i);
	}
	else
	{
		INT HeritageCount, HeritageOffset;
		Ar << HeritageCount << HeritageOffset;
		INT Saved = Ar.Tell();
		if( HeritageCount )
		{
			Ar.Seek( HeritageOffset );
			for( INT i=0; i<HeritageCount; i++ )
				Ar << Sum.Guid.A << Sum.Guid.B << Sum.Guid.C << Sum.Guid.D;
		}
		Ar.Seek( Saved );
		if( Ar.IsLoading() )
		{
			Sum.Generations.Empty( 1 );
			new(Sum.Generations)FGenerationInfo(Sum.ExportCount,Sum.NameCount);
		}
	}
	return Ar;
	unguard;
}

XC_CORE_API FPackageFileSummary LoadPackageSummary( const TCHAR* File)
{
	guard(LoadPackageSummary);
	FPackageFileSummary Summary;
	FArchive_Proxy* Ar = (FArchive_Proxy*)GFileManager->CreateFileReader( File);
	if ( Ar )
	{
		*Ar << Summary;
		ARCHIVE_DELETE(Ar);
	}
	return Summary;
	unguard;
}


XC_CORE_API UBOOL FindPackageFile( const TCHAR* In, const FGuid* Guid, TCHAR* Out )
{
	guard(FindPackageFile);
	TCHAR Temp[256];

	// Don't return it if it's a library.
	if( appStrlen(In)>appStrlen(DLLEXT) && appStricmp( In + appStrlen(In)-appStrlen(DLLEXT), DLLEXT )==0 )
		return 0;

	// If using non-default language, search for internationalized version.
	UBOOL International = (appStricmp(UObject::GetLanguage(),TEXT("int"))!=0);

	// Try file as specified.
	appStrcpy( Out, In );
	if( !Guid && GFileManager->FileSize( Out ) >= 0 )
		return 1;

	// Try all of the predefined paths.
	INT DoCd;
	for( DoCd=0; DoCd<(1+(GCdPath[0]!=0)); DoCd++ )
	{
		for( INT i=DoCd; i<GSys->Paths.Num()+(Guid!=NULL); i++ )
		{
			for( INT j=0; j<International+1; j++ )
			{
				// Get directory only.
				const TCHAR* Ext;
				*Temp = 0;
				if( DoCd )
				{
					appStrcat( Temp, GCdPath );
					appStrcat( Temp, TEXT("System"));
					appStrcat( Temp, PATH_SEPARATOR);
				}
				if( i<GSys->Paths.Num() )
				{
					appStrcat( Temp, *GSys->Paths(i) );
					TCHAR* Ext2 = appStrstr(Temp,TEXT("*"));
					if( Ext2 )
						*Ext2++ = 0;
					Ext = Ext2;
					appStrcpy( Out, Temp );
					appStrcat( Out, In );
				}
				else
				{
					appStrcat( Temp, *GSys->CachePath );
					appStrcat( Temp, PATH_SEPARATOR );
					Ext = *GSys->CacheExt;
					appStrcpy( Out, Temp );
					appStrcat( Out, Guid->String() );
				}

				// Check for file.
				UBOOL Found = 0;
				Found = (GFileManager->FileSize(Out)>=0);
				if( !Found && Ext )
				{
					appStrcat( Out, TEXT(".") );
					if( International-j )
					{
						appStrcat( Out, UObject::GetLanguage() );
						appStrcat( Out, TEXT("_") );
					}
					appStrcat( Out, Ext+1 );
					Found = (GFileManager->FileSize( Out )>=0);
				}
				if ( Found && Guid ) //Deny
				{
					FPackageFileSummary Summary = LoadPackageSummary( Out);
					if ( Summary.Guid != *Guid )
					{
						Found = 0;
						Out[0] = 0;
					}
				}
				if( Found )
				{
					if( i==GSys->Paths.Num() )
						appUpdateFileModTime( Out );
					return 1;
				}
			}
		}
	}

	// Try case-insensitive search.
	for( DoCd=0; DoCd<(1+(GCdPath[0]!=0)); DoCd++ )
	{
		for( INT i=0; i<GSys->Paths.Num()+(Guid!=NULL); i++ )
		{
			// Get directory only.
			const TCHAR* Ext;
			*Temp = 0;
			if( DoCd )
			{
				appStrcat( Temp, GCdPath );
				appStrcat( Temp, TEXT("System"));
				appStrcat( Temp, PATH_SEPARATOR);
			}
			if( i<GSys->Paths.Num() )
			{
				appStrcat( Temp, *GSys->Paths(i) );
				TCHAR* Ext2 = appStrstr(Temp,TEXT("*"));
				if( Ext2 )
					*Ext2++ = 0;
				Ext = Ext2;
				appStrcpy( Out, Temp );
				appStrcat( Out, In );
			}
			else
			{
				appStrcat( Temp, *GSys->CachePath );
				appStrcat( Temp, PATH_SEPARATOR );
				Ext = *GSys->CacheExt;
				appStrcpy( Out, Temp );
				appStrcat( Out, Guid->String() );
			}

			// Find files.
			TCHAR Spec[256];
			*Spec = 0;
			TArray<FString> Files;
			appStrcpy( Spec, Temp );
			appStrcat( Spec, TEXT("*") );
			if( Ext )
				appStrcat( Spec, Ext );
			Files = GFileManager->FindFiles( Spec, 1, 0 );

			// Check for match.
			UBOOL Found = 0;
			TCHAR InExt[256];
			*InExt = 0;
			if( Ext )
			{
				appStrcpy( InExt, In );
				appStrcat( InExt, Ext );
			}
			for( INT j=0; Files.IsValidIndex(j); j++ )
			{
				if( (appStricmp( *(Files(j)), In )==0) ||
					(appStricmp( *(Files(j)), InExt)==0) )
				{
					appStrcpy( Out, Temp );
					appStrcat( Out, *(Files(j)));
					Found = (GFileManager->FileSize( Out )>=0);
					if ( Found && Guid ) //Deny
					{
						FPackageFileSummary Summary = LoadPackageSummary( Out);
						if ( Summary.Guid != *Guid )
						{
							Found = 0;
							Out[0] = 0;
						}
						else
							break;
					}
				}
			}
			if( Found )
			{
				debugf( TEXT("Case-insensitive search: %s -> %s"), In, Out );
				if( i==GSys->Paths.Num() )
					appUpdateFileModTime( Out );
				return 1;
			}
		}
	}

	// Not found.
	return 0;
	unguard;
}
