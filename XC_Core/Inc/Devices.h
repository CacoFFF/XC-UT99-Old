/*=============================================================================
	Devices.h:

	Revision history:
		* Created by Fernando Velázquez (Higor)
=============================================================================*/

#ifndef XC_DEVICES
#define XC_DEVICES

#include "Cacus/CacusOutputDevice.h"

//Some indicators to let XC_Engine (and devices) know that performing some operations is safe
extern XC_CORE_API UBOOL GLogUnlimitedLength;
extern XC_CORE_API UBOOL GMallocThreadSafe;

class XC_CORE_API FOutputDeviceFileXC : public FOutputDevice
{
	COutputDeviceFileUTF8 CacusOut;

public:
	FOutputDeviceFileXC( const TCHAR* InFilename = NULL );
	~FOutputDeviceFileXC();

	void SetFilename( const TCHAR* NewFilename);
	virtual void Serialize( const TCHAR* Data, EName Event );

private:
	void WriteDataToArchive(const TCHAR* Data, EName Event);
};

#define OLD_LINES 16
class XC_CORE_API FLogLine
{
public:
	EName Event;
	FString Msg;
	
	FLogLine();
	FLogLine( EName InEvent, const TCHAR* InData);
	bool operator==( const FLogLine& O);
};
class XC_CORE_API FOutputDeviceInterceptor : public FOutputDevice
{
public:
	FOutputDevice* Next;
	class COutputDeviceFile* CriticalOut;
	volatile UBOOL ProcessLock;
	volatile UBOOL SerializeLock; //Serialize being called

	EName Repeater;
	DWORD RepeatCount;
	TArray<FLogLine> MessageHistory; //Newer=Lower, up to OLD_LINES
	DWORD MultiLineCount;
	DWORD MultiLineCur;

	//Constructor
	FOutputDeviceInterceptor( FOutputDevice* InNext=NULL );
	~FOutputDeviceInterceptor();

	//FOutputDevice interface
	void Serialize( const TCHAR* Msg, EName Event );

	//FOutputDeviceInterceptor
	void SetRepeaterText( TCHAR* Text);
	void ProcessMessage( FLogLine& Line);
	void FlushRepeater();
	void SerializeNext( const TCHAR* Text, EName Event );
};
#endif
