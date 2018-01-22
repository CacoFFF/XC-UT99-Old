/*=============================================================================
	Networking api
=============================================================================*/

#ifndef _INC_XC_NETWORKING
#define _INC_XC_NETWORKING

#include "UnNet.h"

XC_CORE_API extern UBOOL b440Net;
XC_CORE_API void CleanupBunch( FOutBunch* Bunch); //Prevent v436 destructor from killing the app

struct FArchiveHeader
{
	INT ArVer;
	INT ArNetVer;
	INT ArLicenseeVer;
	UBOOL ArIsLoading;
	UBOOL ArIsSaving;
	UBOOL ArIsTrans;
	UBOOL ArIsPersistent;
	UBOOL ArForEdit;
	UBOOL ArForClient;
	UBOOL ArForServer;
	UBOOL ArIsError;
};
struct XC_CORE_API FOutBunchHeader
{
	TArray<BYTE> Buffer;
	INT   Num;
	INT   Max;
	FOutBunch*		Next; //Starting offset of +8 in v440
	UChannel*		Channel;
	FTime			Time;
	UBOOL			ReceivedAck;
	INT				ChIndex;
	INT				ChType;
	INT				ChSequence;
	INT				PacketId;
	BYTE			bOpen;
	BYTE			bClose;
	BYTE			bReliable;

	//Editing across all versions
	static FOutBunchHeader* GetHeader( FOutBunch* Other);
};


//
// A bunch of data to send.
// This works in both v440 and v436
// Just remember to call Exit() when finished using
//
class XC_CORE_API FOutBunch_Hack : public FOutBunch // Size = 108 // Size  = 116 in v440
{ //This class should normalize it to 116 for proper stack allocation in GCC
private:
	BYTE Padding[7];
public:
	BYTE b440; //This byte is always free

	// Forward everything to Engine.dll
	FORCEINLINE FOutBunch_Hack()
	: FOutBunch()
	{
		Init();
	};
	FORCEINLINE FOutBunch_Hack( UChannel* InChannel, UBOOL bClose )
	: FOutBunch( InChannel, bClose)
	{
		Init();
	};
	
	//Data accessors
	FArchiveHeader* Archive();
	FOutBunchHeader* Bunch();
	
	void Exit();
	
private:
	void Init();
};


//
// A improved server commandlet
// Uses QueryPerformanceCounter based timers as seen in appSecondsXC
//
class XC_CORE_API UXC_ServerCommandlet : public UCommandlet
{
	DECLARE_CLASS(UXC_ServerCommandlet,UCommandlet,CLASS_Transient,XC_Core);
	void StaticConstructor();
	INT Main( const TCHAR* Parms );
};


class XC_CORE_API UXC_NetConnectionHack : public UNetConnection
{
public:
	DECLARE_ABSTRACT_CLASS(UXC_NetConnectionHack,UNetConnection,CLASS_Transient|CLASS_Config,XC_Core);
    NO_DEFAULT_CONSTRUCTOR(UXC_NetConnectionHack);

	UXC_NetConnectionHack( UNetDriver* Driver, const FURL& InURL )
	: UNetConnection( Driver, InURL)
	{}
	
	INT Padding[5];
	INT XCGE_Ver; //Remote XCGE ver



	void StaticConstructor();
	
	inline UChannel** GetChannels()
	{
		return (UChannel**) (((BYTE*)Channels) + b440Net * 20);
	}
	inline TArray<UChannel*>* GetOpenChannels()
	{
		return (TArray<UChannel*>*) (((BYTE*)&OpenChannels) + b440Net * 20);
	}
	inline TArray<AActor*>* GetSentTemporaries()
	{
		return (TArray<AActor*>*) (((BYTE*)&SentTemporaries) + b440Net * 20);
	}
	inline TMap<AActor*,UActorChannel*>* GetActorChannels()
	{
		return (TMap<AActor*,UActorChannel*>*) (((BYTE*)&ActorChannels) + b440Net * 20);
	}
	inline UDownload** GetDownload()
	{
		return (UDownload**) (((BYTE*)&Download) + b440Net * 20);
	}
	inline TArray<FDownloadInfo>* GetDownloadInfo()
	{
		return (TArray<FDownloadInfo>*) (((BYTE*)&DownloadInfo) + b440Net * 20);
	}

	//Improved non-virtual functions
	UChannel* CreateChannel( enum EChannelType Type, UBOOL bOpenedLocally, INT ChannelIndex=INDEX_NONE );

	
	//UObject interface
	void Destroy();
};


#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
