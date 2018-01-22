/*=============================================================================
	FOutputDeviceInterceptor.h:
	Threaded spinlock styled log
	Avoids locking the game, which is good for log windows

	Revision history:
		* Created by Fernando Velázquez (Higor)
=============================================================================*/

#ifndef XC_FOUT_INTER
#define XC_FOUT_INTER

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


#endif
