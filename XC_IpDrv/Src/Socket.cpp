/*============================================================================
	Socket.cpp
	Author: Fernando Velázquez

	Definitions for platform independant abstractions for Sockets
============================================================================*/


#if _WINDOWS
// WinSock includes.
	#define __WINSOCK__ 1
	#pragma comment(lib,"ws2_32.lib") //Use Winsock2
	#include <winsock2.h>
	#include <ws2tcpip.h>
	#include <conio.h>
	#define MSG_NOSIGNAL		0
#else
// BSD socket includes.
	#define __BSD_SOCKETS__ 1
	#include <stdio.h>
	#include <unistd.h>
	#include <sys/types.h>
	#include <sys/socket.h>
	#include <netinet/in.h>
	#include <netinet/ip.h>
	#include <arpa/inet.h>
	#include <netdb.h>
	#include <errno.h>
	#include <fcntl.h>

	#ifndef MSG_NOSIGNAL
		#define MSG_NOSIGNAL 0x4000
	#endif
#endif


// Provide WinSock definitions for BSD sockets.
#if __LINUX_X86__
	#define INVALID_SOCKET      -1
	#define SOCKET_ERROR        -1

/*	#define ECONNREFUSED        111
	#define EAGAIN              11*/
#endif

#include "UnIpDrv.h"

/*----------------------------------------------------------------------------
	Resolve.
----------------------------------------------------------------------------*/

// Resolution thread entrypoint.
DWORD ResolveThreadEntry( void* Arg)
{
	FResolveInfo* Info = (FResolveInfo*)Arg;
	Info->Addr = ResolveHostname( Info->HostName, Info->Error);
	return THREAD_END_OK;
}


/*----------------------------------------------------------------------------
	Generic socket.
----------------------------------------------------------------------------*/

const socket_type FSocketGeneric::InvalidSocket = INVALID_SOCKET;
const int32 FSocketGeneric::Error = SOCKET_ERROR;


FSocketGeneric::FSocketGeneric()
	: Socket( INVALID_SOCKET )
{}

FSocketGeneric::FSocketGeneric( bool bTCP, bool bIPv6)
{
	Socket = socket
			(
				bIPv6 ? AF_INET6 : AF_INET, //How to open multisocket?
				bTCP ? SOCK_STREAM : SOCK_DGRAM,
				bTCP ? IPPROTO_TCP : IPPROTO_UDP
			);
}

bool FSocketGeneric::Connect( FIPv4Endpoint& RemoteAddress)
{
	sockaddr_in addr = RemoteAddress.ToSockAddr();
	return connect( Socket, (sockaddr*)&addr, sizeof(addr)) == 0;
}

bool FSocketGeneric::Send( const uint8* Buffer, int32 BufferSize, int32& BytesSent)
{
	BytesSent = send( Socket, (const char*)Buffer, BufferSize, 0);
	return BytesSent >= 0;
}

bool FSocketGeneric::SendTo( const uint8* Buffer, int32 BufferSize, int32& BytesSent, const FIPv4Endpoint& Dest)
{
	sockaddr_in addr = Dest.ToSockAddr();
	BytesSent = sendto( Socket, (const char*)Buffer, BufferSize, 0, (sockaddr*)&addr, sizeof(addr) );
	return BytesSent >= 0;
}

bool FSocketGeneric::Recv( uint8* Data, int32 BufferSize, int32& BytesRead)
{
	BytesRead = recv( Socket, (char*)Data, BufferSize, 0);
	return BytesRead >= 0;
}

bool FSocketGeneric::RecvFrom( uint8* Data, int32 BufferSize, int32& BytesRead, FIPv4Endpoint& Source)
{
	uint8 addrbuf[28]; //Size of sockaddr_6 is 28, this should be safe for both kinds of sockets
	int32 addrsize = sizeof(addrbuf);

	BytesRead = recvfrom( Socket, (char*)Data, BufferSize, 0, (sockaddr*)addrbuf, (socklen_t*)&addrsize);
	//Take IPv4 until we figure out how to start multisocket
	Source = *(sockaddr_in*)addrbuf;
	return BytesRead >= 0;
}

bool FSocketGeneric::EnableBroadcast( bool bEnable)
{
	int32 Enable = bEnable ? 1 : 0;
	return setsockopt( Socket, SOL_SOCKET, SO_BROADCAST, (char*)&Enable, sizeof(Enable)) == 0;
}

void FSocketGeneric::SetQueueSize( int32 RecvSize, int32 SendSize)
{
	socklen_t BufSize = sizeof(RecvSize);
	setsockopt( Socket, SOL_SOCKET, SO_RCVBUF, (char*)&RecvSize, BufSize );
	getsockopt( Socket, SOL_SOCKET, SO_RCVBUF, (char*)&RecvSize, &BufSize );
	setsockopt( Socket, SOL_SOCKET, SO_SNDBUF, (char*)&SendSize, BufSize );
	getsockopt( Socket, SOL_SOCKET, SO_SNDBUF, (char*)&SendSize, &BufSize );
	debugf( NAME_Init, TEXT("%s: Socket queue %i / %i"), FSocket::API, RecvSize, SendSize );
}

uint16 FSocketGeneric::BindPort( FIPv4Endpoint& LocalAddress, int NumTries, int Increment)
{
	for( int32 i=0 ; i<NumTries ; i++ )
	{
		sockaddr_in addr = LocalAddress.ToSockAddr();
		if( !bind( Socket, (sockaddr*)&addr, sizeof(addr)) ) //Zero ret = success
		{
			if ( LocalAddress.Port == 0 ) //A random client port was requested, get it
			{
				sockaddr_in bound;
				int32 size = sizeof(bound);
				getsockname( Socket, (sockaddr*)(&bound), (socklen_t*)&size);
				LocalAddress.Port = ntohs(bound.sin_port);
			}
			return LocalAddress.Port;
		}
		if( LocalAddress.Port == 0 ) //Random binding failed/went full circle in port range
			break;
		LocalAddress.Port += Increment;
	}
	return 0;
}

ESocketState FSocketGeneric::CheckState( ESocketState CheckFor, double WaitTime)
{
	fd_set SocketSet;
	timeval Time;

	Time.tv_sec = (int32)WaitTime;
	Time.tv_usec = (int32) ((WaitTime - (double)Time.tv_sec) * 1000.0 * 1000.0);
	FD_ZERO(&SocketSet);
	FD_SET(Socket, &SocketSet);

	int Status = 0;
	if      ( CheckFor == SOCKET_Readable ) Status = select(Socket + 1, &SocketSet, nullptr, nullptr, &Time);
	else if ( CheckFor == SOCKET_Writable ) Status = select(Socket + 1, nullptr, &SocketSet, nullptr, &Time);
	else if ( CheckFor == SOCKET_HasError ) Status = select(Socket + 1, nullptr, nullptr, &SocketSet, &Time);

	if ( Status == Error )
		return SOCKET_HasError;
	else if ( Status == 0 )
		return SOCKET_Timeout;
	return CheckFor;
}

/*----------------------------------------------------------------------------
	Windows socket.
----------------------------------------------------------------------------*/
#ifdef __WINSOCK__

const int32 FSocketWindows::ENonBlocking = WSAEWOULDBLOCK;
const int32 FSocketWindows::EPortUnreach = WSAECONNRESET;
const TCHAR* FSocketWindows::API = TEXT("WinSock");

bool FSocketWindows::Init( FString& ErrorString )
{
	// Init WSA.
	static uint32 Tried = 0;
	if( !Tried )
	{
		Tried = 1;
		WSADATA WSAData;
		int32 Code = WSAStartup( MAKEWORD(2,2), &WSAData );
		if( !Code )
		{
			debugf( NAME_Init, TEXT("WinSock: version %i.%i (%i.%i), MaxSocks=%i, MaxUdp=%i"),
				WSAData.wVersion>>8,WSAData.wVersion&255,
				WSAData.wHighVersion>>8,WSAData.wHighVersion&255,
				WSAData.iMaxSockets,WSAData.iMaxUdpDg
			);
		}
		else
			ErrorString = FString::Printf( TEXT("WSAStartup failed (%s)"), ErrorText(Code) );
	}
	return true;
}

bool FSocketWindows::Close()
{
	if ( Socket != INVALID_SOCKET )
	{
		int32 err = closesocket( Socket);
		Socket = INVALID_SOCKET;
		return err == 0;
	}
	return false;
}

// This connection will not block the thread, must poll repeatedly to see if it's properly established
bool FSocketWindows::SetNonBlocking()
{
	uint32 NoBlock = 1;
	return ioctlsocket( Socket, FIONBIO, &NoBlock ) == 0;
}

// Reopen connection if a packet arrived after being closed? (apt for servers)
bool FSocketWindows::SetReuseAddr( bool bReUse )
{
	char optval = bReUse ? 1 : 0;
	bool bSuccess = (setsockopt( Socket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval)) == 0);
	if ( !bSuccess )
		debugf(TEXT("setsockopt with SO_REUSEADDR failed"));
	return bSuccess;
}

// This connection will not gracefully shutdown, and will discard all pending data when closed
bool FSocketWindows::SetLinger()
{
	linger ling;
	ling.l_onoff  = 1;	// linger on
	ling.l_linger = 0;	// timeout in seconds
	return setsockopt( Socket, SOL_SOCKET, SO_LINGER, (char*)&ling, sizeof(ling)) == 0;
}

TCHAR* FSocketWindows::ErrorText( int32 Code)
{
	if( Code == -1 )
		Code = WSAGetLastError();
	switch( Code )
	{
	#define CASE(n) case n: return TEXT(#n);
		CASE(WSAEINTR)
		CASE(WSAEBADF)
		CASE(WSAEACCES)
		CASE(WSAEFAULT)
		CASE(WSAEINVAL)
		CASE(WSAEMFILE)
		CASE(WSAEWOULDBLOCK)
		CASE(WSAEINPROGRESS)
		CASE(WSAEALREADY)
		CASE(WSAENOTSOCK)
		CASE(WSAEDESTADDRREQ)
		CASE(WSAEMSGSIZE)
		CASE(WSAEPROTOTYPE)
		CASE(WSAENOPROTOOPT)
		CASE(WSAEPROTONOSUPPORT)
		CASE(WSAESOCKTNOSUPPORT)
		CASE(WSAEOPNOTSUPP)
		CASE(WSAEPFNOSUPPORT)
		CASE(WSAEAFNOSUPPORT)
		CASE(WSAEADDRINUSE)
		CASE(WSAEADDRNOTAVAIL)
		CASE(WSAENETDOWN)
		CASE(WSAENETUNREACH)
		CASE(WSAENETRESET)
		CASE(WSAECONNABORTED)
		CASE(WSAECONNRESET)
		CASE(WSAENOBUFS)
		CASE(WSAEISCONN)
		CASE(WSAENOTCONN)
		CASE(WSAESHUTDOWN)
		CASE(WSAETOOMANYREFS)
		CASE(WSAETIMEDOUT)
		CASE(WSAECONNREFUSED)
		CASE(WSAELOOP)
		CASE(WSAENAMETOOLONG)
		CASE(WSAEHOSTDOWN)
		CASE(WSAEHOSTUNREACH)
		CASE(WSAENOTEMPTY)
		CASE(WSAEPROCLIM)
		CASE(WSAEUSERS)
		CASE(WSAEDQUOT)
		CASE(WSAESTALE)
		CASE(WSAEREMOTE)
		CASE(WSAEDISCON)
		CASE(WSASYSNOTREADY)
		CASE(WSAVERNOTSUPPORTED)
		CASE(WSANOTINITIALISED)
		CASE(WSAHOST_NOT_FOUND)
		CASE(WSATRY_AGAIN)
		CASE(WSANO_RECOVERY)
		CASE(WSANO_DATA)
		case 0:						return TEXT("WSANO_ERROR");
		default:					return TEXT("WSA_Unknown");
	#undef CASE
	}
}

int32 FSocketWindows::ErrorCode()
{
	return WSAGetLastError();
}



#endif
/*----------------------------------------------------------------------------
	Unix socket.
----------------------------------------------------------------------------*/
#ifdef __BSD_SOCKETS__

const int32 FSocketBSD::ENonBlocking = EAGAIN;
const int32 FSocketBSD::EPortUnreach = ECONNREFUSED;
const TCHAR* FSocketBSD::API = TEXT("Sockets");

bool FSocketBSD::Close()
{
	if ( Socket != INVALID_SOCKET )
	{
		int32 err = close( Socket);
		Socket = INVALID_SOCKET;
		return err == 0;
	}
	return false;
}

// This connection will not block the thread, must poll repeatedly to see if it's properly established
bool FSocketBSD::SetNonBlocking()
{
	int32 pd_flags;
	pd_flags = fcntl( Socket, F_GETFL, 0 );
	pd_flags |= O_NONBLOCK;
	return fcntl( Socket, F_SETFL, pd_flags ) == 0;
}

// Reopen connection if a packet arrived after being closed? (apt for servers)
bool FSocketBSD::SetReuseAddr( bool bReUse )
{
	int32 optval = bReUse ? 1 : 0;
	return setsockopt( Socket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval)) != 0;
}

// This connection will not gracefully shutdown, and will discard all pending data when closed
bool FSocketBSD::SetLinger()
{
	linger ling;
	ling.l_onoff  = 1;	// linger on
	ling.l_linger = 0;	// timeout in seconds
	return setsockopt( Socket, SOL_SOCKET, SO_LINGER, &ling, sizeof(ling)) == 0;
}

bool FSocketBSD::SetRecvErr()
{
	int32 on = 1;
	bool bSuccess = (setsockopt(Socket, SOL_IP, IP_RECVERR, &on, sizeof(on)) == 0);
	if ( !bSuccess )
		debugf(TEXT("setsockopt with IP_RECVERR failed"));
	return bSuccess;
}

TCHAR* FSocketBSD::ErrorText( int32 Code)
{
	if( Code == -1 )
		Code = errno;
	switch( Code )
	{
	case EINTR:					return TEXT("EINTR");
	case EBADF:					return TEXT("EBADF");
	case EACCES:				return TEXT("EACCES");
	case EFAULT:				return TEXT("EFAULT");
	case EINVAL:				return TEXT("EINVAL");
	case EMFILE:				return TEXT("EMFILE");
	case EWOULDBLOCK:			return TEXT("EWOULDBLOCK");
	case EINPROGRESS:			return TEXT("EINPROGRESS");
	case EALREADY:				return TEXT("EALREADY");
	case ENOTSOCK:				return TEXT("ENOTSOCK");
	case EDESTADDRREQ:			return TEXT("EDESTADDRREQ");
	case EMSGSIZE:				return TEXT("EMSGSIZE");
	case EPROTOTYPE:			return TEXT("EPROTOTYPE");
	case ENOPROTOOPT:			return TEXT("ENOPROTOOPT");
	case EPROTONOSUPPORT:		return TEXT("EPROTONOSUPPORT");
	case ESOCKTNOSUPPORT:		return TEXT("ESOCKTNOSUPPORT");
	case EOPNOTSUPP:			return TEXT("EOPNOTSUPP");
	case EPFNOSUPPORT:			return TEXT("EPFNOSUPPORT");
	case EAFNOSUPPORT:			return TEXT("EAFNOSUPPORT");
	case EADDRINUSE:			return TEXT("EADDRINUSE");
	case EADDRNOTAVAIL:			return TEXT("EADDRNOTAVAIL");
	case ENETDOWN:				return TEXT("ENETDOWN");
	case ENETUNREACH:			return TEXT("ENETUNREACH");
	case ENETRESET:				return TEXT("ENETRESET");
	case ECONNABORTED:			return TEXT("ECONNABORTED");
	case ECONNRESET:			return TEXT("ECONNRESET");
	case ENOBUFS:				return TEXT("ENOBUFS");
	case EISCONN:				return TEXT("EISCONN");
	case ENOTCONN:				return TEXT("ENOTCONN");
	case ESHUTDOWN:				return TEXT("ESHUTDOWN");
	case ETOOMANYREFS:			return TEXT("ETOOMANYREFS");
	case ETIMEDOUT:				return TEXT("ETIMEDOUT");
	case ECONNREFUSED:			return TEXT("ECONNREFUSED");
	case ELOOP:					return TEXT("ELOOP");
	case ENAMETOOLONG:			return TEXT("ENAMETOOLONG");
	case EHOSTDOWN:				return TEXT("EHOSTDOWN");
	case EHOSTUNREACH:			return TEXT("EHOSTUNREACH");
	case ENOTEMPTY:				return TEXT("ENOTEMPTY");
	case EUSERS:				return TEXT("EUSERS");
	case EDQUOT:				return TEXT("EDQUOT");
	case ESTALE:				return TEXT("ESTALE");
	case EREMOTE:				return TEXT("EREMOTE");
	case HOST_NOT_FOUND:		return TEXT("HOST_NOT_FOUND");
	case TRY_AGAIN:				return TEXT("TRY_AGAIN");
	case NO_RECOVERY:			return TEXT("NO_RECOVERY");
	case 0:						return TEXT("NO_ERROR");
	default:					return TEXT("Unknown");
	}
}

int32 FSocketBSD::ErrorCode()
{
	return errno;
}

#endif

/*----------------------------------------------------------------------------
	Other.
----------------------------------------------------------------------------*/

FIPv4Address ResolveHostname( ANSICHAR* HostName, TCHAR* Error)
{
	addrinfo Hint, *Result;
	appMemzero( &Hint, sizeof(Hint) );
	Hint.ai_family = AF_INET; //Get IPv4 addresses

	FIPv4Address Address = FIPv4Address::Any;

	int32 ErrorCode = getaddrinfo( HostName, NULL, &Hint, &Result);
	if ( ErrorCode != 0 )
	{
		if ( Error )
			appSprintf( Error, TEXT("getaddrinfo failed %s: %s"), ANSI_TO_TCHAR(HostName), gai_strerror(ErrorCode));
	}
	else
	{
		for ( ; Result ; Result=Result->ai_next )
			if ( (Result->ai_family == AF_INET) && Result->ai_addr )
			{
				Address = ((sockaddr_in*)Result->ai_addr)->sin_addr; //IPv4 struct
				break;
			}
		if ( (Address == FIPv4Address::Any) && Error )
			appSprintf( Error, TEXT("Unable to find host %s"), ANSI_TO_TCHAR(HostName));
	}
	return Address;
}

//Should export as C
FIPv4Address GetLocalHostAddress( FOutputDevice& Out, UBOOL& bCanBindAll)
{
	FIPv4Address HostAddr = FIPv4Address::Any;
	TCHAR Home[256] = TEXT("");
	ANSICHAR AnsiHostName[256] = "";

	bCanBindAll = false;
	if ( gethostname( AnsiHostName, 256) )
		Out.Logf(TEXT("%s: gethostname failed (%s)"), FSocket::API, FSocket::ErrorText() );

	if ( Parse( appCmdLine(), TEXT("MULTIHOME="), Home, ARRAY_COUNT(Home)) )
	{
		if ( !FIPv4Address::Parse( FString(Home), HostAddr) )
			Out.Logf( TEXT("Invalid multihome IP address %s"), Home);
	}
	else
	{
		TCHAR* Error = Home;
		HostAddr = ResolveHostname( AnsiHostName, Error);
		if ( Error )
			Out.Logf( Error);
		if ( HostAddr != FIPv4Address::Any )
		{
			if( !ParseParam(appCmdLine(),TEXT("PRIMARYNET")) )
				bCanBindAll = true;
			static uint32 First = 0;
			if( !First )
			{
				First = 1;
				debugf( NAME_Init, TEXT("%s: I am %s (%s)"), FSocket::API, ANSI_TO_TCHAR(AnsiHostName), *HostAddr.String() );
			}
		}
	}
	return HostAddr;
}

/*----------------------------------------------------------------------------
	The End.
----------------------------------------------------------------------------*/

