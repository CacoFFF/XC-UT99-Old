/*=============================================================================
	ScriptCompilerAdds.cpp: 
	Script Compiler addons.

	Revision history:
		* Created by Higor
=============================================================================*/

#include "XC_Core.h"
#include "XC_CoreGlobals.h"
#include "Engine.h"

#define PSAPI_VERSION 1
#include <Psapi.h>

#pragma comment (lib,"Psapi.lib")


// Hook description
class FScriptCompiler_XC
{
public:
	UField* FindField( UStruct* Owner, const TCHAR* InIdentifier, UClass* FieldClass, const TCHAR* P4);
};

// Hook helper
struct ScriptCompilerHelper_XC_CORE
{
public:
	UBOOL bInit;
	TArray<UFunction*> ActorFunctions; //Hardcoded Actor functions
	TArray<UFunction*> ObjectFunctions; //Hardcoded Object functions
	TArray<UFunction*> StaticFunctions; //Hardcoded static functions
	//Struct mirroring causes package dependancy, we need to copy the struct

	ScriptCompilerHelper_XC_CORE()
		: bInit(0)	{}

	void AddFunction( UStruct* InStruct, const TCHAR* FuncName)
	{
		UFunction* F = FindBaseFunction( InStruct, FuncName);
		if ( !F )
			return;

		if ( F->FunctionFlags & FUNC_Static )
			StaticFunctions.AddItem( F);
		else if ( InStruct->IsChildOf( AActor::StaticClass()) )
			ActorFunctions.AddItem( F);
		else
			ObjectFunctions.AddItem( F);
	}
};
static ScriptCompilerHelper_XC_CORE Helper; //Makes C runtime init construct this object


// Writes a long relative jump
static void EncodeJump( uint8* At, uint8* To)
{
	uint32 OldProt;
	VirtualProtect( At, 5, PAGE_EXECUTE_READWRITE, &OldProt);
	uint32 Relative = To - (At + 5);
	*At = 0xE9;
	*(uint32*)(At+1) = Relative;
	VirtualProtect( At, 5, OldProt, &OldProt);
}

#define ForceAssign(Member,dest) \
	__asm { \
		__asm mov eax,Member \
		__asm lea ecx,dest \
		__asm mov [ecx],eax }


int StaticInitScriptCompiler()
{
	if ( !GIsEditor ) 
		return 0; // Do not setup if game instance

	MODULEINFO mInfo;
	GetModuleInformation( GetCurrentProcess(), GetModuleHandleA("Editor.dll"), &mInfo, sizeof(MODULEINFO));
	uint8* EditorBase = (uint8*)mInfo.lpBaseOfDll;

	static int Initialized = 0;
	if ( Initialized++ )
		return 0; //Prevent multiple recursion

	uint8* Tmp;
	ForceAssign( FScriptCompiler_XC::FindField, Tmp);
	EncodeJump( EditorBase + 0xA17A0, Tmp);
}


UField* FScriptCompiler_XC::FindField( UStruct* Owner, const TCHAR* InIdentifier, UClass* FieldClass, const TCHAR* P4)
{
	// Normal stuff
	check(InIdentifier);
	FName InName( InIdentifier, FNAME_Find );
	if( InName != NAME_None )
	{
		for( UStruct* St=Owner ; St ; St=Cast<UStruct>( St->GetOuter()) )
			for( TFieldIterator<UField> It(St) ; It ; ++It )
				if( It->GetFName() == InName )
				{
					if( !It->IsA(FieldClass) )
					{
						if( P4 )
							appThrowf( TEXT("%s: expecting %s, got %s"), P4, FieldClass->GetName(), It->GetClass()->GetName() );
						return nullptr;
					}
					return *It;
				}
	}

	// Initialize hardcoded opcodes
	if ( !Helper.bInit )
	{
		Helper.bInit++;
		Helper.AddFunction( ANavigationPoint::StaticClass(), TEXT("describeSpec") );
		UClass* XCGEA = FindObject<UClass>( NULL, TEXT("XC_Engine.XC_Engine_Actor"), 1);
		if ( XCGEA )
		{
			Helper.AddFunction( XCGEA, TEXT("AddToPackageMap"));
			Helper.AddFunction( XCGEA, TEXT("IsInPackageMap"));
			Helper.AddFunction( XCGEA, TEXT("PawnActors"));
			Helper.AddFunction( XCGEA, TEXT("DynamicActors"));
			Helper.AddFunction( XCGEA, TEXT("InventoryActors"));
			Helper.AddFunction( XCGEA, TEXT("CollidingActors"));
			Helper.AddFunction( XCGEA, TEXT("NavigationActors"));
			Helper.AddFunction( XCGEA, TEXT("ConnectedDests"));
		}
		UClass* XCEL = FindObject<UClass>( NULL, TEXT("XC_Engine.XC_EditorLoader"), 1);
		if ( XCEL )
		{
			Helper.AddFunction( XCEL, TEXT("MakeColor"));
			Helper.AddFunction( XCEL, TEXT("Locs"));
			Helper.AddFunction( XCEL, TEXT("StringToName"));
			Helper.AddFunction( XCEL, TEXT("FindObject"));
			Helper.AddFunction( XCEL, TEXT("GetParentClass"));
			Helper.AddFunction( XCEL, TEXT("AllObjects"));
			Helper.AddFunction( XCEL, TEXT("AppSeconds"));
			Helper.AddFunction( XCEL, TEXT("HasFunction"));
			Helper.AddFunction( XCEL, TEXT("Or_ObjectObject"));
			Helper.AddFunction( XCEL, TEXT("Clock"));
			Helper.AddFunction( XCEL, TEXT("UnClock"));
			Helper.AddFunction( XCEL, TEXT("AppCycles"));
			Helper.AddFunction( XCEL, TEXT("FixName"));
			Helper.AddFunction( XCEL, TEXT("HNormal"));
			Helper.AddFunction( XCEL, TEXT("HSize"));
			Helper.AddFunction( XCEL, TEXT("InvSqrt"));
			Helper.AddFunction( XCEL, TEXT("MapRoutes"));
			Helper.AddFunction( XCEL, TEXT("BuildRouteCache"));
		}
	}

	if ( !FieldClass )
	{
		while ( Owner && !Owner->IsA(UClass::StaticClass()) )
			Owner = Cast<UStruct>(Owner->GetOuter());
		UBOOL IsActor = Owner && Owner->IsChildOf( AActor::StaticClass() );
		InName = FName( InIdentifier, FNAME_Find ); //Name may not have existed before
		if ( InName != NAME_None )
		{
			if ( IsActor )
				for ( int i=0 ; i<Helper.ActorFunctions.Num() ; i++ )
					if ( Helper.ActorFunctions(i)->GetFName() == InName )
						return Helper.ActorFunctions(i);
			for ( int i=0 ; i<Helper.ObjectFunctions.Num() ; i++ )
				if ( Helper.ObjectFunctions(i)->GetFName() == InName )
					return Helper.ObjectFunctions(i);
			for ( int i=0 ; i<Helper.StaticFunctions.Num() ; i++ )
				if ( Helper.StaticFunctions(i)->GetFName() == InName )
					return Helper.StaticFunctions(i);
		}
	}
	
	return nullptr;
}