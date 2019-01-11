/*=============================================================================
	XC_CoreGlobals.h: Public globals for XC_Core and extensions
=============================================================================*/

#ifndef _INC_XC_COREGLOBALS
#define _INC_XC_COREGLOBALS


XC_CORE_API void XCCNatives( UBOOL bEnable); //Enables the commented out opcodes in XC_CoreStatics, careful when using this online

XC_CORE_API UBOOL FixNameCase( const TCHAR* NameToFix); //Only if name is found

XC_CORE_API UFunction* FindBaseFunction( UStruct* InStruct, const TCHAR* FuncName);
XC_CORE_API UProperty* FindScriptVariable( UStruct* InStruct, const TCHAR* PropName, INT* Found=NULL);

XC_CORE_API void SortStringsA( TArray<FString>* List);
XC_CORE_API void SortStringsSA( FString* List, INT ArrayMax);


//Linux doesn't have a working editor
#if _WINDOWS

XC_CORE_API FString CleanupLevel( class ULevel* Level);
XC_CORE_API FString PathsRebuild( class ULevel* Level, class APawn* ScoutReference, UBOOL bBuildAir);

enum EBrushToMeshFlags
{
	BM_MergeAll			= 0x00000001,	// Merge all vertices
	BM_MergeNone		= 0x00000002,	// Do not merge vertices
	BM_Flip			 	= 0x00000004,	// Reverse vertex order (turns front to back)
	BM_TileTextures		= 0x00000008,	// Brush faces are subdivided into texture-sized squares
};
XC_CORE_API void BrushToMesh( class ABrush* Brush, class UMesh* ApplyTo, DWORD Flags); //Mesh must be empty

#else

inline FString CleanupLevel( class ULevel* Level)
{	return FString();	}
inline FString PathsRebuild( class ULevel* Level, class APawn* ScoutReference, UBOOL bBuildAir)
{	return FString();	}
inline void BrushToMesh( class ABrush* Brush, class UMesh* ApplyTo, DWORD Flags)
{}

#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/

#endif
