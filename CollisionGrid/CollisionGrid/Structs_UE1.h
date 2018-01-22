/**
	Structs_UE1.h

	Necessary types to facilitate usage of vftables and access to members.

*/


#pragma once


class GNUFix
{
#ifdef __GNUC__
	virtual void vPad1() {};
	virtual void vPad2() {};
#endif
};



//***********************************************************************************
// Simplified Array Templates
template< class T > class TArray
{
protected:
	T* Data;
public:
	INT	  ArrayNum;
	INT	  ArrayMax;

	T& operator()( int32 i )	{	return ((T*)Data)[i];	}
};

template< class T > class TTransArray : public TArray<T>
{
public:
	class UObject* Owner;
};

class FString : protected TArray< TCHAR >
{
public:
	const TCHAR* operator*() const
	{
		return ArrayNum ? (const TCHAR*)Data : TEXT("");
	}
};

template< class TK, class TI > class TMap
{
	TArray</*TPair*/int32> Pairs;
	INT* Hash;
	INT HashCount;
};



//***********************************************************************************
// Memory allocator base type
class FMalloc : public GNUFix
{
public:
	virtual void* Malloc( uint32 Count, const TCHAR* Tag )=0;
	virtual void* Realloc( void* Original, uint32 Count, const TCHAR* Tag )=0;
	virtual void Free( void* Original )=0;
	virtual void DumpAllocs()=0;
	virtual void HeapCheck()=0;
	virtual void Init()=0;
	virtual void Exit()=0;
};


//***********************************************************************************
// Reduced name table entry
struct FNameEntry
{
	int32       Index;
	uint32      Unused[2];
	TCHAR		Name[1]; //Dynamically allocated (up to 64)

	const TCHAR* operator*() const
	{
		return Name;
	}
};



//***********************************************************************************
// Actor structures

struct FVector
{
	float X, Y, Z;
	FVector()
		: X(0), Y(0), Z(0) {}
	FVector( float inX, float inY, float inZ)
		: X(inX), Y(inY), Z(inZ) {}

	const TCHAR* String() const;
#ifdef GRIDMATH
	//Safe constructor
	FVector( const cg::Vector& V)
		: X(V.X), Y(V.Y), Z(V.Z) {}
	FVector( const cg::Vector& V, ENoSSEFPU)
	{
		for ( uint32 i=0 ; i<3 ; i++ )
			((uint32*)this)[i] = ((uint32*)&V)[i];
	}


	//Fast, unsafe assignment
	FVector operator=( const cg::Vector& V)
	{
		_mm_storeu_ps( (float*)this, _mm_load_ps( V.fa()) );
		return *this;
	}
#endif
};

struct FPlane : public FVector
{
	float W;
};
#define FSphere FPlane


struct FRotator
{
	int32 Pitch; // Looking up and down (0=Straight Ahead, +Up, -Down).
	int32 Yaw;   // Rotating around (running in circles), 0=East, +North, -South.
	int32 Roll;  // Rotation about axis of screen, 0=Straight, +Clockwise, -CCW.
};

struct FBox
{
	FVector Min;
	FVector Max;
	uint8 IsValid;
	uint8 Padding[3];

#ifdef GRIDMATH
	//Fast conversion to SSE box
	operator cg::Box() const
	{
		const cg::Integers Mask( 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0x00000000);
		cg::Box B;
		__m128 mask = _mm_castsi128_ps( _mm_load_si128( Mask.mm() ));
		_mm_store_ps( B.Min.fa(), _mm_and_ps( _mm_loadu_ps(&Min.X), mask) );
		_mm_store_ps( B.Max.fa(), _mm_and_ps( _mm_loadu_ps(&Max.X), mask) );
		return B;
	}
#endif

};

//***********************************************************************************
// Merged FCheckResult struct

struct FIteratorActorList
{
	FIteratorActorList* Next;
	class AActor* Actor;

	FIteratorActorList( FIteratorActorList* InNext) : Next(InNext) {}
};

struct FCheckResult : public FIteratorActorList
{
	FVector		Location;   // Location of the hit in coordinate system of the returner.
	FVector		Normal;     // Normal vector in coordinate system of the returner. Zero=none.
	class UPrimitive*	Primitive;  // Actor primitive which was hit, or NULL=none.
	float       Time;       // Time until hit, if line check.
	int32		Item;       // Primitive data item which was hit, INDEX_NONE=none.

	FCheckResult( FCheckResult* InNext) : FIteratorActorList(InNext)
	{
		*(uint32*)&Time = 0x3F800000; //Time = 1.f (MOV)
	}
};


//***********************************************************************************
// FCollisionHashBase
class FMemStack;
class AActor;

class FCollisionHashBase : public GNUFix
{
public:
	// FCollisionHashBase interface.
#ifdef __GNUC__
	//GCC 2.95 uses a single destructor entry (instead of 2)
	//TODO: See if this object is deallocated in Linux!!!
	virtual void SimulatedDestructor() = 0;
#else
	virtual ~FCollisionHashBase() {};
#endif
	virtual void Tick() = 0;
	virtual void AddActor(AActor *Actor) = 0;
	virtual void RemoveActor(AActor *Actor) = 0;
	virtual FCheckResult* ActorLineCheck(FMemStack& Mem, FVector End, FVector Start, FVector Extent, uint8 ExtraNodeFlags) = 0;
	virtual FCheckResult* ActorPointCheck(FMemStack& Mem, FVector Location, FVector Extent, uint32 ExtraNodeFlags) = 0;
	virtual FCheckResult* ActorRadiusCheck(FMemStack& Mem, FVector Location, float Radius, uint32 ExtraNodeFlags) = 0;
	virtual FCheckResult* ActorEncroachmentCheck(FMemStack& Mem, AActor* Actor, FVector Location, FRotator Rotation, uint32 ExtraNodeFlags) = 0;
	virtual void CheckActorNotReferenced(AActor* Actor) = 0;
};


//***********************************************************************************
// Output device base type

class FOutputDevice : public GNUFix
{
public:
	// FOutputDevice interface.
	virtual void Serialize( const TCHAR* V, EName Event )=0;
};


