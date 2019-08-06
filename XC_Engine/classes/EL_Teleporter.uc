class EL_Teleporter expands EventLink;


function Update()
{
	local Teleporter T;
	
	// Is this Teleporter still relevant?
	T = Teleporter(Owner);
	if ( !class'EngineTeleportersHandler'.static.IsValidTeleporter(T) )
	{
		Destroy();
		return;
	}
	
	bRootEnabled = T.bEnabled;
	bLink = T.Tag != '';
}

function bool CanFireEvent( Actor Other)
{
	return Other.bCanTeleport;
}

function AnalyzedBy( EventLink Other)
{
	Assert( Owner != None);
	AnalyzeEvent( Owner.Event);
}


//Do not create or use generic AI marker
function CreateAIMarker();
function NavigationPoint DeferTo()
{
	return Teleporter(Owner);
}


//Detractor wants this EventLink to grab paths leading to its marked TargetPath and redirect them
//In this case, TargetPath is the other end of this teleporter.
//Here we'll be reassigning the R_Special reacspec that leads to the other end.
function DetractorUpdate( EventDetractorPath EDP)
{
	local Teleporter Destination;
	local ReachSpec R;
	local Actor End;
	local int rIdx, i;
	
	//Pre-requisites
	if ( EDP == None || Teleporter(Owner) == None )
		return;
	Destination = Teleporter(EDP.TargetPath);
	if ( (Destination == None) || !(string(Destination.Tag) ~= Teleporter(Owner).URL) )
		return;

	//Find R_Special ReachSpecs going from Owner -> Destination
	ForEach class'XC_CoreStatics'.static.ConnectedDests( Teleporter(Owner), End, rIdx, i)
		if ( End == Destination )
		{
			GetReachSpec( R, rIdx);
			if ( (R.ReachFlags & R_Special) != 0 )
			{
				R.End = EDP;
				SetReachSpec( R, rIdx, true);
			}
		}
	EDP.SetLocation( Destination.Location - vect(0,0,15));
}




defaultproperties
{
     bRoot=True
     bLink=True
     bLinkEnabled=True
}
