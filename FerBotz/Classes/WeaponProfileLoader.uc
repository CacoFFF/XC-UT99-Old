//==================================================================================
// WeaponProfileLoader
// Load extra weapon profiles here using INT definitions 
//
//
// For testing purposes, do not modify or redistribute
// Have suggestions? Contact me.
// caco_fff@hotmail.com - Higor at UT99.org
//==================================================================================
class WeaponProfileLoader expands InfoPoint;

var MasterGasterFer MasterEntity;
var BotzMutator BotzMutator;

event PostBeginPlay()
{
	SetTimer(1.2, false);
}

event Timer()
{
	local PlayerStart P;
	local string testStr, testDesc, sWeap;
	local class<BotzWeaponProfile> pClass;
	local class<Weapon> wClass;
	local BotzWeaponProfile pNew;
	local int j;

	BotzMutator = MasterEntity.TheMutator;

	ForEach AllActors (class'PlayerStart', P)
		break;

	GetNextIntDesc("FerBotz.BotzWeaponProfile",0,testStr,testDesc);

	While( testStr != "" )
	{
		pClass = class<BotzWeaponProfile>( DynamicLoadObject(testStr,class'class') );
		if ( pClass != none )
		{
			wClass = class<Weapon>( DynamicLoadObject(ParseWeapon(testDesc),class'class',true) );
			if ( wClass != none )
			{
				pNew = new(MasterEntity) pClass;
				//DO POST PROPERTY TREATMENT IN THE FUTURE
				MasterEntity.WProfiles[MasterEntity.WProfileCount] = pNew;
				MasterEntity.WProfiles[MasterEntity.WProfileCount].WeaponClass = wClass;
				MasterEntity.WProfiles[MasterEntity.WProfileCount++].PostInit();
			}
		}

		GetNextIntDesc("FerBotz.BotzWeaponProfile",++j,testStr,testDesc);
	}
	Destroy();
}

function string ParseWeapon( out string aStr)
{
	local int iBloq, iLen;
	local string tmpStr, otherStr;

	LOOP_AGAIN:
	iLen = InStr(aStr,",");
	if ( iLen < 0 )
	{
		if ( Caps(Left(aStr,7)) == "WEAPON=" )
		{
			tmpStr = Mid(aStr,7);
			aStr = otherStr;
			return tmpStr;
		}
		return "";
	}

	tmpStr = Left(aStr,iLen);
	if ( Caps(Left(tmpStr,7)) == "WEAPON=" )
	{
		aStr = Mid(aStr, iLen+1);
		if ( aStr != "" )
			aStr = otherStr $ "," $ aStr;
		else
			aStr = otherStr;
		return Mid(tmpStr,7);
	}

	if ( otherStr == "" )
		otherStr = tmpStr;
	else
		otherStr = otherStr $ "," $ tmpStr;
	aStr = Mid(aStr, iLen+1);
	Goto LOOP_AGAIN;
}

defaultproperties
{
	bGameRelevant=True
}