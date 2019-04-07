/*=============================================================================
	UnXC_Script.h
	Author: Fernando Velázquez

	UnrealScript execution expander.
=============================================================================*/

#ifndef INC_XC_SCRIPT
#define INC_XC_SCRIPT


#define P_GET_CLASS(var)                P_GET_OBJECT(UClass,var)
#define P_GET_PAWN_OPTX(var,def)        P_GET_OBJECT_OPTX(APawn,var,def)
#define P_GET_PAWN_REF(var)             P_GET_OBJECT_REF(APawn,var)
#define P_GET_NAVIG(var)                P_GET_OBJECT(ANavigationPoint,var)
#define P_GET_NAVIG_OPTX(var,def)       P_GET_OBJECT_OPTX(ANavigationPoint,var,def)
#define P_GET_NAVIG_REF(var)            P_GET_OBJECT_REF(ANavigationPoint,var)


//These two macros take a parameter (must be a property, not a function call) of any type and store in a dynamic array
//If script implementation doesn't use 'out' then we can't assure safe functioning.
#define P_GET_GENERIC_ARRAY_INPUT(typ,var)    TArray<typ> var=TNormalParameterToArray<typ>(Stack);
#define P_GET_OBJECT_ARRAY_INPUT(typ,var)     TArray<typ*> var=TNormalParameterToArray<typ*,1>(Stack);


//Default template parameter IgnoreNull=0 stripped because GCC doesn't support this
template <typename T, UBOOL IgnoreNull> inline TArray<T> TNormalParameterToArray( FFrame& Stack)
{
	TArray<T> Result;
	GProperty = NULL;
	GPropAddr = NULL;
	T LocalList[ 1 + 1024 / sizeof(T)];
	appMemzero( LocalList, sizeof(LocalList));
	Stack.Step( Stack.Object, LocalList);

	if ( GProperty && !IgnoreNull ) //We're passing a fixed array as condition
	{
		Result.AddZeroed( GProperty->ArrayDim);
		for ( INT i=0 ; i<GProperty->ArrayDim ; i++ )
			Result(i) = LocalList[i];
	}
	else //We're passing a function return (or we want to remove null results)
	{
		for ( INT i=0 ; i<ARRAY_COUNT(LocalList) ; i++ )
			if ( !IgnoreNull || (LocalList[i] != NULL) ) //Constant condition
				Result.AddItem( LocalList[i]);
	}
	return Result;
}

//Returns sorted list of parameters
inline TArray<UProperty*> GetScriptParameters( UFunction* Func)
{
	TArray<UProperty*> Result;
	if ( Func->NumParms )
	{
		for ( UProperty* Prop=Cast<UProperty>(Func->Children) ; Prop ; Prop=Cast<UProperty>(Prop->Next) )
			if ( (Prop->Offset < Func->ParmsSize) && !(Prop->PropertyFlags & CPF_ReturnParm) )
			{
				INT i = 0;
				while ( i<Result.Num() && (Result(i)->Offset < Prop->Offset) )
					i++;
				Result.Insert( i);
				Result(i) = Prop;
			}
	}
	return Result;
}


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

#endif