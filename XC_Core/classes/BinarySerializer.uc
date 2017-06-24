//====================================================
// Binary Serializer
//
// Version 3 binary serializer, implemented in XC_Core
// release 7
//
// - Added generic text reading
// - Archives are automatically closed when the
// serializer is destroyed in garbage collection.
//
//====================================================
class BinarySerializer expands Object
	native;

//[UCC EXPORTHEADERS] directives, not yet supported
#exec _cpptext void Destroy(); 

var native const int Archive; //c++ Pointer
var native const bool bWrite;

// Serialization functions all modify the OUT parameters if file is in read mode
// These are used for quick type conversion and reading

native final function bool SerializeString( out string Text);
native final function bool SerializeInt( out int I);
native final function bool SerializeFloat( out float F);
native final function bool SerializeByte( out byte B);
native final function bool SerializeRotator( out rotator R);
native final function bool SerializeVector( out vector V);

//Raw ANSI format writing
native final function bool WriteText( string Text, optional bool bAppendEOL);

//Raw ANSI format reading, good for manual parsing
native final function bool ReadLine( out string Line, optional int MaxChars); //Auto seeks next line, line is chopped at max 2047 chars!


// Reads/Writes 4 bytes from an object at a certain unreal variable's address
// This can be used to set multiple booleans packed in the same 4 byte block
// Example:
// - var bool bVar1, bVar2, bVar3,...;
//Doing SerializeTo( something, 'bVar1', 4); will read and write all of the booleans in the block (up to 32)
//Do not use this for dynamic arrays and strings
// LimitSize can be used to limit the number of array members to serialize
native final function bool SerializeTo( Object O, name VariableName, optional int LimitSize);

native final function bool OpenFileRead( string FileName);
native final function bool OpenFileWrite( string FileName, optional bool bAppend);
native final function bool CloseFile();

//Return -1 if archive not open, i should instead crash the game
native final function int Position();
native final function int TotalSize();


