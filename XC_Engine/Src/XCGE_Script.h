// Script functions belonging to:
// XC_Engine_Actor

//Move to common macros later
#include "UnXC_Script.h"

	

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





