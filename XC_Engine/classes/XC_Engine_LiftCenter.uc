class XC_Engine_LiftCenter expands LiftCenter;

native(3541) final iterator function NavigationActors( class<NavigationPoint> NavClass, out NavigationPoint P, optional float Distance, optional vector VOrigin, optional bool bVisible);
native(3553) final iterator function DynamicActors( class<actor> BaseClass, out actor Actor, optional name MatchTag );

//Auto-connect
event PreBeginPlay()
{
	local Actor A;
	local LiftExit LE;
	local XC_Engine_Actor XCGEA;
	local vector LOffset, LPoint;
	local int i, Exits;
	local bool bSuccess;

	Super.PreBeginPlay();
	if ( bDeleteMe )
		return;

	XCGEA = XC_Engine_Actor(Owner);
	if ( XCGEA == None )
		ForEach DynamicActors (class'XC_Engine_Actor', XCGEA)
			break;
	if ( XCGEA != None )
	{
		A = Trace( LOffset, LPoint, Location - vect(0,0,78) );
		if ( Mover(A) != None )
		{
			//Give it a tag if necessary
			if ( A.Tag == 'Mover' || A.Tag == '' )
			{
				if ( !XCGEA.TaggedMover( A.Name) )
					A.Tag = A.Name;
				else
					A.SetPropertyText("Tag","XC_Fix_"$A.Name);
				LiftTag = A.Tag;
			}

			LiftTag = A.Tag;
			ForEach NavigationActors ( class'LiftExit', LE)
				if ( LE.LiftTag == LiftTag )
				{
					XCGEA.EzConnectNavigationPoints( Self, LE);
					Exits++;
				}
			
			if ( Exits < 2 )
			{
				LOffset	= Location - A.Location;
				For ( i=0 ; i<Mover(A).NumKeys ; i++ )
				{
					LPoint = Mover(A).BasePos + Mover(A).KeyPos[i] + LOffset;
					ForEach NavigationActors ( class'LiftExit', LE, 300, LPoint, true)
						if ( LE.LiftTag == '' || !XCGEA.TaggedMover(LE.LiftTag) )
						{
							LE.LiftTag = LiftTag;
							XCGEA.EzConnectNavigationPoints( Self, LE);
							Exits++;
						}
				}
			}
			bSuccess = true;
			XCGEA.LockToNavigationChain( Self, true);
		}
	}
	if ( !bSuccess )
		Warn( self @ "failed to find elevator");
	else if ( Exits < 2 )
		Warn( self @ "failed to connect to at least two LiftExit");
}

defaultproperties
{
    bGameRelevant=True
    bStatic=False
	bNoDelete=False
}