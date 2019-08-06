class XC_Engine_Bot expands Bot
	abstract;


//Usage of GetPropertyText to add compatibility with non-BotReplicationInfo pri's
//This also allows minimal interaction with non-Bot pawns, FerBotz being the most notable example.
function SetOrders(name NewOrders, Pawn OrderGiver, optional bool bNoAck)
{
	local Pawn P;

	if ( PlayerReplicationInfo == none )
		return;
	
	if ( String(NewOrders) != PlayerReplicationInfo.GetPropertyText("RealOrders") )
	{ 
		if ( (IsInState('Roaming') && bCamping) || IsInState('Wandering') )
			GotoState('Roaming', 'PreBegin');
		else if ( !IsInState('Dying') )
			GotoState('Attacking');
	}

	bLeading = false;
	if ( NewOrders == 'Point' )
	{
		NewOrders = 'Attack';
		SupportingPlayer = PlayerPawn(OrderGiver);
	}
	else
		SupportingPlayer = None;

	bSniping = bSniping && (NewOrders == 'Defend');
	bStayFreelance = false;
	if ( !bNoAck && (OrderGiver != None) && (OrderGiver.PlayerReplicationInfo != none) && (PlayerReplicationInfo.VoiceType != none) )
		SendTeamMessage(OrderGiver.PlayerReplicationInfo, 'ACK', Rand(class<ChallengeVoicePack>(PlayerReplicationInfo.VoiceType).Default.NumAcks), 5);

	if ( BotReplicationInfo(PlayerReplicationInfo) != None )
	{
		BotReplicationInfo(PlayerReplicationInfo).SetRealOrderGiver(OrderGiver);
		BotReplicationInfo(PlayerReplicationInfo).RealOrders = NewOrders;
	}
	else
	{	//This fails if the map has a bad string (Deck16][ best example)
		PlayerReplicationInfo.SetPropertyText("RealOrderGiver",string(OrderGiver));
		if ( OrderGiver != none )
			PlayerReplicationInfo.SetPropertyText("RealOrderGiverPRI",string(OrderGiver.PlayerReplicationInfo));
		else
			PlayerReplicationInfo.SetPropertyText("RealOrderGiverPRI","None");
		PlayerReplicationInfo.SetPropertyText("RealOrders", String(NewOrders));
	}

	Aggressiveness = BaseAggressiveness;
	if ( Orders == 'Follow' )
		Aggressiveness -= 1;
	Orders = NewOrders;
	if ( !bNoAck && (HoldSpot(OrderObject) != None) )
	{
		OrderObject.Destroy();
		OrderObject = None;
	}
	if ( Orders == 'Hold' )
	{
		Aggressiveness += 1;
		if ( !bNoAck )
			OrderObject = OrderGiver.Spawn(class'HoldSpot');
	}
	else if ( Orders == 'Follow' )
	{
		Aggressiveness += 1;
		OrderObject = OrderGiver;
	}
	else if ( Orders == 'Defend' )
	{
		if ( Level.Game.IsA('TeamGamePlus') )
			OrderObject = TeamGamePlus(Level.Game).SetDefenseFor(self);
		else
			OrderObject = None;
		if ( OrderObject == None )
		{
			Orders = 'Freelance';
			if ( bVerbose )
				log(self$" defender couldn't find defense object");
		}
		else
			CampingRate = 1.0;
	}
	else if ( Orders == 'Attack' )
	{
		CampingRate = 0.0;
		// set bLeading if have supporters
		if ( Level.Game.bTeamGame )
		{
			ForEach PawnActors( class'Pawn', P, 0, Location, true) //bHasPRI set!
				if ( P.bIsPlayer && (P.PlayerReplicationInfo.Team == PlayerReplicationInfo.Team) )
					if ( (P.PlayerReplicationInfo.GetPropertyText("RealOrders") ~= "Follow") && (P.GetPropertyText("OrderObject") ~= String(self)) )
					{
						bLeading = true;
						break;
					}
		}
	}	
				
	PlayerReplicationInfo.SetPropertyText("OrderObject",String(OrderObject));
}

// Call Super.BaseChange() in all cases, don't shoot bDelaying movers
singular event BaseChange()
{
	local actor HitActor;
	local vector HitNormal, HitLocation;

	if ( Mover(Base) != None )
	{
		// handle shootable secret floors
		if ( Mover(Base).bDamageTriggered && !Mover(Base).bOpening && !Mover(Base).bDelaying && (MoveTarget != None) )
		{
			HitActor = Trace(HitLocation, HitNormal, MoveTarget.Location, Location, true);
			if ( HitActor == Base )
			{
				Target = Base;
				bShootSpecial = true;
				FireWeapon();
				bFire = 0;
				bAltFire = 0;
				Base.Trigger(Base, Self);
				bShootSpecial = false;
			}
		}
	}
	Super(Pawn).BaseChange();
}
