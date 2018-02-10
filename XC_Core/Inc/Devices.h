/*=============================================================================
	Devices.h:

	Revision history:
		* Created by Fernando Velázquez (Higor)
=============================================================================*/

#ifndef XC_DEVICES
#define XC_DEVICES


class XC_CORE_API FOutputDeviceFileXC : public FOutputDevice
{
public:
	FOutputDeviceFileXC( const TCHAR* InFilename = NULL );
	~FOutputDeviceFileXC();

	void SetFilename(const TCHAR* InFilename);
	void TearDown(); //Destructor replacement (static objects)
	void Flush();

	virtual void Serialize( const TCHAR* Data, EName Event );

private:
	FArchive*	LogAr;
	TCHAR		Filename[1024];
	UBOOL		Opened;
	UBOOL		Dead;

	FArchive* CreateArchive( DWORD MaxAttempts = 32);
	void Write( const TCHAR* C );
	void WriteDataToArchive(const TCHAR* Data, EName Event );
};





#define OLD_LINES 16
class FLogLine
{
public:
	EName Event;
	INT Len; //Allows faster matching
	TCHAR Msg[1024];
	
	UBOOL Matches( const FLogLine& o)
	{
		return o.Event == Event && o.Len == Len && !appStrcmp(o.Msg, Msg);
	}
};
class XC_CORE_API FOutputDeviceInterceptor : public FOutputDevice
{
public:
	FOutputDevice* Next;
	class FArchive_Proxy* LogCritical;
	volatile UBOOL SerializeLock; //Serialize being called

	EName Repeater;
	volatile UBOOL CriticalSet;
	INT RepeatCount;
	DWORD StartCmp, LastCmp, CurCmp;
	FLogLine MessageBuffer[OLD_LINES]; //Lines held for comparison

	//Constructor
	FOutputDeviceInterceptor( FOutputDevice* InNext=NULL );
	~FOutputDeviceInterceptor();

	//FOutputDevice interface
	void Serialize( const TCHAR* Msg, EName Event );

	//FOutputDeviceInterceptor
	void SetRepeaterText( TCHAR* Text);
	void ProcessMessage( const FLogLine& Line);
	void FlushRepeater();
	void ClearRepeater();
};


/** 
	If a launcher wishes to implement it's own singleton
	it should define DO_NOT_IMPORT_MALLOC and then implement
	the code in it's own source.
*/

#ifdef CUSTOM_MALLOC_SINGLETON
	#define MALLOC_IMPORT 
	#define MALLOC_SET_SINGLETON XC_CORE_API
#else
	#define MALLOC_IMPORT XC_CORE_API
	#define MALLOC_SET_SINGLETON 
#endif

class MALLOC_IMPORT FMallocThreadedProxy : public FMalloc
{
	INT Signature; //Stuff
	FMalloc* MainMalloc;
	UBOOL NoAttachOperations; //This malloc is fixed
	volatile INT Lock;

	#ifndef CUSTOM_MALLOC_SINGLETON
		static FMallocThreadedProxy* Singleton;
	#endif
public:
	FMallocThreadedProxy();
	FMallocThreadedProxy( FMalloc* InMalloc );
	
	// FMalloc interface.
	void* Malloc( DWORD Count, const TCHAR* Tag );
	void* Realloc( void* Original, DWORD Count, const TCHAR* Tag );
	void Free( void* Original );
	void DumpAllocs();
	void HeapCheck();
	void Init();
	void Exit();

	#ifndef CUSTOM_MALLOC_SINGLETON
		//Automated singleton operations
		void Attach();
		void Detach();
		UBOOL IsAttached();
	#endif

	static MALLOC_SET_SINGLETON FMallocThreadedProxy* GetInstance();
	static MALLOC_SET_SINGLETON void SetSingleton( FMallocThreadedProxy* NewSingleton);
};


#endif
