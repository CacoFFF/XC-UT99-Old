class XCOptionsClientWindow expands UMenuOptionsClientWindow;

function Created() 
{
	Super.Created();
	Pages.AddPage("XC_Engine", class'XCGEConfigScrollClient');
}
