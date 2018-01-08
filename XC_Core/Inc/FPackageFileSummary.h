#ifndef _INC_PFS
#define _INC_PFS

//Requires UnXC_Arc.h included somewhere

struct XC_CORE_API FGenerationInfo
{
	INT ExportCount;
	INT NameCount;

	FGenerationInfo( INT InExportCount, INT InNameCount )
	: ExportCount(InExportCount), NameCount(InNameCount)
	{}

	#ifdef _INC_XC_ARC
	XC_CORE_API friend FArchive_Proxy& operator<<( FArchive_Proxy& Ar, FGenerationInfo& Info )
	{
		guard(FGenerationInfo<<);
		return Ar << Info.ExportCount << Info.NameCount;
		unguard;
	}
	#endif
};

struct XC_CORE_API FPackageFileSummary
{
	INT		Tag;
	INT		FileVersion;
	DWORD	PackageFlags;
	INT		NameCount,		NameOffset;
	INT		ExportCount,	ExportOffset;
	INT     ImportCount,	ImportOffset;
	FGuid	Guid;
	TArray<FGenerationInfo> Generations;

	FPackageFileSummary();

	INT GetFileVersion() const { return (FileVersion & 0xffff); }
	INT GetFileVersionLicensee() const { return ((FileVersion >> 16) & 0xffff); }
	void SetFileVersions(INT Epic, INT Licensee) { if( GSys->LicenseeMode == 0 ) FileVersion = Epic; else FileVersion = ((Licensee << 16) | Epic); }

	#ifdef _INC_XC_ARC
	XC_CORE_API friend FArchive_Proxy& operator<<( FArchive_Proxy& Ar, FPackageFileSummary& Sum );
	#endif
};


XC_CORE_API FPackageFileSummary LoadPackageSummary( const TCHAR* File);
XC_CORE_API UBOOL FindPackageFile( const TCHAR* In, const FGuid* Guid, TCHAR* Out );

#endif
