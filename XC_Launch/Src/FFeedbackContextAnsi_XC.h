/*=============================================================================
	FFeedbackContextAnsi.h: Unreal Ansi user interface interaction.
	Copyright 1997-1999 Epic Games, Inc. All Rights Reserved.

	Revision history:
		* Created by Tim Sweeney
=============================================================================*/

/*-----------------------------------------------------------------------------
	FFeedbackContextAnsi.
-----------------------------------------------------------------------------*/

static TCHAR SpaceText[2] = { ' ', 0};

//
// Feedback context.
//
class FFeedbackContextAnsi_XC : public FFeedbackContext
{
public:
	// Variables.
	INT SlowTaskCount;
	INT WarningCount;
	FContextSupplier* Context;
	FOutputDevice* AuxOut;

	// Local functions.
	void LocalPrint( const TCHAR* Str )
	{
#if UNICODE
		wprintf(TEXT("%s"),Str);
#else
		printf(TEXT("%s"),Str);
#endif
	}

	// Constructor.
	FFeedbackContextAnsi_XC()
	: SlowTaskCount( 0 )
	, WarningCount( 0 )
	, Context( NULL )
	, AuxOut( NULL )
	{}
	void Serialize( const TCHAR* V, EName Event )
	{
		guard(FFeedbackContextAnsi_XC::Serialize);
		TCHAR Temp[1024]=TEXT("");
		guard(EventHandling);
		if ( !V[0] )
			return;
		if( Event==NAME_Title )
			return;
		else if( Event==NAME_Heading )
		{
			appSprintf( Temp, TEXT("--------------------%s--------------------"), (TCHAR*)V );
			V = Temp;
		}
		else if( Event==NAME_SubHeading )
		{
			appSprintf( Temp, TEXT("%s..."), (TCHAR*)V );
			V = Temp;
		}
		else if( Event==NAME_Error || Event==NAME_Warning || Event==NAME_ExecWarning || Event==NAME_ScriptWarning )
		{
			if( Context )
			{
				appSprintf( Temp, TEXT("%s : %s, %s"), *Context->GetContext(), *FName(Event), (TCHAR*)V );
				V = Temp;
			}
			WarningCount++;
		}
		else if( Event==NAME_Progress )
		{
			guard( Progress);
			appSprintf( Temp, TEXT("%s"), (TCHAR*)V );
			V = Temp;
			LocalPrint( V );
			LocalPrint( TEXT("\r") );
			fflush( stdout );
			return;
			unguard;
		}
		unguard;
		const TCHAR* NV = V[0] ? V : SpaceText;
		LocalPrint( NV );
		LocalPrint( TEXT("\n") );
		guard( PropagateToLog);
		if( GLog != this )
			GLog->Serialize( NV, Event );
		unguard;
		guard( PropagateToAux);
		if( AuxOut )
			AuxOut->Serialize( NV, Event );
		unguard;
		fflush( stdout );
		unguard;
	}
	UBOOL YesNof( const TCHAR* Fmt, ... )
	{
		TCHAR TempStr[4096];
		GET_VARARGS( TempStr, ARRAY_COUNT(TempStr), Fmt );
		guard(FFeedbackContextAnsi_XC::YesNof);
		if( (GIsClient || GIsEditor) && !ParseParam(appCmdLine(),TEXT("Silent")) )//!!
		{
			LocalPrint( TempStr );
			LocalPrint( TEXT(" (Y/N): ") );
			INT Ch = getchar();
			return (Ch=='Y' || Ch=='y');
		}
		else return 1;
		unguard;
	}
	void BeginSlowTask( const TCHAR* Task, UBOOL StatusWindow, UBOOL Cancelable )
	{
		guard(FFeedbackContextAnsi_XC::BeginSlowTask);
		GIsSlowTask = ++SlowTaskCount>0;
		unguard;
	}
	void EndSlowTask()
	{
		guard(FFeedbackContextAnsi_XC::EndSlowTask);
		check(SlowTaskCount>0);
		GIsSlowTask = --SlowTaskCount>0;
		unguard;
	}
	UBOOL VARARGS StatusUpdatef( INT Numerator, INT Denominator, const TCHAR* Fmt, ... )
	{
		guard(FFeedbackContextAnsi_XC::StatusUpdatef);
		TCHAR TempStr[4096];
		GET_VARARGS( TempStr, ARRAY_COUNT(TempStr), Fmt );
		if( GIsSlowTask )
		{
			//!!
		}
		return 1;
		unguard;
	}
	void SetContext( FContextSupplier* InSupplier )
	{
		guard(FFeedbackContextAnsi_XC::SetContext);
		Context = InSupplier;
		unguard;
	}
};

/*-----------------------------------------------------------------------------
	The End.
-----------------------------------------------------------------------------*/
