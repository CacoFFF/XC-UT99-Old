/*=============================================================================
	UnXC_Script.cpp
	Author: Fernando Velázquez

	UnrealScript functionality.
=============================================================================*/

#include "XC_Engine.h"
#include "UnXC_Script.h"
#include "XC_CoreGlobals.h"

//*************************************************
//************* CONFIG FILE MANIPULATORS
//
void AXC_Engine_Actor::GetConfigStr( FFrame& Stack, RESULT_DECL)
{
	P_GET_STR(Section);
	P_GET_STR(Key);
	P_GET_STR_REF(Value);
	P_GET_STR_OPTX(FileName,TEXT(""));
	P_FINISH;

	const TCHAR* FileNamePtr = FileName.Len() ? *FileName : NULL;
	*(UBOOL*)Result = GConfig->GetString( *Section, *Key, *Value, FileNamePtr);
}
void AXC_Engine_Actor::SetConfigStr( FFrame& Stack, RESULT_DECL)
{
	P_GET_STR(Section);
	P_GET_STR(Key);
	P_GET_STR(Value);
	P_GET_STR_OPTX(FileName,TEXT(""));
	P_FINISH;

	const TCHAR* FileNamePtr = FileName.Len() ? *FileName : NULL;
	GConfig->SetString( *Section, *Key, *Value, FileNamePtr);
}

//*************************************************
//************* SCRIPT ENGINE IMPROVEMENTS
//
void AXC_Engine_Actor::NewDynArrayElement( FFrame& Stack, RESULT_DECL )
{
	INT Index=0; // Grab the index
	Stack.Step( Stack.Object, &Index );

	GProperty = NULL; // Grab the property
	Stack.Step( this, NULL );

	if( GProperty && GPropAddr )
	{
		FArray* Array=(FArray*)GPropAddr;
		UArrayProperty* ArrayProp = (UArrayProperty*)GProperty;
		if( Index>=Array->Num() || Index<0 )
		{
			//if we are returning a value, check for out-of-bounds
			if ( Result || Index<0 || (GProperty->PropertyFlags & CPF_Const) )
			{
				Stack.Logf( NAME_Error, TEXT("Accessed array '%s' out of bounds (%i/%i)"), ArrayProp->GetName(), Index, Array->Num() );
				GPropAddr = 0;
				if (Result)
					appMemzero( Result, ArrayProp->Inner->ElementSize );
				return;
			}
			//if we are setting a value, allow the array to be resized
			else
				Array->AddZeroed(ArrayProp->Inner->ElementSize,Index-Array->Num()+1);
		}
		GPropAddr = (BYTE*)Array->GetData() + Index * ArrayProp->Inner->ElementSize;

		// Add scaled offset to base pointer.
		if( Result )
			ArrayProp->Inner->CopySingleValue( Result, GPropAddr );
	}
}

void AXC_Engine_Actor::NewDynArrayLength( FFrame& Stack, RESULT_DECL )
{
	GProperty = NULL;
	Stack.Step( this, NULL );
	UBOOL bSetSize = false;
	INT NewSize = 0;
	if ( *(Stack.Code) != EX_EndFunctionParms )
	{
		Stack.Step( Stack.Object, &NewSize);
		if ( GProperty->PropertyFlags & CPF_Const )
			debugf( NAME_ScriptWarning, TEXT("Set length of Dynamic Array '%s' marked as 'const'"), GProperty->GetName() );
		else if ( NewSize < 0 )
			debugf( NAME_ScriptWarning, TEXT("Set length of Dynamic Array '%s' to a negative size: %i"), GProperty->GetName(), NewSize );
		else
			bSetSize = true;
	}
	P_FINISH;

	if (GPropAddr && GProperty)
	{
		FArray* Array=(FArray*)GPropAddr;
		UArrayProperty* ArrayProp = (UArrayProperty*)GProperty;
		if ( bSetSize )
		{
			if ( NewSize > Array->Num() )
				Array->AddZeroed(ArrayProp->Inner->ElementSize, NewSize-Array->Num());
			else if (NewSize < Array->Num())
			{
				for (INT i=Array->Num()-1; i>=NewSize; i--)
					ArrayProp->Inner->DestroyValue((BYTE*)Array->GetData() + ArrayProp->Inner->ElementSize*i);
				Array->Remove(NewSize, Array->Num()-NewSize, ArrayProp->Inner->ElementSize );
			}
		}
		*(INT*)Result = Array->Num();
	}
}

void AXC_Engine_Actor::NewDynArrayInsert( FFrame& Stack, RESULT_DECL )
{
	GProperty = NULL;
	Stack.Step( this, NULL );
	UArrayProperty* ArrayProperty = Cast<UArrayProperty>(GProperty);
	FArray* Array=(FArray*)GPropAddr;

	P_GET_INT(Index);
	P_GET_INT_OPTX(Count,1);
	P_FINISH;

	if ( ArrayProperty->PropertyFlags & CPF_Const )
		debugf( NAME_ScriptWarning, TEXT("Insert in Dynamic Array '%s' marked as 'const'"), ArrayProperty->GetName() );
	else if (Array && Count)
	{
		if ( Count < 0 )
		{
			Stack.Logf( TEXT("Attempt to insert a negative number of elements '%s'"), ArrayProperty->GetName() );
			return;
		}
		if ( Index < 0 || Index > Array->Num() )
		{
			Stack.Logf( TEXT("Attempt to insert %i elements at %i an %i-element array '%s'"), Count, Index, Array->Num(), ArrayProperty->GetName() );
			Index = Clamp(Index, 0,Array->Num());
		}
		Array->InsertZeroed( Index, Count, ArrayProperty->Inner->ElementSize);
		*(UBOOL*)Result = true;
	}
}

void AXC_Engine_Actor::NewDynArrayRemove( FFrame& Stack, RESULT_DECL )
{	
	GProperty = NULL;
	Stack.Step( this, NULL );
	UArrayProperty* ArrayProperty = Cast<UArrayProperty>(GProperty);
	FArray* Array=(FArray*)GPropAddr;

	P_GET_INT(Index);
	P_GET_INT_OPTX(Count, 1);
	P_FINISH;
	if ( ArrayProperty->PropertyFlags & CPF_Const )
		debugf( NAME_ScriptWarning, TEXT("Remove in Dynamic Array '%s' marked as 'const'"), ArrayProperty->GetName() );
	else if (Array && Count)
	{
		if ( Count < 0 )
		{
			Stack.Logf( TEXT("Attempt to remove a negative number of elements '%s'"), ArrayProperty->GetName() );
			return;
		}
		if ( Index < 0 || Index >= Array->Num() || Index + Count > Array->Num() )
		{
			if (Count == 1)
				Stack.Logf( TEXT("Attempt to remove element %i in an %i-element array '%s'"), Index, Array->Num(), ArrayProperty->GetName() );
			else
				Stack.Logf( TEXT("Attempt to remove elements %i through %i in an %i-element array '%s'"), Index, Index+Count-1, Array->Num(), ArrayProperty->GetName() );
			Index = Clamp(Index, 0,Array->Num());
			if ( Index + Count > Array->Num() )
				Count = Array->Num() - Index;
		}

		for (INT i=Index+Count-1; i>=Index; i--)
			ArrayProperty->Inner->DestroyValue((BYTE*)Array->GetData() + ArrayProperty->Inner->ElementSize*i);
		Array->Remove( Index, Count, ArrayProperty->Inner->ElementSize);
		*(UBOOL*)Result = true;
	}
}

void AXC_Engine_Actor::NewVirtualFunction( FFrame& Stack, RESULT_DECL )
{
	FName FuncName = Stack.ReadName();
	guard(ScriptDebugV);
	CallFunction( Stack, Result, FindFunctionChecked(FuncName) );
	unguardf( (TEXT("%s.%s"), GetName(), *FuncName ) );
}



//*************************************************
//************* ITERATOR FUNCTIONS
//

//native final function iterator PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional pawn StartAt);
void AXC_Engine_Actor::execPawnActors(FFrame &Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execPawnActors);
	P_GET_CLASS(BaseClass);
	P_GET_PAWN_REF(P);
	P_GET_FLOAT_OPTX(Distance,0.0);
	P_GET_VECTOR_OPTX(SearchPosition,this->Location);
	P_GET_UBOOL_OPTX(bPRI,false);
	P_GET_OBJECT_OPTX(APawn,PP,NULL);
	P_FINISH;

	BaseClass = BaseClass ? BaseClass : APawn::StaticClass();
	if ( !PP )
		PP = Level->PawnList;
	const float DistSq = Square(Distance);

	PRE_ITERATOR;
	*P = NULL;
	while( PP && *P == NULL )
	{
		if ( PP->IsA(BaseClass)
			&& (!bPRI || PP->PlayerReplicationInfo)
			&& (DistSq <= 0.f || (PP->Location - SearchPosition).SizeSquared() < DistSq) )
		{
			*P = PP;
		}
		PP = PP->nextPawn;
	}

	if ( *P == NULL )
	{
		Stack.Code = &Stack.Node->Script(wEndOffset + 1);
		break;
	}
	POST_ITERATOR;
	unguard;
}

//native final function iterator NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint P, optional float Distance, optional vector VOrigin, optional bool bVisible);
void AXC_Engine_Actor::execNavigationActors(FFrame &Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execNavigationActors);
	P_GET_CLASS(BaseClass);
	P_GET_NAVIG_REF(N);
	P_GET_FLOAT_OPTX(dist,0.0);
	P_GET_VECTOR_OPTX(SearchPosition,this->Location);
	P_GET_UBOOL_OPTX(bTrace,false);
	P_FINISH;

	BaseClass = BaseClass ? BaseClass : ANavigationPoint::StaticClass();
	ANavigationPoint *NN = Level->NavigationPointList;
	const float DistSq = Square(dist);
	FCheckResult Hit;

	PRE_ITERATOR;
	*N = NULL;
	while( NN && *N == NULL )
	{
		if ( NN->IsA(BaseClass)
			&& (DistSq <= 0.0 || (NN->Location - SearchPosition).SizeSquared() < DistSq)
			&& (!bTrace || GetLevel()->SingleLineCheck( Hit, NULL, SearchPosition, NN->Location, TRACE_Level, FVector(0,0,0)) ) )
		{
			*N = NN;
		}
		NN = NN->nextNavigationPoint;
	}

	if ( *N == NULL )
	{
		Stack.Code = &Stack.Node->Script(wEndOffset + 1);
		break;
	}
	POST_ITERATOR;
	unguard;
}

//native final function iterator InventoryActors( class<Inventory> InvClass, out Inventory Inv, optional bool bSubclasses, optional Actor StartFrom);
void AXC_Engine_Actor::execInventoryActors(FFrame &Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execInventoryActors);
	P_GET_CLASS(BaseClass);
	P_GET_OBJECT_REF(AInventory,Inv);
	P_GET_UBOOL_OPTX(bSubclasses,false);
	P_GET_OBJECT_OPTX(AActor,StartFrom,NULL);
	P_FINISH;

	BaseClass = BaseClass ? BaseClass : AInventory::StaticClass();
	if ( !StartFrom )
		StartFrom = this;
	AInventory* II = StartFrom->Inventory;

	PRE_ITERATOR;
	*Inv = NULL;
	while( II && *Inv == NULL )
	{
		if ( (bSubclasses && II->IsA(BaseClass)) || (!bSubclasses && II->GetClass() == BaseClass) )
			*Inv = II;
		II = II->Inventory;
	}

	if ( *Inv == NULL )
	{
		Stack.Code = &Stack.Node->Script(wEndOffset + 1);
		break;
	}
	POST_ITERATOR;
	unguard;
}


void AXC_Engine_Actor::execCollidingActors( FFrame& Stack, RESULT_DECL )
{
	P_GET_OBJECT(UClass,BaseClass);
	P_GET_ACTOR_REF(OutActor);
	P_GET_FLOAT(Radius);
	P_GET_VECTOR_OPTX(TraceLocation,Location);
	P_FINISH;

	BaseClass = BaseClass ? BaseClass : AActor::StaticClass();
	FMemMark Mark(GMem);
	FIteratorActorList* Link=GetLevel()->Hash->ActorRadiusCheck( GMem, TraceLocation, Radius, 0 );

	PRE_ITERATOR;
	*OutActor = NULL;
	if ( Link )
	{
		while ( Link )
		{	//Actors can be de-collided or killed during the iterator, perform (almost) all checks!
			if( !Link->Actor || Link->Actor->bDeleteMe || !Link->Actor->bCollideActors || !Link->Actor->IsA(BaseClass) )
				Link=Link->GetNext();
			else
				break;
		}
		if ( Link )
		{
			*OutActor = Link->Actor;
			Link=Link->GetNext();
		}
	}
	if ( *OutActor == NULL ) 
	{
		Stack.Code = &Stack.Node->Script(wEndOffset + 1);
		break;
	}
	POST_ITERATOR;
	Mark.Pop();
}

void AXC_Engine_Actor::execDynamicActors( FFrame& Stack, RESULT_DECL )
{
	P_GET_OBJECT(UClass,BaseClass);
	P_GET_ACTOR_REF(OutActor);
	P_GET_NAME_OPTX(TagName,NAME_None);
	P_FINISH;

	BaseClass = BaseClass ? BaseClass : AActor::StaticClass();
	INT iActor = GetLevel()->iFirstDynamicActor;

	PRE_ITERATOR;
	// Fetch next actor in the iteration.
	*OutActor = NULL;
	while( iActor<GetLevel()->Actors.Num() && *OutActor==NULL )
	{
		AActor* TestActor = GetLevel()->Actors(iActor++);
		if(	TestActor && 
			!TestActor->IsPendingKill() &&
			TestActor->IsA(BaseClass) && 
			(TagName==NAME_None || TestActor->Tag==TagName) )
			*OutActor = TestActor;
	}
	if( *OutActor == NULL )
	{
		Stack.Code = &Stack.Node->Script(wEndOffset + 1);
		break;
	}
	POST_ITERATOR;
}

//*************************************************
//************* MAP NAME SORTING HOOK
//

void AXC_Engine_Actor::execGetMapName_XC( FFrame &Stack, RESULT_DECL)
{
	guard( AXC_Engine_Actor::execGetMapName_XC );
	P_GET_STR( NameEnding);
	P_GET_STR( MapName);
	P_GET_INT( Dir);
	P_FINISH;

	UXC_GameEngine* Engine = (UXC_GameEngine*)GetLevel()->Engine;
	if ( !Engine->MapCache.Num() || (NameEnding != Engine->MapCachedPrefix) )
	{
		SafeEmpty( Engine->MapCache);
		Engine->MapCachedPrefix = NameEnding;
		if ( Engine->bEnableDebugLogs )
			debugf( NAME_XC_Engine, TEXT("MapCache needs reloading...") );

		// Setup environment
		INT i;
		FMemMark Mark(GMem);
		FString** Paths = new(GMem,GSys->Paths.Num()) FString*;
		TArray<FString>* PathsResult;
		INT PathsCount = 0;
		INT ResultsSize = 0;
		INT ResultsAdded = 0;

		// Count paths
		for ( i=0 ; i<GSys->Paths.Num() ; i++ )
		{
			FString& Path = GSys->Paths(i);
			if ( (Path.Len() >= 5) && !appStricmp( *Path + Path.Len() - 5, TEXT("*.unr")) )
				Paths[PathsCount++] = &Path;
		}

		// Get results from paths
		PathsResult = new(GMem,MEM_Zeroed,PathsCount) TArray<FString>;
		for ( i=0 ; i<PathsCount ; i++ )
		{
			FString Dir = Paths[i]->Left( Paths[i]->Len() - 5) + NameEnding + TEXT("*.unr");
			PathsResult[i] = GFileManager->FindFiles( *Dir, 1, 0);
			if ( Engine->bSortMaplistByFolder )
				SortStringsA( PathsResult + i);
			if ( Engine->bEnableDebugLogs )
				debugf( NAME_XC_Engine, TEXT("Searching through directory %s => Found %i results"), *Dir, PathsResult[i].Num());
			ResultsSize += PathsResult[i].Num();
		}

		// Setup cache list with minimum reallocs
		Engine->MapCache.Add( ResultsSize);
		for ( i=0 ; i<PathsCount ; i++ )
			if ( PathsResult[i].Num() )
			{
				appMemcpy( &Engine->MapCache(ResultsAdded), &PathsResult[i](0), PathsResult[i].Num() * sizeof(FString));
				ResultsAdded += PathsResult[i].Num();
				((FArray*)(PathsResult+i))->Empty( sizeof(FString)); //Empty without destructing elements
			}
		if ( !Engine->bSortMaplistByFolder )
			SortStringsA( &Engine->MapCache);
		if ( Engine->bSortMaplistInvert )
		{
			const INT Top = Engine->MapCache.Num();
			for ( i=0 ; i<Top/2 ; i++ )
				appMemswap( &Engine->MapCache(i), &Engine->MapCache(Top-(i+1)), sizeof(FString));
		}
		check( ResultsSize == ResultsAdded);
		Mark.Pop();
	}
	if ( Engine->MapCache.Num() > 0 )
	{
		if ( !MapName.Len() )
			Engine->LastMapIdx = 0;
		else if ( Engine->MapCache(Engine->LastMapIdx) == MapName ) //Chained search
			Engine->LastMapIdx += Dir;
		else
		{
			for ( INT i = 0 ; i<Engine->MapCache.Num() ; i++ )
				if ( Engine->MapCache(i) == MapName )
				{
					Engine->LastMapIdx = i + Dir;
					break;
				}
		}
		// Normalize
		while ( Engine->LastMapIdx >= Engine->MapCache.Num() )
			Engine->LastMapIdx -= Engine->MapCache.Num();
		while ( Engine->LastMapIdx < 0 )
			Engine->LastMapIdx += Engine->MapCache.Num();
		*(FString*)Result = Engine->MapCache( Engine->LastMapIdx );
	}
	unguard;
}