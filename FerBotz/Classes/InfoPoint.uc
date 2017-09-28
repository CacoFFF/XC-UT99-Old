//===============================================================================
// InfoPoint.
// La clase base de los 'InfoPoints' usados por mis 'Botz'
// Estos consisten en varias cosas :
// Simular un error en la puntería mucho más humano,
// ##Uso futuro## Crear waypoints y SniperSpots desde un archivo de texto,
// Grabar localizaciones útiles para DM, que sirven para determinar si un a
// botz le gusta ir por algunos lugares, si teme atacar por algun lado y
// determinar puntos de camping cerca de las armas.
// Como ultimo uso, hacer picar discos, misiles y pedazos de metal en las paredes
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//===============================================================================
class InfoPoint expands Actor;
//	abstract;

struct JtJInfo
{
	var() bool JumpToJump;
	var() bool ForceBruteJump;
	var() bool ForceDodgeJump;
	var() bool ForceBootsJump;
	var() bool ForceTransloc;
};

struct SBotzInfo
{
	var() byte Team, CampTime;
	var() string BotSkin, Face, BotName;
	var() mesh BotMesh;
	var() byte Skill, Punteria, CampChance; //Skill from 0 to 70, divide by 10 then
	var() class<weapon> ArmaFavorita;
	var() class<ChallengeVoicePack> VoiceBot;
	var() class<PlayerPawn> SimulatedPP;
	var() bool RandomWeapon;
};

enum EPathType
{
	PT_Normal,
	PT_JumpOnly,
	PT_TranslocOnly,
	PT_TranslocJump
};

//====================
// XC_Core / XC_Engine
//====================
native(601) static final function Class<Object> GetParentClass( Class<Object> ObjClass );
native(3540) final iterator function PawnActors( class<Pawn> PawnClass, out pawn P, optional float Distance, optional vector VOrigin, optional bool bHasPRI, optional Pawn StartAt);
native(3541) final iterator function NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint P, optional float Distance, optional vector VOrigin, optional bool bVisible);
native(3542) final iterator function InventoryActors( class<Inventory> InvClass, out Inventory Inv, optional bool bSubclasses, optional Actor StartFrom); 
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );
native(3555) static final operator(22) Actor Or (Actor A, skip Actor B);
native(3555) static final operator(22) Object Or (Object A, skip Object B);
native(3570) static final function vector HNormal( vector A);
native(3571) static final function float HSize( vector A);


final function ServerOnlyMessage( coerce string ServerMessage)
{
	Local playerpawn P;

	ForEach AllActors (class'playerPawn', P)
		P.ClientMessage("Server InfoPoint:"@ServerMessage);

	Log("InfoPoint: "$ServerMessage);
}

defaultproperties
{
     bHidden=True
}
