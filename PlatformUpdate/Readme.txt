A short guide into PlatformUpdate headers.

These headers are experimental and their purpose is to build UT binaries on newer compilers.

=== Setting up your project.
Project guidelines:
- Platform must be defined as a preprocessor macro "PLATFORM=WindowsVC140"
- Add these include directories
[.]/PlatformUpdate/Core
[.]/PlatformUpdate/Engine
[.]/PlatformUpdate/Platform
[.]/CacusLib

If you need to build using a different compiler with new settings, create a new header
in PlatformUpdate/Platform with the same name as the new value of "PLATFORM=" using
and existing one as base then edit what needs to be edited to let the compiler work.


=== Discarding newer C++ runtimes on Visual C++.
Include the following header in ONE of your source files:
[.]/PlatformUpdate/OldCRT/API_MSC.h

This header contains pragmas that force the compiler to link to an old MSVCRT.LIB file.
The compiler will intrinsically add functions and symbols that will have to be defined
in API_MSC, unless MSVCRT.LIB is repacked with these new functions at a later date.

Additionally, you'll have to disable
- Enhanced Instruction Set (/arch:ia32)
- Security Check (/GS-)
