/*=============================================================================
	XC_CoreObj.h:
	Generic objects for XC_Core
=============================================================================*/

#ifndef _INC_XC_COREOBJ
#define _INC_XC_COREOBJ

#include "Atomics.h"

//==============================================
// Generic systems
//==============================================

class XC_CORE_API FGenericSystem : public FExec
{
public:
	//FExec interface
	UBOOL Exec( const TCHAR* Cmd, FOutputDevice& Ar );

	//FGenericSystem interface
	virtual UBOOL Init()
	{
		return true;
	}
	virtual INT Tick( FLOAT DeltaSeconds=0.f)
	{
		return 0;
	} 
	virtual void Exit() { }
	virtual ~FGenericSystem() { }

	virtual UBOOL IsTyped( const TCHAR* Type)
	{
		return 0; //return appStricmp( Type, TEXT("SomeName")) == 0;
	}
};

class XC_CORE_API FGenericSystemDispatcher : public FGenericSystem
{
public:
	//FExec interface
	UBOOL Exec( const TCHAR* Cmd, FOutputDevice& Ar );

	//FGenericSystem interface
	UBOOL Init();
	INT Tick( FLOAT DeltaSeconds=0.f);
	void Exit();
	UBOOL IsTyped( const TCHAR* Type);

	//FGenericSystemDispatcher interface
	FGenericSystemDispatcher( UBOOL InMultiExec=0)
	:	GenSystems()
	,	MultiExec( InMultiExec)
	{}
	FGenericSystem* FindByType( const TCHAR* Type); //Uses FGenericSystem::IsTyped to find a system of a specific type
	virtual ~FGenericSystemDispatcher();

	TArray<FGenericSystem*> GenSystems;
	UBOOL MultiExec;
};



//==============================================
// Class cache
//==============================================
//A standard cached property
struct XC_CORE_API FPropertyCache
{
	FPropertyCache* Next;
	UProperty* Property;
	FPropertyCache() {};
	FPropertyCache( UProperty* InProperty, FPropertyCache* InNext)
	:	Next( InNext)
	,	Property( InProperty)
	{};
};

//Base type of Class cache, subdefine for different property caching types
//The first object to be added should be the highest intended class
struct XC_CORE_API FClassPropertyCache
{
	FClassPropertyCache* Parent;
	FClassPropertyCache* Next;
	UClass* Class;
	UBOOL bProps;
	FPropertyCache* Properties;

	FClassPropertyCache( UClass* MasterClass=UObject::StaticClass() );
	FClassPropertyCache( FClassPropertyCache* InNext, UClass* InClass);

	FClassPropertyCache* GetCache( UClass* Other);
	inline UBOOL IsCached( UClass* Other)
	{
		return GetCache( Other) != NULL;
	}
	
	void GrabProperties( FMemStack& Mem);

	virtual UBOOL AcceptProperty( UProperty* Property)
	{
		return true;
	}
	virtual FClassPropertyCache* CreateParent( FMemStack& Mem)
	{
		return new(Mem) FClassPropertyCache( Next, Class->GetSuperClass() );
	}
};

#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
