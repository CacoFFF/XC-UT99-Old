/*===========================================================================
    C++ class definitions exported from UnrealScript.
===========================================================================*/
#if _MSC_VER
#pragma pack (push,4)
#endif

#ifndef FERBOTZ_API
#define FERBOTZ_API DLL_IMPORT
#endif

#ifndef NAMES_ONLY
#define AUTOGENERATE_NAME(name) extern FERBOTZ_API FName FERBOTZ_##name;
#define AUTOGENERATE_FUNCTION(cls,idx,name)
#endif

AUTOGENERATE_NAME(ModifyFlags)
AUTOGENERATE_NAME(IsCandidateTo)
AUTOGENERATE_NAME(OtherIsCandidate)
AUTOGENERATE_NAME(AddPathHere)
AUTOGENERATE_NAME(FinishedPathing)

#ifndef NAMES_ONLY

enum ESecondaryActions
{
    SA_Hunting              =0,
    SA_None                 =1,
    SA_Sniping              =2,
    SA_Supporting           =3,
    SA_Covering             =4,
    SA_MAX                  =5,
};
enum EMainActionList
{
    MAL_None                =0,
    MAL_Attacking           =1,
    MAL_Defending           =2,
    MAL_Following           =3,
    MAL_Freelancing         =4,
    MAL_Holding             =5,
    MAL_CarryingFlag        =6,
    MAL_InitialStand        =7,
    MAL_MAX                 =8,
};
enum EAttackDistance
{
    AD_Cercana              =0,
    AD_Media                =1,
    AD_Larga                =2,
    AD_MAX                  =3,
};
#define UCONST_AngleFactor 182.044444444444444444444444444
#define UCONST_MaxTactical 5.0
#define UCONST_MinTactical 0.0
#define UCONST_MinAccuracy 5.0
#define UCONST_MaxAccuracy 0.0
#define UCONST_MaxSkill 7.0

enum EPathMode
{
    PM_None                 =0,
    PM_Normal               =1,
    PM_Forced               =2,
    PM_MAX                  =3,
};

struct ABotz_NavigBase_eventAddPathHere_Parms
{
    class ANavigationPoint* Start;
    class ANavigationPoint* End;
    BITFIELD bForce;
	BITFIELD bOneWay;
};
struct ABotz_NavigBase_eventOtherIsCandidate_Parms
{
    class ANavigationPoint* Nav;
    BYTE ReturnValue;
};
struct ABotz_NavigBase_eventIsCandidateTo_Parms
{
    class ABotz_NavigBase* Other;
    BYTE ReturnValue;
};
struct ABotz_NavigBase_eventModifyFlags_Parms
{
    class ANavigationPoint* Dest;
    INT CurFlags;
    INT ReturnValue;
};

class FERBOTZ_API ABotz_NavigBase : public ANavigationPoint
{
public:
    FLOAT MaxDistance;
    BITFIELD bPushSave:1 GCC_PACK(4);
    BITFIELD bOneWayInc:1;
    BITFIELD bOneWayOut:1;
    BITFIELD bFlying:1;
    BITFIELD bHighPath:1;
    BITFIELD bCustomFlags:1;
    BITFIELD bDirectConnect:1;
    BITFIELD bNeverPrune:1;
    BITFIELD bFinishedPathing:1;
    INT ReservePaths GCC_PACK(4);
    INT ReserveUpstreamPaths;
    FStringNoInit FriendlyName;
    class ABotz_PathLoader* MyLoader;
    DECLARE_FUNCTION(execFreeUpstreamSlot);
    DECLARE_FUNCTION(execFreePathSlot);
    DECLARE_FUNCTION(execClearAllPaths);
    DECLARE_FUNCTION(execIsConnectedTo);
    DECLARE_FUNCTION(execUnusedReachSpec);
    DECLARE_FUNCTION(execEditReachSpec);
    DECLARE_FUNCTION(execExistingPath);
    DECLARE_FUNCTION(execPathCandidates);
    DECLARE_FUNCTION(execCreateReachSpec);
    DECLARE_FUNCTION(execLockActor);
    DECLARE_FUNCTION(execCollideTrace);
	DECLARE_FUNCTION(execResetScriptRunaway);
	DECLARE_FUNCTION(execPruneReachSpec);
	DECLARE_FUNCTION(execMapRoutes);
	DECLARE_FUNCTION(execBuildRouteCache);
 
	void eventFinishedPathing()
    {
		if ( FERBOTZ_FinishedPathing.GetIndex() == NAME_None )
			FERBOTZ_FinishedPathing = FName("FinishedPathing", FNAME_Intrinsic);
        ProcessEvent(FindFunctionChecked(FERBOTZ_FinishedPathing),NULL);
    }
	
    void eventAddPathHere(class ANavigationPoint* Start, class ANavigationPoint* End, BITFIELD bForce, BITFIELD bOneWay=0)
    {
        ABotz_NavigBase_eventAddPathHere_Parms Parms;
        Parms.Start=Start;
        Parms.End=End;
        Parms.bForce=bForce;
		Parms.bOneWay=bOneWay;
		if ( FERBOTZ_AddPathHere.GetIndex() == NAME_None )
			FERBOTZ_AddPathHere = FName("AddPathHere", FNAME_Intrinsic);
        ProcessEvent(FindFunctionChecked(FERBOTZ_AddPathHere),&Parms);
    }
    BYTE eventOtherIsCandidate(class ANavigationPoint* Nav)
    {
        ABotz_NavigBase_eventOtherIsCandidate_Parms Parms;
        Parms.Nav=Nav;
        Parms.ReturnValue=0;
		if ( FERBOTZ_OtherIsCandidate.GetIndex() == NAME_None )
			FERBOTZ_OtherIsCandidate = FName("OtherIsCandidate", FNAME_Intrinsic);
        ProcessEvent(FindFunctionChecked(FERBOTZ_OtherIsCandidate),&Parms);
        return Parms.ReturnValue;
    }
    BYTE eventIsCandidateTo(class ABotz_NavigBase* Other)
    {
        ABotz_NavigBase_eventIsCandidateTo_Parms Parms;
        Parms.Other=Other;
        Parms.ReturnValue=0;
		if ( FERBOTZ_IsCandidateTo.GetIndex() == NAME_None )
			FERBOTZ_IsCandidateTo = FName("IsCandidateTo", FNAME_Intrinsic);
        ProcessEvent(FindFunctionChecked(FERBOTZ_IsCandidateTo),&Parms);
        return Parms.ReturnValue;
    }
    INT eventModifyFlags(class ANavigationPoint* Dest, INT CurFlags)
    {
        ABotz_NavigBase_eventModifyFlags_Parms Parms;
        Parms.Dest=Dest;
        Parms.CurFlags=CurFlags;
        Parms.ReturnValue=0;
		if ( FERBOTZ_ModifyFlags.GetIndex() == NAME_None )
			FERBOTZ_ModifyFlags = FName("ModifyFlags", FNAME_Intrinsic);
        ProcessEvent(FindFunctionChecked(FERBOTZ_ModifyFlags),&Parms);
        return Parms.ReturnValue;
    }
    DECLARE_CLASS(ABotz_NavigBase,ANavigationPoint,0,FerBotz)
    NO_DEFAULT_CONSTRUCTOR(ABotz_NavigBase)
};


#endif

AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execFreeUpstreamSlot);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execFreePathSlot);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execClearAllPaths);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execIsConnectedTo);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execUnusedReachSpec);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execEditReachSpec);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execExistingPath);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execPathCandidates);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execCreateReachSpec);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execLockActor);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execCollideTrace);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execResetScriptRunaway);
AUTOGENERATE_FUNCTION(ABotz_NavigBase,-1,execPruneReachSpec);


#ifndef NAMES_ONLY
#undef AUTOGENERATE_NAME
#undef AUTOGENERATE_FUNCTION
#endif NAMES_ONLY

#if _MSC_VER
#pragma pack (pop)
#endif
