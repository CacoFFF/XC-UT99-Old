/*=============================================================================
	XC_Core extended download protocols
=============================================================================*/

#ifndef _INC_XC_DL
#define _INC_XC_DL

#include "FThread.h"

class XC_CORE_API UXC_Download : public UDownload
{
	DECLARE_ABSTRACT_CLASS(UXC_Download,UDownload,CLASS_Transient|CLASS_Config,XC_Core);
	NO_DEFAULT_CONSTRUCTOR(UXC_Download);

	INT CompressedSize; //Works as padding... actually, this is what v440 IMPLEMENTED!!!!
	UBOOL EnableLZMA;
	BYTE IsLZMA;
	BYTE IsBinary; //Take special considerations with this file, NOT IMPLEMENTED
	BYTE IsUNative; //UPackage has native code, NOT IMPLEMENTED
	BYTE IsDecompressing;
	UBOOL WaitingForApproval; //Needs approval before loading, NOT IMPLEMENTED
	TCHAR FileHash[64]; //Last char always 0x00, NOT IMPLEMENTED
	struct FThreadDecompressor* Decompressor;

	// Constructors.
	void StaticConstructor();

	// UObject interface.
	void Destroy();

	// UDownload interface
	void Tick();
	void DownloadDone();
	void ReceiveData( BYTE* Data, INT Count );
	
	// UXC_Download
	void StartDecompressor();
	void DestFilename( TCHAR* T);

};

class XC_CORE_API UXC_ChannelDownload : public UXC_Download
{
	DECLARE_CLASS(UXC_ChannelDownload,UXC_Download,CLASS_Transient|CLASS_Config,XC_Core);
    NO_DEFAULT_CONSTRUCTOR(UXC_ChannelDownload);
	
	// Variables.
	UFileChannel* Ch;

	// Constructors.
	void StaticConstructor();

	// UObject interface.
	void Destroy();
	void Serialize( FArchive& Ar );

	// UDownload Interface.
	void ReceiveFile( UNetConnection* InConnection, INT PackageIndex, const TCHAR *Params=NULL, UBOOL InCompression=0 );
	UBOOL TrySkipFile();
};

//
// A channel for exchanging binary files.
//
class XC_CORE_API UXC_FileChannel : public UFileChannel
{
	DECLARE_CLASS(UXC_FileChannel,UFileChannel,CLASS_Transient,XC_Core);

	// Receive Variables.
/*	UChannelDownload*	Download;		 // UDownload when receiving.

	// Send Variables.
	FArchive*			SendFileAr;		 // File being sent.
	TCHAR				SrcFilename[256];// Filename being sent.
	INT					PackageIndex;	 // Index of package in map.
	INT					SentData;		 // Number of bytes sent.
*/

	// Constructor.
	void StaticConstructor()
	{
		UChannel::ChannelClasses[7] = GetClass();
		GetDefault<UXC_FileChannel>()->ChType = (EChannelType)7;
	}
	UXC_FileChannel();
	void Init( UNetConnection* InConnection, INT InChIndex, UBOOL InOpenedLocally );
	void Destroy();

	// UChannel interface.
	void ReceivedBunch( FInBunch& Bunch );

	// UFileChannel interface.
//	FString Describe();
	void Tick();
};



#endif
/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
