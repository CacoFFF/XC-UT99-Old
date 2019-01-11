/*=============================================================================
Include this in only one CPP file, this isn't supposed to be available for
other classes anyways
=============================================================================*/

#ifndef _INC_COMMANDLETS
#define _INC_COMMANDLETS

static UObject* OuterMost( UObject* Other)
{
	while ( Other->GetOuter() )
		Other = Other->GetOuter();
	return Other;
}

static UBOOL InvalidCharacters( const TCHAR* Stream)
{
	#define aCHAR *Stream
	for ( ; aCHAR ; Stream++ )
	{
		if ( (aCHAR < 48) || (aCHAR >= 123) )
			return 1;
		if ( aCHAR == 95 )
			continue;
		if ( (aCHAR < 58) || (aCHAR >= 97) )
			continue;
		if ( (aCHAR < 65) || (aCHAR > 90) )
			return 1;
	}
	#undef aCHAR
	return 0;
}


class XC_CORE_API UStripSourceCommandlet : public UCommandlet
{
	DECLARE_CLASS(UStripSourceCommandlet,UCommandlet,CLASS_Transient,XC_Core);
	NO_DEFAULT_CONSTRUCTOR(UStripSourceCommandlet)
	void StaticConstructor();
	INT Main( const TCHAR* Parms );
};

class XC_CORE_API UDeobfuscateNamesCommandlet : public UCommandlet
{
	DECLARE_CLASS(UDeobfuscateNamesCommandlet,UCommandlet,CLASS_Transient,XC_Core);
	NO_DEFAULT_CONSTRUCTOR(UDeobfuscateNamesCommandlet)
	void StaticConstructor();
	INT Main( const TCHAR* Parms );
};

/*-----------------------------------------------------------------------------
	UStripSourceCommandlet
-----------------------------------------------------------------------------*/
//Move to CPP

void UStripSourceCommandlet::StaticConstructor()
{
	IsClient        = 1;
	IsEditor        = 1;
	IsServer        = 1;
	LazyLoad        = 0;
	ShowErrorCount  = 1;
}
INT UStripSourceCommandlet::Main( const TCHAR* Parms )
{
	FString PackageName;
	if( !ParseToken(Parms, PackageName, 0) )
		appErrorf( TEXT("A .u package file must be specified.") );

	warnf( TEXT("Loading package %s..."), *PackageName );
	warnf(TEXT(""));
	UObject* Package = LoadPackage( NULL, *PackageName, LOAD_NoWarn );
	if( !Package )
		appErrorf( TEXT("Unable to load %s"), *PackageName );


	for( TObjectIterator<UClass> It; It; ++It )
	{
		if( It->GetOuter() == Package && It->ScriptText )
		{
			warnf( TEXT("  Stripping source code from class %s"), It->GetName() );
			It->ScriptText->Text = FString(TEXT(" "));
			It->ScriptText->Pos = 0;
			It->ScriptText->Top = 0;
		}
	}

	warnf(TEXT(""));
	warnf(TEXT("Saving %s..."), *PackageName );
	SavePackage( Package, NULL, RF_Standalone, *PackageName, GWarn );

	GIsRequestingExit=1;
	return 0;
}
IMPLEMENT_CLASS(UStripSourceCommandlet)


/*-----------------------------------------------------------------------------
	UDeobfuscateNamesCommandlet
-----------------------------------------------------------------------------*/
//Move to CPP

void UDeobfuscateNamesCommandlet::StaticConstructor()
{
	IsClient        = 1;
	IsEditor        = 0;
	IsServer        = 1;
	LazyLoad        = 0;
	ShowErrorCount  = 1;
}
INT UDeobfuscateNamesCommandlet::Main( const TCHAR* Parms )
{
	FString PackageName;
	if( !ParseToken(Parms, PackageName, 0) )
		appErrorf( TEXT("A .u package file must be specified.") );

	warnf( TEXT("Loading package %s..."), *PackageName );
	warnf(TEXT(""));
	UObject* Package = LoadPackage( NULL, *PackageName, LOAD_NoWarn );
	if( !Package )
		appErrorf( TEXT("Unable to load %s"), *PackageName );

/*	INT ClassCount = 0;
	INT FunctionCount = 0;
	INT PropertyCount = 0;
*/	INT OtherCount = 0;

	for( TObjectIterator<UObject> It; It; ++It )
	{
		if ( OuterMost( *It) == Package )
		{
			if ( !InvalidCharacters( It->GetName()) )
				continue;
			FName NewName( *FString::Printf( TEXT("RemappedName%i"), OtherCount++) );
			FName OldName = It->GetFName();
			for( TObjectIterator<UObject> Et; Et; ++Et )
				if ( Et->GetFName() == OldName )
					*(INT*) (((DWORD) (*Et)) + 32) = NewName.GetIndex(); //Hardchange name
		}
	}

	warnf(TEXT("Deobfuscated %i names"), OtherCount);
	PackageName += TEXT("_Deobf.u");
	warnf(TEXT("Saving deobfuscated file to %s..."), *PackageName );
	warnf(TEXT("You may ignore the following error, it is expected."));
	warnf( TEXT("") );
	SavePackage( Package, NULL, RF_Standalone, *PackageName, GWarn );

	GIsRequestingExit=1;
	return 0;
}
IMPLEMENT_CLASS(UDeobfuscateNamesCommandlet)

#endif

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
