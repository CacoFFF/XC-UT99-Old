class XC_CoreTest expands Actor;

event PostBeginPlay()
{
	local float F[2], Time;
	local int CycleCounter;
	local Texture Textures;
	local int TextureCount;


	class'XC_CoreStatics'.static.TestClock();
	class'XC_CoreStatics'.static.TestCycles();
	Log("Iterating through all textures...");
	class'XC_CoreStatics'.static.Clock( F);
	ForEach class'XC_CoreStatics'.static.AllObjects( class'Texture', Textures)
		TextureCount++;
	Time = class'XC_CoreStatics'.static.UnClock( F);
	Log("Found"@TextureCount@"textures, time taken: "$Time);
	Log("Test finished at "$class'XC_CoreStatics'.static.AppSeconds() );
	Destroy();
}