class XCPlayerSetupScrollClient extends UTPlayerSetupScrollClient;

function Created()
{
	ClientClass = class'XCPlayerSetupClient';
	FixedAreaClass = None;

	Super(UWindowScrollingDialogClient).Created();
}
