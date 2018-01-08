/*=============================================================================
	XC_Networking.cpp:
	UT version friendly implementation on networking extensions
=============================================================================*/

#include "XC_Core.h"
#include "Engine.h"
#include "FConfigCacheIni.h"
#include "XC_Networking.h"
#include "XC_Download.h"
#include "XC_LZMA.h"
#include "UnXC_Arc.h"
#include "FMallocThreadedProxy.h"
#include "FCodec_XC.h"


XC_CORE_API UBOOL b440Net = 0;

void FOutBunch_Hack::Init()
{
	b440 = (b440Net != 0);
}

//Editing across all versions
FOutBunchHeader* FOutBunch_Hack::Bunch()
{
	return (FOutBunchHeader*)(((BYTE*)this) + 48 + b440Net*8);
}
//Accessor
FArchiveHeader* FOutBunch_Hack::Archive()
{
	return (FArchiveHeader*)this;
}

//Prevent v436 destructor from killing the app
void FOutBunch_Hack::Exit()
{
	FOutBunchHeader* Header = Bunch();
	if ( Header->Buffer.GetData() )
		Header->Buffer.Empty();
	appMemzero( ((BYTE*)this)+48, 12); 
}


/*=============================================================================
XC_Core server commandlet
=============================================================================*/

void UXC_ServerCommandlet::StaticConstructor()
{
	guard(UXC_ServerCommandlet::StaticConstructor);

	LogToStdout = 1;
	IsClient    = 0;
	IsEditor    = 0;
	IsServer    = 1;
	LazyLoad    = 1;

	unguard;
}

INT UXC_ServerCommandlet::Main( const TCHAR* Parms)
{
	guard(UXC_ServerCommandlet::Main);

	debugf( NAME_Init, TEXT("XC_ServerCommandlet initializing..."));

	// Language.
	TCHAR Temp[256];
	if( GConfig->GetString( TEXT("Engine.Engine"), TEXT("Language"), Temp, ARRAY_COUNT(Temp) ) )
	UObject::SetLanguage( Temp );

    XC_InitTiming();

	UClass* EngineClass = UObject::StaticLoadClass( UEngine::StaticClass(), NULL, TEXT("ini:Engine.Engine.GameEngine"), NULL, LOAD_NoFail, NULL );
	UEngine* Engine = ConstructObject<UEngine>( EngineClass );
	Engine->Init();

	// Main loop.
	GIsRunning = 1;
	DOUBLE OldTime = appSecondsXC();
	DOUBLE SecondStartTime = OldTime;
	INT TickCount = 0;

	while( GIsRunning && !GIsRequestingExit )
	{
		// Update the world.
		guard(UpdateWorld);
		DOUBLE NewTime = appSecondsXC();
		FLOAT DeltaTime = NewTime - OldTime;
		Engine->Tick( DeltaTime );
		OldTime = NewTime;
		TickCount++;
		//Update CurrentTickRate value every 1 second
		if( OldTime > SecondStartTime + 1 )
		{
			Engine->CurrentTickRate = (FLOAT)TickCount / (OldTime - SecondStartTime);
			SecondStartTime = OldTime;
			TickCount = 0;
		}
		unguard;

		// Enforce optional maximum tick rate.
		guard(EnforceTickRate);
		FLOAT MaxTickRate = Engine->GetMaxTickRate();
		if( MaxTickRate>0.f )
		{
			FLOAT IdealDelta = 1.0f / MaxTickRate;
			FLOAT Delta = IdealDelta - (appSecondsXC()-OldTime);
			appSleep( Max(0.f,Delta - 0.0005f) ); //This can reduce sleep timing by 1ms

			//Attempt to approach the ideal time sleep-by-sleep
			while ( ((IdealDelta - (appSecondsXC()-OldTime)) - 0.000005f) > 0.f )
				appSleep( 0.f );
		}
		unguard;
	}
	GIsRunning = 0;
	return 0;
	unguard;
}
IMPLEMENT_CLASS(UXC_ServerCommandlet)


/*=============================================================================
XC_Core extended download protocols
=============================================================================*/

static FMallocThreadedProxy MallocProxy( E_Temporary);

struct FThreadDecompressor : public FThread
{
	volatile UBOOL bClosedByMain;
	UXC_Download* Download;
	TCHAR* TempFilename;
	TCHAR* Error;
	
	FThreadDecompressor( UXC_Download* DL)
	: FThread()
	, bClosedByMain(0)
	, Download(DL)
	, TempFilename(DL->TempFilename)
	, Error(DL->Error)	{}
};


void UXC_Download::StaticConstructor()
{
	EnableLZMA = 1;
	UseCompression = 1;
	
	if ( UNetConnection::StaticClass()->GetPropertiesSize() == 16088 )
		b440Net = 1;
}

void UXC_Download::Tick()
{
	guard(UXC_Download::Tick);
	if ( !IsDecompressing && Decompressor ) //Compression finished?
	{
		delete Decompressor;
		Decompressor = NULL;

		if( Error[0] )
		{
			GFileManager->Delete( TempFilename );
//HIGOR: Control channel is being closed, do not notify level of file failure (it will restart download using a different method!)
			Connection->Driver->Notify->NotifyReceivedFile( Connection, PackageIndex, Error, 0 );
		}
		else
		{
			// Success.
			TCHAR Msg[256];
			FString IniName = GSys->CachePath + PATH_SEPARATOR + TEXT("cache.ini");
			FConfigCacheIni CacheIni;
			CacheIni.SetString( TEXT("Cache"), Info->Guid.String(), *(*Info->URL) ? *Info->URL : Info->Parent->GetName(), *IniName );

			appSprintf( Msg, TEXT("Received '%s'"), Info->Parent->GetName() );
			Connection->Driver->Notify->NotifyProgress( TEXT("Success"), Msg, 4.f );
			Connection->Driver->Notify->NotifyReceivedFile( Connection, PackageIndex, Error, 0 );
		}
	
	}
	unguard;
}

void UXC_Download::ReceiveData( BYTE* Data, INT Count )
{
	guard( UXC_Download:ReceiveData);
	// Receiving spooled file data.
	if( Transfered==0 && !RecvFileAr )
	{
		// Open temporary file initially.
		debugf( NAME_DevNet, TEXT("Receiving package '%s'"), Info->Parent->GetName() );
		appCreateTempFilename( *GSys->CachePath, TempFilename );
		FixFilename( TempFilename);
		GFileManager->MakeDirectory( *GSys->CachePath, 0 );
		RecvFileAr = GFileManager->CreateFileWriter( TempFilename );
		if ( Count >= 13 )
		{
			QWORD* LZMASize = (QWORD*)&Data[5];
			if ( Info->FileSize == *LZMASize )
			{
				IsCompressed = 1;
				IsLZMA = 1;
				debugf( NAME_DevNet, TEXT("USES LZMA"));
			}
			INT* UzSignature = (INT*)&Data[0];
			if ( *UzSignature == 1234 || *UzSignature == 5678 )
			{
				IsCompressed = 1;
				debugf( NAME_DevNet, TEXT("USES UZ: Signature %i"), *UzSignature);
			}
		}
	}

	// Receive.
	if( !RecvFileAr )
	{
		// Opening file failed.
		DownloadError( LocalizeError(TEXT("NetOpen"),TEXT("Engine")) );
	}
	else
	{
		if( Count > 0 )
			((FArchive_Proxy*)RecvFileAr)->Serialize( Data, Count);
		if( RecvFileAr->IsError() )
		{
			// Write failed.
			DownloadError( *FString::Printf( LocalizeError(TEXT("NetWrite"),TEXT("Engine")), TempFilename ) );
		}
		else
		{
			// Successful.
			Transfered += Count;
			INT RealSize = CompressedSize ? CompressedSize : Info->FileSize;
			FString Msg1 = FString::Printf( (Info->PackageFlags&PKG_ClientOptional)?LocalizeProgress(TEXT("ReceiveOptionalFile"),TEXT("Engine")):LocalizeProgress(TEXT("ReceiveFile"),TEXT("Engine")), Info->Parent->GetName() );
			FString Msg2 = FString::Printf( LocalizeProgress(TEXT("ReceiveSize"),TEXT("Engine")), RealSize/1024, 100.f*Transfered/RealSize );
			Connection->Driver->Notify->NotifyProgress( *Msg1, *Msg2, 4.f );
		}
	}	
	unguard;
}

void UXC_Download::DownloadDone()
{
	guard( UXC_Download::DownloadDone);
	
	if ( Decompressor ) //Prevent XC_IpDrv reentrancy
		return;	
	FixFilename( TempFilename);
	if( RecvFileAr )
	{
		guard( DeleteFile );
		ARCHIVE_DELETE( RecvFileAr); //Sets NULL
		unguard;
	}
	if( SkippedFile )
	{
		guard( Skip );
		debugf( TEXT("Skipped download of '%s'"), Info->Parent->GetName() );
		GFileManager->Delete( TempFilename );
		TCHAR Msg[256];
		appSprintf( Msg, TEXT("Skipped '%s'"), Info->Parent->GetName() );
		Connection->Driver->Notify->NotifyProgress( TEXT("Success"), Msg, 4.f );
		Connection->Driver->Notify->NotifyReceivedFile( Connection, PackageIndex, TEXT(""), 1 );
		unguard;
	}
	else
	{
		UChannel** Channels = ((UXC_NetConnectionHack*)Connection)->GetChannels();
		if ( !Channels[0] || Channels[0]->Closing )
			return;
		if( !Error[0] && Transfered==0 )
			DownloadError( *FString::Printf( LocalizeError(TEXT("NetRefused"),TEXT("Engine")), Info->Parent->GetName() ) );
		if( !Error[0] && IsCompressed )
		{
			
			if ( IsA(UXC_ChannelDownload::StaticClass()) )
				((UXC_ChannelDownload*)this)->Ch->Download = NULL; //Detach download from channel
			StartDecompressor();
			return;
/*			TCHAR CFilename[256];
			appStrcpy( CFilename, TempFilename );
			appCreateTempFilename( *GSys->CachePath, TempFilename );
			FArchive* CFileAr = GFileManager->CreateFileReader( CFilename );
			FArchive_Proxy* CFilePx = (FArchive_Proxy*)CFileAr;

			FArchive* UFileAr = NULL; //Don't open yet
			if ( CFileAr && !IsLZMA )
				UFileAr = GFileManager->CreateFileWriter( TempFilename );

			if( !CFileAr || (!IsLZMA && !UFileAr) )
				DownloadError( LocalizeError(TEXT("NetOpen"),TEXT("Engine")) );
			else if ( IsLZMA )
			{
				if ( LzmaDecompress( CFileAr, *Dest, Error) )
					debugf( NAME_DevNet, TEXT("LZMA Decompress: %s"), TempFilename);
			}
			else
			{
				INT Signature;
				FString OrigFilename;
				CFilePx->Serialize( &Signature, sizeof(INT) );
				if( (Signature != 5678) && (Signature != 1234) )
					DownloadError( LocalizeError(TEXT("NetSize"),TEXT("Engine")) );
				else
				{
					*CFilePx << OrigFilename;
					FCodecFull Codec;
					Codec.AddCodec(new FCodecRLE);
					Codec.AddCodec(new FCodecBWT);
					Codec.AddCodec(new FCodecMTF);
					if ( Signature == 5678 ) //UZ2 Support
						Codec.AddCodec(new FCodecRLE);
					Codec.AddCodec(new FCodecHuffman);
					Codec.Decode( *CFileAr, *UFileAr );
				}
			}
			if( CFileAr )
			{
				ARCHIVE_DELETE( CFileAr);
				GFileManager->Delete( CFilename );
			}
			if( UFileAr )
				ARCHIVE_DELETE( UFileAr);*/
		}
		FixFilename( TempFilename);
		if( !Error[0] && !IsCompressed && GFileManager->FileSize(TempFilename)!=Info->FileSize ) //Compression screws up filesize, ignore
			DownloadError( LocalizeError(TEXT("NetSize"),TEXT("Engine")) );
		TCHAR Dest[256];
		DestFilename( Dest);
		if( !Error[0] && !IsLZMA && !GFileManager->Move( Dest, TempFilename, 1 ) ) //LZMA already performs this step
			DownloadError( LocalizeError(TEXT("NetMove"),TEXT("Engine")) );
		if( Error[0] )
		{
			GFileManager->Delete( TempFilename );
//HIGOR: Control channel is being closed, do not notify level of file failure (it will restart download using a different method!)
			Connection->Driver->Notify->NotifyReceivedFile( Connection, PackageIndex, Error, 0 );
		}
		else
		{
			// Success.
			TCHAR Msg[256];
			FString IniName = GSys->CachePath + PATH_SEPARATOR + TEXT("cache.ini");
			FConfigCacheIni CacheIni;
			CacheIni.SetString( TEXT("Cache"), Info->Guid.String(), *(*Info->URL) ? *Info->URL : Info->Parent->GetName(), *IniName );

			appSprintf( Msg, TEXT("Received '%s'"), Info->Parent->GetName() );
			Connection->Driver->Notify->NotifyProgress( TEXT("Success"), Msg, 4.f );
			Connection->Driver->Notify->NotifyReceivedFile( Connection, PackageIndex, Error, 0 );
		}
	}
	unguard;
}



THREAD_ENTRY(LZMADecompress,arg)
{
	//Setup environment
	FThreadDecompressor* TInfo = (FThreadDecompressor*)arg;
	
	//Setup decompression
	TCHAR Dest[256];
	TCHAR Error[256];
	TInfo->Download->DestFilename( Dest);
	LzmaDecompress( TInfo->TempFilename, Dest, Error);

	//Check that environment is still active (download could have been cancelled)
	if ( !TInfo->bClosedByMain )
	{
		if ( Error[0] )
		{
			appStrcpy( TInfo->Error, Error);
			if ( GFileManager->FileSize( Dest) )
				GFileManager->Delete( Dest);
		}
		TInfo->Download->IsDecompressing = 0;
		TInfo->ThreadEnded();
	}
	else
	{
		TInfo->ThreadEnded();
		delete TInfo;
	}
	MallocProxy.Exit();
	return 0;
}

THREAD_ENTRY(UZDecompress,arg)
{
	//Setup environment
	FThreadDecompressor* TInfo = (FThreadDecompressor*)arg;
	
	//Setup decompression
	TCHAR DecompressProgress[256];
	
	appCreateTempFilename( *GSys->CachePath, DecompressProgress );
	FArchive_Proxy* CFileAr = (FArchive_Proxy*)GFileManager->CreateFileReader( TInfo->Download->TempFilename );
	if ( CFileAr )
	{
		FArchive_Proxy* UFileAr = (FArchive_Proxy*)GFileManager->CreateFileWriter( DecompressProgress );
		if ( UFileAr )
		{
			INT Signature;
			FString OrigFilename;
			CFileAr->Serialize( &Signature, sizeof(INT) );
			if( (Signature != 5678) && (Signature != 1234) )
				TInfo->Download->DownloadError( LocalizeError(TEXT("NetSize"),TEXT("Engine")) );
			else
			{
				*CFileAr << OrigFilename;
				FCodecFull Codec;
				Codec.AddCodec(new FCodecRLE);
				Codec.AddCodec(new FCodecBWT);
				Codec.AddCodec(new FCodecMTF);
				if ( Signature == 5678 ) //UZ2 Support
					Codec.AddCodec(new FCodecRLE);
				Codec.AddCodec(new FCodecHuffman);
				Codec.Decode( *CFileAr, *UFileAr );
			}
			ARCHIVE_DELETE( UFileAr);
			if ( !TInfo->Download->Error[0] )
			{
				TCHAR Dest[256];
				TInfo->Download->DestFilename( Dest);
				if( !GFileManager->Move( Dest, DecompressProgress, 1 ) )
					TInfo->Download->DownloadError( LocalizeError(TEXT("NetMove"),TEXT("Engine")) );
				if ( GFileManager->FileSize( DecompressProgress) )
					GFileManager->Delete( DecompressProgress );
			}
		}
		ARCHIVE_DELETE( CFileAr);
		GFileManager->Delete( TInfo->Download->TempFilename );
	}
	else
		TInfo->Download->DownloadError( LocalizeError(TEXT("NetOpen"),TEXT("Engine")) );
	
	//Check that environment is still active (download could have been cancelled)
	if ( !TInfo->bClosedByMain )
	{
		TInfo->Download->IsDecompressing = 0;
		TInfo->ThreadEnded();
	}
	else
	{
		TInfo->ThreadEnded();
		delete TInfo;
	}
	MallocProxy.Exit();
	return 0;
}

void UXC_Download::StartDecompressor()
{
	if ( IsDecompressing ) //XC_IpDrv makes reentrant calls
		return;
	IsDecompressing = 1;
	MallocProxy.Init();
	Decompressor = new( TEXT("Decompressor Thread")) FThreadDecompressor(this);
	if ( IsLZMA )
		Decompressor->RunThread( &LZMADecompress, Decompressor);
	else
		Decompressor->RunThread( &UZDecompress, Decompressor);

	TCHAR Prg[128];
	appStrcpy( Prg, TEXT("%s: %iK > %iK"));
	FString Msg1 = FString::Printf( LocalizeProgress(TEXT("DecompressFile"),TEXT("XC_Core")), Info->Parent->GetName() );
	FString Msg2 = FString::Printf( Prg, (IsLZMA ? TEXT("LZMA") : TEXT("UZ")), Transfered/1024, Info->FileSize/1024 );
	Connection->Driver->Notify->NotifyProgress( *Msg1, *Msg2, 4.f );
}

void UXC_Download::DestFilename( TCHAR* T)
{
	T[0] = 0;
	appStrcat( T, *(GSys->CachePath));
	appStrcat( T, PATH_SEPARATOR);
	appStrcat( T, Info->Guid.String());
	appStrcat( T, *(GSys->CacheExt));
	FixFilename( T);
}
IMPLEMENT_CLASS(UXC_Download)



void UXC_ChannelDownload::StaticConstructor()
{
	DownloadParams = TEXT("Enabled");
	UChannel::ChannelClasses[7] = UXC_FileChannel::StaticClass();
	new( GetClass(),TEXT("Ch"), RF_Public) UObjectProperty( CPP_PROPERTY(Ch), TEXT("Download"), CPF_Edit|CPF_EditConst|CPF_Const, UFileChannel::StaticClass() );
}

void UXC_Download::Destroy()
{
	if ( Decompressor )
		Decompressor->bClosedByMain = true;
	MallocProxy.Exit();
	Super::Destroy();
}

void UXC_ChannelDownload::Serialize( FArchive& Ar )
{
	Super::Serialize( Ar );
//	*((FArchive_Proxy*)&Ar) << Ch;
}
UBOOL UXC_ChannelDownload::TrySkipFile()
{
	if( Ch && Super::TrySkipFile() )
	{
		FOutBunch_Hack Bunch( Ch, 1 );
		FString Cmd = TEXT("SKIP");
		Bunch << Cmd;
		Bunch.Bunch()->bReliable = 1;
		Ch->SendBunch( &Bunch, 0 );
		Bunch.Exit();
		return 1;
	}
	return 0;
}
void UXC_ChannelDownload::ReceiveFile( UNetConnection* InConnection, INT InPackageIndex, const TCHAR *Params, UBOOL InCompression )
{
	UXC_Download::ReceiveFile( InConnection, InPackageIndex, Params, InCompression );

	// Create channel.
	Ch = (UFileChannel *)Connection->CreateChannel( (EChannelType)7, 1 );

	if( !Ch )
	{
		DownloadError( LocalizeError(TEXT("ChAllocate"),TEXT("Engine")) );
		DownloadDone();
		return;
	}

	// Set channel properties.
	Ch->Download = (UChannelDownload*)this; //THIS IS A HACK!!!!
	Ch->PackageIndex = PackageIndex;

	// Send file request.
	FOutBunch_Hack Bunch( Ch, 0 );
	Bunch.Bunch()->ChType = 7;
	Bunch << Info->Guid;
	Bunch.Bunch()->bReliable = 1;
	check(!Bunch.IsError());
	Ch->SendBunch( &Bunch, 0 );
	Bunch.Exit();
}

void UXC_ChannelDownload::Destroy()
{
	if( Ch && Ch->Download == (UChannelDownload*)this )
		Ch->Download = NULL;
	Ch = NULL;
	Super::Destroy();
}
IMPLEMENT_CLASS(UXC_ChannelDownload)



UXC_FileChannel::UXC_FileChannel()
{
	Download = NULL;
}

void UXC_FileChannel::Init( UNetConnection* InConnection, INT InChannelIndex, INT InOpenedLocally )
{
	Super::Init( InConnection, InChannelIndex, InOpenedLocally );
	if ( InConnection && InConnection->Driver && !InConnection->Driver->ServerConnection ) //This is not a client
		ChType = CHTYPE_File; //Avoid ULevel->NotifyAcceptingChannel from deleting this channel
}

void UXC_FileChannel::ReceivedBunch( FInBunch& Bunch )
{
//	UNREAL ADV: BUG REPORTED BY LUIGI AURIEMMA
//	check(!Closing);
	guard( UXC_FileChannel:ReceivedBunch);
	if ( Closing )
		return;
	if( OpenedLocally )
	{
		// Receiving a file sent from the other side.  If Bunch.GetNumBytes()==0, it means the server refused to send the file.
		Download->ReceiveData( Bunch.GetData(), Bunch.GetNumBytes() );
	}
	else
	{
		if( !Connection->Driver->AllowDownloads )
		{
			// Refuse the download by sending a 0 bunch.
			debugf( NAME_DevNet, LocalizeError(TEXT("NetInvalid"),TEXT("Engine")) );
			FOutBunch_Hack Bunch( this, 1 );
			SendBunch( &Bunch, 0 );
			Bunch.Exit();
			return;
		}
		if( SendFileAr )
		{
			FString Cmd;
			Bunch << Cmd;
			if( !Bunch.IsError() && Cmd==TEXT("SKIP") )
			{
				// User cancelled optional file download.
				// Remove it from the package map
				debugf( TEXT("User skipped download of '%s'"), SrcFilename );
				Connection->PackageMap->List.Remove( PackageIndex );
				return;
			}
		}
		else
		{
			// Request to send a file.
			FGuid Guid;
			Bunch << Guid;
			if( !Bunch.IsError() )
			{
				for( INT i=0; i<Connection->PackageMap->List.Num(); i++ )
				{
					FPackageInfo& Info = Connection->PackageMap->List(i);
					if( Info.Guid==Guid && Info.URL!=TEXT("") )
					{
						FixFilename( *Info.URL );
						if( Connection->Driver->MaxDownloadSize>0 && GFileManager->FileSize(*Info.URL) > Connection->Driver->MaxDownloadSize )
							break;							
						appStrncpy( SrcFilename, *Info.URL, ARRAY_COUNT(SrcFilename) );
						if( Connection->Driver->Notify->NotifySendingFile( Connection, Guid ) )
						{
							check(Info.Linker);
							SendFileAr = NULL;
							FString FileToSend( SrcFilename);
							FileToSend += TEXT(".lzma");
							SendFileAr = GFileManager->CreateFileReader( *FileToSend);
							if ( !SendFileAr )
							{
								FileToSend = SrcFilename;
								FileToSend += TEXT(".uz");
								SendFileAr = GFileManager->CreateFileReader( *FileToSend);
							}
							if ( !SendFileAr )
								SendFileAr = GFileManager->CreateFileReader( SrcFilename );
							if( SendFileAr )
							{
								// Accepted! Now initiate file sending.
								debugf( NAME_DevNet, LocalizeProgress(TEXT("NetSend"),TEXT("Engine")), *FileToSend );
								PackageIndex = i;
								return;
							}
						}
					}
				}
			}
		}

		// Illegal request; refuse it by closing the channel.
		debugf( NAME_DevNet, LocalizeError(TEXT("NetInvalid"),TEXT("Engine")) );
		
		FOutBunch_Hack Bunch( this, 1 );
		SendBunch( &Bunch, 0 );
		Bunch.Exit();
	}
	unguard;
}

void UXC_FileChannel::Tick()
{
	UChannel::Tick();
	Connection->TimeSensitive = 1;
	INT Size;

	//TIM: IsNetReady(1) causes the client's bandwidth to be saturated. Good for clients, very bad
	// for bandwidth-limited servers. IsNetReady(0) caps the clients bandwidth.
	static UBOOL LanPlay = ParseParam(appCmdLine(),TEXT("lanplay"));
	while( !OpenedLocally && SendFileAr && IsNetReady(LanPlay) && (Size=MaxSendBytes())!=0 )
	{
		// Sending.
		INT Remaining = ((FArchive_Proxy*)SendFileAr)->TotalSize() - SentData;
		Size = Min( Size, Remaining );
		//Never send less than 13 bytes, we ensure LZMA header is sent in one chunk
		if ( (SentData == 0) && (Size <= 13) )
			return;
		FOutBunch_Hack Bunch( this, Size>=Remaining );

		//Serialize directly INTO the bunch // BROKEN?
//		SendFileAr->Serialize( Bunch.GetData(), Size);
		
		BYTE* Buffer = (BYTE*)appAlloca( Size );
		((FArchive_Proxy*)SendFileAr)->Serialize( Buffer, Size ); //Linux v440 net crashfix
		if( SendFileAr->IsError() )
		{
			//HANDLE THIS!!
		}
		SentData += Size;
		Bunch.Serialize( Buffer, Size );
		Bunch.Bunch()->bReliable = 1;
		check(!Bunch.IsError());
		SendBunch( &Bunch, 0 );
		Connection->FlushNet();
		if ( Bunch.Bunch()->bClose ) //Finished
			ARCHIVE_DELETE( SendFileAr);
		Bunch.Exit();
	}
}

void UXC_FileChannel::Destroy()
{
	check(Connection);
	if( RouteDestroy() )
		return;

	UChannel** Channels = ((UXC_NetConnectionHack*)Connection)->GetChannels();
	check( Channels[ChIndex]==this);

	// Close the file.
	if( SendFileAr )
		ARCHIVE_DELETE( SendFileAr);

	// Notify that the receive succeeded or failed.
	if( OpenedLocally && Download )
	{
		Download->DownloadDone();
		if ( Download ) //Detachable download may not want to be deleted yet
			delete Download;
	}
	UChannel::Destroy();
}
IMPLEMENT_CLASS(UXC_FileChannel)




//==============================================================================
// Net Connection Hack
//==============================================================================


//
// Setup any extra variables
//
void UXC_NetConnectionHack::StaticConstructor()
{
}


//
// Create a channel with a non-unique name.
//
UChannel* UXC_NetConnectionHack::CreateChannel( EChannelType ChType, UBOOL bOpenedLocally, INT ChIndex )
{
	guard(UXC_NetConnectionHack::CreateChannel);
	check(UChannel::IsKnownChannelType(ChType));
	AssertValid();

	UChannel** Channels = GetChannels(); //Override global variable
	
	
	if( ChIndex==INDEX_NONE )
	{
		INT FirstChannel = (ChType != CHTYPE_Control); //0 if control, 1 if other
		for( ChIndex=FirstChannel; ChIndex<MAX_CHANNELS; ChIndex++ )
			if( !Channels[ChIndex] )
				break;
		if( ChIndex==MAX_CHANNELS )
			return NULL;
	}

	// Make sure channel is valid.
	check(ChIndex<MAX_CHANNELS);
	check(Channels[ChIndex]==NULL);

	// Need to construct a non-unique name for this channel
	FName NewChannelName( *FString::Printf( TEXT("%s%i"), UChannel::ChannelClasses[ChType]->GetName(), ChIndex) );
	// Create channel. ** residing in the connection with the non-unique name
	UChannel* Channel = ConstructObject<UChannel>( UChannel::ChannelClasses[ChType], this, NewChannelName );
	Channel->Init( this, ChIndex, bOpenedLocally );
	Channels[ChIndex] = Channel;
	GetOpenChannels()->AddItem(Channel);

	return Channel;
	unguard;
}


//
// There are memory leaks with the data bunches, deal with this one day
//
void UXC_NetConnectionHack::Destroy()
{
	guard( XC_Core::~UXC_NetConnectionHack );
	Super::Destroy();
	//Fix for v451-v440
	if ( b440Net )
	{
		UNetConnection* Conn451 = (UNetConnection*) (((DWORD)this) + 20);
		if ( Conn451->QueuedAcks.GetData() )
			Conn451->QueuedAcks.Empty();
		if ( Conn451->ResendAcks.GetData() )
			Conn451->ResendAcks.Empty();
		if ( Conn451->OpenChannels.GetData() ) //Garbage collector will crash the game if we don't kill the channels
			Conn451->OpenChannels.Empty();
		if ( Conn451->SentTemporaries.GetData() )
			Conn451->SentTemporaries.Empty();
		if ( Conn451->ActorChannels.Num() > 0 )
			Conn451->ActorChannels.Empty();
		if ( Conn451->DownloadInfo.GetData() )
			Conn451->DownloadInfo.Empty();

#if DO_ENABLE_NET_TEST
		if ( Conn451->Delayed.GetData() )
			Conn451->Delayed.Empty();
#endif
		appMemzero( &Conn451->LastOut, 84); //FBitWriter size in v440
		appMemzero( &Conn451->Out, 84); //FBitWriter size in v440
		appMemzero( &Conn451->QueuedAcks, 132); //Clear dynamic arrays plus neg offsets
	}
	unguard;
}


IMPLEMENT_CLASS(UXC_NetConnectionHack)
