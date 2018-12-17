/*=============================================================================
	Class cache definitions
	Move to XC_Core later, do not link here
=============================================================================*/

#ifndef _INC_XC_CLASSCACHE
#define _INC_XC_CLASSCACHE

//A standard PlayerPawn iterator list
struct FIteratorPList
{
	APlayerPawn* P;
	FIteratorPList* Next;
	FIteratorPList() {};
	FIteratorPList( APlayerPawn* nP, FIteratorPList* InNext)
	:	P(nP)
	,	Next(InNext)
	{};
};

#endif
