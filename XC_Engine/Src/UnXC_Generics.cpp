/*=============================================================================
	Generic systems code
	By Higor, feel free to use this code on your project.
=============================================================================*/

#ifdef _MSC_VER
	#include "../OldCRT/API_MSC.h"
#endif

#include "XC_Engine.h"
#include "XC_Networking.h"

//**********************************************************
// Level watcher, performs various tasks on the loaded level
#include "UnXC_LevelWatcher.h"
FXC_LevelWatcher::FXC_LevelWatcher() {}

UBOOL FXC_LevelWatcher::Init()
{
	Level = NULL;
	OldACUnique = 0;
	CurActorNameIdx = 0;
	return true;
}

struct ActorChannelPair
{
	INT Hash;
	AActor* Actor;
	UActorChannel* Channel;
};

INT FXC_LevelWatcher::Tick( FLOAT DeltaSeconds)
{
	guard(FXC_LevelWatcher::Tick);

	TickCount++;
	//Level change detector
	guard(LevelCheck);
	if ( Engine->Level() != Level )
	{
		Level = Engine->Level();
		//Level changed
		if ( Level )
			CurActorNameIdx = Level->iFirstDynamicActor;
	}
	if ( !Level && (Level != Engine->Entry()) )
		return 0;
	unguard;
	
	//Find bNetTemporary actors that could use a name reset
	guard(ActorNames);
	AActor* Actor = NULL;
	if ( CurActorNameIdx >= Level->Actors.Num() )
		CurActorNameIdx = Level->iFirstDynamicActor;
	else if ( TickCount % 8 > 0 )
	{
		INT Id = Max(Level->Actors.Num() - (INT)(TickCount%8), Level->iFirstDynamicActor);
		if ( Id < Level->Actors.Num() )
			Actor = Level->Actors( Id); //Query 7 out of 8 times
	}
	else
		Actor = Level->Actors(CurActorNameIdx++);
	if ( Actor && Level->NetDriver && Level->NetDriver->ServerConnection )
	{
		const TCHAR* cName = Actor->GetClass()->GetName();
		INT NameNumberIdx = appStrlen( cName );
		while ( (NameNumberIdx > 0) && appIsDigit(cName[NameNumberIdx-1]) )
			NameNumberIdx--;
		TCHAR BaseName[64];
		appStrncpy( BaseName, cName, NameNumberIdx+1);
		//These actors are good candidates for aggresive cycle sweeping
//		if ( Actor->LifeSpan != 0 ) 
		{
			//Negate if we find ONE name with at least 2 digits in name (less than 100 instances)
			if ( (Actor->GetClass()->ClassUnique > 99) && (appStrlen( Actor->GetName()) > NameNumberIdx+2) )
			{
				UBOOL bReduce = true;
				for ( INT i=Level->iFirstDynamicActor ; i<Level->Actors.Num() ; i++ )
				{
					AActor* AA = Level->Actors(i);
					if ( AA && (AA->GetClass() == Actor->GetClass()) && (appStrlen(AA->GetName()) <= NameNumberIdx+2) )
					{
						bReduce = false;
						break;
					}
				}
				if ( bReduce )
				{
					Actor->GetClass()->ClassUnique = 0;
				//	debugf( NAME_Log, TEXT("Reset names for %s"), cName);
				}
			}
		}
	}
	unguard;
	
	return 1;
	unguard;
}

UBOOL FXC_LevelWatcher::IsTyped( const TCHAR* Type)
{
	return appStricmp( Type, TEXT("LevelWatcher")) == 0;
}



//**********************************************************
// Halfassed time manager, used to correct game tick.
#include "UnXC_TimeManager.h"

FXC_TimeManager::FXC_TimeManager()
:	MSecAccumulator(0)
,	MSecInterval(100)
,	Factor(1)
,	DeltaAcc(0)
,	IgnoreTimers(10)
{
	appMemzero( &SystemDigest[0], 80); //Size of both arrays

	INT Year;
	INT Month;
	INT DayOfWeek;
	INT Day;
	INT Hour;
	INT Min;
	appSystemTime( Year, Month, DayOfWeek, Day, Hour, Min, LastSec, LastMSec );
}

UBOOL FXC_TimeManager::IsTyped( const TCHAR* Type)
{
	return appStricmp( Type, TEXT("TimeManager")) == 0;
}

INT FXC_TimeManager::Tick( FLOAT DeltaSeconds)
{
	INT Year;
	INT Month;
	INT DayOfWeek;
	INT Day;
	INT Hour;
	INT Min;
	INT Sec;
	INT MSec;
	INT i=0;

	appSystemTime( Year, Month, DayOfWeek, Day, Hour, Min, Sec, MSec );

	if ( Sec < LastSec )
		LastSec -= 60;

	i = MSec - LastMSec;
	if ( (Sec - LastSec) % 60 )
		i += ((Sec - LastSec) % 60) * 1000;
	MSecAccumulator += i;
	DeltaAcc += DeltaSeconds;
	if ( MSecAccumulator >= MSecInterval ) //DO THE MATH HERE
	{
//		if ( MSecAccumulator >= MSecInterval * 2 )
//			debugf( NAME_Log, TEXT("MSEC: SYSTEM RESOURCES HOGGED") );
	
		appMemmove( &SystemDigest[1], &SystemDigest[0], 36 );
		appMemmove( &TimeDigest[1], &TimeDigest[0], 36 );
		SystemDigest[0] = MSec;
		while ( SystemDigest[0] < SystemDigest[1] )
			SystemDigest[0] += 1000;
		TimeDigest[0] = TimeDigest[1] + DeltaAcc;
		for ( i=0 ; i<10 ; i++ )
			TimeDigest[i] -= TimeDigest[9];

		if ( SystemDigest[9] > 1000 )
			for ( i=0 ; i<10 ; i++ )
				SystemDigest[i] -= 1000;

//		INT AvgMSec = (SystemDigest[0] - SystemDigest[9]) / 9;
		INT DevMSec = 0;
		for ( i=1 ; i<10 ; i++ )
			DevMSec += Abs(((SystemDigest[9 - i] - SystemDigest[9]) / i) - MSecInterval);

		if ( DevMSec < MSecInterval )
		{
			FLOAT Delta = TimeDigest[0] * 1000;
//			debugf( NAME_Log, TEXT("MSEC TIMER %i %i %i %f"), MSecAccumulator, AvgMSec, DevMSec, Delta );
			FLOAT fMSecInv = _Reciprocal( (FLOAT)(SystemDigest[0] - SystemDigest[9]) );
			if ( IgnoreTimers <= 0 ) //Don't change factor after ignore timers expire
				Factor = _Reciprocal(Delta * fMSecInv);
			else
				IgnoreTimers--;
		}
//		else
//			debugf( NAME_Log, TEXT("MSEC: DEVIATION TOO HIGH  %i %i %i"), MSecAccumulator, AvgMSec, DevMSec );

		MSecAccumulator = MSecAccumulator % MSecInterval;
		DeltaAcc = 0;
	}
	
	LastMSec = MSec;
	LastSec = Sec;
	return 1;
}



UBOOL FXC_TimeManager::Exec( const TCHAR* Cmd, FOutputDevice& Ar )
{
	guard(FXC_TimeManager::Exec);
	if ( ParseCommand(&Cmd,TEXT("TimeFactor")) )
		Ar.Log( * FString::Printf( TEXT("XC_TimeManager time scaler is set at Factor=%f"), Factor) );
	else
		return 0;
	return 1;
	unguard;
}

//**********************************************************
// Server Processor, used to tweak connections and setup brush tracker
#include "UnXC_ServerProc.h"
FXC_ServerProc::FXC_ServerProc()
{}

UBOOL FXC_ServerProc::IsTyped( const TCHAR* Type)
{
	return appStricmp( Type, TEXT("ServerProc")) == 0;
}

INT FXC_ServerProc::Tick( FLOAT DeltaSeconds)
{
	// This is a net server
	if (  Engine->Level() 
	  &&  Engine->Level()->NetDriver
	  && !Engine->Level()->NetDriver->ServerConnection )
	{
		// Process faster upload feature
		if ( Engine->bFasterUpload )
		{
			UNetDriver* NetDriver = Engine->Level()->NetDriver;
			for ( int i=0 ; i<NetDriver->ClientConnections.Num() ; i++ )
			{
				UNetConnection* C = NetDriver->ClientConnections(i);
				//This player is joining
				if ( !C->Actor )
				{
					if ( C->CurrentNetSpeed != 1000001 ) //v440 requires ConfiguredInternetSpeed to be set on server
						C->ConfiguredInternetSpeed = C->CurrentNetSpeed;
					C->CurrentNetSpeed = 1000001;
				}
				//Player has joined, restore original netspeed
				else if ( C->CurrentNetSpeed == 1000001 )
					C->CurrentNetSpeed = Min(C->ConfiguredInternetSpeed, NetDriver->MaxClientRate);
			}
		}
		return 1;
	}
	return 0;
}
