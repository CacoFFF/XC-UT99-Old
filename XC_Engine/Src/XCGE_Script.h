// Script functions belonging to:
// XC_Engine_Actor

//Move to common macros later
#define P_GET_CLASS(var)				P_GET_OBJECT(UClass,var)
#define P_GET_INPUT_REF(var)			P_GET_OBJECT_REF(UInput,var)
#define P_GET_PAWN_REF(var)				P_GET_OBJECT_REF(APawn,var)
#define P_GET_NAVIG(var)				P_GET_OBJECT(ANavigationPoint,var)
#define P_GET_NAVIG_OPTX(var,def)		P_GET_OBJECT_OPTX(ANavigationPoint,var,def)
#define P_GET_NAVIG_REF(var)			P_GET_OBJECT_REF(ANavigationPoint,var)


	
// For iterating through a linked list of fields (don't search on superfield).
template <class T> class TStrictFieldIterator
{
public:
	TStrictFieldIterator( UStruct* InStruct )
	: Field( InStruct ? InStruct->Children : NULL )
	{
		IterateToNext();
	}
	void operator++()
	{
		Field = Field->Next;
		IterateToNext();
	}
	operator UBOOL()	{	return Field != NULL;	}
	T* operator*()		{	return (T*)Field;	}
	T* operator->()		{	return (T*)Field;	}
protected:
	void IterateToNext()
	{
		while( Field )
		{
			if( Field->IsA(T::StaticClass()) )
				return;
			Field = Field->Next;
		}
	}
	UField* Field;
};


//There's 4096 of these
static UFunction* GNativeToScriptFuncs[EX_Max];
void AXC_Engine_Actor::GNativeScriptWrapper( FFrame &Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::GNativeScriptWrapper);
	uint16 iNative = Stack.Code[-1];
	if ( (Stack.Code[-2] >= 0x60) && (Stack.Code[-2] < 0x70) )
		iNative += 0x100 * (Stack.Code[-2] - 0x60);
	check(iNative < EX_Max);
	UFunction* Func = GNativeToScriptFuncs[iNative];
	check(Func->iNative == iNative);
	Func->iNative = 0;
	CallFunction( Stack, Result, Func);
	Func->iNative = iNative;
	unguard;
}



//native static final function bool ReplaceFunction( class<Object> ReplaceClass, class<Object> WithClass, name ReplaceFunction, name WithFunction, optional name InState);
void AXC_Engine_Actor::execReplaceFunction(FFrame &Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execReplaceFunction);
	P_GET_CLASS(ReplaceClass);
	P_GET_CLASS(WithClass);
	P_GET_NAME(ReplaceFunction);
	P_GET_NAME(WithFunction);
	P_GET_NAME_OPTX(InState, NAME_None);
	P_FINISH;
	
	*(UBOOL*)Result = 0;

	if ( !ThisXC_Engine || !ThisXC_Engine->Level() || !ThisXC_Engine->Level()->IsServer() )
		return;
	
	if ( !ReplaceClass || !WithClass || ReplaceFunction == NAME_None || WithFunction == NAME_None )
	{
		debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: called with bad or null parameters"));
		return;
	}
	
	//Find template function we want to copy
	UFunction* WithFunc = NULL;
	{for( TStrictFieldIterator<UFunction> It( WithClass ); It; ++It )
		if( It->GetFName() == WithFunction )
		{
			WithFunc = *It;
			break;
	}	}
	if ( !WithFunc )
	{
		debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: cannot find WithFunction=%s in %s"), *WithFunction, WithClass->GetFullName() );
		return;
	}
	
	UState* rField = ReplaceClass;
	//Find optional state target function resides in
	if ( InState != NAME_None )
	{
		UState* InUState = NULL;
		for( TStrictFieldIterator<UState> It( ReplaceClass ); It; ++It )
			if( It->GetFName() == InState )
			{
				InUState = *It;
				break;
			}
		if ( !InUState )
		{
			debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: cannot find InState=%s in %s"), *InState, ReplaceClass->GetFullName() );
			return;
		}
		rField = InUState;
	}
	
	//Find target function
	UFunction* ReplaceFunc = NULL;
	{for( TStrictFieldIterator<UFunction> It( rField ); It; ++It )
		if( It->GetFName() == ReplaceFunction )
		{
			ReplaceFunc = *It;
			break;
	}	}
	if ( !ReplaceFunc )
	{
		debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: cannot find ReplaceFunction=%s in %s"), *ReplaceFunction, rField->GetFullName() );
		return;
	}
	
	//We have both WithFunc and ReplaceFunc
	//Validate function flags
	static const DWORD FlagsForbidden = FUNC_PreOperator | FUNC_Operator;
	static const DWORD FlagsKeep = FUNC_Net | FUNC_NetReliable | FUNC_Simulated | FUNC_Exec | FUNC_Event;
	static const DWORD FlagsCopy = FUNC_Native | FUNC_Singular;
	static const DWORD FlagsMustMatch = FUNC_Iterator | FUNC_Latent | FUNC_Static | FUNC_Const | FUNC_Invariant;
	
	if ( (WithFunc->FunctionFlags ^ ReplaceFunc->FunctionFlags) & FlagsMustMatch )
	{
		debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: %s and %s have critical mismatching flags (Iterator, Latent, Static, Const, Invariant)"), *ReplaceFunction, *WithFunction );
		return;
	}
	if ( ReplaceFunc->FunctionFlags & FlagsForbidden )
	{
		debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: Operator %s replacement is forbidden"), *ReplaceFunction);
		return;
	}
	if ( WithFunc->FunctionFlags & FlagsForbidden )
	{
		debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: Operator %s cannot be used as replacement"), *WithFunction );
		return;
	}
	DWORD NewFlags = (ReplaceFunc->FunctionFlags & (FlagsKeep | FlagsMustMatch)) | (WithFunc->FunctionFlags & FlagsCopy);

	//Validate function parameters (simple)
	if ( WithFunc->NumParms != ReplaceFunc->NumParms )
	{
		debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: %s and %s parameter count mismatch"), *ReplaceFunction, *WithFunction );
		return;
	}
	if ( WithFunc->ParmsSize != ReplaceFunc->ParmsSize )
	{
		debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: %s and %s parameter size mismatch"), *ReplaceFunction, *WithFunction );
		return;
	}
	if ( WithFunc->ReturnValueOffset != ReplaceFunc->ReturnValueOffset )
	{
		debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: %s and %s have return value offset mismatch"), *ReplaceFunction, *WithFunction );
		return;
	}

	//Net reliable functions need extra care!!
	if ( (ReplaceFunc->FunctionFlags & FUNC_Net) && (ReplaceFunc->ParmsSize != 0) && !(NewFlags & FUNC_Native) )
	{
//		debugf( NAME_Log, TEXT("Net func found: %s"), ReplaceFunc->GetFullName() );
		if ( ReplaceFunc->PropertiesSize != WithFunc->PropertiesSize )
		{
			debugf(NAME_ScriptWarning, TEXT("ReplaceFunction: [NET] %s and %s have different properties size"), *ReplaceFunction, *WithFunction);
			return;
		}
		UProperty* RR = Cast<UProperty>(ReplaceFunc->Children);
		UProperty* WR = Cast<UProperty>(WithFunc->Children);
		while ( true )
		{
			if (!RR && !WR)
				break;

			if ( !RR || !WR )
			{
				debugf( NAME_ScriptWarning, TEXT("ReplaceFunction: [NET] %s and %s have different property count"), *ReplaceFunction, *WithFunction);
				return;
			}
			if ( (RR->PropertyFlags ^ WR->PropertyFlags) & CPF_Parm )
			{
				debugf(NAME_ScriptWarning, TEXT("ReplaceFunction: [NET] %s.%s and %s.%s have mismatching parameter flags"), *ReplaceFunction, *WithFunction, RR->GetName(), WR->GetName() );
				return;
			}
			if ( RR->GetClass() != WR->GetClass() )
			{
				debugf(NAME_ScriptWarning, TEXT("ReplaceFunction: [NET] %s.%s and %s.%s have mismatching class"), *ReplaceFunction, *WithFunction, RR->GetName(), WR->GetName());
				return;
			}
			RR = Cast<UProperty>(RR->Next);
			WR = Cast<UProperty>(WR->Next);
		}
	}

	//Replace!
	FFunctionEntry::AddFunction( ReplaceFunc ); //Backup important stuff so we can restore
	ReplaceFunc->FunctionFlags = NewFlags;
	ReplaceFunc->Func = WithFunc->Func;
	if ( !(NewFlags & FUNC_Native) ) //Script to Script requires extra stuff
	{
		if ( !(NewFlags & FUNC_Net) )
		{
			ReplaceFunc->PropertiesSize = WithFunc->PropertiesSize;
			ReplaceFunc->Children = WithFunc->Children; //CHECK!!
		}
		ReplaceFunc->Script = WithFunc->Script;
	}

	if ( ReplaceFunc->iNative > 0 && ReplaceFunc->iNative < EX_Max ) //Original func has a iNative opcode!
	{
		if ( WithFunc->Func != &UObject::ProcessInternal ) //Replacement is native function
			GNatives[ReplaceFunc->iNative] = WithFunc->Func;
		else //Replacement is pure unrealscript function
		{
			GNativeToScriptFuncs[ReplaceFunc->iNative] = ReplaceFunc;
			GNatives[ReplaceFunc->iNative] = (Native)&AXC_Engine_Actor::GNativeScriptWrapper;
		}
	}

	*(UBOOL*)Result = 1;
	unguard;
}

//native static final function bool RestoreFunction( class<Object> RestoreClass, name RestoreFunction, optional name InState);
void AXC_Engine_Actor::execRestoreFunction(FFrame &Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execRestoreFunction);
	P_GET_CLASS(RestoreClass);
	P_GET_NAME(RestoreFunction);
	P_GET_NAME_OPTX(InState, NAME_None);
	P_FINISH;
	
	*(UBOOL*)Result = 0;

	if ( ThisXC_Engine )
	{
		FGameLevelHeader* GLH = (FGameLevelHeader*) (((BYTE*)&ThisXC_Engine->GLevel) + ThisXC_Engine->b451Setup * 4);
		if ( !GLH->GLevel || !GLH->GLevel->IsServer() )
			return;
	}
	else
		return;
	
	if ( !RestoreClass || RestoreFunction == NAME_None )
	{
		debugf( NAME_ScriptWarning, TEXT("RestoreFunction: called with bad or null parameters"));
		return;
	}
	
	UState* rField = RestoreClass;
	//Find optional state target function resides in
	if ( InState != NAME_None )
	{
		UState* InUState = NULL;
		for( TStrictFieldIterator<UState> It( RestoreClass ); It; ++It )
			if( It->GetFName() == InState )
			{
				InUState = *It;
				break;
			}
		if ( !InUState )
		{
			debugf( NAME_ScriptWarning, TEXT("RestoreFunction: cannot find InState=%s in %s"), *InState, RestoreClass->GetFullName() );
			return;
		}
		rField = InUState;
	}
	
	//Find target function
	UFunction* RestoreFunc = NULL;
	{for( TStrictFieldIterator<UFunction> It( rField ); It; ++It )
		if( It->GetFName() == RestoreFunction )
		{
			RestoreFunc = *It;
			break;
	}	}
	if ( !RestoreFunc )
	{
		debugf( NAME_ScriptWarning, TEXT("RestoreFunction: cannot find RestoreFunction=%s in %s"), *RestoreFunction, rField->GetFullName() );
		return;
	}
	

	//Replace!
	*(UBOOL*)Result = FFunctionEntry::ClearFunction( RestoreFunc);
	unguard;
}





void AXC_Engine_Actor::execAddToPackagesMap( FFrame& Stack, RESULT_DECL )
{
	guard(AXC_Engine_Actor::execAddToPackagesMap);
	ULinkerLoad* ToAdd = NULL;
	UBOOL bSelfLinker = 1;
	*(UBOOL*)Result = 0;
	UXC_GameEngine* XC = (UXC_GameEngine*) XLevel->Engine;
	if ( !XLevel->NetDriver || !XLevel->NetDriver->MasterMap )
		XC->bCanEditPackageMap = false;
	if ( *Stack.Code != EX_EndFunctionParms ) //Someone specified a package name
	{
		FString PackageName(0);
		Stack.Step( Stack.Object, &PackageName);
		bSelfLinker = 0;
		if ( XC->bCanEditPackageMap )
		{
			BeginLoad();
			ToAdd = GetPackageLinker( NULL, *PackageName, 0, NULL, NULL );
			EndLoad();
			if ( !ToAdd )
				debugf( NAME_Warning, TEXT("AddToPackagesMap: Linker not found for %s"), *PackageName );
		}
	}
	P_FINISH;
	if ( !XC->bCanEditPackageMap )
	{
		debugf( NAME_Warning, TEXT("AddToPackagesMap: Cannot edit the Master Map"));
		return;
	}

	if ( bSelfLinker )
	{
		ToAdd = GetClass()->GetLinker();
		if ( !ToAdd )
			debugf( NAME_Warning, TEXT("AddToPackagesMap: Actor %s has no linker!"), GetName() );
	}
	if ( !ToAdd )
		return;
	INT OldNum = XLevel->NetDriver->MasterMap->List.Num();
	XLevel->NetDriver->MasterMap->AddLinker( ToAdd );
	if ( OldNum != XLevel->NetDriver->MasterMap->List.Num() ) //Linker was inserted, Compute
	{
		XLevel->NetDriver->MasterMap->Compute();
		*(UBOOL*)Result = 1;
	}
	unguard;
}

void AXC_Engine_Actor::execIsInPackageMap( FFrame& Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execAddToPackagesMap);
	FString PackageName(0);
	ULinkerLoad* ToCheck = NULL;
	Stack.Step( Stack.Object, &PackageName);
	P_GET_UBOOL_OPTX( bServerPackagesOnly, 0);
	P_FINISH;
	*(UBOOL*)Result = 0;

	if ( !XLevel->NetDriver || !XLevel->NetDriver->MasterMap ) //Not a net server
		return;

	if ( !PackageName.Len() ) //Package this actor was created from
	{
		PackageName = GetClass()->GetName();
		ToCheck = GetClass()->GetLinker();
	}

	if ( bServerPackagesOnly )
	{
		UGameEngine* GameEngine = Cast<UGameEngine>(XLevel->Engine);
		check( GameEngine);
		TArray<FString>* SP = (TArray<FString>*)  (((DWORD) &GameEngine->ServerPackages) + XCGE_Defaults->b451Setup * 4 );
		for ( INT i=0 ; i<SP->Num() ; i++ )
			if ( (*SP)(i) == PackageName )
			{
				*(UBOOL*)Result = 1;
				break;
			}
	}
	else
	{
		if ( !ToCheck )
		{
			BeginLoad();
			ToCheck = GetPackageLinker( NULL, *PackageName, 0, NULL, NULL );
			EndLoad();
			if ( !ToCheck )
			{
				debugf( NAME_Warning, TEXT("IsInPackageMap: Linker not found for %s"), *PackageName );
				return;
			}
		}
		TArray<FPackageInfo>* PList = &XLevel->NetDriver->MasterMap->List;
		for ( INT i=0 ; i<PList->Num() ; i++ )
			if ( (*PList)(i).Linker == ToCheck )
			{
				*(UBOOL*)Result = 1;
				break;
			}
	}
	unguard;
}


//========================================================================
//======================== ReachSpec implementation ======================
//========================================================================
void AXC_Engine_Actor::execGetReachSpec( FFrame& Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execGetReachSpec);
	GPropAddr = 0;
	Stack.Step( Stack.Object, NULL); //Don't store reachspec info
	P_GET_INT(Idx);
	P_FINISH;
	
	if ( GPropAddr && (Idx >= 0) && (Idx < GetLevel()->ReachSpecs.Num()) )
	{
		*(FReachSpec*)GPropAddr = GetLevel()->ReachSpecs(Idx);
		*(UBOOL*)Result = true;
	}
	else
		*(UBOOL*)Result = false;
	unguard;
}

static void AutoSetSpec( const FReachSpec& RS, int Idx)
{
	ANavigationPoint* N = Cast<ANavigationPoint>(RS.Start);
	INT* PathArray = N ? N->Paths : 0;
	for ( INT j=0 ; j<2 ; j++ ) //Branchless huehue
	{
		if ( N )
		{
			for ( INT i=0 ; i<16 ; i++ )
				if ( PathArray[i] == -1 )
				{
					PathArray[i] = Idx;
					break;
				}
		}
		
		N = Cast<ANavigationPoint>(RS.End);
		PathArray = N ? N->upstreamPaths : 0;
	}
}

void AXC_Engine_Actor::execSetReachSpec( FFrame& Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execSetReachSpec);
	FReachSpec Spec;
	Stack.Step( Stack.Object, &Spec);
	P_GET_INT(Idx);
	P_GET_UBOOL_OPTX(bAutoSet,false);
	P_FINISH;
	
	if ( GPropAddr && (Idx >= 0) && (Idx < GetLevel()->ReachSpecs.Num()) )
	{
		GetLevel()->ReachSpecs(Idx) = Spec;
		if ( bAutoSet )
			AutoSetSpec( Spec, Idx);
		*(UBOOL*)Result = true;
	}
	else
		*(UBOOL*)Result = false;
	unguard;
}

void AXC_Engine_Actor::execReachSpecCount( FFrame& Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execReachSpecCount);
	P_FINISH;
	*(INT*)Result = GetLevel()->ReachSpecs.Num();
	unguard;
}

void AXC_Engine_Actor::execAddReachSpec( FFrame& Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execAddReachSpec);
	*(INT*)Result = GetLevel()->ReachSpecs.Add();
	Stack.Step( Stack.Object, &GetLevel()->ReachSpecs(*(INT*)Result) );
	P_GET_UBOOL_OPTX(bAutoSet,false);
	P_FINISH;
	if ( bAutoSet )
		AutoSetSpec( GetLevel()->ReachSpecs(*(INT*)Result), *(INT*)Result);
	unguard;
}

void AXC_Engine_Actor::execFindReachSpec( FFrame& Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execFindReachSpec);
	P_GET_ACTOR( Start);
	P_GET_ACTOR( End);
	P_FINISH;
	
	*(INT*)Result = -1;

	INT iNum = GetLevel()->ReachSpecs.Num();
	if ( iNum )
	{
		FReachSpec* Specs = (FReachSpec*) GetLevel()->ReachSpecs.GetData();
		for ( INT i=0 ; i<iNum ; i++ )
		{
			if ( Specs[i].Start == Start && Specs[i].End == End )
			{
				*(INT*)Result = i;
				break;
			}
		}
	}
	unguard;
}

void AXC_Engine_Actor::execCompactPathList( FFrame& Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execCompactPathList);
	P_GET_NAVIG(N);
	P_FINISH;

	if ( !N )
		return;

	INT TotalRS = GetLevel()->ReachSpecs.Num();
	FReachSpec* Specs = (FReachSpec*) GetLevel()->ReachSpecs.GetData();

	INT* PathArrays[3] = { N->upstreamPaths, N->Paths, N->PrunedPaths};
	for ( INT k=0 ; k<3 ; k++ )
	{
		INT* Paths = PathArrays[k];
		INT i;
		for ( i=0 ; i<16 ; i++ )
			if ( (Paths[i] >= 0) && (Paths[i] < TotalRS) && (!Specs[Paths[i]].Start || !Specs[Paths[i]].End) )
				Paths[i] = -1;
		INT iEmpty;
		for ( iEmpty=0; iEmpty<16 ; iEmpty++ )
			if ( Paths[iEmpty] == -1 )
				break;
		for ( i=iEmpty+1 ; i<16 ; i++ )
			if ( Paths[i] != -1 )
			{
				Paths[iEmpty++] = Paths[i];
				Paths[i] = -1;
			}
	}
	unguard;
}

void AXC_Engine_Actor::execLockToNavigationChain( FFrame& Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execLockToNavigationChain);
	P_GET_NAVIG(nBase);
	P_GET_UBOOL(bLock);
	P_FINISH;

	ANavigationPoint** NR = &(Level->NavigationPointList);
	//Find path in chain, unlock if present
	while ( *NR )
	{
		if ( *NR == nBase )
		{
			if ( !bLock )
			{
				*NR = nBase->nextNavigationPoint;
				nBase->nextNavigationPoint = NULL;
			}
			return;
		}
		NR = &((*NR)->nextNavigationPoint);
	}
	//If not found, lock if necessary
	if ( bLock )
	{
		nBase->nextNavigationPoint = Level->NavigationPointList;
		Level->NavigationPointList = nBase;
	}
	unguard;
}


void AXC_Engine_Actor::execAllReachSpecs( FFrame& Stack, RESULT_DECL)
{
	guard(AXC_Engine_Actor::execAllReachSpecs);
	
	GPropAddr = 0;
	Stack.Step( Stack.Object, NULL);
	FReachSpec* RS = (FReachSpec*)GPropAddr;
	P_GET_INT_REF( IdxRef);
	P_FINISH;

	if ( !RS )
		return;
	
	if ( *IdxRef < 0 )
		*IdxRef = 0;
	else if ( *IdxRef >= GetLevel()->ReachSpecs.Num() )
		return;
	*IdxRef -= 1;

	PRE_ITERATOR;
		*IdxRef += 1;
		if ( *IdxRef >= GetLevel()->ReachSpecs.Num() )
		{
			Stack.Code = &Stack.Node->Script(wEndOffset + 1);
			break;
		}
		*RS = GetLevel()->ReachSpecs(*IdxRef);
	POST_ITERATOR;
	
	unguard;
}


static UBOOL PCanSee( AActor* Seen, APlayerPawn* Other)
{
	guard( XC_Engine::PCanSee);
	check( Other && Seen);
	FVector aVec = Seen->Location - Other->Location;
	if ( aVec.IsZero() )
		return 0;
	if ( aVec.SizeSquared() > 2560000 )
		return 0;
	if ( aVec.SizeSquared() > (aVec + Other->ViewRotation.Vector()).SizeSquared() )
		return 0;
	if ( !aVec.Normalize() )
		return 0;
	FLOAT aFov = Other->FovAngle / 114.6; //Real angle outside of the center
	FLOAT aDot = aVec|Other->ViewRotation.Vector(); //This is the cosine of our angle
	if ( aDot < appCos(aFov * 1.2) )
		return 0;
	FCheckResult Hit;
	return Seen->XLevel->SingleLineCheck( Hit, Seen, Seen->Location, Other->Location + FVector(0,0,Other->BaseEyeHeight), TRACE_Level, FVector(0,0,0), 0|NF_NotVisBlocking);
	unguard;
}

//Called mostly on Actor context
void AXC_Engine_Actor::execPlayerCanSeeMe_XC(FFrame &Stack, RESULT_DECL)
{
	guard( XC_Engine::execPlayerCanSeeMe_XC);
	P_FINISH;

	*(UBOOL*)Result = 0;
	if ( XLevel )
	{
		if ( XLevel->Engine->Client && XLevel->Engine->Client->Viewports.Num() && XLevel->Engine->Client->Viewports(0) && XLevel->Engine->Client->Viewports(0)->Actor ) //Local player
			if ( PCanSee( this, XLevel->Engine->Client->Viewports(0)->Actor) )
			{
				*(UBOOL*)Result = 1;
				return;
			}
		if ( XLevel->NetDriver && XLevel->NetDriver->ClientConnections.Num() ) //Clients
		{
			for ( INT ip=0 ; ip < XLevel->NetDriver->ClientConnections.Num() ; ip++ )
				if ( XLevel->NetDriver->ClientConnections(ip) && XLevel->NetDriver->ClientConnections(ip)->Actor )
					if ( PCanSee( this, XLevel->NetDriver->ClientConnections(ip)->Actor) )
					{
						*(UBOOL*)Result = 1;
						return;
					}
		}
	}

	unguard;
}
