/*=============================================================================
	UnXC_ConnHandler.h
=============================================================================*/

class XC_ENGINE_API AXC_ConnectionHandler : public AActor
{
	public:
	FLOAT DatalessTimeout; //Timeout for dataless connections in normal conditions
	FLOAT CriticalTimeout; //Timeout for dataless connections in critical conditions
	INT CriticalConnCount; //Amount of dataless connections needed to trigger critical mode
	INT ExtraTCPQueries; //Extra TCPNetDriver queries per frame
	
	virtual UBOOL Tick( FLOAT DeltaTime, enum ELevelTick TickType );

 	static const TCHAR* StaticConfigName() {return TEXT("XC_Engine");}
	NO_DEFAULT_CONSTRUCTOR(AXC_ConnectionHandler)
	DECLARE_CLASS(AXC_ConnectionHandler,AActor,0|CLASS_Config,XC_Engine)
};
