//Find Sort in UWindowList and link it to c++ code

// DEPRECATED

//************************************
//Precached variables go here

static INT NAMES_UWindowListSort = 0;
static FName NAME_Compare;

//************************************
//Definitions, classes and events go here
class UUWindowList;

struct UUWindowList_eventCompareParams
{
	UUWindowList* T;
	UUWindowList* B;
	INT ReturnValue;
};


//Dummy class, lets c++ compiler know how to handle this pure UScript object
class UUWindowList : public UObject //Size: 92
{
public:
	UUWindowList* Next;					//40
	UUWindowList* Last;					//44
	UUWindowList* Prev;					//48
	UUWindowList* Sentinel;				//52
	INT InternalCount;					//56
	BITFIELD bItemOrderChanged:1 GCC_PACK(4);	//60
	BITFIELD bSuspendableSort:1;
	INT CompareCount GCC_PACK(4);				//64
	BITFIELD bSortSuspended:1 GCC_PACK(4);		//68
	UUWindowList* CurrentSortItem GCC_PACK(4);	//72
	BITFIELD bTreeSort:1 GCC_PACK(4);			//76
	UUWindowList* BranchLeft GCC_PACK(4);		//80
	UUWindowList* BranchRight;					//84
	UUWindowList* ParentNode;					//88

	INT eventCompare( UUWindowList* T, UUWindowList* B)
	{
		UUWindowList_eventCompareParams Parms;
		Parms.T = T;
		Parms.B = B;
		Parms.ReturnValue = 0;
		ProcessEvent(FindFunctionChecked(NAME_Compare),&Parms);
		return Parms.ReturnValue;
	}


	DECLARE_FUNCTION(SortNative);
};


//************************************
//Bind function to native, register uscript function names

static void ReplaceSortFunc( UBOOL bSet)
{
	guard(ReplaceSortFunc);

	UClass* UWindowList = NULL;
	for( TObjectIterator<UClass> It; It; ++It )
		if( It->GetOuter() && (appStricmp( It->GetOuter()->GetName(), TEXT("UWindow") ) == 0) && (appStricmp( It->GetName(), TEXT("UWindowList") ) == 0) )
		{
			UWindowList = *It;
			break;
		}
	if ( !UWindowList )
		return;
	
	UFunction* Sort = FindBaseFunction( UWindowList, TEXT("Sort"));
	if ( !Sort ) //Script not serialized?
		return;

	if ( !bSet )
	{
		Sort->Func = &UObject::ProcessInternal;
		Sort->FunctionFlags = Sort->FunctionFlags & ~(FUNC_Native);
	}
	else
	{
		Sort->Func = (Native)&UUWindowList::SortNative;
		Sort->FunctionFlags = Sort->FunctionFlags | FUNC_Native;
	}

	//Register subnames
	if ( !NAMES_UWindowListSort )
	{
		NAMES_UWindowListSort = 1;
		NAME_Compare = FName(TEXT("Compare"),FNAME_Intrinsic);
	}

	unguard;
}

//************************************
//Natives go here

void UUWindowList::SortNative( FFrame& Stack, RESULT_DECL)
{
	P_FINISH;
	guard(SortNative);
	
	*(UUWindowList**)Result = this;
	return;
	//Higor: no need to split sort in various frames
/*	if( bTreeSort )
	{
		if(bSortSuspended)
		{
			ContinueSort();
			return Self;
		}

		CurrentSortItem = Next;
		DisconnectList();
		ContinueSort();
		return Self;
	}*/

	UUWindowList* CurrentItem = this;

	while( CurrentItem )
	{
		UUWindowList* S =		 CurrentItem->Next;
		UUWindowList* Best =	 CurrentItem->Next;
		UUWindowList* Previous = CurrentItem;
		UUWindowList* BestPrev = CurrentItem;
		

		// Find the best server
		while( S )
		{
			if( CurrentItem->eventCompare( S, Best) <= 0 ) 
			{
				Best = S;
				BestPrev = Previous;
			}
			
			Previous = S;
			S = S->Next;
		}

		// If we're not already in the right order, move the best one next.
		if( Best != CurrentItem->Next )
		{
			// Delete Best's old position
			BestPrev->Next = Best->Next;
			if ( BestPrev->Next )
				BestPrev->Next->Prev = BestPrev;

			// Fix Self and Best
			Best->Prev = CurrentItem;
			Best->Next = CurrentItem->Next;
			CurrentItem->Next->Prev = Best; 
			CurrentItem->Next = Best;
			
			// Fix up Sentinel if Best was also Last 
			if ( Sentinel->Last == Best )
			{
				Sentinel->Last = BestPrev;
				if ( Sentinel->Last == NULL )
					Sentinel->Last = Sentinel;
			}
		}
		CurrentItem = CurrentItem->Next;
	}
	unguard;
}
