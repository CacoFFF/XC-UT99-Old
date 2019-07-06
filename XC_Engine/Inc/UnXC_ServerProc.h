/*=============================================================================
	UnXC_ServerProc.h
	Author: Fernando Velázquez

	Additional processing for a net server
=============================================================================*/

#ifndef _INC_XC_SERVERPROC
#define _INC_XC_SERVERPROC

class FNetClientInfo
{
public:
	UNetConnection* Connection;
	INT ObjectIndex;
	INT TickRate;
	FLOAT BandwidthFraction;
	FTime LastRelevancyTime;

	// Saturation measure
	#define SATURATION_FRACTIONS 10
	FLOAT Saturation[SATURATION_FRACTIONS];
	DWORD SaturationIndex;
	FLOAT AccumulatedSaturation;
	FLOAT SaturationTime;

	FNetClientInfo( UNetConnection* InConnection);

	void AddSaturation( FLOAT NewSaturation, FLOAT DeltaTime);
	FLOAT GetSaturation();
private:
	FNetClientInfo();
};

class FXC_ServerProc : public FGenericSystem
{
public:
	UXC_GameEngine* Engine;
	TArray<FNetClientInfo> Clients; //Won't need a hash... unless player count goes above 30
	TArray<double> TickTimeStamps; //Over the last second

	// Replication helper
	AActor** ConsiderList; //Global, not owned
	INT ConsiderListSize;
	INT SpecialConsiderListSize;

	FXC_ServerProc();

	// FGenericSystem interface
	INT Tick( FLOAT DeltaSeconds);
	UBOOL IsTyped( const TCHAR* Type);

	// FXC_ServerProc
	FNetClientInfo* GetClient( UNetConnection* InConnection);
	INT BuildConsiderLists( FMemStack& Mem, FLOAT DeltaSeconds);
	FLOAT CalcRealTickRate();
};

#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/