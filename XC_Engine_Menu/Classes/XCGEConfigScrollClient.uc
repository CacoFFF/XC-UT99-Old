class XCGEConfigScrollClient expands UWindowScrollingDialogClient;

function Created()
{
	ClientClass = Class'XCGEConfigOptionsClient';
	Super.Created();
}

