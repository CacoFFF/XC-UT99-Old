/*=============================================================================
	FOutputDeviceFile.h: ANSI file output device.
	Copyright 1997-1999 Epic Games, Inc. All Rights Reserved.

	Revision history:
		* Created by Tim Sweeney
		* Adapted to more current dates by Higor


	FOutputDeviceFile_XC.h
		* Thread safe
		* No overflow
		* Last lines cached for smaller filesizes
	
=============================================================================*/

#define OLD_LINES 12
#include "Atomics.h"

struct OldLineCache
{
	INT Length;
	TCHAR Text[1024];
	enum EName MyEvent;
	
	void Init()
	{
		Length = 0;
		Text[0] = 0;
	}
	UBOOL Matches( const TCHAR* Data)
	{
		for ( INT i=0 ; i<Length ; i++ )
		{
			if ( !Data[i] )
				return 0;
			if ( Text[i] != Data[i] )
				return 0;
		}
		if ( !Data[i] )
			return 1;
		if ( Length == 1023 )
			return 1;
		return 0;
	}
	void Set( const TCHAR* Data, INT NLength, enum EName NEvent)
	{
		MyEvent = NEvent;
		Length = NLength;
		appStrncpy( Text, Data, Length+1);
	}
};

//
// ANSI file output device.
//
class FOutputDeviceFile_XC : public FOutputDevice
{
public:
	FOutputDeviceFile_XC()
	: LogAr( NULL )
	, Opened( 0 )
	, Dead( 0 )
	{
		Filename[0]=0;
		ResetPrevs();
	}
	~FOutputDeviceFile_XC()
	{
		if( LogAr )
		{
			Logf( NAME_Log, TEXT("Log file closed, %s"), appTimestamp() );
			delete LogAr;
			LogAr = NULL;
		}
	}
	void ResetPrevs()
	{
		CurLine = 0;
		StartCurLine = 0;
		LastCurLine = 0;
		RepeatCount = 0;
		for ( INT i=0 ; i<OLD_LINES ; i++ )
			PrevLines[i].Init();
	}
	INT XC_TCHAR_to_ANSI( const TCHAR* Ch, ANSICHAR* ACh)
	{
		INT i = 0;
		for( ; Ch[i]; i++ )
			ACh[i] = ToAnsi(Ch[i]);
		ACh[i] = 0;
		return i;
	}
	void Serialize( const TCHAR* Data, enum EName Event )
	{
		static UBOOL Entry=0;
		static UBOOL ForceFlush=0;
		if( !GIsCriticalError || Entry )
		{
			if( Data[0] && !FName::SafeSuppressed(Event) )
			{
				if( !LogAr && !Dead )
				{
					// Make log filename.
					if( !Filename[0] )
					{
						appStrcpy( Filename, appBaseDir() );
						if
						(	!Parse(appCmdLine(), TEXT("LOG="), Filename+appStrlen(Filename), ARRAY_COUNT(Filename)-appStrlen(Filename) )
						&&	!Parse(appCmdLine(), TEXT("ABSLOG="), Filename, ARRAY_COUNT(Filename) ) )
						{
							appStrcat( Filename, appPackage() );
							appStrcat( Filename, TEXT(".log") );
						}
					}

					// Open log file.
					LogAr = GFileManager->CreateFileWriter( Filename, FILEWRITE_AllowRead|FILEWRITE_Unbuffered|(Opened?FILEWRITE_Append:0));
					if( LogAr )
					{
						Opened = 1;
#if UNICODE && !FORCE_ANSI_LOG
						_WORD UnicodeBOM = UNICODE_BOM;
						LogAr->Serialize( &UnicodeBOM, 2 );
#endif
						Logf( NAME_Log, TEXT("Log file open, %s"), appTimestamp() );
					}
					else Dead = 1;
				}
				UBOOL bDoLog = 1;
				if( LogAr && Event!=NAME_Title )
				{
#if FORCE_ANSI_LOG && UNICODE
					if ( ForceFlush == 0 )
					{
						if ( StartCurLine == CurLine ) //Single line comparison
						{
							if ( PrevLines[CurLine].Matches( Data) )
							{
								RepeatCount++;
								bDoLog = 0;
							}
							else if ( RepeatCount )
							{
								TCHAR Ch[128];	ANSICHAR ACh[128];
								appSprintf( Ch, TEXT("XC_UCC: === Last line repeats %i times.%s"), RepeatCount, LINE_TERMINATOR);
								if( GLogHook )
									GLogHook->Serialize( Ch, NAME_Warning );
								INT i = XC_TCHAR_to_ANSI( Ch, ACh);
								LogAr->Serialize( ACh, i);
								ResetPrevs();
							}
							else //Attempt to find and setup multi line here!
							{
								for ( INT i=1 ; i<OLD_LINES ; i++ )
								{
									INT Idx = (CurLine-i) % OLD_LINES;
									if ( PrevLines[Idx].Matches( Data) ) //One of the previous lines indeed matches...
									{
										RepeatCount = 0; //Dont log yet, may not be a full repeat yet
										StartCurLine = Idx;
										LastCurLine = (Idx+1)%OLD_LINES;
										bDoLog = 0;
										break;
									}
								}
							}
						}
						else //Multi line comparison
						{
							if ( PrevLines[LastCurLine].Matches( Data) )
							{
								if ( LastCurLine == CurLine ) //Combo just ended successfully, restart and increase counter
								{
									LastCurLine = StartCurLine;
									RepeatCount++;
								}
								else
									LastCurLine = (LastCurLine+1) % OLD_LINES;
								bDoLog = 0;
							}
							else //No match, flush buffered lines
							{
								ForceFlush++;
								if ( RepeatCount ) //Only print repeat info if there was repeat
								{
									TCHAR Ch[128];	ANSICHAR ACh[128];
									appSprintf( Ch, TEXT("XC_UCC: === Last %i lines repeat %i times%s"), (CurLine-StartCurLine)%OLD_LINES + 1, RepeatCount, LINE_TERMINATOR);
									if( GLogHook )
										GLogHook->Serialize( Ch, NAME_Warning );
									INT i = XC_TCHAR_to_ANSI( Ch, ACh);
									LogAr->Serialize( ACh, i);
								}
								INT BufStart = StartCurLine;
								INT BufLast = LastCurLine;
								while ( BufStart != BufLast )
								{
									Serialize( Data, PrevLines[StartCurLine].MyEvent);
									BufStart = (BufStart+1) % OLD_LINES;
								}
								if ( RepeatCount )
									ResetPrevs(); //Reset all buffered lines if there was repeat
								ForceFlush--;
							}
						}
					}
					if ( bDoLog )
					{
						//Proceed to log
						const TCHAR* EventString = FName::SafeString(Event);
						ANSICHAR ACh[1024];

						//Serialize event string
						INT i = XC_TCHAR_to_ANSI( EventString, ACh);
						ACh[i++] = ':';
						ACh[i++] = ' ';
						ACh[i] = 0;
						LogAr->Serialize( ACh, i);

						INT Length = Min( appStrlen( Data), 1023);
						CurLine = (CurLine+1)%OLD_LINES;
						LastCurLine = CurLine;
						StartCurLine = CurLine;
						PrevLines[CurLine].Set( Data, Length, Event);
						
						for( i=0; i<Length; i++ )
							ACh[i] = ToAnsi( Data[i] );
						ACh[i] = 0;
						LogAr->Serialize( ACh, i );
						TCHAR Ch[8];
						appSprintf( Ch, LINE_TERMINATOR);
						for( i=0 ; Ch[i]; i++ )
							ACh[i] = ToAnsi(Ch[i]);
						ACh[i] = 0;
						LogAr->Serialize( ACh, i );
					}
#else
					WriteRaw( FName::SafeString(Event) );
					WriteRaw( TEXT(": ") );
					WriteRaw( Data );
					WriteRaw( LINE_TERMINATOR );
#endif
				}
				if( GLogHook && bDoLog )
					GLogHook->Serialize( Data, Event );
			}
		}
		else
		{
			Entry=1;
			ForceFlush++;
			try
			{
				// Ignore errors to prevent infinite-recursive exception reporting.
				Serialize( Data, Event );
			}
			catch( ... )
			{}
			ForceFlush--;
			Entry=0;
		}
	}
	FArchive* LogAr;
	TCHAR Filename[1024];
	INT CurLine;
	INT StartCurLine;
	INT LastCurLine; //COMBO
	INT RepeatCount;
	OldLineCache PrevLines[OLD_LINES];
private:
	UBOOL Opened, Dead;
	void WriteRaw( const TCHAR* C )
	{
		LogAr->Serialize( const_cast<TCHAR*>(C), appStrlen(C)*sizeof(TCHAR) );
	}
};

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
