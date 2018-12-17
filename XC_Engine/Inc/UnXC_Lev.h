/*=============================================================================
	UnXC_Lev.h
=============================================================================*/

#ifndef _INC_XC_LEV
#define _INC_XC_LEV

class XC_ENGINE_API UXC_Level : public ULevel
{
	public:
	UXC_Level()
	{};

	//UObject interface
	virtual void Destroy();

	//ULevel interface
//	virtual FCheckResult* MultiLineCheck( FMemStack& Mem, FVector End, FVector Start, FVector Size, UBOOL bCheckActors, ALevelInfo* LevelInfo, BYTE ExtraNodeFlags );
//	virtual UBOOL MoveActor( AActor *Actor, FVector Delta, FRotator NewRotation, FCheckResult &Hit, UBOOL Test=0, UBOOL IgnorePawns=0, UBOOL bIgnoreBases=0, UBOOL bNoFail=0 );
	virtual void TickNetServer( FLOAT DeltaSeconds );
	virtual AActor* SpawnActor( UClass* Class, FName InName=NAME_None, AActor* Owner=NULL, class APawn* Instigator=NULL, FVector Location=FVector(0,0,0), FRotator Rotation=FRotator(0,0,0), AActor* Template=NULL, UBOOL bNoCollisionFail=0, UBOOL bRemoteOwned=0 );
	virtual void CleanupDestroyed( UBOOL bForce );
	virtual void SetActorCollision( UBOOL bCollision );
	virtual void WelcomePlayer( UNetConnection* Connection, TCHAR* Optional=TEXT("") );

	//FNetworkNotify interface
	virtual EAcceptConnection NotifyAcceptingConnection();
	virtual void NotifyAcceptedConnection( class UNetConnection* Connection );
	virtual void NotifyReceivedText(UNetConnection* Connection, const TCHAR* Text);

	//UXC_Level interface
	virtual INT ServerTickClients( FLOAT DeltaSeconds );

	DECLARE_CLASS(UXC_Level,ULevel,0,XC_Engine);
};

//
// MIRROR!
//
class UPendingLevelMirror : public ULevelBase
{
public:
	// Variables.
	UBOOL		Success;
	UBOOL		SentJoin;
	UBOOL		LonePlayer;
	INT			FilesNeeded;
	FString		Error;
	FString		FailCode;
	FString		FailURL;
};

//
// XC_Engine vtable model for pending level network notify
//
class FNetworkNotifyPL : public FNetworkNotify
{
public:
	UPendingLevelMirror* PendingLevel;
	INT LastPackageIndex;
	INT CurrentDownloader;
	INT DownloadedCount;
	INT BytesLeft;
	
	void SetPending( UPendingLevelMirror* NewPendingLevel);
	void CountBytesLeft( UNetConnection* Connection);
	void ReceiveNextFile( UNetConnection* Connection );
	
	// FNetworkNotify interface
	EAcceptConnection NotifyAcceptingConnection();
	void NotifyAcceptedConnection( class UNetConnection* Connection );
	UBOOL NotifyAcceptingChannel( class UChannel* Channel );
	ULevel* NotifyGetLevel();
	void NotifyReceivedText( UNetConnection* Connection, const TCHAR* Text );
	UBOOL NotifySendingFile( UNetConnection* Connection, FGuid GUID );
	void NotifyReceivedFile( UNetConnection* Connection, INT PackageIndex, const TCHAR* Error, UBOOL Skipped );
	void NotifyProgress( const TCHAR* Str1, const TCHAR* Str2, FLOAT Seconds );
};


#ifndef DISABLE_ADDONS
#include "XC_CoreObj.h"

class XC_ENGINE_API FXC_BrushTrackerFixer : public FGenericSystem
{
public:
	TArray<AMover*> StaticMovers;
	UXC_GameEngine* Engine;
	ULevel* Level;

	//FExec interface
//	UBOOL Exec( const TCHAR* Cmd, FOutputDevice& Ar );

	FXC_BrushTrackerFixer( UXC_GameEngine* InEngine);

	//FGenericSystem interface
	UBOOL Init();
	INT Tick( FLOAT DeltaSeconds=0.f);
	void Exit();

	UBOOL IsTyped( const TCHAR* Type);
};

#endif



#endif
