=========================================================
XC_Core - Base extension for native UT99 addons by Higor
Version 10
=========================================================


This package is required to run all other XC Tools.
See XC_CoreStatics class for information on new native functions.


====================
 UBinary serializer:

Now merged into XC_Core, provides minimal binary file handling to UnrealScript.
Check classes BinarySerializer (Object) and BinaryTester (Actor) for usage guidelines.
For security measures file writer doesn't allow creating files outside of the game directory.


=========================
 c++ headers and linking:

This package contains headers that allow the user to utilize XC_Core features in own native packages.
Just add ..\XC_Core\Inc to include settings and link to XC_Core.lib (or XC_Core.so in Linux)

Don't forget to define this macro somewhere in your code (or preprocessor):
#define XC_CORE_API DLL_IMPORT

