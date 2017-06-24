class BinaryTester expands Actor;


var bool bVar0, bVar1, bVar2, bVar3,
 bVar4, bVar5, bVar6,
 bVar7, bVar8, bVar9,
 bVar10, bVar11, bVar12,
 bVar13, bVar14, bVar15;

var byte Separator; //Because consecutive booleans are packed in the same 4byte group

var bool cVar0, cVar1, cVar2, cVar3,
 cVar4, cVar5, cVar6,
 cVar7, cVar8, cVar9,
 cVar10, cVar11, cVar12,
 cVar13, cVar14, cVar15;

var int WriteInt, ReadInt;
var float WriteFloat, ReadFloat;
var vector WriteVector, ReadVector;
var byte WriteByte, ReadByte;
var rotator WriteRotator, ReadRotator;
var string WriteString, ReadString;

event PostBeginPlay()
{
	local BinarySerializer BS;

	Log("TESTING THE BINARY SERALIZER!");
	WriteInt = Rand( MaxInt);
	WriteFloat = FRand();
	WriteVector = VRand();
	WriteRotator = Rotator(WriteVector);
	WriteByte = WriteInt & 0xFF;
	WriteString = string(WriteInt) $ string(WriteFloat) $ string(WriteVector) $ string(WriteRotator) $ string(WriteByte);

	bVar1 = true;
	bVar4 = true;
	bVar7 = true;
	bVar10 = true;
	bVar13 = true;

	//Create a serializer
	Log("Creating serializer...");
	BS = new class'BinarySerializer';

	//Write a file
	Log("Opening writer...");
	BS.OpenFileWrite( "BinaryTest.bin");	
	BS.SerializeTo( Self, 'bVar1');
	BS.SerializeInt( WriteInt);
	BS.SerializeFloat( WriteFloat);
	BS.SerializeVector( WriteVector);
	BS.SerializeRotator( WriteRotator);
	BS.SerializeByte( WriteByte);
	BS.SerializeString( WriteString);
	Log("Closing writer...");
	BS.CloseFile();

	//Read a file
	Log("Opening reader...");
	BS.OpenFileRead( "BinaryTest.bin");
	BS.SerializeTo( Self, 'cVar1');
	Assert( BS.Position() == 4 );
	BS.SerializeInt( ReadInt);
	Assert( BS.Position() == 8 );
	BS.SerializeFloat( ReadFloat);
	Assert( BS.Position() == 12 );
	BS.SerializeVector( ReadVector);
	Assert( BS.Position() == 24 );
	BS.SerializeRotator( ReadRotator);
	Assert( BS.Position() == 36 );
	BS.SerializeByte( ReadByte);
	Assert( BS.Position() == 37 );
	BS.SerializeString( ReadString);
	Assert( BS.Position() == BS.TotalSize() );
	Log("Closing reader...");
	BS.CloseFile();

	//Check
	Assert( WriteInt == ReadInt);
	Assert( WriteFloat == ReadFloat);
	Assert( WriteVector == ReadVector);
	Assert( WriteRotator == ReadRotator);
	Assert( WriteByte == ReadByte);
	Assert( WriteString == ReadString);
	Assert( cVar1);
	Assert( cVar4);
	Assert( cVar7);
	Assert( cVar10);
	Assert( cVar13);
	Assert( !cVar0 );

	Log("Test 1 concluded succesfully",'BinaryTester');
	
	Log("TESTING FORBIDDEN ACCESS!");
	Assert( !BS.OpenFileWrite("C:\Games\Test.txt") );
	Assert( !BS.OpenFileWrite("TC:\Games\Test.txt") );
	Assert( !BS.OpenFileWrite("..\..\Test.txt") );


	Log("Test 2 concluded succesfully",'BinaryTester');
	
	Log("TESTING ANSI TEXT FUNCTIONS",'BinaryTester');
	//Write a file
	Log("Opening writer...");
	BS.OpenFileWrite( "BinaryTest.txt");
	BS.WriteText(";Sample ini file", true);
	BS.WriteText("", true);
	BS.WriteText("TestOption=");
	BS.WriteText(WriteString, true);
	BS.WriteText("   ");
	Log("Closing writer...");
	BS.CloseFile();

	Log("Opening reader...");
	BS.OpenFileRead( "BinaryTest.txt");
	BS.ReadLine( ReadString, 1);
	Assert( ReadString == ";");
	BS.ReadLine( ReadString);
	Assert( ReadString == "Sample ini file");
	BS.ReadLine( ReadString);
	Assert( ReadString == "");
	BS.ReadLine( ReadString);
	Assert( ReadString == ("TestOption="$WriteString) );
	BS.ReadLine( ReadString);
	Assert( ReadString == "   ");
	Log("Closing reader...");
	BS.CloseFile();

	Log("Test 3 concluded succesfully",'BinaryTester');
	
	
	Destroy();
}
