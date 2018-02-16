/* ============================================================================

GetWeapon recode experiment by Higor.

This contains a method that replaces the game's default GetWeapon UFunction
with a different implementation.

Said change is done in runtime by altering the 'script' opcodes of the already
compiled function.

In order to preserve version and platform compatibility, the whole new script
block was built piece by piece, emulating a precomiled function but adding
pointers found in runtime. Also most of the opcodes have commented information
to allow the reader to better understand what is being done by UnrealScript
parser in runtime.

Be adviced that changes of this nature persist map switches and will cause
positives from anticheat software unless reverted, which can be done by
restarting the game or by restoring the UFunction->Script array with a backup
taken in runtime.


>>>> Some observations have been made from the compiled code:
- Evaluating integers to 0 or 1 uses a single opcode, and saves up a data read
operation.
This means that doing ( A < 0 ) is less expensive than ( A <= -1 )

- Evaluating booleans to True/False is also done in predefined opcodes.

- Evaluating to 'None' also uses a single opcode (with no data reading).
If ( A == none ), don't do ( B == A ) to see if ( B == none ).
Stick with ( B == none ) all the time!.

- Typecasting one Object type (class) into another type is simply a safety step
that sets the reference to None if the typecasting fails (Weapon = Weapon(Inv))
It is kind of a wasted step if we already know what what we're typecasting is of
said type, but the compiler forces us to do said typecasting anyways.
It is entirely possible to do (Weapon = Inv) without typecasting if the compiled
code was manually written as done below or generated with a custom compiler.

- Calling functions is expensive, the function pointers aren't stored in code,
instead the name indices, meaning the functions have to be found everytime we
attempt to call them. The good side of that is that is less prone to crashes
if the code is supposed to call a non-existant function on a certain class,
be it for version mismatches or compilation tricks as seen in ZeroPing and
LCWeapons to support UTPure without adding package dependancy.

- For loops ( exp, cond, action ) compile the 'exp' expression like any other
code statement, and then adds an IF(cond) block with the remaining code inside.
The 'action' is added at the end of the IF block right before the Jump back to
the IF(cond) statement.
'Continue' statements will cause a Jump into 'action' which will then jump back
to IF(cond).

- While loop jumps follow the same conditions, only that there is no 'exp'
expression added before the IF(cond) block, and the 'action' block is empty.
Any 'Continue' statement will jump to the end of the block, and then jump back!

- Unfortunately For loops cannot be compiled without an 'exp' expression to
allow more c++ styled loops, but you can always add ANY expression, even if
it's not related to the loop to make up for it. Doing so is really good if we
need the common 'action' among all 'continue' statements.

- Every single byte opcode is a native function, be it implicit (<0x60),
composite ( 0x60 - 0x6F ) or an explicit native (>= 0x70 ).

- There are up to 4096 (0x1000) possible native opcodes stored in the GNatives
array, the unused ones always refer to a native function called DoNothing()

- Composite natives are the 'HighNatives' these take their opcode minus 0x60
and add it to the next opcode calling an explicit native like this:
(0x61 0x02) calls HighNative 0x61, which calls explicit native 0x0102.
Explicit native 0x0102 is ClassIsChildOf (opcode 258).

- Single byte explicit natives don't require a HighNative to be called, these
are the native functions with an opcode below 256.

- Native functions without an opcode are called via any Function Call opcode
Just provide the function name as argument as you would with any normal
UFunction.
Takes more steps to execute, which explains why certain native functions and
operators of intensive use indeed have their preset opcode.

============================================================================ */



inline void ParseLocalVariable( BYTE* Addr, UProperty* Other) //5 bytes
{
	*Addr++ = 0; //First opcode is a 00
	appMemcpy( Addr, &Other, 4); //Then pointer to property
}

inline void ParseInstanceVariable( BYTE* Addr, UProperty* Other) //5 bytes
{
	*Addr++ = 1; //First opcode is a 01
	appMemcpy( Addr, &Other, 4); //Then pointer to property
}

inline void ObjectConstant( BYTE* Addr, UObject* Other) //5 bytes
{
	*Addr++ = EX_ObjectConst; //First opcode is a 0x20
	appMemcpy( Addr, &Other, 4); //Then pointer to object
}

inline void SkipAhead( BYTE* Addr, _WORD Ahead) //3 bytes
{
	*Addr++ = 0x018; //EX_Skip
	appMemcpy( Addr, &Ahead, 2); //Bytes to skip
}

inline void JumpToIfNot( BYTE* Addr, _WORD JumpDest) //3 bytes
{
	*Addr++ = 0x07; //EX_JumpIfNot
	appMemcpy( Addr, &JumpDest, 2); //Where to jump (2 bytes)
}

inline void JumpTo( BYTE* Addr, _WORD JumpDest) //3 bytes
{
	*Addr++ = 0x06; //EX_Jump
	appMemcpy( Addr, &JumpDest, 2); //Where to jump (2 bytes)
}

inline void HighNative( BYTE* Addr, _WORD Native) //2 bytes, write a native opcode > 255 and it will be parsed
{
	BYTE Parts[3];
	appMemcpy( &Parts, &Native, 2);
	Parts[2] = Parts[0];	Parts[0] = Parts[1] | 0x60;		Parts[1] = Parts[2]; //Swap
	appMemcpy( Addr, &Parts, 2);
}

inline INT WriteINT( BYTE* Addr, INT Value)
{	appMemcpy( Addr, &Value, 4);	return 4;	}

inline void AddReturn( BYTE* Addr)	//2 bytes
{	*Addr++ = 0x04;	*Addr = 0x0B; /* EX_Return + EX_Nothing */	}

inline void _Generic_SingleContext( BYTE* Addr, BYTE VariableType, UProperty* Context, BYTE VarSize) //9 bytes, Prepares a context for a Subsequent object
{
	*Addr++ = 0x19;
	*Addr++ = VariableType; //0 is local, 1 is instanced, 2 is default
	appMemcpy( Addr, &Context, 4); //Then pointer to property
	Addr += 4;	*Addr++ = 5;	*Addr++ = 0;	*Addr++ = VarSize;
}

inline void _obj_SingleContext( BYTE* Addr, BYTE VariableType, UProperty* Context) //9 bytes, Prepares a context for a Subsequent object
{
	_Generic_SingleContext( Addr, VariableType, Context, 4);
}

inline void _str_SingleContext( BYTE* Addr, BYTE VariableType, UProperty* Context) //9 bytes, Prepares a context for a Subsequent string
{
	_Generic_SingleContext( Addr, VariableType, Context, 0);
}

inline void _byte_SingleContext( BYTE* Addr, BYTE VariableType, UProperty* Context) //9 bytes, Prepares a context for a Subsequent byte
{
	_Generic_SingleContext( Addr, VariableType, Context, 1);
}

inline void _vector_SingleContext( BYTE* Addr, BYTE VariableType, UProperty* Context) //9 bytes, Prepares a context for a Subsequent byte
{
	_Generic_SingleContext( Addr, VariableType, Context, 12);
}


//This version is for ClassIsChildOf( Context.Class, TestClass); //Testclass is Local
inline void _call_ClassIsChildOf( BYTE* Addr, BYTE ContextType, UProperty* Context, UProperty* Class, UProperty* TestClass) //22 bytes
{
	HighNative( Addr, 258);
	_obj_SingleContext( Addr+2, ContextType, Context);
	ParseInstanceVariable( Addr+11, Class); //Passing Context.Class as parameter TestClass
	ParseLocalVariable( Addr+16, TestClass);
	*(Addr+21) = 0x16; //EX_EndFunctionParms
}

inline INT StringConstant( BYTE* Addr, const char* StrC) //Returns the amount of bytes it took
{
	*Addr++ = EX_StringConst; //1 byte
	INT i=0;
	while ( *(StrC+i) != 0x00 ) //i bytes
	{
		*Addr++ = *(StrC+i);
		i++;
	}
	*Addr = 0x00; //Append final char, 1 byte
	return i + 2;
}


//So long, I finally deprecated you after perfecting the function replacement methods
/*
void UXC_GameEngine::ReplaceGetWeaponFunc( UBOOL bSet)
{
	guard(UXC_GameEngine::ReplaceGetWeaponFunc);

	UFunction* GetWeapon = FindBaseFunction( APlayerPawn::StaticClass(), TEXT("GetWeapon"));
	if ( !GetWeapon ) //Script not serialized?
		return;

	if ( OldGetWeapon.IsCleared() && (!bSet || !OldGetWeapon.Setup( &GetWeapon->Script )) )
		return;

	if ( !bSet )
	{
		OldGetWeapon.Restore( &GetWeapon->Script);
		if ( bEnableDebugLogs )
			debugf( NAME_XC_Engine, TEXT("Reverting GetWeapon hook") );
		return;
	}
	else if ( OldGetWeapon.MismatchSize(&GetWeapon->Script) )
		return;


	INT Found = 0;
	UProperty* NewWeaponClass = FindScriptVariable( GetWeapon, TEXT("NewWeaponClass"), &Found);
	UProperty* Inv = FindScriptVariable( GetWeapon, TEXT("Inv"), &Found);

	UProperty* Inventory = FindScriptVariable( AActor::StaticClass(), TEXT("Inventory"), &Found);
	UProperty* PendingWeapon = FindScriptVariable( APawn::StaticClass(), TEXT("PendingWeapon"), &Found);
	UProperty* Weapon = FindScriptVariable( APawn::StaticClass(), TEXT("Weapon"), &Found);
	UProperty* pClass = FindScriptVariable( UObject::StaticClass(), TEXT("Class"), &Found);
	UProperty* AmmoType = FindScriptVariable( AWeapon::StaticClass(), TEXT("AmmoType"), &Found);
	UProperty* AmmoAmount = FindScriptVariable( AAmmo::StaticClass(), TEXT("AmmoAmount"), &Found);
	UProperty* ItemName = FindScriptVariable( AInventory::StaticClass(), TEXT("ItemName"), &Found);
	UProperty* MessageNoAmmo = FindScriptVariable( AWeapon::StaticClass(), TEXT("MessageNoAmmo"), &Found);
	UClass* WeaponClass = AWeapon::StaticClass();

	FName Name_PutDown = FName( TEXT("PutDown"), FNAME_Find);
	FName Name_BringUp = FName( TEXT("BringUp"), FNAME_Find);

	if ( Found < 10 ) //10
		return;

	//REPLACE THIS CODE LATER
	UFunction* Func = GetWeapon;

	Func->Script.Empty();
	Func->Script.AddZeroed( 588); //New function is 588 bytes long


	//if ( (Inventory == None) || (NewWeaponClass == None) )
	//	return;
	JumpToIfNot( &Func->Script(0), 26); //IF() MACRO
		Func->Script(3) = 0x84;		//native(132) static final operator(32) bool  || ( bool A, skip bool B );
			Func->Script(4) = 0x72;		//native(114) static final operator(24) bool == ( Object A, Object B );
				ParseInstanceVariable( &Func->Script(5), Inventory); //Passing Inventory as parameter A
				Func->Script(10) = 0x2A;	//EX_NoObject, passing None as paramater B
			Func->Script(11) = 0x16;	//EX_EndFunctionParms
			Func->Script(12) = 0x18;	//EX_Skip
			Func->Script(13) = 0x09;	//Skip 9 bits?
			Func->Script(14) = 0x00;	//?????
			Func->Script(15) = 0x72;	//native(114) static final operator(24) bool == ( Object A, Object B );
				ParseLocalVariable( &Func->Script(16), NewWeaponClass); //Passing NewWeaponClass as parameter A
				Func->Script(21) = 0x2A;	//EX_NoObject, passing None as paramater B
			Func->Script(22) = 0x16;	//EX_EndFunctionParms
		Func->Script(23) = 0x16;	//EX_EndFunctionParms
	AddReturn( &Func->Script(24) );


	//Inv = Inventory;
	Func->Script(26) = 0x0F;	//EX_Let    (A = B)
	ParseLocalVariable( &Func->Script(27), Inv); //Passing Inv as parameter A
	ParseInstanceVariable( &Func->Script(32), Inventory); //Passing Inventory as parameter B


	//if ((Weapon != None) && ClassIsChildOf(Weapon.Class, NewWeaponClass) )
	//	Inv = Weapon.Inventory;
	JumpToIfNot( &Func->Script(37), 95); //IF() MACRO
		Func->Script(40) = 0x82;	//native(130) static final operator(30) bool  && ( bool A, skip bool B );
			Func->Script(41) = 0x77;	//native(119) static final operator(26) bool != ( Object A, Object B );
				ParseInstanceVariable( &Func->Script(42), Weapon); //Passing Weapon as parameter A
				Func->Script(47) = 0x2A;	//EX_NoObject, passing None as paramater B
			Func->Script(48) = 0x16;	//EX_EndFunctionParms
			Func->Script(49) = 0x18;	//EX_Skip
			Func->Script(50) = 0x17;	//Skip 23 bits?
			Func->Script(51) = 0x00;	//?????
			_call_ClassIsChildOf( &Func->Script(52), 1, Weapon, pClass, NewWeaponClass); //22 bytes
		Func->Script(74) = 0x16;	//EX_EndFunctionParms
	Func->Script(75) = 0x0F;	//EX_Let    (A = B)
	ParseLocalVariable( &Func->Script(76), Inv); //Passing Inv as parameter A
	_obj_SingleContext( &Func->Script(81), 1, Weapon);	//Passing Weapon as our context
	ParseInstanceVariable( &Func->Script(90), Inventory); //Passing Weapon.Inventory as parameter B


	//While ( Inv != none )
	//{
	//	if ( ClassIsChildOf(Inv.Class, NewWeaponClass) )
	//	{
	//		PendingWeapon = Weapon(Inv);
	//		if ( (PendingWeapon.AmmoType != none) && (PendingWeapon.AmmoType.AmmoAmount <= 0) )
	//		{
	//			ClientMessage( PendingWeapon.ItemName$PendingWeapon.MessageNoAmmo );
	//			PendingWeapon = none;
	//			Inv = Inv.Inventory;
	//			continue;
	//		}
	//		Goto SELECTPENDING;
	//	}
	//	Inv = Inv.Inventory;
	//}
	JumpToIfNot( &Func->Script(95), 290);
		Func->Script(98) = 0x77;	//native(119) static final operator(26) bool != ( Object A, Object B );
			ParseLocalVariable( &Func->Script(99), Inv);	//Passing Inv as parameter A
			Func->Script(104) = 0x2A;	//EX_NoObject, passing None as paramater B
		Func->Script(105) = 0x16;	//EX_EndFunctionParms
		JumpToIfNot( &Func->Script(106), 267);
			_call_ClassIsChildOf( &Func->Script(109), 0, Inv, pClass, NewWeaponClass); //22 bytes
			Func->Script(131) = 0x0F;	//EX_Let    (A = B)
			ParseInstanceVariable( &Func->Script(132), PendingWeapon); //Passing PendingWeapon as parameter A
			Func->Script(137) = 0x2E;	//EX_DynamicCast
			appMemcpy( &Func->Script(138), &WeaponClass , 4); //Casting into Weapon class
			ParseLocalVariable( &Func->Script(142), Inv); //Passing Weapon(Inv) as Parameter B
			JumpToIfNot( &Func->Script(147), 264);
				Func->Script(150) = 0x82;	//native(130) static final operator(30) bool  && ( bool A, skip bool B );
					Func->Script(151) = 0x77;	//native(119) static final operator(26) bool != ( Object A, Object B );
						_obj_SingleContext( &Func->Script(152), 1, PendingWeapon);	//Passing PendingWeapon as our context
						ParseInstanceVariable( &Func->Script(161), AmmoType); //Passing PendingWeapon.AmmoType as parameter A
						Func->Script(166) = 0x2A;	//EX_NoObject, passing None as paramater B
					Func->Script(167) = 0x16;	//EX_EndFunctionParms
					Func->Script(168) = 0x18;	//EX_Skip
					Func->Script(169) = 0x1B;	//skip 27 bits?
					Func->Script(170) = 0x00;	//?????
					Func->Script(171) = 0x98;	//native(152) static final operator(24) bool <= ( int A, int B );	
						Func->Script(172) = 0x19;	//EX_Context >>> DOUBLE CONTEXT, CARE
						_obj_SingleContext( &Func->Script(173), 1, PendingWeapon);
						ParseInstanceVariable( &Func->Script(182), AmmoType);
						Func->Script(187) = 0x05;	//Skip if context fails (byte 1) (Accessed none!)
						Func->Script(188) = 0x00;	//Skip if context fails (byte 2) (Accessed none!)
						Func->Script(189) = 0x04;	//Size of return value to ZERO if context fails (Accessed none!)
						ParseInstanceVariable( &Func->Script(190), AmmoAmount);
						Func->Script(195) = 0x25;	//EX_IntZero
					Func->Script(196) = 0x16;	//EX_EndFunctionParms
				Func->Script(197) = 0x16;	//EX_EndFunctionParms
				Func->Script(198) = 0x1B;	//EX_VirtualFunction
				WriteINT( &Func->Script(199), ENGINE_ClientMessage.GetIndex() );
					Func->Script(203) = 0x70;	//native(112) static final operator(40) string $  ( coerce string A, coerce string B );
						_str_SingleContext( &Func->Script(204), 1, PendingWeapon);
						ParseInstanceVariable( &Func->Script(213), ItemName);	//Passing PendingWeapon.ItemName as parameter A
						_str_SingleContext( &Func->Script(218), 1, PendingWeapon);
						ParseInstanceVariable( &Func->Script(227), MessageNoAmmo);	//Passing PendingWeapon.MessageNoAmmo as parameter A
					Func->Script(232) = 0x16;	//EX_EndFunctionParms
				Func->Script(233) = 0x16;	//EX_EndFunctionParms
				Func->Script(234) = 0x0F;	//EX_Let    (A = B)
				ParseInstanceVariable( &Func->Script(235), PendingWeapon);	//Passing PendingWeapon as parameter A
				Func->Script(240) = 0x2A;	//EX_NoObject, passing None as paramater B
				Func->Script(241) = 0x0F;	//EX_Let    (A = B)
				ParseLocalVariable( &Func->Script(242), Inv); //Passing Inv as Parameter A
				_obj_SingleContext( &Func->Script(247), 0, Inv);
				ParseInstanceVariable( &Func->Script(256), Inventory); //Passing Inv.Inventory as parameter B
				JumpTo( &Func->Script(261), 287); //Continue statement, jumps to end of WHILE block, right before the LOOP jump
			JumpTo( &Func->Script(264), 524); //Manual Goto
		Func->Script(267) = 0x0F;	//EX_Let    (A = B)
		ParseLocalVariable( &Func->Script(268), Inv); //Passing Inv as Parameter A
		_obj_SingleContext( &Func->Script(273), 0, Inv);
		ParseInstanceVariable( &Func->Script(282), Inventory); //Passing Inv.Inventory as parameter B
	JumpTo( &Func->Script(287), 95);


	//if ( !ClassIsChildOf(Weapon.Class, NewWeaponClass) ) //Our weapon is already of said type, cycle
	//	return;
	JumpToIfNot( &Func->Script(290), 319);
		Func->Script(293) = 0x81;	//native(129) static final preoperator  bool  !  ( bool A );
			_call_ClassIsChildOf( &Func->Script(294), 1, Weapon, pClass, NewWeaponClass); //22 bytes
		Func->Script(316) = 0x16;	//EX_EndFunctionParms
	AddReturn( &Func->Script(317) );


	//For ( Inv=Inventory ; Inv!=none ; Inv=Inv.Inventory )
	//{
	//	if ( Inv == Weapon )
	//		return;
	//	if ( ClassIsChildOf(Inv.Class, NewWeaponClass) )
	//	{
	//		PendingWeapon = Weapon(Inv);
	//		if ( (PendingWeapon.AmmoType != none) && (PendingWeapon.AmmoType.AmmoAmount <= 0) )
	//		{
	//			ClientMessage( PendingWeapon.ItemName$PendingWeapon.MessageNoAmmo );
	//			PendingWeapon = none;
	//			continue;
	//		}
	//		Goto SELECTPENDING;
	//	}
	//}
	//return;
	Func->Script(319) = 0x0F;	//EX_Let    (A = B)
	ParseLocalVariable( &Func->Script(320), Inv);
	ParseInstanceVariable( &Func->Script(325), Inventory);
	JumpToIfNot( &Func->Script(330), 522);
		Func->Script(333) = 0x77;	//native(119) static final operator(26) bool != ( Object A, Object B );
			ParseLocalVariable( &Func->Script(334), Inv);	//Passing Inv as parameter A
			Func->Script(339) = 0x2A;	//EX_NoObject, passing None as paramater B
		Func->Script(340) = 0x16;	//EX_EndFunctionParms
		JumpToIfNot( &Func->Script(341), 358);
			Func->Script(344) = 0x72;		//native(114) static final operator(24) bool == ( Object A, Object B );
				ParseLocalVariable( &Func->Script(345), Inv);
				ParseInstanceVariable( &Func->Script(350), Weapon);
			Func->Script(355) = 0x16;	//EX_EndFunctionParms
			AddReturn( &Func->Script(356) );
		JumpToIfNot( &Func->Script(358), 499);
			_call_ClassIsChildOf( &Func->Script(361), 0, Inv, pClass, NewWeaponClass);
			Func->Script(383) = 0x0F;	//EX_Let    (A = B)
			ParseInstanceVariable( &Func->Script(384), PendingWeapon); //Passing PendingWeapon as parameter A
			Func->Script(389) = 0x2E;	//EX_DynamicCast
			appMemcpy( &Func->Script(390), &WeaponClass , 4); //Casting into Weapon class
			ParseLocalVariable( &Func->Script(394), Inv); //Passing Weapon(Inv) as Parameter B
			JumpToIfNot( &Func->Script(399), 496 );
				Func->Script(402) = 0x82;	//native(130) static final operator(30) bool  && ( bool A, skip bool B );
					Func->Script(403) = 0x77;	//native(119) static final operator(26) bool != ( Object A, Object B );
						_obj_SingleContext( &Func->Script(404), 1, PendingWeapon);	//Passing PendingWeapon as our context
						ParseInstanceVariable( &Func->Script(413), AmmoType); //Passing PendingWeapon.AmmoType as parameter A
						Func->Script(418) = 0x2A;	//EX_NoObject, passing None as paramater B
					Func->Script(419) = 0x16;	//EX_EndFunctionParms
					Func->Script(420) = 0x18;	//EX_Skip
					Func->Script(421) = 0x1B;	//skip 27 bits?
					Func->Script(422) = 0x00;	//?????
					Func->Script(423) = 0x98;	//native(152) static final operator(24) bool <= ( int A, int B );	
						Func->Script(424) = 0x19;	//EX_Context >>> DOUBLE CONTEXT, CARE
						_obj_SingleContext( &Func->Script(425), 1, PendingWeapon);
						ParseInstanceVariable( &Func->Script(434), AmmoType);
						Func->Script(439) = 0x05;	//Skip if context fails (byte 1) (Accessed none!)
						Func->Script(440) = 0x00;	//Skip if context fails (byte 2) (Accessed none!)
						Func->Script(441) = 0x04;	//Size of return value to ZERO if context fails (Accessed none!)
						ParseInstanceVariable( &Func->Script(442), AmmoAmount);
						Func->Script(447) = 0x25;	//EX_IntZero
					Func->Script(448) = 0x16;	//EX_EndFunctionParms
				Func->Script(449) = 0x16;	//EX_EndFunctionParms
				Func->Script(450) = 0x1B;	//EX_VirtualFunction
				WriteINT( &Func->Script(451), ENGINE_ClientMessage.GetIndex() );
					Func->Script(455) = 0x70;	//native(112) static final operator(40) string $  ( coerce string A, coerce string B );
						_str_SingleContext( &Func->Script(456), 1, PendingWeapon);
						ParseInstanceVariable( &Func->Script(465), ItemName);	//Passing PendingWeapon.ItemName as parameter A
						_str_SingleContext( &Func->Script(470), 1, PendingWeapon);
						ParseInstanceVariable( &Func->Script(479), MessageNoAmmo);	//Passing PendingWeapon.MessageNoAmmo as parameter A
					Func->Script(484) = 0x16;	//EX_EndFunctionParms
				Func->Script(485) = 0x16;	//EX_EndFunctionParms
				Func->Script(486) = 0x0F;	//EX_Let    (A = B)
				ParseInstanceVariable( &Func->Script(487), PendingWeapon);	//Passing PendingWeapon as parameter A
				Func->Script(492) = 0x2A;	//EX_NoObject, passing None as paramater B
				JumpTo( &Func->Script(493) , 499);
			JumpTo( &Func->Script(496), 524); //Manual Goto
		Func->Script(499) = 0x0F;	//EX_Let    (A = B)
		ParseLocalVariable( &Func->Script(500), Inv); //Passing Inv as Parameter A
		_obj_SingleContext( &Func->Script(505), 0, Inv);
		ParseInstanceVariable( &Func->Script(514), Inventory); //Passing Inv.Inventory as parameter B
	JumpTo( &Func->Script(519), 330);
	AddReturn( &Func->Script(522) );

	//SELECTPENDING:
	//if ( Weapon != none )
	//	Weapon.PutDown();
	//else
	//{
	//	Weapon = PendingWeapon;
	//	PendingWeapon = none;
	//	Weapon.BringUp();
	//}
	JumpToIfNot( &Func->Script(524), 553);
		Func->Script(527) = 0x77;	//native(119) static final operator(26) bool != ( Object A, Object B );
			ParseInstanceVariable( &Func->Script(528), Weapon);
			Func->Script(533) = 0x2A;	//EX_NoObject
		Func->Script(534) = 0x16;	//EX_EndFunctionParms
		Func->Script(535) = 0x19;	//EX_Context
		ParseInstanceVariable( &Func->Script(536), Weapon);
		Func->Script(541) = 0x06;	//Extra byte, includes a virtual function call
		Func->Script(542) = 0x00;
		Func->Script(543) = 0x04;
		Func->Script(544) = 0x1B;	//EX_VirtualFunction
			WriteINT( &Func->Script(545), Name_PutDown.GetIndex() ); //Weapon.PutDown()
		Func->Script(549) = 0x16;	//EX_EndFunctionParms
		JumpTo( &Func->Script(550), 586);
	Func->Script(553) = 0x0F;	//EX_Let    (A = B)
	ParseInstanceVariable( &Func->Script(554), Weapon);
	ParseInstanceVariable( &Func->Script(559), PendingWeapon);
	Func->Script(564) = 0x0F;	//EX_Let    (A = B)
	ParseInstanceVariable( &Func->Script(565), PendingWeapon);
	Func->Script(570) = 0x2A;	//EX_NoObject
		Func->Script(571) = 0x19;	//EX_Context
		ParseInstanceVariable( &Func->Script(572), Weapon);
		Func->Script(577) = 0x06;	//Extra byte, includes a virtual function call
		Func->Script(578) = 0x00;
		Func->Script(579) = 0x00;
		Func->Script(580) = 0x1B;	//EX_VirtualFunction
			WriteINT( &Func->Script(581), Name_BringUp.GetIndex() ); //Weapon.BringUp()
		Func->Script(585) = 0x16;	//EX_EndFunctionParms
	AddReturn( &Func->Script(586) );
	
	if ( bEnableDebugLogs )
		debugf( NAME_XC_Engine, TEXT("GetWeapon hook success") );

	unguard;
}
*/