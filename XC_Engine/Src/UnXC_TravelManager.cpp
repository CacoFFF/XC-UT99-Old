/*=============================================================================
	Advanced travel manager functions
	By Higor, feel free to use this code on your project.
=============================================================================*/

#include "XC_Engine.h"
#ifndef DISABLE_ADDONS
#include "UnXC_Travel.h"
#include "XC_ClassCache.h" //Move to XC_Core

#include "UnNet.h"

struct FStrPair
{
	INT HashNext;
	FString Key;
	FString Value;
};

struct FClassPropertyCacheTravel : public FClassPropertyCache
{
	FClassPropertyCacheTravel( UClass* MasterClass=AActor::StaticClass() )
	:	FClassPropertyCache( MasterClass)
	{};
	FClassPropertyCacheTravel( FClassPropertyCache* InNext, UClass* InClass)
	:	FClassPropertyCache( InNext, InClass)
	{};

	UBOOL AcceptProperty( UProperty* Property)
	{
		return Property->PropertyFlags & CPF_Travel;
	}
	FClassPropertyCache* CreateParent( FMemStack& Mem)
	{
		return new(Mem) FClassPropertyCacheTravel( Next, Class->GetSuperClass() );
	}
};
static FClassPropertyCacheTravel* TravelCache = NULL;


UBOOL FXC_TravelManager::Exec( const TCHAR* Cmd, FOutputDevice& Ar )
{
	guard(FXC_TravelManager::Exec);
	if ( ParseCommand(&Cmd,TEXT("TRAVELINFO")) )
	{
		TArray<FStrPair>& Map = *(TArray<FStrPair>*) &Engine->Level()->TravelInfo;
		debugf(NAME_XC_Engine, TEXT("Map has %i entries"), Map.Num() );
		for ( int i=0 ; i<Map.Num() ; i++ )
			debugf(NAME_XC_Engine, TEXT("Travel %s > %s"), *(Map(i).Key), *(Map(i).Value) );
	}
	else if ( ParseCommand(&Cmd,TEXT("TRAVELUPDATE")) )
		Poll( 0.f, true);
	else
		return 0;
	return 1;
	unguard;
}

INT FXC_TravelManager::Tick( FLOAT DeltaTime)
{
	if ( bNoPoll )
		return 0;
	Poll( DeltaTime);
	return 1;
}

UBOOL FXC_TravelManager::IsTyped( const TCHAR* Type)
{
	return appStricmp( Type, TEXT("TravelManager")) == 0;
}

void FXC_TravelManager::Poll( FLOAT DeltaTime, UBOOL bForceUpdate)
{
	if ( bNoPoll )
		return;
	guard( FXC_TravelManager::Poll);
	if ( Engine )
		bAutoMode = Engine->bAutoTravelManager;

	ULevel* Lev = Engine->Level();

	FMemMark Mark(GMem);
	FIteratorPList* BaseL = NULL;
	if ( Engine->Client && Engine->Client->Viewports.Num() && Engine->Client->Viewports(0) && Engine->Client->Viewports(0)->Actor )
		BaseL = new(GMem) FIteratorPList( Engine->Client->Viewports(0)->Actor, BaseL);
	if ( Lev && Lev->NetDriver && Lev->NetDriver->ClientConnections.Num() ) //Clients
	{
		for ( INT ip=0 ; ip < Lev->NetDriver->ClientConnections.Num() ; ip++ )
			if ( Lev->NetDriver->ClientConnections(ip) && Lev->NetDriver->ClientConnections(ip)->Actor )
				BaseL = new(GMem) FIteratorPList( Lev->NetDriver->ClientConnections(ip)->Actor, BaseL);
	}

	FIteratorPList* Link;
	for ( Link=BaseL ; Link ; Link=Link->Next )
		FixUpPlayerId( Link->P);
	if ( (bAutoMode || bForceUpdate) && BaseL ) //Timed every 1-2 seconds to scan players and update their stuff
	{
		TimerCounter -= DeltaTime;
		if ( bForceUpdate || TimerCounter < 0 )
		{
			TravelCache = new(GMem) FClassPropertyCacheTravel( AActor::StaticClass() ); //Base class
			TravelCache->GrabProperties(GMem);
			for ( Link=BaseL ; Link ; Link=Link->Next )
				GenerateTravelInfo( Link->P);
			TimerCounter = 2.0;
			TravelCache = NULL;
		}
	}
	Mark.Pop();
	unguard;
}


void FXC_TravelManager::FixUpPlayerId( APlayerPawn* P)
{
	guard(FXC_TravelManager::FixUpPlayerId);
	check( P);
	if ( P->PlayerReplicationInfo )
	{
		INT i;
		for ( i=0 ; i<PlayerMap.Num() ; i++ )
			if ( PlayerMap(i).PlayerID == P->PlayerReplicationInfo->PlayerID ) //Found
			{
				if ( appStrcmp( *(P->PlayerReplicationInfo->PlayerName), *PlayerMap(i).PlayerName) ) //Name mismatch
				{
					for ( INT j=0 ; j<PlayerMap.Num() ; j++ )
						if ( !appStrcmp( *(P->PlayerReplicationInfo->PlayerName), *PlayerMap(j).PlayerName) ) //Name match
						{
							P->PlayerReplicationInfo->PlayerName = PlayerMap(j).PlayerName; //Revert name
							return;
						}
					Engine->Level()->TravelInfo.Remove( *PlayerMap(i).PlayerName );
					PlayerMap(i).PlayerName = P->PlayerReplicationInfo->PlayerName;
					Engine->Level()->TravelInfo.Set( *PlayerMap(i).PlayerName, *PlayerMap(i).TravelList);
				}
				return;
			}
		//Not in map, let's find
		for ( i=0 ; i<PlayerMap.Num() ; i++ )
			if ( PlayerMap(i).PlayerName == P->PlayerReplicationInfo->PlayerName ) //Found
			{
				PlayerMap(i).PlayerID = P->PlayerReplicationInfo->PlayerID; //Attach
				return;
			}

		//Not in map, let's add
		PlayerMap.AddZeroed();
		PlayerMap.Last().PlayerID = P->PlayerReplicationInfo->PlayerID;
		PlayerMap.Last().PlayerName = P->PlayerReplicationInfo->PlayerName;
	}
	unguard;
}

#define CRLF TEXT("\r\n")
void FXC_TravelManager::GenerateTravelInfo( APlayerPawn* P)
{
	guard(FXC_TravelManager::GenerateTravelInfo);
	if ( !P || P->bDeleteMe )
		return;
	FString STR;
	TCHAR Temp[512] = TEXT("");
	for ( AActor* A=P ; A ; A=A->Inventory )
	{
		if ( A->bTravel )
		{
			FClassPropertyCache* Cached = TravelCache->GetCache( A->GetClass() );
			if ( !Cached )
			{
				TravelCache = new(GMem) FClassPropertyCacheTravel( TravelCache, A->GetClass() );
				TravelCache->GrabProperties(GMem);
				Cached = TravelCache;
				check( Cached->Class == A->GetClass() );
			}
			STR += FString::Printf(TEXT("Class=%s Name=%s") CRLF TEXT("{") CRLF, A->GetClass()->GetPathName(), A->GetName() );
			for ( ; Cached ; Cached=Cached->Parent )
			{
				for ( FPropertyCache* PCached=Cached->Properties ; PCached ; PCached=PCached->Next )
				{
					UProperty* Prop = PCached->Property;
					check( Prop);
					if ( Prop->Matches( A, A->GetClass()->GetDefaultActor(), 0) ) //Same as default, disregard ||TREAT AS ARRAY (3RD PARAMETER)
						continue;
						//Should be treating this as array!!!
					guard(TEST2);
					Prop->ExportText( 0, Temp, (BYTE*)A,(BYTE*)A, PPF_Localized );
					unguard;
					if ( Prop->IsA( UObjectProperty::StaticClass() ) && !Prop->Matches( A, 0, 0) )
					{
						UObject* TestObj = *(UObject**)( DWORD(A) + Prop->Offset );
						STR += FString::Printf( TEXT("%s=%s") CRLF TEXT("%s"), Prop->GetName(), TestObj->GetName(), Temp);
					}
					else
						STR += FString::Printf(  TEXT("%s=%s"), Prop->GetName(), Temp);
					STR += CRLF;
				}
			}
			STR += TEXT("}") CRLF;
		}
	}

	INT i;
	for ( i=0 ; i<PlayerMap.Num() ; i++ )
		if ( PlayerMap(i).PlayerID == P->PlayerReplicationInfo->PlayerID ) //Found
		{
			PlayerMap(i).TravelList = STR;
			break;
		}
	Engine->Level()->TravelInfo.Set( *P->PlayerReplicationInfo->PlayerName, *STR);
	unguard;
}

void FXC_TravelManager::PostMapChange( ULevel* NewLevel, UBOOL bClearMap)
{
	guard( FXC_TravelManager::PostMapChange);
	//Empty the map... let's not support cross map remembering yet..
	if ( bClearMap && (PlayerMap.Num() > 0) )
		PlayerMap.Empty();
	TimerCounter = 2;

	bNoPoll = 0;
	if ( !NewLevel || !NewLevel->IsServer() || !NewLevel->Actors.Num() || !NewLevel->NetDriver )
		bNoPoll = 1;

	if ( !bNoPoll && !bClearMap ) //Set new level's travel list for multi travel
	{
		for ( INT i=0 ; i<PlayerMap.Num() ; i++ )
			NewLevel->TravelInfo.Set( *PlayerMap(i).PlayerName, *PlayerMap(i).TravelList);
	}
	unguard;
}
#endif


/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
