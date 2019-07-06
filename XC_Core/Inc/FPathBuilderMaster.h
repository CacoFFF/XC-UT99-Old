/*=============================================================================
	FPathBuilderMaster.h
	Author: Fernando Velázquez

	Unreal Editor addon for path network generation.
	Can also generate paths inside the game (single Navigation Point)
=============================================================================*/

#ifndef INC_PATHBUILDER
#define INC_PATHBUILDER

class ENGINE_API FPathBuilder
{
	friend class FPathBuilderMaster;

public:
	ULevel*                  Level;
	APawn*                   Scout;

private:
	void getScout();
	int32 findScoutStart(FVector start);
};


class XC_CORE_API FPathBuilderMaster : public FPathBuilder
{
public:
	float                    GoodDistance; //Up to 2x during lookup
	float                    GoodHeight;
	float                    GoodRadius;
	float                    GoodJumpZ;
	float                    GoodGroundSpeed;
	int32                    Aerial;
	UClass*                  InventorySpotClass;
	UClass*                  WarpZoneMarkerClass;
	int32                    TotalCandidates;
	FString                  BuildResult;

	FPathBuilderMaster();
	void RebuildPaths();

	void Setup();
	void AutoDefine( ANavigationPoint* NewPoint, AActor* AdjustTo=0);

private:
	void DefinePaths();
	void UndefinePaths();

	void AddMarkers();
	void DefineSpecials();
	void BuildCandidatesLists();
	void ProcessCandidatesLists();

	void HandleInventory( AInventory* Inv);
	void HandleWarpZone( AWarpZoneInfo* Info);
	void AdjustToActor( ANavigationPoint* N, AActor* Actor);

	void DefineFor( ANavigationPoint* A, ANavigationPoint* B);
	FReachSpec CreateSpec( ANavigationPoint* Start, ANavigationPoint* End);
	int AttachReachSpec( const FReachSpec& Spec, int32 bPrune=0);

	void GetScout();
	int FindStart( FVector V);
};

#endif