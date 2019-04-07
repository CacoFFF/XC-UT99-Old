class XC_Engine_Pawn expands Pawn
	abstract;


native(3541) final iterator function NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint P, optional float Distance, optional vector VOrigin, optional bool bVisible);
native(3542) final iterator function InventoryActors( class<Inventory> InvClass, out Inventory Inv, optional bool bSubclasses, optional Actor StartFrom); 
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );
native(3555) static final operator(22) Actor | (Actor A, skip Actor B);


//==============
//Faster loop, don't increase iteration count
function Inventory FindInventoryType_Fast( class<Inventory> DesiredClass ) //Compiler hack, originally class<Object>
{
	local Inventory Inv;
	if ( ClassIsChildOf( DesiredClass, class'Inventory') ) //Here we do check that it's a class<Inventory> being passed
		ForEach InventoryActors( DesiredClass, Inv) //Native class check occurs here, so Inv matches what we're looking for
			return Inv;
}


//==============
//Single trace mode, prevents dangerous recursions
function Actor TraceShot_Safe( out vector HitLocation, out vector HitNormal, vector EndTrace, vector StartTrace)
{
	local Actor A, Other;
	
	ForEach TraceActors( class'Actor', A, HitLocation, HitNormal, EndTrace, StartTrace)
	{
		if ( Pawn(A) != None )
		{
			if ( (A != self) && Pawn(A).AdjustHitLocation( HitLocation, EndTrace - StartTrace) )
				Other = A;
		}
		else if ( (A == Level) || (Mover(A) != None) || A.bProjTarget || (A.bBlockPlayers && A.bBlockActors) )
			Other = A;

		if ( Other != None )
			break;
	}
	return Other;
}


//==============
// Route mapper version of FindPathToward
//native(517) final function Actor FindPathToward(actor anActor, optional bool bSinglePath, optional bool bClearPaths);
final function Actor FindPathToward_Org(actor anActor, optional bool bSinglePath, optional bool bClearPaths);
function Actor FindPathToward_RouteMapper( Actor anActor, optional bool bSinglePath, optional bool bClearPaths)
{
	local Actor Found;
	local XC_Engine_Actor Caller;
	local NavigationPoint EndPoint;
	
	Found = FindPathToward_Org( anActor);
	if ( Found == None )
	{
		ForEach DynamicActors( class'XC_Engine_Actor', Caller)
			if ( Caller.class == class'XC_Engine_Actor' )
				break;
		if ( Caller != None )
		{
			Caller.Target = anActor;
			EndPoint = Caller.MapRoutes_FPTW( self,,'FindPathToward_Event');
			if ( EndPoint != None )
			{
				log( EndPoint);
				Found = class'XC_CoreStatics'.static.BuildRouteCache( EndPoint, RouteCache, self);
			}
		}
	}
	return Found;
}