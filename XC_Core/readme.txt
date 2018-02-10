=========================================================
XC_Core - Base extension for native UT99 addons by Higor

Version 8

=============
Installation:
=============
XC_Core.u
XC_Core.int
XC_Core.dll (win32)
XC_Core.so (linux)
LZMA.dll (win32)
LZMA.so (linux)
>>>	~UnrealTournament\System\


=================================
Setting up LZMA channel upload:
(optional, unredirected servers)
=================================
~UnrealTournament.ini
>>>
[IpDrv.TcpNetDriver] or [XC_IpDrv.XC_TcpNetDriver]
AllowDownloads=True
...
DownloadManagers=IpDrv.HTTPDownload
DownloadManagers=XC_Core.XC_ChannelDownload
DownloadManagers=Engine.ChannelDownload

Then keep the .LZMA (or .UZ) files on the same directory as the uncompressed versions.


=============================
LZMA Compression commandlets:
=============================

You can LZMA compress using a XC_Core commandlet:
UCC LZMACompress ..\Maps\CTF-Coret.unr

You can LZMA decompress using 7zip, WinRar or:
UCC LZMADecompress ..\Maps\CTF-Coret.unr.lzma

Both commandlets support wildcards.


===================
Additional natives:
===================
See XC_CoreStatics class (Object subclass).


===================
UBinary serializer:
===================
Now merged into XC_Core, proves minimal binary file handling to UnrealScript.
Check classes BinarySerializer (Object) and BinaryTester (Actor) for usage guidelines.
For security measures file writer doesn't allow creating files outside of the game directory.


======
Notes:
======
This package is required to run all other XC Tools.


========================
c++ headers and linking:
========================
This package contains headers that allow the user to utilize XC_Core features in own native packages.
Just add ..\XC_Core\Inc to include settings and link to XC_Core.lib (or XC_Core.so in Linux)

Don't forget to define this macro somewhere in your code (or preprocessor):
#define XC_CORE_API DLL_IMPORT

