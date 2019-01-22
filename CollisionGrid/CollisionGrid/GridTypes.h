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
struct DE ActorInfo
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
	cg::Box GridBox;


	//[16] Container info!
/*	uint8 GXStart;
	uint8 GYStart;
	uint8 GZStart;
	uint8 GXEnd;
	uint8 GYEnd;
	uint8 GZEnd;
	*/

	ActorInfo() {}

	static const TCHAR* Name() { return TEXT("ActorInfo"); }

	bool Init( AActor* InActor);
	bool IsValid() const;
};

//int tat = sizeof(ActorInfo);

//
// Actor Link container with helper functions
//
class DE ActorLinkContainer : public TArray<struct ActorInfo*>
{
public:
	ActorLinkContainer()
		: TArray<ActorInfo*>()
	{}

	~ActorLinkContainer()
	{
		if( Data )
			appFree( Data );
		Data = nullptr;
		ArrayNum = ArrayMax = 0;
	}

	void Remove( int32 Index) //Fast remove, no memory move or deallocation
	{
		if ( Index < --ArrayNum )
			(*this)(Index) = (*this)(ArrayNum);
		(*this)(ArrayNum) = 0; //Temporary
	}

	bool RemoveItem( ActorInfo* AInfo)
	{
		for ( int32 i=0 ; i<ArrayNum ; i++ )
			if ( (*this)(i) == AInfo )
			{
				Remove(i);
				return true;
			}
		return false;
	}

	class Iterator
	{
		ActorLinkContainer& Cont;
		int32 Cur;
	public:
		Iterator( ActorLinkContainer& InContainer) : Cont(InContainer), Cur(0) {}
		ActorInfo* GetInfo();
	};
};

//
// Grid 'node' used as container for actors
//
struct DE GridElement
{
	ActorLinkContainer Actors;
	MiniTree* Tree;
	uint32 CollisionTag;
	uint8 X, Y, Z, W;

	GridElement( uint32 i, uint32 j, uint32 k);
	~GridElement() {};

	cg::Integers Coords()
	{
		return cg::Integers( X, Y, Z, W);
	}
};

//
// Grid of 128^3 cubes
//
struct DE Grid
{
	cg::Integers Size;
	cg::Box Box;
	ActorLinkContainer Actors;
	MiniTree* TreeList;
	GridElement* Nodes;

	Grid( class ULevel* Level);
	~Grid();
	
	bool InsertActor( class AActor* InActor);
	bool RemoveActor( class AActor* OutActor);
	FCheckResult* LineQuery( const PrecomputedRay& Ray, uint32 ExtraNodeFlags);
	void Tick();

	//Accessor
	GridElement* Node( int32 i, int32 j, int32 k);
	GridElement* Node( const cg::Integers& I);
	cg::Box GetNodeBoundingBox( const cg::Integers& Coords) const;
};


//
// Mini octree for grid
//
struct DE MiniTree
{
	cg::Box Bounds;
	MiniTree* Children[8];
	MiniTree* Next; //Linked list
	ActorLinkContainer Actors;
	uint8 Depth;
	uint8 Timer;
	uint8 ChildCount;
	uint8 HasActors; //Bit array

	MiniTree() {}
	MiniTree( Grid* G, const cg::Integers& C);
	MiniTree( MiniTree* T, uint32 SubOctant);
	~MiniTree();

	static const TCHAR* Name() { return TEXT("MiniTree"); }

	cg::Box GetSubOctantBox( uint32 Index) const;
	uint32 GetSubOctant( const cg::Vector& Point) const;

	void InsertActorInfo( ActorInfo* InActor, const cg::Box& Box);
	void RemoveActorInfo( ActorInfo* InActor, const cg::Vector& Location);
	void CleanupActors();
	bool ShouldQuery() { return HasActors != 0 || Actors.ArrayNum != 0; }

	void GenericQuery( const GenericQueryHelper& Helper, FCheckResult*& ResultList);
	void LineQuery( const PrecomputedRay& Ray, FCheckResult*& ResultList);
};


//
// Trace helper
//
struct DE PrecomputedRay
{
	cg::Vector Org;
	cg::Vector End;
	cg::Vector Dir;
	cg::Vector Inv;
	cg::Integers iBoxV; //Backface cull helper
	cg::Vector Extent;
	cg::Vector coX;
	float Length;
	uint32 ExtraNodeFlags;
	bool(PrecomputedRay::*Hits_CylActor)( ActorInfo*, FCheckResult*& Link) const;

	PrecomputedRay( const FVector& TraceStart, const FVector& TraceEnd, const FVector& TraceExtent, uint32 ENF);


	bool IntersectsBox( const cg::Box& Box) const;
	void QueryContainer(ActorLinkContainer& Container, FCheckResult*& Result) const;

	bool Hits_GCylActor( ActorInfo* AInfo, FCheckResult*& Link) const;
	bool Hits_HCylActor( ActorInfo* AInfo, FCheckResult*& Link) const;
	bool Hits_VCylActor( ActorInfo* AInfo, FCheckResult*& Link) const;

	inline bool IsValid() { return ExtraNodeFlags != 0xFFFFFFFF; }
};

typedef void (GenericQueryHelper::*ActorQuery)( ActorInfo*, FCheckResult*&) const;
//
// Base model of the query helper
//
class DE GenericQueryHelper
{
public:
	cg::Vector Location;
	cg::Box Bounds;
	uint32 ExtraNodeFlags; //0xFFFFFFFF = invalid query
	ActorQuery Query;

	GenericQueryHelper() {}
	GenericQueryHelper( const FVector& Loc3, uint32 InENF, ActorQuery NewQuery);
	bool IntersectsBox( const cg::Box& Box) const;
	FCheckResult* QueryGrid( Grid* Grids);
	void QueryContainer( ActorLinkContainer& Container, FCheckResult*& Result) const;
	inline bool IsValid() { return ExtraNodeFlags != 0xFFFFFFFF; }

};

// Point query helper
class DE PointHelper : public GenericQueryHelper
{
public:
	cg::Vector Extent;

	PointHelper( const FVector& Origin, const FVector& Extent, uint32 ExtraNodeFlags);

	void PointQuery(ActorInfo* AInfo, FCheckResult*& ResultList) const;

};

// Radius query helper
class DE RadiusHelper : public GenericQueryHelper
{
public:
	float RadiusSq;

	RadiusHelper( const FVector& Origin, float InRadius, uint32 ExtraNodeFlags);

	void RadiusQuery(ActorInfo* AInfo, FCheckResult*& ResultList) const;

};

// Encroach query helper
class DE EncroachHelper : public GenericQueryHelper
{
public:
	AActor* Actor;
	FRotator* Rotation;

	EncroachHelper( AActor* InActor, const FVector& Loc3, FRotator* Rot3, uint32 InExtraNodeFlags);
	~EncroachHelper();

	void EncroachmentQuery(ActorInfo* AInfo, FCheckResult*& ResultList) const;
	void EncroachmentQueryCyl(ActorInfo* AInfo, FCheckResult*& ResultList) const;

};
