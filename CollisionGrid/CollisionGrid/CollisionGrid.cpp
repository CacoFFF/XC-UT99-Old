//
// CollisionGrid.cpp
// Bridge between XC_Engine and CollisionGrid
// 
//

#include "API.h"
#include "GridTypes.h"
#include "GridMem.h"

ActorLinkHolder* G_ALH = nullptr;
ActorInfoHolder* G_AIH = nullptr;
MiniTreeHolder* G_MTH = nullptr;
FCollisionHashBase* G_CHB = nullptr;
GenericMemStack* G_Stack = nullptr;

//
// Grid container, UE interface
//
class FCollisionGrid : public FCollisionHashBase
{
public:
	Grid* Grid;
	static uint32 GridCount;

	//FCollisionGrid interface.
	FCollisionGrid( class ULevel* Level)
	{
		GridCount++;
		Grid = Grid::AllocateFor( Level);
	}
	~FCollisionGrid();

#ifdef __GNUC__
	void SimulatedDestructor()
	{
		delete this;
	}
#endif


	// FCollisionHashBase interface.
	virtual void Tick();
	virtual void AddActor(AActor *Actor);
	virtual void RemoveActor(AActor *Actor);
	virtual FCheckResult* ActorLineCheck(FMemStack& Mem, FVector End, FVector Start, FVector Extent, uint8 ExtraNodeFlags);
	virtual FCheckResult* ActorPointCheck(FMemStack& Mem, FVector Location, FVector Extent, uint32 ExtraNodeFlags);
	virtual FCheckResult* ActorRadiusCheck(FMemStack& Mem, FVector Location, float Radius, uint32 ExtraNodeFlags);
	virtual FCheckResult* ActorEncroachmentCheck(FMemStack& Mem, AActor* Actor, FVector Location, FRotator Rotation, uint32 ExtraNodeFlags);
	virtual void CheckActorNotReferenced(AActor* Actor) {};


};

uint32 FCollisionGrid::GridCount = 0;

//
// XC_Engine's first interaction
//
extern "C"
{

TEST_EXPORT FCollisionHashBase* GNewCollisionHash( ULevel* Level)
{
	if ( !LoadUE() )
		return nullptr;
	if ( Loaded == 1 )
		debugf_ansi( "[CG] CollisionGrid library succesfully initialized.");
	if ( !G_ALH )	G_ALH = new (A_16) ActorLinkHolder();
	if ( !G_AIH )	G_AIH = new (A_16) ActorInfoHolder();
	if ( !G_MTH )	G_MTH = new (A_16) MiniTreeHolder();
	if ( !G_Stack )	G_Stack = new (SIZE_KBytes, 256) GenericMemStack( 256 * 1024); //5461 results
	debugf_ansi( "[CG] Element holders succesfully spawned.");
	//Unreal Engine destroys this object
	//Therefore use Unreal Engine allocator
	G_CHB = new(TEXT("FCollisionGrid")) FCollisionGrid( Level);
	return G_CHB;
}

}

FCollisionGrid::~FCollisionGrid()
{
	Grid->Exit();
	//		DebugLock( "DeleteGrid", 'D');
	GridCount--;
	if ( !GridCount )
	{
		Delete_A(G_ALH);
		Delete_A(G_AIH);
		Delete_A(G_MTH);
		if ( G_Stack )
		{
			delete G_Stack;
			G_Stack = nullptr;
		}
	}
	appFreeAligned( Grid);
};

GCC_STACK_ALIGN void FCollisionGrid::Tick()
{
	Grid->Tick();
}

GCC_STACK_ALIGN void FCollisionGrid::AddActor( AActor* Actor)
{
	Grid->InsertActor( Actor);
}

GCC_STACK_ALIGN void FCollisionGrid::RemoveActor(AActor *Actor)
{
	Grid->RemoveActor( Actor);
}

GCC_STACK_ALIGN FCheckResult* FCollisionGrid::ActorLineCheck(FMemStack& Mem, FVector End, FVector Start, FVector Extent, uint8 ExtraNodeFlags)
{
	FCheckResult* Result = nullptr;
	PrecomputedRay Ray( Start, End, Extent);
	if ( !Ray.UsePoint )
		Result = Grid->LineQuery( Ray, ExtraNodeFlags);
	return Result;
}

GCC_STACK_ALIGN FCheckResult* FCollisionGrid::ActorPointCheck(FMemStack& Mem, FVector Location, FVector Extent, uint32 ExtraNodeFlags)
{
	PointHelper Helper( Location, Extent, ExtraNodeFlags);
	return Helper.QueryGrids( Grid);
}

GCC_STACK_ALIGN FCheckResult* FCollisionGrid::ActorRadiusCheck(FMemStack& Mem, FVector Location, float Radius, uint32 ExtraNodeFlags)
{
	RadiusHelper Helper( Location, Radius, ExtraNodeFlags);
	return Helper.QueryGrids( Grid);
}

GCC_STACK_ALIGN FCheckResult* FCollisionGrid::ActorEncroachmentCheck(FMemStack& Mem, AActor* Actor, FVector Location, FRotator Rotation, uint32 ExtraNodeFlags)
{
	EncroachHelper Helper( Actor, Location, &Rotation, ExtraNodeFlags);
	return Helper.QueryGrids( Grid);
}
