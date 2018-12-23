class XC_EngineStatics expands XC_CoreStatics
	abstract;
	
//API
struct SGTSC //Simple global time stamp counter
{
	var int Counter;
	var float TimeStamp;
};
struct SPTSB //Simple player time stamp blocker
{
	var bool bDisable;
	var int PlayerID;
	var float TimeStamp;
};
struct DPA //Dynamic player accumulator
{
	var float Accumulated;
	var int PlayerID;
};

//Status
var SPTSB Ip2C_Status[4];
var float Mutate_TimeStamp;
var array<DPA> Mutate_Status;

native(640) static final function int Array_Length_DPA( out array<DPA> Ar, optional int SetSize);
native(641) static final function bool Array_Insert_DPA( out array<DPA> Ar, int Offset, optional int Count );
native(642) static final function bool Array_Remove_DPA( out array<DPA> Ar, int Offset, optional int Count );


static final function bool ResetAll()
{
	default.Mutate_TimeStamp = 0;
	Array_Length_DPA( default.Mutate_Status, 0);
}


//************************
// 

//One command per second, per player
/*static final function bool Allow_Ip2C( PlayerPawn Sender)
{
	local int i;
	if ( Sender == None || Sender.PlayerReplicationInfo == None || Sender.Level == None )
		return true;
	For ( i=0 ; i<4 ; i++ )
		if ( default.Ip2C_Status[i].bDisable )	//Cleanup old disabled entries
		{
			default.Ip2C_Status[i].bDisable = (Square(Sender.Level.TimeSeconds-default.Ip2C_Status[i].TimeStamp) <= Sender.Level.TimeDilation); 
			if ( default.Ip2C_Status[i].bDisable && (default.Ip2C_Status[i].PlayerID == Sender.PlayerReplicationInfo.PlayerID) )
				return false;
		}
	For ( i=0 ; i<4 ; i++ )
		if ( !default.Ip2C_Status[i].bDisable ) //Found clean entry
		{
			default.Ip2C_Status[i].bDisable = true;
			default.Ip2C_Status[i].PlayerID = Sender.PlayerReplicationInfo.PlayerID;
			default.Ip2C_Status[i].TimeStamp = Sender.Level.TimeSeconds;
			return true;
		}
	//Ip2C being spammed, deny
	return false;
}*/


//*********************
// Mutate anti-spam fix
static final function bool Allow_Mutate( PlayerPawn Sender)
{
	local int i, iMax;
	local float TimeStampDiff;
	
	//Compute time stamps
	TimeStampDiff = (Sender.Level.TimeSeconds - default.Mutate_TimeStamp) / Sender.Level.TimeDilation;
	default.Mutate_TimeStamp = Sender.Level.TimeSeconds;
	if (TimeStampDiff >= 1)	iMax = Array_Length_DPA( default.Mutate_Status, 0);
	else					iMax = Array_Length_DPA( default.Mutate_Status);
	
	//Compute new accumulated values and process player if found
	For ( i=iMax-1 ; i>=0 ; i-- )
		if ( ((default.Mutate_Status[i].Accumulated -= TimeStampDiff) < 0) && Array_Remove_DPA( default.Mutate_Status, i) )
			iMax--;
	//Accumulate 0.5 for caller
	For ( i=0 ; i<iMax ; i++ )		
		if ( default.Mutate_Status[i].PlayerID == Sender.PlayerReplicationInfo.PlayerID )
		{
			if ( default.Mutate_Status[i].Accumulated >= 1 )
				return false;
			default.Mutate_Status[i].Accumulated += 0.5;
			return true;
		}
	Array_Insert_DPA( default.Mutate_Status, 0);
	default.Mutate_Status[0].PlayerID = Sender.PlayerReplicationInfo.PlayerID;
	default.Mutate_Status[0].Accumulated = 0.5;
	return true;
}
