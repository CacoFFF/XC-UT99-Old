class EL_BlockedPath expands EL_SpecialPath;

var EventLink Unlocker;

native(3538) final function NavigationPoint MapRoutes_ELBP( Pawn Seeker, NavigationPoint StartAnchor, optional name RouteMapperEvent);


function Update()
{
	//Do not update at level startup
	if ( Level.bStartup )
	{
		SetTimer( FRand(), false);
		return;
	}

	if ( (BlockedPath(Owner) == None) || (BlockedPath(Owner).ExtraCost == 0) )
	{
		Destroy();
		return;
	}
	
	DestroyAIMarker();
	Unlocker = GetEnabledRoot();
	DefineAttractor();
	SetTimer( 20 + FRand() * 30, false);
}


function DefineAttractor()
{
	local int rIdx, i;
	local Actor End;
	local int Lowest;
	local FV_Scout Scout;
	local NavigationPoint NEnd;
	
	if ( Unlocker != None )
	{
		if ( Unlocker.DeferTo() == None )
		{
			Unlocker.bDestroyMarker = true;
			Unlocker.CreateAIMarker();
		}

		if ( (Unlocker.DeferTo() != None) && (Unlocker.DeferTo().Paths[15] == -1) )
		{
			Scout = Spawn( class'FV_Scout');
			if ( Scout == None )
				return;
			MapRoutes_ELBP( Scout, Unlocker.DeferTo());
			Scout.Destroy();
		
			//Not ready
			Lowest = LowestReachableWeight( BlockedPath(Owner));
			if ( Lowest >= 10000000 )
				return;


			AIMarker = Spawn( class'SimpleObjectiveAttractor', self, 'SimpleObjectiveAttractor',
				Unlocker.DeferTo().Location + vect(0,0,10) + Normal(Unlocker.Owner.Location - Unlocker.DeferTo().Location) * 5 );
			SimpleObjectiveAttractor(AIMarker).AttractTo = Unlocker.Owner;
			LockToNavigationChain( AIMarker, true);
			SpecialConnectNavigationPoints( Unlocker.DeferTo(), AIMarker, 1, R_SPECIAL | R_PLAYERONLY);
			ForEach class'XC_CoreStatics'.static.ConnectedDests( BlockedPath(Owner), End, rIdx, i)
			{
				NEnd = NavigationPoint(End);
				// Consider this as potential link
				if ( (NEnd != None) && (GetWeight(NEnd) >= Lowest + 5000) )
					SpecialConnectNavigationPoints( AIMarker, NEnd, Lowest + 500, R_SPECIAL | R_PLAYERONLY);
			}
		}
	}
}

