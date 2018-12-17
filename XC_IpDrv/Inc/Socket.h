/*============================================================================
	Socket.h
	Author: Fernando Velázquez

	Platform independant abstractions for Sockets
	Inspired in UE4's sockets.
============================================================================*/

#ifndef INC_SOCKET_H
#define INC_SOCKET_H

/*-----------------------------------------------------------------------------
	Definitions.
-----------------------------------------------------------------------------*/

#if _WINDOWS
	typedef uint32 socket_type;
#else
	typedef int32 socket_type;
#endif

#include "IPv4.h"

/*----------------------------------------------------------------------------
	Unified socket system 
----------------------------------------------------------------------------*/

enum ESocketState
{
	SOCKET_Timeout, //Used for return values
	SOCKET_Readable,
	SOCKET_Writable,
	SOCKET_HasError
};

/*----------------------------------------------------------------------------
	FSocket abstraction (win32/unix).
----------------------------------------------------------------------------*/

class FSocketGeneric
{
protected:
	socket_type Socket; //Should not be doing this!
public:
	static const socket_type InvalidSocket;
	static const int32 Error;

	FSocketGeneric();
	FSocketGeneric( bool bTCP, bool bIPv6=false);

	static bool Init( FString& Error)       {return true;}
	static TCHAR* ErrorText( int32 Code=-1)     {return (TCHAR*)TEXT("");}
	static int32 ErrorCode()                {return 0;}

	bool Close()                            {SetInvalid(); return false;}
	bool IsInvalid()                        {return Socket==InvalidSocket;}
	void SetInvalid()                       {Socket=InvalidSocket;}
	bool SetNonBlocking()                   {return true;}
	bool SetReuseAddr( bool bReUse=true)    {return true;}
	bool SetLinger()                        {return true;}
	bool SetRecvErr()                       {return false;}

	bool Connect( FIPv4Endpoint& RemoteAddress);
	bool Send( const uint8* Buffer, int32 BufferSize, int32& BytesSent);
	bool SendTo( const uint8* Buffer, int32 BufferSize, int32& BytesSent, const FIPv4Endpoint& Dest);
	bool Recv( uint8* Data, int32 BufferSize, int32& BytesRead); //Implement flags later
	bool RecvFrom( uint8* Data, int32 BufferSize, int32& BytesRead, FIPv4Endpoint& Source); //Implement flags later, add IPv6 type support
	bool EnableBroadcast( bool bEnable=1);
	void SetQueueSize( int32 RecvSize, int32 SendSize);
	uint16 BindPort( FIPv4Endpoint& LocalAddress, int NumTries=1, int Increment=1);
	ESocketState CheckState( ESocketState CheckFor, double WaitTime=0);
};

#ifdef _WINDOWS
class FSocketWindows : public FSocketGeneric
{
public:
	static const int32 ENonBlocking;
	static const int32 EPortUnreach;
	static const TCHAR* API;

	FSocketWindows() {}
	FSocketWindows( bool bTCP, bool bIPv6=false) : FSocketGeneric(bTCP, bIPv6) {}

	static bool Init( FString& Error);
	static TCHAR* ErrorText( int32 Code=-1);
	static int32 ErrorCode();
	
	bool Close();
	bool SetNonBlocking();
	bool SetReuseAddr( bool bReUse=true);
	bool SetLinger();
};
typedef FSocketWindows FSocket;


#else
class FSocketBSD : public FSocketGeneric
{
public:
	static const int32 ENonBlocking;
	static const int32 EPortUnreach;
	static const TCHAR* API;

	FSocketBSD() {}
	FSocketBSD( bool bTCP, bool bIPv6=false) : FSocketGeneric(bTCP, bIPv6) {}

	static TCHAR* ErrorText( int32 Code=-1);
	static int32 ErrorCode();

	bool Close();
	bool SetNonBlocking();
	bool SetReuseAddr( bool bReUse=true);
	bool SetLinger();
	bool SetRecvErr();
};
typedef FSocketBSD FSocket;


#endif




/*----------------------------------------------------------------------------
	Functions.
----------------------------------------------------------------------------*/

FIPv4Address ResolveHostname( ANSICHAR* HostName, TCHAR* Error);
//FIPv6Address ResolveHostname6( ANSICHAR* HostName, TCHAR* Error);
FIPv4Address GetLocalHostAddress( FOutputDevice& Out, UBOOL& bCanBindAll);

/*----------------------------------------------------------------------------
	The End.
----------------------------------------------------------------------------*/

#endif
