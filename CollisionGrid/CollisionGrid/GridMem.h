/**
	GridMem.h
	Author: Fernando Velázquez

	Preallocated memory managing subsystems.
	These are used to eliminate the usage of system memory allocators/deallocators.

*/

#pragma once

#include "GridTypes.h"


extern class ActorInfoHolder* G_AIH;
extern class MiniTreeHolder* G_MTH;
extern class GenericMemStack* G_Stack;

//*************************************************
//
// GenericMemStack stack
//
//*************************************************
class GenericMemStack
{
	uint32 Cur;
	uint32 End;

	friend class GSBaseMarker;
	friend void* operator new( size_t Size, GenericMemStack* Mem);
public:
	GenericMemStack( uint32 InSize)
		: Cur(0), End( InSize - sizeof(GenericMemStack)) {}

	bool Validate( void* Ptr);

	template<typename T> void Pop()
	{
		Cur -= sizeof(T);
	}

	void Exit() {};
};

inline void* operator new( size_t Size, GenericMemStack* Mem )
{
	UE_DEV_THROW( Mem->Cur+Size > Mem->End, "Generic memory stack fully used");
	void* Result =  (void*) (((uint32)Mem) + sizeof(GenericMemStack) + Mem->Cur);
	Mem->Cur += Size;
	return Result;
}

inline bool GenericMemStack::Validate( void* Ptr)
{
	uint32 PtrVal = (uint32)Ptr;
	uint32 Start = (uint32)this + sizeof(GenericMemStack);
	uint32 Top = Start + End;
	UE_DEV_THROW( PtrVal < Start || PtrVal >= Top, "Validation for mem object failed" );
	return PtrVal >= Start && PtrVal < Top;
}



class GSBaseMarker
{
public:
	GSBaseMarker();
	~GSBaseMarker();
};

enum EHolderFlags
{
	HF_Construct = 0x01,
	HF_Destruct = 0x02,
	HF_ZeroInit = 0x04,
	HF_ZeroExit = 0x08
};

//*************************************************
//
// Element holder
// Holds a bunch of contiguous objects without required allocation/deallocation
//
//*************************************************
template<typename T,int kb,int hflags=0> class ElementHolder
{
	//Ideally keep data in 4kb*n size blocks, amount of blocks is reasonably deducted here
	//Why substract 32 bytes? _freecount=4, _next=4
	#define HOLDER_COUNT ((1024*kb-8)/(sizeof(uint32)+sizeof(T)))

	ElementHolder<T,kb,hflags>* _next;
	int32                _freecount;
	T                    _holder[HOLDER_COUNT];
	int32                _free[HOLDER_COUNT];

public:
	//Constructor
	ElementHolder()
		:	_next(nullptr)
		,	_freecount(HOLDER_COUNT)
	{
		for ( uint32 i=0; i<HOLDER_COUNT; i++)
			_free[i] = i;
		if ( hflags & HF_ZeroInit )
			memset( _holder, 0, sizeof(_holder) );
		UE_DEV_LOG( TEXT("[CG] Allocated element holder for %s with %i entries at %i"), T::Name(), _freecount, this);
	}

	//Destructor
	~ElementHolder()
	{
		if ( hflags & HF_Destruct )
		{
			debugf_ansi("Destructing holder");
			for ( uint32 i=0 ; i<HOLDER_COUNT ; i++ )
				_holder[i].~T();
		}
		if ( hflags & HF_ZeroExit )
			memset( _holder, 0, sizeof(_holder) );
	}

	//Destructs whole chain of holders
	void Exit()
	{
		ElementHolder<T,kb,hflags> *C, *N;
		for ( C=this ; C ; C=N )
		{
			N = C->_next;
			delete C;
		}
	}

	//Gets index of an element by pointer
	int32 GetIndex(T* N)
	{
		if ( N < _holder || N >= (&_holder[HOLDER_COUNT]))
			return -1;
		return ((uint32)N - (uint32)_holder) / sizeof(T);
	}

	//Verifies that is contained by ANY of the chained holders (can release the object as well)
	bool IsValid( T* N)
	{
		uint32 HolderMemSize = HOLDER_COUNT * sizeof(T);
		uint32 ElemAddr = (uint32)N;
		for ( ElementHolder<T,kb,hflags>* Link=this ; Link ; Link=Link->_next )
		{
			uint32 StartAddr = (uint32)Link->_holder;
			if ( ElemAddr >= StartAddr && ElemAddr < StartAddr+HolderMemSize )
				return true;
		}
		PlainText Error = PlainText(TEXT("[CG ]IsValid cannot validate element ")) + T::Name() + TEXT(" ") + ElemAddr + TEXT(" (H=") + HolderMemSize + TEXT(") against:");
		for ( ElementHolder<T,kb,hflags>* Link=this ; Link ; Link=Link->_next )
		{
			uint32 StartAddr = (uint32)Link->_holder;
			Error = Error + TEXT(" [") + StartAddr + TEXT("-") + (StartAddr+HolderMemSize) + TEXT("]");
		}
		(GLog->*Debugf)( *Error);
//		appFailAssert( Error.Ansi() );
		return false;
	}

	//Picks up a new element, will create new holder if no new elements
	T* GrabElement()
	{
		guard_slow(#T#::GrabElement);
		int i = 0;
		for ( ElementHolder<T,kb,hflags>* Link=this ; Link ; Link=Link->_next )
		{
			i++;
			if ( Link->_freecount > 0 )
			{
				Link->_freecount--;
				int32 free = Link->_free[Link->_freecount];
				T* Result = &Link->_holder[ free];
				if ( hflags & HF_Construct )
					Result = new ( Result, E_Stack) T();
				return Result; //Index never mismatches, code is good
			}
			else if ( !Link->_next )
			{
				UE_DEV_LOG( TEXT("[CG] Allocating extra element holder for %s"), T::Name() );
				Link->_next = new ElementHolder<T,kb,hflags>();
				UE_DEV_THROW( !Link->_next, "Unable to allocate new element holder");
			}
		}
		appFailAssert("ElementHolder::GrabElement error.");
		return nullptr;
		unguard_slow;
	}

	//Releases element by adding to '_free' list
	bool ReleaseElement(void* N)
	{
		for ( ElementHolder<T,kb,hflags>* Link = this ; Link ; Link=Link->_next)
		{
			int32 idx = Link->GetIndex( (T*)N);
			if ( idx != -1 )
			{
				if ( hflags & HF_Destruct )
					Link->_holder[idx].~T();
				if ( hflags & HF_ZeroExit )
					memset( &Link->_holder[idx], 0, sizeof(T) );
				Link->_free[Link->_freecount++] = idx;
				return true;
			}
		}
		//Deprecate these at some point
		PlainText Error = PlainText( TEXT("ElementHolder::ReleaseElement error, TYPE=")) + T::Name();
		appFailAssert( Error.Ansi() );
		return false;
	}

};

//
// Customized element holder for ActorInfo(s) (should contain ~ elements)
//
class ActorInfoHolder : public ElementHolder<ActorInfo,64>
{
public:
	//Picks up a new element, will create new holder if no new elements
	ActorInfo* GrabElement( class AActor* InitFor)
	{
		guard_slow(Grab);
		ActorInfo* res = ElementHolder<ActorInfo,64>::GrabElement();
		if ( res && !res->Init(InitFor) )
		{
			ReleaseElement(res);
			return nullptr;
		}
		return res;
		unguard_slow;
	}
	//Releases element by adding to '_free' list
	void ReleaseElement(ActorInfo* AI)
	{
		if ( AI->Flags.bCommited )
		{
			AI->Flags.bCommited = false;
			ElementHolder<ActorInfo,64>::ReleaseElement(AI);
		}
	}
};

//
// Customized element holder for MiniTree(s) (should contain 779 elements)
//
class MiniTreeHolder : public ElementHolder<MiniTree,64,HF_ZeroInit|HF_Destruct|HF_ZeroExit>
{
public:
};




