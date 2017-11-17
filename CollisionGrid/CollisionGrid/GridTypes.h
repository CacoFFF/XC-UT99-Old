/**
	GridTypes.h
	Author: Fernando Velázquez

	Grid system designed for UE1 physics.

	Actors may reside in:
	- global references if they're too large (>1000 slots)
	- shared references if they touch the boundaries of grid slots
	- internal references held in a mini 'octree' if inside the grid slot

	This grid has been designed so that no upwards references are held
	and memory allocations/deallocations are kept to a minimum (or none)

*/



#pragma once

#include "GridMath.h"
#include "Structs_UE1.h"

#define GRID_NODE_DIM 512.f
#define GRID_MULT 1.f/GRID_NODE_DIM
#define MAX_TREE_DEPTH 3
#define REQUIRED_FOR_SUBDIVISION 4
#define MAX_NODES_BOUNDARY 512
#define MAX_GRID_COUNT 64
#define MAX_NODE_LINKS 128 //Maximum amount of Node elements before using 'global' placement

extern cg::Vector Grid_Unit;
extern cg::Vector Grid_Mult;
extern cg::Vector SMALL_VECTOR;
extern cg::Integers XYZi_One;
extern cg::Vector ZNormals[2]; //Up then down
extern cg::Integers Vector3Mask;


struct ActorLink;
struct MiniTree;
struct PrecomputedRay;
class GenericQueryHelper;
class PointHelper;
class RadiusHelper;
class EncroachHelper;

enum EFullGrid { E_FullGrid = 0 };
enum ELocationType { ELT_Global = 0 , ELT_Node = 1 , ELT_Tree = 2 , ELT_Max = 3 };

//
// Basic Actor container
//
MS_ALIGN(16) struct DE ActorInfo
{
	//[16]
	uint32 ObjIndex;
	class AActor* Actor;
	uint32 CollisionTag;
	struct
	{
		uint8 bUseCylinder:1; //Instead of box+primitive, do cylinder checking directly
		uint8 bCommited:1; //Not free (element holder, needed because the reference can be shared)
		uint8 bIsMovingBrush:1;
	} Flags;
	uint8 LocationType;
	uint8 CurDepth; //These are per-grid, they gotta go
	uint8 TopDepth;
	//[32]
	union
	{	struct
		{	cg::Vector Location;
			cg::Vector Extent;		} C; //Cylinder mode
		struct
		{	cg::Box pBox;			} P; //Primitive mode
	};

	ActorInfo() {}

	static const TCHAR* Name() { return TEXT("ActorInfo"); }
	static void LineQuery( ActorLink* Container, const PrecomputedRay& Ray, FCheckResult*& Link);
	static void PointQuery( ActorLink* ALink, const PointHelper& Helper, FCheckResult*& ResultList);
	static void RadiusQuery( ActorLink* ALink, const RadiusHelper& Helper, FCheckResult*& ResultList);
	static void EncroachmentQuery( ActorLink* ALink, const EncroachHelper& Helper, FCheckResult*& ResultList);
	static void EncroachmentQueryCyl( ActorLink* ALink, const EncroachHelper& Helper, FCheckResult*& ResultList);

	bool Init( AActor* InActor);
	bool IsValid();

	cg::Box cBox();
	cg::Vector cLocation();
} GCC_ALIGN(16);


//int tat = sizeof(ActorInfo);

//
// Actor node, holds references
//
struct ActorLink
{
	ActorInfo* Info;
	ActorLink* Next;

	static const TCHAR* Name() { return TEXT("ActorLink"); }
	static void Decommit( ActorLink*& AL); //Decommits it's ActorInfo, returns next in chain
	static bool Unlink( ActorLink** Container, ActorInfo* AInfo);
	static uint32 UnlinkInvalid( ActorLink** Container);
};


//
// Grid 'node' used as container for actors
//
MS_ALIGN(16) struct DE GridElement
{
	uint8 X, Y, Z, IsValid;
	ActorLink* BigActors;
	MiniTree* Tree;
	uint32 CollisionTag;

	void Init( uint8 i, uint8 j, uint8 k, uint8 bValid);
} GCC_ALIGN(16);

//
// Grid of 128^3 cubes
// Dynamically allocated with user-made alignment
//
MS_ALIGN(16) struct DE Grid
{
	cg::Integers Size;
	cg::Box Box;
	cg::Vector ReducedBoxSize; //Optimization
	ActorLink* GlobalActors;
	MiniTree* TreeList;
	uint32 CurNodeCleanup;
	
	//Variable-sized (through allocation)
	GridElement Nodes[1];

	bool InsertActor( class AActor* InActor);
	bool RemoveActor( class AActor* OutActor);
	FCheckResult* LineQuery( const PrecomputedRay& Ray, uint32 ExtraNodeFlags);
	void Tick();


	//Accessor
	GridElement* Node( uint32 i, uint32 j, uint32 k);
	GridElement* Node( const cg::Integers& I);
	cg::Box GetNodeBoundingBox( const cg::Integers& Coords) const;

	//Global grid for now...
	static Grid* AllocateFor( class ULevel* Level);
	static Grid* AllocateFull();
	void Init();
	void Exit();

} GCC_ALIGN(16);


//
// Mini octree for grid
//
MS_ALIGN(16) struct DE MiniTree
{
	cg::Box RealBounds;
	cg::Box OptimalBounds;
	MiniTree* Children[8];
	MiniTree* Next; //Linked list
	ActorLink* Actors; //Linked list
	uint32 ActorCount;
	uint8 Depth;
	uint8 Timer;
	uint8 ChildCount;
	uint8 ChildIdx;

	MiniTree() {}
	MiniTree( Grid* G, const cg::Integers& C);
	MiniTree( MiniTree* T, uint32 SubOctant);

	static const TCHAR* Name() { return TEXT("MiniTree"); }

	cg::Box GetSubOctantBox( uint32 Index) const;
	uint32 GetSubOctant( const cg::Vector& Point) const;

	void InsertActorInfo( ActorInfo* InActor, const cg::Box& Box);
	void RemoveActorInfo( ActorInfo* InActor, const cg::Vector& Location);
	void CalcOptimalBounds();
	void CleanupActors();

	void GenericQuery( const GenericQueryHelper& Helper, FCheckResult*& ResultList);
	void LineQuery( const PrecomputedRay& Ray, FCheckResult*& ResultList);
} GCC_ALIGN(16);


//
// Trace helper
//
MS_ALIGN(16) struct DE PrecomputedRay
{
	cg::Vector Org;
	cg::Vector End;
	cg::Vector Dir;
	cg::Vector Inv;
	cg::Integers iBoxV; //Backface cull helper
	cg::Vector Extent;
	cg::Vector coX;
	float Length;
	uint32 UsePoint;
	bool(PrecomputedRay::*Hits_CylActor)( ActorInfo*, FCheckResult*& Link) const;

	PrecomputedRay( const FVector& TraceStart, const FVector& TraceEnd, const FVector& TraceExtent);

	bool IntersectsBox( const cg::Box& Box) const;

	bool Hits_GCylActor( ActorInfo* AInfo, FCheckResult*& Link) const;
	bool Hits_HCylActor( ActorInfo* AInfo, FCheckResult*& Link) const;
	bool Hits_VCylActor( ActorInfo* AInfo, FCheckResult*& Link) const;
	bool Hits_UCylActor( ActorInfo* AInfo, FCheckResult*& Link) const;

} GCC_ALIGN(16);


typedef void (*ActorQuery)( ActorLink*, const class GenericQueryHelper&, FCheckResult*&);
//
// Base model of the query helper
//
MS_ALIGN(16) class DE GenericQueryHelper
{
public:
	cg::Vector Location;
	cg::Box Bounds;
	uint32 ExtraNodeFlags; //0xFFFFFFFF = invalid query
	ActorQuery Query;
	//2 extra DWORDs as padding

	GenericQueryHelper() {}
	GenericQueryHelper( const FVector& Loc3, uint32 InENF, ActorQuery NewQuery);
	bool IntersectsBox( const cg::Box& Box) const;
	FCheckResult* QueryGrids( Grid* Grids);
} GCC_ALIGN(16);

// Point query helper
MS_ALIGN(16) class DE PointHelper : public GenericQueryHelper
{
public:
	cg::Vector Extent;
	PointHelper( const FVector& Origin, const FVector& Extent, uint32 ExtraNodeFlags);
} GCC_ALIGN(16);

// Radius query helper
MS_ALIGN(16) class DE RadiusHelper : public GenericQueryHelper
{
public:
	float RadiusSq;
	RadiusHelper( const FVector& Origin, float InRadius, uint32 ExtraNodeFlags);
} GCC_ALIGN(16);

// Encroach query helper
MS_ALIGN(16) class DE EncroachHelper : public GenericQueryHelper
{
public:
	AActor* Actor;
	FRotator* Rotation;

	EncroachHelper( AActor* InActor, const FVector& Loc3, FRotator* Rot3, uint32 InExtraNodeFlags);
	~EncroachHelper();
} GCC_ALIGN(16);
