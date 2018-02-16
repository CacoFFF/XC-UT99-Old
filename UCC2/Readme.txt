UCC2 rebuilt by Higor
(build 3)

This is a small UCC modification that uses enhanced malloc and log interfaces.

XC_Core interfaces:

== FMallocThreadedProxy:
Uses spinlocks to prevent multiple threads from using the game's allocator.

== FOutputDeviceFileXC:
Improved log output device for launchers and UCC apps.
Safe to log lines of any char length.
Uses Windows \r\n newline characters regardless of platform.
Adding -logflush to the app's command line will force flush after every line.
The log file can be opened in read-only mode while the app is still running.
If two apps attempt to use the same filename, another file with a '_2' appended to it will be used.



You may rename this UCC.exe and run it without replacing the original UCC.
Source code included in package, taken from UT Public v432 headers.