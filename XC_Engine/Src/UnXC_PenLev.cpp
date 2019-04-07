/*=============================================================================
	UnXC_PenLev.cpp
	Author: Fernando Velázquez

	Pending level proxy.
=============================================================================*/

#include "XC_Engine.h"
#include "UnXC_Lev.h"
#include "XC_Networking.h"

//CANNOT INCLUDE!
XC_CORE_API UBOOL FindPackageFile( const TCHAR* In, const FGuid* Guid, TCHAR* Out );
//Because I don't want to add extra includes
//Need to get rid of this

FNetworkNotifyPL FNetworkNotifyPL::Instance;

void FNetworkNotifyPL::CountBytesLeft( UNetConnection* Connection)
{
	BytesLeft = 0;
	TArray<FPackageInfo>& List = Connection->PackageMap->List;
	for( INT i=0; i<List.Num(); i++ )
		if( List(i).PackageFlags & PKG_Need )
			BytesLeft += List(i).FileSize;
}


void FNetworkNotifyPL::SetPending( UPendingLevelMirror* NewPendingLevel)
{
	PendingLevel = NewPendingLevel;
	if ( PendingLevel && PendingLevel->NetDriver )
		PendingLevel->NetDriver->Notify = this;
	LastPackageIndex = INDEX_NONE;
	CurrentDownloader = 0;
	DownloadedCount = 0;
	BytesLeft = 0;
	XCGE_Server = 0;
}

void FNetworkNotifyPL::ReceiveNextFile( UNetConnection* Connection )
{
	UXC_NetConnectionHack* Conn = (UXC_NetConnectionHack*)Connection;
	guard(FNetworkNotifyPL::ReceiveNextFile);
	for( INT i=0; i<Conn->PackageMap->List.Num(); i++ )
		if( Conn->PackageMap->List(i).PackageFlags & PKG_Need )
		{
			Conn->ReceiveFile( i );
			if ( LastPackageIndex < 0 ) //First download
				LastPackageIndex = i;
			return;
		}
	if( *Conn->GetDownload() )
		delete *Conn->GetDownload();
	unguard;
}

EAcceptConnection FNetworkNotifyPL::NotifyAcceptingConnection()
{
	return PendingLevel->NotifyAcceptingConnection();
}

void FNetworkNotifyPL::NotifyAcceptedConnection( class UNetConnection* Connection )
{
	PendingLevel->NotifyAcceptedConnection( Connection );
}

UBOOL FNetworkNotifyPL::NotifyAcceptingChannel( class UChannel* Channel )
{
	return PendingLevel->NotifyAcceptingChannel( Channel );
}

ULevel* FNetworkNotifyPL::NotifyGetLevel()
{
	return PendingLevel->NotifyGetLevel();
}

void FNetworkNotifyPL::NotifyReceivedText( UNetConnection* Connection, const TCHAR* Text )
{
	if ( ParseCommand( &Text, TEXT("XC_ENGINE")) )
	{
		Parse( Text, TEXT("VERSION="), XCGE_Server);
		return;
	}
	else if ( ParseCommand( &Text, TEXT("WELCOME")) )
	{
		UXC_NetConnectionHack* Conn = (UXC_NetConnectionHack*)Connection;

		check(Conn==PendingLevel->NetDriver->ServerConnection);
		debugf( NAME_DevNet, TEXT("Welcomed by server: WELCOME %s"), Text );

		// Parse welcome message.
		Parse( Text, TEXT("LEVEL="), PendingLevel->URL.Map );
		ParseUBOOL( Text, TEXT("LONE="), PendingLevel->LonePlayer );
		Parse( Text, TEXT("CHALLENGE="), Conn->Challenge );

		INT i;
		// Make sure all packages we need are downloadable.
		for( i=0; i<Conn->PackageMap->List.Num(); i++ )
		{
			TCHAR Filename[256];
			FPackageInfo& Info = Conn->PackageMap->List(i);
			if( !FindPackageFile( Info.Parent->GetName(), &Info.Guid, Filename ) )
			{
				appSprintf( Filename, TEXT("%s%s"), Info.Parent->GetName(), DLLEXT );
				if( !Filename[0] || GFileManager->FileSize(Filename) <= 0 )
				{
					// We need to download this package.
					PendingLevel->FilesNeeded++;
					Info.PackageFlags |= PKG_Need;

					if( !PendingLevel->NetDriver->AllowDownloads || !(Info.PackageFlags & PKG_AllowDownload) )
					{
						PendingLevel->Error = FString::Printf( TEXT("Downloading '%s' not allowed"), Info.Parent->GetName() );
						PendingLevel->NetDriver->ServerConnection->State = USOCK_Closed;
						return;
					}
				}
			}
		}

		guard(ExamineDownloaders);
		if ( PendingLevel->FilesNeeded )
		{
			UClass* XC_DL_CL = UObject::StaticLoadClass( UDownload::StaticClass(), NULL, TEXT("XC_IpDrv.XC_HTTPDownload"), NULL, LOAD_NoWarn | LOAD_Quiet, NULL );
			if ( XC_DL_CL )
			{
				//Find all standard IpDrv downloaders
				for ( i=0 ; i<Conn->GetDownloadInfo()->Num() ; i++ )
				{
					FDownloadInfo* InfoBase = &(*Conn->GetDownloadInfo())(i);
					if ( InfoBase->ClassName == TEXT("IpDrv.HTTPDownload") )
					{
						//Find matching XC_IpDrv downloader, delete IpDrv one if found
						UBOOL Found = 0;
						for ( INT j=0 ; j<Conn->GetDownloadInfo()->Num() ; j++ )
						{
							FDownloadInfo* InfoSub = &(*Conn->GetDownloadInfo())(j);
							if ( i != j
								&& InfoSub->Class == XC_DL_CL
								&& !appStricmp( *InfoSub->Params, *InfoBase->Params) )
							{
								Found = 1;
								debugf( NAME_DevNet, TEXT("Removing DownloadInfo(%i) due to redundancy with XC version"), i);
								Conn->GetDownloadInfo()->Remove(i--);
								break;
							}
						}

						//Not found, upgrade to XC_IpDrv
						if ( !Found )
						{
							InfoBase->ClassName = TEXT("XC_IpDrv.XC_HTTPDownload");
							InfoBase->Class = XC_DL_CL;
							debugf( NAME_DevNet, TEXT("Upgrading DownloadInfo(%i) to XC_HTTPDownload"), i);
						}
					}
				}
			}
		}
		unguard;

		ReceiveNextFile( Conn );
		CountBytesLeft( Conn );
		PendingLevel->Success = 1;
		return;
	}

	PendingLevel->NotifyReceivedText( Connection, Text );
}

UBOOL FNetworkNotifyPL::NotifySendingFile( UNetConnection* Connection, FGuid GUID )
{
	return PendingLevel->NotifySendingFile( Connection, GUID);
}


void FNetworkNotifyPL::NotifyReceivedFile( UNetConnection* Connection, INT PackageIndex, const TCHAR* InError, UBOOL Skipped )
{
	UXC_NetConnectionHack* Conn = (UXC_NetConnectionHack*)Connection;

	guard(UXC_PendingLevel::NotifyReceivedFile);
	check(Conn->PackageMap->List.IsValidIndex(PackageIndex));

	//New package means that we tried with method 0
	if ( LastPackageIndex != PackageIndex )
		CurrentDownloader = 0;

	// Map pack to package.
	FPackageInfo& Info = Conn->PackageMap->List(PackageIndex);
	TCHAR Filename[256];
	if( *InError || !FindPackageFile( Info.Parent->GetName(), &Info.Guid, Filename) )
	{
		if ( LastPackageIndex == PackageIndex ) //Redownload attempt detected
			CurrentDownloader++;

		if( Conn->GetDownloadInfo()->Num() > CurrentDownloader ) //Was 1
		{
			// Try with the next download method.
			//Connection->DownloadInfo.Remove(0);
			Exchange( (*Conn->GetDownloadInfo())(0), (*Conn->GetDownloadInfo())(CurrentDownloader));
			ReceiveNextFile( Conn );
			Exchange( (*Conn->GetDownloadInfo())(0), (*Conn->GetDownloadInfo())(CurrentDownloader));
		}
		else
		{
			// All download methods failed
			if( PendingLevel->Error==TEXT("") )
				PendingLevel->Error = FString::Printf( LocalizeError(TEXT("DownloadFailed"),TEXT("Engine")), Info.Parent->GetName(), InError );
		}
	}
	else
	{
		// Now that a file has been successfully received, mark its package as downloaded.
		check(Conn==PendingLevel->NetDriver->ServerConnection);
		check(Info.PackageFlags&PKG_Need);
		Info.PackageFlags &= ~PKG_Need;
		PendingLevel->FilesNeeded--;
		if( Skipped )
			Conn->PackageMap->List.Remove( PackageIndex );
		else
			DownloadedCount++;
		// Send next download request.
		ReceiveNextFile( Conn );
	}
	LastPackageIndex = PackageIndex;
	CountBytesLeft( Conn);
	unguard;
}

void FNetworkNotifyPL::NotifyProgress( const TCHAR* Str1, const TCHAR* Str2, FLOAT Seconds )
{
	INT TotalFiles = PendingLevel->FilesNeeded + DownloadedCount;
	TCHAR RemainingData[64] = TEXT("");
	INT KBytes = BytesLeft / 1024;
	if ( KBytes < 1 )
		appSprintf( RemainingData, TEXT("%iB"), BytesLeft);
	else if ( KBytes < 10 ) //KBytes with dots
		appSprintf( RemainingData, TEXT("%i.%iK"), KBytes, (BytesLeft % 1024) / 103);
	else if ( KBytes < 1024 ) //KBytes
		appSprintf( RemainingData, TEXT("%iK"), KBytes);
	else if ( KBytes < 1024*10 ) //MBytes with dots
		appSprintf( RemainingData, TEXT("%i.%iM"), KBytes / 1024, (KBytes % 1024) / 103);
	else
		appSprintf( RemainingData, TEXT("%iM"), KBytes / 1024);

	//Compose a list of full package data
	FString NewStr2 = FString(Str2) + TEXT("\n") + FString::Printf( LocalizeProgress(TEXT("RemainingFiles"),TEXT("XC_Core")), DownloadedCount+1, TotalFiles, RemainingData);
	PendingLevel->NotifyProgress( Str1, *NewStr2, Seconds);
}