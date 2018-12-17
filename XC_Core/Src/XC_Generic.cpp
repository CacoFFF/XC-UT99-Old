
// XC_Core generics

#if _WINDOWS
	#include "../OldCRT/API_MSC.h"
#endif

#include "XC_Core.h"
#include "XC_CoreObj.h"
#include "XC_CoreGlobals.h"


UBOOL FGenericSystem::Exec( const TCHAR* Cmd, FOutputDevice& Ar )
{
	return 0;
}

UBOOL FGenericSystemDispatcher::IsTyped( const TCHAR* Type)
{
	return appStricmp( Type, TEXT("Dispatcher")) == 0;
}

UBOOL FGenericSystemDispatcher::Exec( const TCHAR* Cmd, FOutputDevice& Ar )
{
	INT j=0;
	for ( INT i=0 ; i<GenSystems.Num() ; i++ )
	{
		j += GenSystems(i)->Exec( Cmd, Ar );
		if ( !MultiExec && j>0 )
			return 1;
	}
	return j;
}

UBOOL FGenericSystemDispatcher::Init()
{
	for ( INT i=0 ; i<GenSystems.Num() ; i++ )
		GenSystems(i)->Init();
	return GenSystems.Num() > 0;
}

INT FGenericSystemDispatcher::Tick( FLOAT DeltaSeconds)
{
	INT j=0;
	for ( INT i=0 ; i<GenSystems.Num() ; i++ )
		j += GenSystems(i)->Tick( DeltaSeconds);
	return j;
}

void FGenericSystemDispatcher::Exit()
{
	for ( INT i=0 ; i<GenSystems.Num() ; i++ )
		GenSystems(i)->Exit();
}

FGenericSystem* FGenericSystemDispatcher::FindByType( const TCHAR* Type)
{
	for ( INT i=0 ; i<GenSystems.Num() ; i++ )
		if ( GenSystems(i)->IsTyped( Type) )
			return GenSystems(i);
	return NULL;
}

FGenericSystemDispatcher::~FGenericSystemDispatcher()
{
	guard ( FGenericSystemDispatcher::Destructor );
	GenSystems.Empty();
	unguard;
}

FClassPropertyCache::FClassPropertyCache( UClass* MasterClass )
:	Parent( NULL), Next( NULL), Class( MasterClass ), bProps(0), Properties( NULL)
{
};

FClassPropertyCache::FClassPropertyCache( FClassPropertyCache* InNext, UClass* InClass)
:	Parent( NULL), Next( InNext), Class( InClass), bProps(0), Properties( NULL)
{
	for ( FClassPropertyCache* FPC=Next ; FPC ; FPC=FPC->Next )
		if ( FPC->Class == Class->GetSuperClass() )
		{
			Parent = FPC;
			break;
		}
};

FClassPropertyCache* FClassPropertyCache::GetCache( UClass* Other)
{
	for ( FClassPropertyCache* Cached=this ; Cached ; Cached=Cached->Next )
		if ( Cached->Class == Other )
			return Cached;
	return NULL;
}

void FClassPropertyCache::GrabProperties( FMemStack& Mem)
{
	UProperty* Prop = Class->PropertyLink;
	INT MinOffset = Class->GetSuperClass() ? Class->GetSuperClass()->GetPropertiesSize() : 0;
	while ( Prop && Prop->Offset >= MinOffset ) //Find Travel properties
	{
		if ( AcceptProperty(Prop) )
			Properties = new(Mem) FPropertyCache( Prop, Properties);
		Prop = Prop->PropertyLinkNext;
	}
	bProps = 1;
	if ( Next && !Parent && Class->GetSuperClass() ) //Not last, but needs parent
	{
		Next = CreateParent( Mem);
		Parent = Next;
		Parent->GrabProperties( Mem);
	}
}

