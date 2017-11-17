#pragma once

#include "PlatformTypes.h"
#include "Structs_UE1.h"

//
// Result of GotoState.
//
enum EGotoState
{
	GOTOSTATE_NotFound = 0,
	GOTOSTATE_Success = 1,
	GOTOSTATE_Preempted = 2,
};

//
// Globally unique identifier.
//
class FGuid
{
public:
	uint32 A, B, C, D;
};


//
// COM IUnknown interface.
//
class FUnknown : public GNUFix
{
public:
	virtual uint32 STDCALL QueryInterface(const FGuid& RefIID, void** InterfacePtr) { return 0; }
	virtual uint32 STDCALL AddRef() { return 0; }
	virtual uint32 STDCALL Release() { return 0; }
};



//
// Portable struct of UE1's UObject
//
class UObject : public FUnknown
{
public:
	// Internal per-object variables.
	uint32					Index;				// Index of object into table.
	int32					Unused1[6];
	FName					Name;				// Name of the object.
	void*					Class;	  			// Class the object belongs to.

public:

	// Virtual methods.
#ifdef __GNUC__
	//GCC 2.95 uses a single destructor entry (instead of 2)
	//TODO: See if this object is deallocated in Linux!!!
	virtual void SimulatedDestructor() = 0;
#else
	virtual ~UObject() {};
#endif

	// UObject interface.
	virtual void ProcessEvent( class UFunction* Function, void* Parms, void* Result=NULL )=0;
	virtual void ProcessState( float DeltaSeconds )=0;
	virtual int32 ProcessRemoteFunction( UFunction* Function, void* Parms, class FFrame* Stack )=0;
	virtual void Modify()=0;
	virtual void PostLoad()=0;
	virtual void Destroy()=0;
	virtual void Serialize( class FArchive& Ar )=0;
	virtual int32 IsPendingKill()=0;
	virtual EGotoState GotoState( FName State )=0;
	virtual int32 GotoLabel( FName Label )=0;
	virtual void InitExecution()=0;
	virtual void ShutdownAfterError()=0;
	virtual void PostEditChange()=0;
	virtual void CallFunction( FFrame& TheStack, void*const Result, UFunction* Function )=0;
	virtual int32 ScriptConsoleExec( const TCHAR* Cmd, FOutputDevice& Ar, UObject* Executor )=0;
	virtual void Register()=0;
	virtual void LanguageChange()=0;



	// Functions.
//	const TCHAR* GetFullName( TCHAR* Str = nullptr) const;
//	UBOOL IsValid();
//	UBOOL IsA(UClass* SomeBaseClass) const;

	// Accessors, modified for CollisionGrid
	const TCHAR* GetName() const
	{
		return (*Core_NameTable)[Name]->Name;
//		return *Name;
	}
	FName GetFName() const
	{
		return Name;
	}
	uint32 GetIndex() const
	{
		return Index;
	}

};


//
// The net code uses this to send notifications.
//
class FNetworkNotify
{
public:
	virtual /*EAcceptConnection*/uint8 NotifyAcceptingConnection()=0;
	virtual void NotifyAcceptedConnection( class UNetConnection* Connection )=0;
	virtual int32 NotifyAcceptingChannel( class UChannel* Channel )=0;
	virtual class ULevel* NotifyGetLevel()=0;
	virtual void NotifyReceivedText( UNetConnection* Connection, const TCHAR* Text )=0;
	virtual int32 NotifySendingFile( UNetConnection* Connection, FGuid GUID )=0;
	virtual void NotifyReceivedFile( UNetConnection* Connection, INT PackageIndex, const TCHAR* Error, UBOOL Skipped )=0;
	virtual void NotifyProgress( const TCHAR* Str1, const TCHAR* Str2, float Seconds )=0;
};

//
// A game level.
//
class ULevelBase : public UObject, public FNetworkNotify //Size=140
{
public:
	TTransArray<AActor*> Actors; //O=44
								 // Variables.
	class UNetDriver*	NetDriver; //O=60
	class UEngine*		Engine; //O=64
	int URLPad[17];
//	FURL				URL; //O=68
	class UNetDriver*	DemoRecDriver; //O=136
};


//
// The level object.  Contains the level's actor list, Bsp information, and brush list.
//
class ULevel : public ULevelBase
{
public:
	enum {NUM_LEVEL_TEXT_BLOCKS=16};

	// Main variables, always valid.
	TArray</*FReachSpec*/int32>	ReachSpecs;
	class UModel*				Model;
	class UTextBuffer*			TextBlocks[NUM_LEVEL_TEXT_BLOCKS];
	double                   TimeSeconds;
	TMap<FString,FString>	TravelInfo;

	// Only valid in memory.
	FCollisionHashBase* Hash;
	class FMovingBrushTrackerBase* BrushTracker;
	AActor* FirstDeleted;
	struct FActorLink* NewlySpawned;
	UBOOL InTick, Ticked;
	INT iFirstDynamicActor, iFirstNetRelevantActor, NetTag;
	uint8 ZoneDist[64][64];

	INT NetTickCycles, NetDiffCycles, ActorTickCycles, AudioTickCycles, FindPathCycles, MoveCycles, NumMoves, NumReps, NumPV, GetRelevantCycles, NumRPC, SeePlayer, Spawning, Unused;
};


//
// UPrimitive, the base class of geometric entities capable of being
// rendered and collided with.
//
class UPrimitive : public UObject
{
public:
	// Variables.
	FBox BoundingBox;
	FSphere BoundingSphere;

	// UPrimitive collision interface.
	virtual int32 PointCheck
	(
		FCheckResult	&Result,
		AActor			*Owner,
		FVector			Location,
		FVector			Extent,
		uint32          ExtraNodeFlags
	)=0;
	virtual int32 LineCheck
	(
		FCheckResult	&Result,
		AActor			*Owner,
		FVector			End,
		FVector			Start,
		FVector			Extent,
		uint32          ExtraNodeFlags
	)=0;
	virtual FBox GetRenderBoundingBox( const AActor* Owner, UBOOL Exact )=0;
	virtual FSphere GetRenderBoundingSphere( const AActor* Owner, UBOOL Exact )=0;
	virtual FBox GetCollisionBoundingBox( const AActor* Owner ) const=0;
};

//
// Identifies a unique convex volume in the world.
//
struct FPointRegion
{
	class AZoneInfo* Zone;
	int32 iLeaf;
	uint8 ZoneNumber;
};

//
// Model objects are used for brushes and for the level itself.
//
enum {MAX_NODES  = 65536};
enum {MAX_POINTS = 128000};
class UModel : public UPrimitive
{
public:
	class UPolys*			Polys;
	TTransArray</*FBspNode*/int32>	Nodes;
	TTransArray</*FVert*/int32>      Verts;
	TTransArray<FVector>	Vectors;
	TTransArray<FVector>	Points;
	TTransArray</*FBspSurf*/int32>	Surfs;
	TArray</*FLightMapIndex*/int32>	LightMap;
	TArray<uint8>			LightBits;
	TArray<FBox>			Bounds;
	TArray<int32>				LeafHulls;
	TArray</*FLeaf*/int32>			Leaves;
	TArray<AActor*>			Lights;

	UBOOL					RootOutside;
	UBOOL					Linked;
	INT						MoverLink;
	INT						NumSharedSides;
	INT						NumZones;
//	FZoneProperties			Zones[FBspNode::MAX_ZONES];
};





class AActor : public UObject
{
public:
	BITFIELD bStatic : 1 GCC_PACK(4);
	BITFIELD bHidden : 1;
	BITFIELD bNoDelete : 1;
	BITFIELD bAnimFinished : 1;
	BITFIELD bAnimLoop : 1;
	BITFIELD bAnimNotify : 1;
	BITFIELD bAnimByOwner : 1;
	BITFIELD bDeleteMe : 1;
	BITFIELD bAssimilated : 1;
	BITFIELD bTicked : 1;
	BITFIELD bLightChanged : 1;
	BITFIELD bDynamicLight : 1;
	BITFIELD bTimerLoop : 1;
	BITFIELD bCanTeleport : 1;
	BITFIELD bOwnerNoSee : 1;
	BITFIELD bOnlyOwnerSee : 1;
	BITFIELD bIsMover : 1;
	BITFIELD bAlwaysRelevant : 1;
	BITFIELD bAlwaysTick : 1;
	BITFIELD bHighDetail : 1;
	BITFIELD bStasis : 1;
	BITFIELD bForceStasis : 1;
	BITFIELD bIsPawn : 1;
	BITFIELD bNetTemporary : 1;
	BITFIELD bNetOptional : 1;
	BITFIELD bReplicateInstigator : 1;
	BITFIELD bTrailerSameRotation : 1;
	BITFIELD bTrailerPrePivot : 1;
	BITFIELD bClientAnim : 1;
	BITFIELD bSimFall : 1;
	uint8 Physics GCC_PACK(4);
	uint8 Role;
	uint8 RemoteRole;
	INT NetTag;
	class AActor* Owner;
	FName InitialState;
	FName Group;
	float TimerRate;
	float TimerCounter;
	float LifeSpan;
	FName AnimSequence;
	float AnimFrame;
	float AnimRate;
	float TweenRate;
	class UAnimation* SkelAnim;
	float LODBias;
	class ALevelInfo* Level;
	class ULevel* XLevel;
	FName Tag;
	FName Event;
	class AActor* Target;
	class APawn* Instigator;
	class USound* AmbientSound;
	class AInventory* Inventory;
	class AActor* Base;
	FPointRegion Region;
	FName AttachTag;
	uint8 StandingCount;
	uint8 MiscNumber;
	uint8 Latentuint8;
	INT LatentInt;
	float Latentfloat;
	class AActor* LatentActor;
	class AActor* Touching[4];
	class AActor* Deleted;
	INT CollisionTag;
	INT LightingTag;
	INT OtherTag;
	INT ExtraTag;
	INT SpecialTag;
	FVector Location;
	FRotator Rotation;
	FVector OldLocation;
	FVector ColLocation;
	FVector Velocity;
	FVector Acceleration;
	float OddsOfAppearing;
	BITFIELD bHiddenEd : 1 GCC_PACK(4);
	BITFIELD bDirectional : 1;
	BITFIELD bSelected : 1;
	BITFIELD bMemorized : 1;
	BITFIELD bHighlighted : 1;
	BITFIELD bEdLocked : 1;
	BITFIELD bEdShouldSnap : 1;
	BITFIELD bEdSnap : 1;
	BITFIELD bTempEditor : 1;
	BITFIELD bDifficulty0 : 1;
	BITFIELD bDifficulty1 : 1;
	BITFIELD bDifficulty2 : 1;
	BITFIELD bDifficulty3 : 1;
	BITFIELD bSinglePlayer : 1;
	BITFIELD bNet : 1;
	BITFIELD bNetSpecial : 1;
	BITFIELD bScriptInitialized : 1;
	class AActor* HitActor GCC_PACK(4);
	uint8 DrawType;
	uint8 Style;
	class UTexture* Sprite;
	class UTexture* Texture;
	class UTexture* Skin;
	class UMesh* Mesh;
	class UModel* Brush;
	float DrawScale;
	FVector PrePivot;
	float ScaleGlow;
	float VisibilityRadius;
	float VisibilityHeight;
	uint8 AmbientGlow;
	uint8 Fatness;
	float SpriteProjForward;
	BITFIELD bUnlit : 1 GCC_PACK(4);
	BITFIELD bNoSmooth : 1;
	BITFIELD bParticles : 1;
	BITFIELD bRandomFrame : 1;
	BITFIELD bMeshEnviroMap : 1;
	BITFIELD bMeshCurvy : 1;
	BITFIELD bFilterByVolume : 1;
	BITFIELD bShadowCast : 1;
	BITFIELD bHurtEntry : 1;
	BITFIELD bGameRelevant : 1;
	BITFIELD bCarriedItem : 1;
	BITFIELD bForcePhysicsUpdate : 1;
	BITFIELD bIsSecretGoal : 1;
	BITFIELD bIsKillGoal : 1;
	BITFIELD bIsItemGoal : 1;
	BITFIELD bCollideWhenPlacing : 1;
	BITFIELD bTravel : 1;
	BITFIELD bMovable : 1;
	class UTexture* MultiSkins[8] GCC_PACK(4);
	uint8 SoundRadius;
	uint8 SoundVolume;
	uint8 SoundPitch;
	float TransientSoundVolume;
	float TransientSoundRadius;
	float CollisionRadius;
	float CollisionHeight;
	BITFIELD bCollideActors : 1 GCC_PACK(4);
	BITFIELD bCollideWorld : 1;
	BITFIELD bBlockActors : 1;
	BITFIELD bBlockPlayers : 1;
	BITFIELD bProjTarget : 1;
	uint8 LightType GCC_PACK(4);
	uint8 LightEffect;
	uint8 LightBrightness;
	uint8 LightHue;
	uint8 LightSaturation;
	uint8 LightRadius;
	uint8 LightPeriod;
	uint8 LightPhase;
	uint8 LightCone;
	uint8 VolumeBrightness;
	uint8 VolumeRadius;
	uint8 VolumeFog;
	BITFIELD bSpecialLit : 1 GCC_PACK(4);
	BITFIELD bActorShadows : 1;
	BITFIELD bCorona : 1;
	BITFIELD bLensFlare : 1;
	BITFIELD bBounce : 1;
	BITFIELD bFixedRotationDir : 1;
	BITFIELD bRotateToDesired : 1;
	BITFIELD bInterpolating : 1;
	BITFIELD bJustTeleported : 1;
	uint8 DodgeDir GCC_PACK(4);
	float Mass;
	float Buoyancy;
	FRotator RotationRate;
	FRotator DesiredRotation;
	float PhysAlpha;
	float PhysRate;
	class AActor* PendingTouch;
	float AnimLast;
	float AnimMinRate;
	float OldAnimRate;
	float SimAnim[4]; //FPlane SimAnim;
	float NetPriority;
	float NetUpdateFrequency;
	BITFIELD bNetInitial : 1 GCC_PACK(4);
	BITFIELD bNetOwner : 1;
	BITFIELD bNetRelevant : 1;
	BITFIELD bNetSee : 1;
	BITFIELD bNetHear : 1;
	BITFIELD bNetFeel : 1;
	BITFIELD bSimulatedPawn : 1;
	BITFIELD bDemoRecording : 1;
	BITFIELD bClientDemoRecording : 1;
	BITFIELD bClientDemoNetFunc : 1;
	BITFIELD bNotRelevantToOwner : 1;
	BITFIELD bRelevantIfOwnerIs : 1;
	BITFIELD bRelevantToTeam : 1;
	BITFIELD bSuperClassRelevancy : 1;
	BITFIELD bTearOff : 1;
	BITFIELD bNetDirty : 1;
	class UClass* RenderIteratorClass GCC_PACK(4);
	class URenderIterator* RenderInterface;

	// AActor interface.
//	class ULevel* GetLevel() const;
//	class APlayerPawn* GetPlayerPawn() const;
//	UBOOL IsPlayer() const;
//	FVector GetCylinderExtent() const { return FVector(CollisionRadius, CollisionRadius, CollisionHeight); }

	// AActor collision functions.
//	UPrimitive* GetPrimitive() const;
//	UBOOL IsOverlapping(const AActor *Other) const;

	// AActor general functions.
//	UBOOL IsBrush()       const;
//	UBOOL IsStaticBrush() const;
	int32 IsMovingBrush() const
	{
/*		static volatile char Debug[] = {"CACUS"}; //DEBUGGER HELPER
		while ( Debug[0] == 'C' )
		{}*/
		int32 result = (this->*IsMovingBrushFunc)();
		return result;
	}
//	FRotator GetViewRotation();
//	FBox GetVisibilityBox();


	// Special editor behavior
//	AActor* GetHitActor();


};
