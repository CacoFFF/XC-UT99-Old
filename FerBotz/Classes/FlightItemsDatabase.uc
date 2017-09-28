//=============================================================================
// FlightItemsDatabase.
//
// Identifying stuff that makes bots fly and adding the correct flight profile
// will be this object's task.
// The checks can be extremely slow so we have to do some caching and data
// selection so that we don't check against the full list.
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//=============================================================================

class FlightItemsDatabase expands BotzExtension;

const BFM = class'BotzFunctionManager';

var string CheckedP[128];
var int iCheckedP;

var class<Inventory> CheckedC[128];
var class<FlightProfileBase> FlightClass[128];
var int iCheckedC;

function Initialize( LevelInfo Level)
{
	local Inventory Inv;
	local int i;
	local Mutator M;
	
	PackageCheck( BFM.static.ByDelimiter( string(Level.Game.class), ".") );
	ForEach Level.AllActors (class'Inventory', Inv)
		PackageCheck( BFM.static.ByDelimiter( string(Inv.class), ".") );
	For ( M=Level.Game.BaseMutator ; M!=none ; M=M.NextMutator )
		PackageCheck( BFM.static.ByDelimiter( string(M.class), ".") );

//	For ( i=0 ; i<iCheckedP ; i++ )
//		Log("RELEVANT PACKAGE: "$CheckedP[i] );
}

function PackageCheck( string aPkg)
{
	local int i;

	if ( aPkg == "" )
		return;

	For ( i=0 ; i<iCheckedP ; i++ )
		if ( CheckedP[i] ~= aPkg )
			return;

	//Default jets
	if ( Left( aPkg, 3) ~= "Jet" )
	{
		if ( aPkg ~= "JetReplaceG" )
		{
			AddPackage( "JetReplaceG");
			AddItem( "JetReplaceG.GhandiJetLauncher", class'FP_JetG');
		}
	}
	else if ( Left( aPkg, 5) ~= "Siege" )
	{
		AddPackage( aPkg);
		AddItem( aPkg $ ".Jetpack" , class'FlightProfileBase' );
	}

}

function ItemAdded( Botz B, Inventory Inv)
{
	local int i;

	if ( Ammo(Inv) != none )
		return;

	While ( i<iCheckedC )
	{
		if ( Inv.Class == CheckedC[i] )
		{
			B.FlightProfiles[B.iFlight] = B.MasterEntity.RequestFlightProf( FlightClass[i] );
			B.FlightProfiles[B.iFlight].BotIndex = B.iFlight;
			B.FlightProfiles[B.iFlight].Item = Inv;
			B.iFlight++;
			return;
		}
		i++;
	}
}

final function AddPackage( string pkg)
{
	CheckedP[iCheckedP++] = pkg;
}

final function AddItem( string itemclass, class<FlightProfileBase> handlerclass)
{
	FlightClass[iCheckedC] = handlerclass;
	CheckedC[iCheckedC++] = class<Inventory>( DynamicLoadObject( itemclass,class'class') );
}

defaultproperties
{
	CheckedP(0)=Botpack
	CheckedP(1)=Unreali
	CheckedP(2)=UnrealShare
	iCheckedP=3
}