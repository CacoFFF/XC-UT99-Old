/*=============================================================================
	XC_Core script implementation
=============================================================================*/

// Includes.
#include "XC_Core.h"

#include "Engine.h"


XC_CORE_API extern UBOOL b440Net;
#include "UnXC_Arc.h"

#include "XC_CoreGlobals.h"
#include "UnXC_Math.h"

#include "XC_Commandlets.h"

#include "Cacus/CacusString.h"
#include "Cacus/AppTime.h"
#ifdef __LINUX_X86__
	#include "Cacus/CacusGlobals.h"
#endif

inline void CompilerCheck()
{
	UXC_CoreStatics* CS;
	CS->StaticConstructor();

/**			 -- Auto Error -- 
		You must add these to UXC_CoreStatics:
	void StaticConstructor();
	void PostLoad();
  */
}


/*-----------------------------------------------------------------------------
	The following must be done once per package (.dll).
-----------------------------------------------------------------------------*/

#define NAMES_ONLY
#define AUTOGENERATE_NAME(name) XC_CORE_API FName XC_CORE_##name;
#define AUTOGENERATE_FUNCTION(cls,idx,name) IMPLEMENT_FUNCTION(cls,idx,name)
#include "XC_CoreClasses.h"
#undef AUTOGENERATE_FUNCTION
#undef AUTOGENERATE_NAME
#undef NAMES_ONLY
static void RegisterNames()
{
	static INT Registered=0;
	if(!Registered++)
	{
		#define NAMES_ONLY
		#define AUTOGENERATE_NAME(name) extern XC_CORE_API FName XC_CORE_##name; XC_CORE_##name=FName(TEXT(#name),FNAME_Intrinsic);
		#define AUTOGENERATE_FUNCTION(cls,idx,name)
		#include "XC_CoreClasses.h"
		#undef DECLARE_NAME
		#undef NAMES_ONLY
	}
}

// Package implementation, windows should not call DLLMAIN yet...
#ifdef _MSC_VER
	#undef IMPLEMENT_PACKAGE_PLATFORM
	#define IMPLEMENT_PACKAGE_PLATFORM(pkgname) \
		extern "C" {HINSTANCE hInstance;}
//		INT DLL_EXPORT STDCALL DllMain( HINSTANCE hInInstance, DWORD Reason, void* Reserved ) \
//		{ hInstance = hInInstance; return 1; }
#endif
IMPLEMENT_PACKAGE(XC_Core);


// Package loading
#ifdef _MSC_VER
INT DLL_EXPORT STDCALL DllMain( HINSTANCE hInInstance, DWORD Reason, void* Reserved )
{
	hInstance = hInInstance;
	if ( Reason == DLL_PROCESS_ATTACH && FName::GetInitialized() )
#elif __LINUX_X86__
__attribute__((constructor)) INT FixNamesOnLoad()
{
#else
INT DummyFixNames()
{
#endif
	guard(FixNames);
	if ( FName::GetInitialized() )
	{
		FixNameCase( TEXT("execTotalSize") );
		FixNameCase( TEXT("execPosition") );
		FixNameCase( TEXT("execCloseFile") );
		FixNameCase( TEXT("execOpenFileWrite") );
		FixNameCase( TEXT("execOpenFileRead") );
		FixNameCase( TEXT("execSerializeTo") );
		FixNameCase( TEXT("execWriteText") );
		FixNameCase( TEXT("execSerializeVector") );
		FixNameCase( TEXT("execSerializeRotator") );
		FixNameCase( TEXT("execSerializeByte") );
		FixNameCase( TEXT("execSerializeFloat") );
		FixNameCase( TEXT("execSerializeInt") );
		FixNameCase( TEXT("execSerializeString") );
		FixNameCase( TEXT("execInvSqrt") );
		FixNameCase( TEXT("execHSize") );
		FixNameCase( TEXT("execHNormal") );
		FixNameCase( TEXT("execUnClock") );
		FixNameCase( TEXT("execClock") );
		FixNameCase( TEXT("execOr_ObjectObject") );
		FixNameCase( TEXT("execConnectedDests") );
		FixNameCase( TEXT("execAppSeconds") );
		FixNameCase( TEXT("execAppCycles") );
		FixNameCase( TEXT("execGetParentClass") );
		FixNameCase( TEXT("execStringToName") );
		FixNameCase( TEXT("execLocs") );
		FixNameCase( TEXT("execMakeColor") );
		FixNameCase( TEXT("FindObject") );
		FixNameCase( TEXT("AllObjects") );
		FixNameCase( TEXT("HasFunction") );
		FixNameCase( TEXT("FixName") );
		FixNameCase( TEXT("CleanupLevel") );
		FixNameCase( TEXT("PathsRebuild") );
	}
	unguard;
	return 1;
}



//*************************************************
// Register GNatives in their respective opcodes
// Helps keeping the engine clean when playing
// on protected GNatives environments
//*************************************************
#pragma DISABLE_OPTIMIZATION
XC_CORE_API void XCCNatives( UBOOL bEnable)
{
	if ( bEnable )
	{
		GetDefault<UXC_CoreStatics>()->bGNatives = true;
		GNatives[198] = (Native)&UXC_CoreStatics::execMakeColor;
		GNatives[238] = (Native)&UXC_CoreStatics::execLocs;
		GNatives[391] = (Native)&UXC_CoreStatics::execStringToName;
		GNatives[600] = (Native)&UXC_CoreStatics::execFindObject;
		GNatives[601] = (Native)&UXC_CoreStatics::execGetParentClass;
		GNatives[602] = (Native)&UXC_CoreStatics::execAllObjects;
		GNatives[643] = (Native)&UXC_CoreStatics::execAppSeconds;
		GNatives[3014] = (Native)&UXC_CoreStatics::execHasFunction;
		GNatives[3554] = (Native)&UXC_CoreStatics::execConnectedDests;
		GNatives[3555] = (Native)&UXC_CoreStatics::execOr_ObjectObject;
		GNatives[3556] = (Native)&UXC_CoreStatics::execClock;
		GNatives[3557] = (Native)&UXC_CoreStatics::execUnClock;
		GNatives[3558] = (Native)&UXC_CoreStatics::execFixName;
		GNatives[3559] = (Native)&UXC_CoreStatics::execAppCycles;
		GNatives[3570] = (Native)&UXC_CoreStatics::execHNormal;
		GNatives[3571] = (Native)&UXC_CoreStatics::execHSize;
		GNatives[3572] = (Native)&UXC_CoreStatics::execInvSqrt;
	}
	else
	{
		GetDefault<UXC_CoreStatics>()->bGNatives = false;
		GNatives[198] = (Native)&UObject::execUndefined;
		GNatives[238] = (Native)&UObject::execUndefined;
		GNatives[391] = (Native)&UObject::execUndefined;
		GNatives[600] = (Native)&UObject::execUndefined;
		GNatives[601] = (Native)&UObject::execUndefined;
		GNatives[602] = (Native)&UObject::execUndefined;
		GNatives[643] = (Native)&UObject::execUndefined;
		GNatives[3014] = (Native)&UObject::execUndefined;
		GNatives[3554] = (Native)&UObject::execUndefined;
		GNatives[3555] = (Native)&UObject::execUndefined;
		GNatives[3556] = (Native)&UObject::execUndefined;
		GNatives[3557] = (Native)&UObject::execUndefined;
		GNatives[3558] = (Native)&UObject::execUndefined;
		GNatives[3559] = (Native)&UObject::execUndefined;
		GNatives[3570] = (Native)&UObject::execUndefined;
		GNatives[3571] = (Native)&UObject::execUndefined;
		GNatives[3572] = (Native)&UObject::execUndefined;
	}
}
#pragma ENABLE_OPTIMIZATION


//Function aliasing

#if _MSC_VER
	#define IMPLEMENT_REDIRECTED_FUNCTION(cls,num,func,othercls)
//	#define IMPLEMENT_REDIRECTED_FUNCTION(cls,num,func,othercls) \
//		extern "C" DLL_EXPORT Native int##othercls##func = (Native)&cls::func; \
//		static BYTE othercls##func##Temp = GRegisterNative( num, int##othercls##func );
#else
	#define IMPLEMENT_REDIRECTED_FUNCTION(cls,num,func,othercls) \
		extern "C" DLL_EXPORT { Native int##othercls##func = (Native)&cls::func; } \
		static BYTE othercls##func##Temp = GRegisterNative( num, int##othercls##func );
#endif

#if _MSC_VER
	#define IMPLEMENT_RENAMED_FUNCTION(cls,num,func,othersymbol)
//	#define IMPLEMENT_RENAMED_FUNCTION(cls,num,func,othersymbol) \
//		extern "C" DLL_EXPORT Native int##cls##othersymbol = (Native)&cls::func; \
//		static BYTE cls##othersymbol##Temp = GRegisterNative( num, int##cls##othersymbol );
#else
	#define IMPLEMENT_RENAMED_FUNCTION(cls,num,func,othersymbol) \
		extern "C" DLL_EXPORT { Native int##cls##othersymbol = (Native)&cls::func; } \
		static BYTE cls##othersymbol##Temp = GRegisterNative( num, int##cls##othersymbol );
#endif

#define ABORT_IF(condition, returnvalue, text) \
	if ( condition ) { debugf( NAME_Warning, text); *(INT*)Result = returnvalue; return; }


/*-----------------------------------------------------------------------------
	Make class post-loadable
-----------------------------------------------------------------------------*/
static UBOOL HackingClass = 0;
class UClassHack : public UClass
{
public:
	UClassHack()
	{}

	//Destruction occurs when native class is being (re)loaded from unrealscript
	~UClassHack() 
	{
		if ( HackingClass )
			UClass::StaticClass()->ClassConstructor = &UClassHack::InternalConstructor;
	}

	//So we temporarily replace the internal constructor
	static void InternalConstructor( void* X ) 
	{
		if ( HackingClass )
			UClass::StaticClass()->ClassConstructor = &UClass::InternalConstructor;
		HackingClass = 0;
		new( (EInternal*)X )UClassHack();
	}

	//So that the native class can override the unrealscript's empty default properties
	virtual void SerializeTaggedProperties( FArchive& Ar, BYTE* Data, UClass* DefaultsClass )
	{
		UClass::SerializeTaggedProperties( Ar, Data, DefaultsClass);
		if ( UXC_CoreStatics::StaticClass() == this )
		{
			//Restore and process
			UXC_CoreStatics* DefaultObject = (UXC_CoreStatics*)&Defaults(0);
			((size_t*)this)[0] = ((size_t*)UObject::StaticClass())[0];
			DefaultObject->XC_Core_Version = 9;
		}
	}

};


/*-----------------------------------------------------------------------------
	UXC_CoreStatics
-----------------------------------------------------------------------------*/

static double StartTime = 0;
void UXC_CoreStatics::StaticConstructor()
{
	UClass* TheClass = GetClass();
	UXC_CoreStatics* DefaultObject = (UXC_CoreStatics*) &TheClass->Defaults(0);
	DefaultObject->XC_Core_Version = 9;

	StartTime = FPlatformTime::InitTiming();

#ifdef __LINUX_X86__
	appStrcat( (char*)CUserDir(), ".loki/ut/System/");
#endif

	CStringBufferInit( 16 * 1024); //Only initialize a 16kb buffer
	RegisterNames();

	INT Dummy = 0;
	UClassHack::InternalConstructor( &Dummy);
	HackingClass = 1;
	((size_t*)TheClass)[0] = Dummy;
}


void UXC_CoreStatics::execInvSqrt( FFrame &Stack, RESULT_DECL)
{
	P_GET_FLOAT( C);
	P_FINISH;
	*(FLOAT*)Result = _appInvSqrt( C);
}

void UXC_CoreStatics::execHSize( FFrame &Stack, RESULT_DECL)
{
	P_GET_VECTOR( A);
	P_FINISH;
	*(FLOAT*)Result = appSqrt( A.X*A.X+A.Y*A.Y);
}
IMPLEMENT_RENAMED_FUNCTION(UXC_CoreStatics,-1,execHSize,exechsize);
IMPLEMENT_RENAMED_FUNCTION(UXC_CoreStatics,-1,execHSize,exechSize);

void UXC_CoreStatics::execHNormal( FFrame &Stack, RESULT_DECL)
{
	P_GET_VECTOR( A);
	P_FINISH;
	if ( A.X == 0.0 || A.Y == 0.0 )
		*(FVector*)Result = FVector(0,0,0);
	else
		*(FVector*)Result = _UnsafeNormal2D( A);
}

void UXC_CoreStatics::execUnClock( FFrame &Stack, RESULT_DECL)
{
	QWORD Temp = FPlatformTime::Cycles64();
	Stack.Step( Stack.Object, NULL); //Do not paste result
//	P_GET_FLOAT_REF( C);
	P_FINISH;
	*(FLOAT*)Result = (FLOAT)FPlatformTime::ToSeconds(Temp - *((QWORD*)GPropAddr));
	*((QWORD*)GPropAddr) = Temp;
}

void UXC_CoreStatics::execClock( FFrame &Stack, RESULT_DECL)
{
//#define P_GET_FLOAT_REF(var)          FLOAT var##T=0.f; GPropAddr=0;       Stack.Step( Stack.Object, &var##T ); FLOAT*   var = GPropAddr ? (FLOAT  *)GPropAddr:&var##T;
	Stack.Step( Stack.Object, NULL); //Do not paste result
//	P_GET_FLOAT_REF( C);
	P_FINISH;
	*((QWORD*)GPropAddr) = FPlatformTime::Cycles64();
}
IMPLEMENT_RENAMED_FUNCTION(UXC_CoreStatics,-1,execClock,execclock);

void UXC_CoreStatics::execOr_ObjectObject(FFrame &Stack, RESULT_DECL)
{
	Stack.Step( Stack.Object, Result);
	P_GET_SKIP_OFFSET(W);
	if ( ! (*(INT*)(Result)) )
	{
		Stack.Step( Stack.Object, Result);
		Stack.Code++;
	}
	else
		Stack.Code += W;

/*	P_GET_ACTOR(A);
	P_GET_SKIP_OFFSET(W);
	if( !A )
	{
		P_GET_ACTOR(B);
		*(AActor**)Result = B;
		Stack.Code++; //DEBUGGER
	}
	else
	{
		*(AActor**)Result = A;
		Stack.Code += W;
	}
*/
}

void UXC_CoreStatics::execHasFunction(FFrame &Stack, RESULT_DECL)
{
	guard(UsdkObject::execHasFunction);

	P_GET_NAME(FunctionName);
	P_GET_OBJECT_OPTX(UObject, O, Stack.Object);
	P_FINISH;

	*(UBOOL*)Result = 0;
	if ( !O )
		return;
	
	*(UBOOL*)Result = O->FindFunction(FunctionName,1) != NULL;

	unguard;
}


//Developed for FerBotz
void UXC_CoreStatics::execConnectedDests(FFrame &Stack, RESULT_DECL)
{
	guard(ABotz_NavigBase::execConnectedDests);
	P_GET_OBJECT(ANavigationPoint,Start);
	P_GET_ACTOR_REF(End);
	P_GET_INT_REF(SpecIdx);
	P_GET_INT_REF(Idx);
	P_FINISH;

	INT i = 0;

	PRE_ITERATOR;
		*End = NULL;
		*Idx = -1;
		*SpecIdx = -1;
		if ( !Start ) //Get out of this iterator if no start point
		{
			Stack.Code = &Stack.Node->Script(wEndOffset + 1);
			break;
		}

		while ( i<16 && Start->Paths[i] < 0 ) //Skip invalid paths
			i++;

		if ( i<16 )
		{
			FReachSpec *RS;
			RS = &Start->GetLevel()->ReachSpecs(Start->Paths[i]);
			*End = RS->End;
			*Idx = i;
			*SpecIdx = Start->Paths[i];
			i++;
		}
		else
		{
			Stack.Code = &Stack.Node->Script(wEndOffset + 1);
			break;
		}
	POST_ITERATOR;
	unguard;
}

void UXC_CoreStatics::execAppSeconds( FFrame& Stack, RESULT_DECL )
{
	P_FINISH;
	*(FLOAT*)Result = (FLOAT) (FPlatformTime::Seconds() - StartTime);
}

void UXC_CoreStatics::execAppCycles( FFrame& Stack, RESULT_DECL )
{
	P_FINISH;
	*(DWORD*)Result = FPlatformTime::Cycles();
}

void UXC_CoreStatics::execGetParentClass( FFrame& Stack, RESULT_DECL )
{
	P_GET_OBJECT(UClass,A);
	P_FINISH;
	*(UClass**)Result = A ? A->GetSuperClass() : NULL;
}

void UXC_CoreStatics::execFixName( FFrame& Stack, RESULT_DECL )
{
	P_GET_STR( Str);
	P_GET_UBOOL_OPTX( bCreate, false);
	P_FINISH;
	
	if ( !FixNameCase(*Str) && bCreate )
		FName NewName( *Str);
}

void UXC_CoreStatics::execStringToName( FFrame& Stack, RESULT_DECL )
{
	P_GET_STR( S);
	P_FINISH;
	
	*(FName*)Result = FName( *S);
}


void UXC_CoreStatics::execLocs( FFrame& Stack, RESULT_DECL )
{
	P_GET_STR( A);
	P_FINISH;
	*(FString*)Result = A.Locs();
}

void UXC_CoreStatics::execMakeColor( FFrame& Stack, RESULT_DECL )
{
	Stack.Step( Stack.Object, (BYTE*)Result);
	Stack.Step( Stack.Object, ((BYTE*)Result)+1 );
	Stack.Step( Stack.Object, ((BYTE*)Result)+2 );
	if ( *Stack.Code != EX_EndFunctionParms )
		Stack.Step( Stack.Object, ((BYTE*)Result)+3 );
	P_FINISH;

/*	BYTE CData[4];
	Stack.Step( Stack.Object, &CData);
	Stack.Step( Stack.Object, &CData[1]);
	Stack.Step( Stack.Object, &CData[2]);
	if ( *Stack.Code != EX_EndFunctionParms )
		Stack.Step( Stack.Object, &CData[3]);
	else
		CData[3] = 0;
	P_FINISH;
	*(FColor*)Result = *( (FColor*) ((DWORD) &CData));*/
}

void UXC_CoreStatics::execFindObject( FFrame& Stack, RESULT_DECL )
{
	P_GET_STR(Name);
	P_GET_OBJECT(UClass,Class);
	P_GET_OBJECT_OPTX(UObject,InOuter,ANY_PACKAGE);
	P_FINISH;

	*(UObject**)Result = StaticFindObject( Class, InOuter, *Name );
}

void UXC_CoreStatics::execAllObjects( FFrame& Stack, RESULT_DECL )
{
	// Get the parms.
	P_GET_OBJECT(UClass,objClass);
	P_GET_OBJECT_REF(UObject,obj);
	P_FINISH;

	objClass = objClass ? objClass : UObject::StaticClass();
    TObjectIterator<UObject> It;

	PRE_ITERATOR;
		// Fetch next object in the iteration.
		*obj = NULL;
        while (It && *obj==NULL)
        {
            if (It->IsA(objClass) && !It->IsPendingKill())
            {
                *obj = *It;
            }
            ++It;
        }
		if( *obj == NULL )
		{
			Stack.Code = &Stack.Node->Script(wEndOffset + 1);
			break;
		}
	POST_ITERATOR;
}

void UXC_CoreStatics::execDynamicLoadObject_Fix( FFrame& Stack, RESULT_DECL )
{
	P_GET_STR(Name);
	P_GET_OBJECT(UClass,Class);
	P_GET_UBOOL_OPTX(bMayFail,0);
	P_FINISH;
	
	if ( Name.InStr(TEXT("%")) >= 0 )
	{
		*(UObject**)Result = NULL;
		return;
	}

	*(UObject**)Result = StaticLoadObject( Class, NULL, *Name, NULL, LOAD_NoWarn | (bMayFail?LOAD_Quiet:0), NULL );
}


void UXC_CoreStatics::execBrushToMesh( FFrame& Stack, RESULT_DECL )
{
	P_GET_ACTOR( Brush);
	P_GET_NAME( InPkg);
	P_GET_NAME( InName);
	P_GET_INT_OPTX( InFlags, 0);
	P_FINISH;

	UPackage* Pkg = CreatePackage( NULL, *InPkg);
	UMesh* Mesh = NULL;
	if ( InName != NAME_None && !FindObject<UObject>( Pkg, *InName) )
		Mesh = new( Pkg, InName, RF_Public|RF_Standalone )UMesh( 0, 0, 1);
	if ( Mesh )
	{
		BrushToMesh( (ABrush*)Brush, Mesh, InFlags);
		if ( !Mesh->Tris.Num() )
		{
			delete Mesh;
			Mesh = NULL;
		}
	}
	*(UMesh**)Result = Mesh;
}

void UXC_CoreStatics::execCleanupLevel( FFrame& Stack, RESULT_DECL )
{
	P_GET_OBJECT( ULevel, Level);
	P_FINISH;
	*(FString*)Result = Level ? CleanupLevel(Level) : FString();
}

void UXC_CoreStatics::execPathsRebuild( FFrame& Stack, RESULT_DECL )
{
	P_GET_OBJECT( ULevel, Level);
	P_GET_PAWN_OPTX( ScoutReference, NULL);
	P_GET_UBOOL_OPTX( bBuildAir, 0);
	P_FINISH;
	*(FString*)Result = Level ? PathsRebuild(Level,ScoutReference,bBuildAir) : FString();
}
IMPLEMENT_CLASS(UXC_CoreStatics);


/*-----------------------------------------------------------------------------
	UBinary functions
-----------------------------------------------------------------------------*/

void UBinarySerializer::execCloseFile(FFrame &Stack, RESULT_DECL)
{
	P_FINISH;

	ABORT_IF( !Archive, 0, TEXT("Failed CloseFile, no file to close"));
	ARCHIVE_DELETE( Archive); //Sets null
	bWrite = 0;
	*(UBOOL*)Result = true;
}
IMPLEMENT_RENAMED_FUNCTION(UBinarySerializer,-1,execCloseFile,execcloseFile);

void UBinarySerializer::execOpenFileWrite(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execOpenFileWrite);
	P_GET_STR(SrcFile);
	P_FINISH;

	ABORT_IF( Archive, 0, TEXT("Failed OpenFileWrite, there's already an open file, close it first"));
	ABORT_IF( (*SrcFile)[1] == ':', 0, TEXT("Failed OpenFileWrite, drive letter access is forbidden") );
	INT k = SrcFile.Len();
	INT FailCount = 0;
	for ( INT i=0 ; i<k ; i++ )
	{
		ABORT_IF( (*SrcFile)[i] == ':', 0, TEXT("Failed OpenFileWrite, forbidden character") );
		if ( (*SrcFile)[i] == '.' && (*SrcFile)[i+1] == '.' )
			FailCount++;
		ABORT_IF( FailCount >= 2, 0, TEXT("Failed OpenFileWrite, forbidden directory access") );
	}

	Archive = (FArchive_Proxy*) GFileManager->CreateFileWriter( OSpath(*SrcFile), FILEWRITE_EvenIfReadOnly );
	if ( Archive )
	{
		*(UBOOL*)Result = true;
		bWrite = 1;
		return;
	}
	*(UBOOL*)Result = false;
	unguard;
}

void UBinarySerializer::execOpenFileRead(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execOpenFileRead);
	P_GET_STR(SrcFile);
	P_FINISH;

	ABORT_IF( Archive, 0, TEXT("Failed OpenFileRead, there's already an open file, close it first"));
	Archive = (FArchive_Proxy*) GFileManager->CreateFileReader( OSpath(*SrcFile) );
	*(UBOOL*)Result = (Archive != NULL);
	unguard;
}

void UBinarySerializer::execSerializeInt(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execSerializeInt);
	P_GET_INT_REF( I);
	P_FINISH;

	ABORT_IF( !Archive, 0, TEXT("Failed SerializeInt, no file"));
	*Archive << *I;
	*(UBOOL*)Result = true;
	unguard;
}

void UBinarySerializer::execSerializeFloat(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execSerializeFloat);
	P_GET_FLOAT_REF( F);
	P_FINISH;

	ABORT_IF( !Archive, 0, TEXT("Failed SerializeFloat, no file"));
	*Archive << *F;
	*(UBOOL*)Result = true;
	unguard;
}

void UBinarySerializer::execSerializeByte(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execSerializeByte);
	P_GET_BYTE_REF( B);
	P_FINISH;

	ABORT_IF( !Archive, 0, TEXT("Failed SerializeByte, no file"));
	*Archive << *B;
	*(UBOOL*)Result = true;
	unguard;
}

//Very ugly, override string serializator
static void SerializeStringSafe( FArchive_Proxy& Ar, FString& SA )
{
	INT ArrayRaw[3] = {0,0,0}; //VC++ 2015 complains | Data[0], Num[1], Max[2]
	TArray<TCHAR>* A = (TArray<TCHAR>*) &ArrayRaw[0];
	appMemcpy( A, &SA, 12);
#ifdef _UNICODE
	INT SaveNum = appIsPureAnsi(*SA) ? A->Num() : -A->Num();
#else
	INT SaveNum = A->Num(); //Linux can only save non-ansi strings
#endif
	Ar << SaveNum;
	if( Ar.IsLoading() )
	{
		if ( ArrayRaw[1] ) //A->Num()
			A->Empty();
		A->Add( Abs(SaveNum) );
		A->Shrink();
		if( SaveNum>=0 )
			for( INT i=0; i<ArrayRaw[1]; i++ )
				{ANSICHAR ACh; Ar << *(BYTE*)&ACh; (*A)(i)=FromAnsi(ACh);}
		else
			for( INT i=0; i<ArrayRaw[1]; i++ )
				{UNICHAR UCh; Ar << UCh; (*A)(i)=FromUnicode(UCh);}
		if( Ar.IsLoading() && ArrayRaw[1]==1 )
			A->Empty();
	}
	else
	{
		if( SaveNum>=0 )
			for( INT i=0; i<ArrayRaw[1]; i++ )
				{ANSICHAR ACh=ToAnsi((*A)(i)); Ar << *(BYTE*)&ACh;}
		else
			for( INT i=0; i<ArrayRaw[1]; i++ )
				{UNICHAR UCh=ToUnicode((*A)(i)); Ar << UCh;}
	}
	appMemcpy( &SA, A, 12);
//	appMemzero( &A, 12); //Not necessary
}

void UBinarySerializer::execSerializeString(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execSerializeString);
	P_GET_STR_REF( S);
	P_FINISH;

	ABORT_IF( !Archive, 0, TEXT("Failed SerializeString, no file"));
	SerializeStringSafe( *Archive, *S );
	*(UBOOL*)Result = true;
	unguard;
}

void UBinarySerializer::execWriteText(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execWriteText);
	P_GET_STR( S);
	P_GET_UBOOL_OPTX(bAppendEOL,0);
	P_FINISH;

	ABORT_IF( !Archive, 0, TEXT("Failed WriteText, no file"));
	ABORT_IF( !Archive->IsSaving(), 0, TEXT("Failed WriteText, file is not in write mode"));

#if UNICODE
	const TCHAR* CurPos = *S;
	INT ArraySize = S.Len(); //Don't serialize nullterminated
	//Safely serialize Unicode text into ANSI
	while ( ArraySize > 0 )
	{
		ANSICHAR Chars[1024];
		INT Top = ::Min( 1024, ArraySize);
		for ( INT i=0 ; i<Top ; i++ )
			Chars[i] = ToAnsi( CurPos[i] );
		Archive->Serialize( (void*)Chars, Top);
		CurPos += Top;
		ArraySize -= Top;
	}
#else
	if ( S.Len() > 0 )
		Archive->Serialize( (void*)*S, S.Len() );
#endif


	if ( bAppendEOL )
	{
		FString EOL = LINE_TERMINATOR;
#if UNICODE
		const ANSICHAR* AC = TCHAR_TO_ANSI( *EOL );
		Archive->Serialize( (void*)AC, EOL.Len() );
#else
		Archive->Serialize( (void*)*EOL, EOL.Len() );
#endif
	}
	*(UBOOL*)Result = true;
	unguard;
}

void UBinarySerializer::execSerializeVector(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execSerializeVector);
	P_GET_VECTOR_REF( V);
	P_FINISH;

	ABORT_IF( !Archive, 0, TEXT("Failed SerializeVector, no file"));
	*Archive << V->X;
	*Archive << V->Y;
	*Archive << V->Z;
	*(UBOOL*)Result = true;
	unguard;
}

void UBinarySerializer::execSerializeRotator(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execSerializeRotator);
	P_GET_ROTATOR_REF( R);
	P_FINISH;

	ABORT_IF( !Archive, 0, TEXT("Failed SerializeRotator, no file"));
	*Archive << R->Pitch;
	*Archive << R->Yaw;
	*Archive << R->Roll;
	*(UBOOL*)Result = true;
	unguard;
}

void UBinarySerializer::execReadLine(FFrame &Stack, RESULT_DECL)
{
	P_GET_STR_REF(Line);
	P_GET_INT_OPTX(MaxChars,0);
	P_FINISH;
	
	ABORT_IF( !Archive, 0, TEXT("Failed ReadLine, no file"));
	ABORT_IF( !Archive->IsLoading(), 0, TEXT("Failed ReadLine, file is not in read mode"));

	if ( Archive->AtEnd() )
	{
		*(UBOOL*)Result = false;
		return;
	}
	if ( MaxChars <= 0 || MaxChars > 2047 )
		MaxChars = 2047;
	
	TCHAR Buffer[2048];
	INT i = 0;
	INT iMax = ::Min( Archive->TotalSize()-Archive->Tell(), MaxChars );
	while ( i<iMax )
	{
		ANSICHAR Char;
		Archive->Serialize( &Char, 1);
		if ( Char == '\n' )
		{
			if ( i>0 && Buffer[i-1] == '\r' ) //Windows styled newline
				Buffer[i-1] = 0;
			break;
		}
		Buffer[i++] = FromAnsi(Char);
	}
	Buffer[i] = 0;
	*Line = Buffer;
	*(UBOOL*)Result = true;
}

void UBinarySerializer::execSerializeTo(FFrame &Stack, RESULT_DECL)
{
	guard(UBinarySerializer::execSerializeTo);
	P_GET_OBJECT( UObject, O);
	P_GET_NAME( VariableName);
	P_GET_INT( LimitSize);
	P_FINISH;

	ABORT_IF( !Archive, 0, TEXT("Failed SerializeTo, no file"));
	ABORT_IF( !O, 0, TEXT("Failed SerializeTo, no Object specified"));

	for( TFieldIterator<UProperty> It( O->GetClass() ); It; ++It )
		if ( appStricmp( It->GetName(), *VariableName )== 0 )
		{
			INT aSize = It->ElementSize * It->ArrayDim;
			if ( LimitSize <= 0 || LimitSize > aSize )
				LimitSize = aSize;
			BYTE* Data = (BYTE*)O + It->Offset;
			Archive->Serialize( Data, LimitSize);
			*(UBOOL*)Result = true;
			return;
		}

	debugf( NAME_Warning, TEXT("Failed SerializeTo, Variable %s not found"), VariableName);
	unguard;
}

void UBinarySerializer::execPosition(FFrame &Stack, RESULT_DECL)
{
	P_FINISH;

	ABORT_IF( !Archive, -1, TEXT("Failed Position, no file open") )
	*(INT*)Result = Archive->Tell();
}
IMPLEMENT_RENAMED_FUNCTION(UBinarySerializer,-1,execPosition,execposition);

void UBinarySerializer::execTotalSize(FFrame &Stack, RESULT_DECL)
{
	P_FINISH;

	ABORT_IF( !Archive, -1, TEXT("Failed TotalSize, no file open") )
	*(INT*)Result = Archive->TotalSize();
}
IMPLEMENT_RENAMED_FUNCTION(UBinarySerializer,-1,execTotalSize,exectotalSize);
IMPLEMENT_RENAMED_FUNCTION(UBinarySerializer,-1,execTotalSize,exectotalsize);
IMPLEMENT_RENAMED_FUNCTION(UBinarySerializer,-1,execTotalSize,execTotalsize);


void UBinarySerializer::Destroy()
{
	Super::Destroy();
	if ( Archive )
		ARCHIVE_DELETE( Archive);
}

IMPLEMENT_CLASS(UBinarySerializer);

#undef ARCHIVE_440
/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
