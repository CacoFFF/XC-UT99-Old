/*=============================================================================
	Travel manager to enhance coop games
=============================================================================*/

#ifndef _INC_XC_TRAVEL
#define _INC_XC_TRAVEL

#ifndef DISABLE_ADDONS
#include "XC_CoreObj.h"

struct FTravelPlayerMap
{
	INT PlayerID;
	FString PlayerName;
	FString TravelList;
	FTravelPlayerMap()
	:	PlayerID(0)
	,	PlayerName(0)
	,	TravelList(0)
	{};
};

class XC_ENGINE_API FXC_TravelManager : public FGenericSystem
{
	public:
	UXC_GameEngine*	Engine;
	BITFIELD		bAutoMode:1 GCC_PACK(4); //Do stuff myself
	BITFIELD		bNoPoll:1; //Do not operate during this level
	FLOAT			TimerCounter GCC_PACK(4); //For automatic manager

	TArray<FTravelPlayerMap> PlayerMap;
	
	FXC_TravelManager( UXC_GameEngine* InEngine=NULL)
	:	Engine(InEngine)
	,	TimerCounter( 2.f)
	,	PlayerMap()
	{
//		appMemzero( &PlayerMap, 24);
	};
	
	//FExec interface
	UBOOL Exec( const TCHAR* Cmd, FOutputDevice& Ar );

	//FGenericSystem interface
	INT Tick( FLOAT DeltaTime);
	UBOOL IsTyped( const TCHAR* Type);
	
	//FXC_TravelManager interface
	void Poll( FLOAT DeltaTime, UBOOL bForceUpdate=0);
	void FixUpPlayerId( APlayerPawn* P); //Checks for name changes
	void GenerateTravelInfo( APlayerPawn* P);
//	void PreMapChange( ULevel* OldLevel);
	void PostMapChange( ULevel* NewLevel, UBOOL bClearMap=0);
	
};
#endif

#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
