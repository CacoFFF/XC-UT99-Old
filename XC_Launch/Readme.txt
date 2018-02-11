Unreal Tournament launcher readme

- Render setup/recovery window removed.
- MainLoop uses QueryPerformanceCounter instead of RDTSC for timer measuring, there shouldn't be any need to setup CPUspeed or anything.
- Can be opened multiple times at the same time.
- Uses enhanced malloc and log interfaces.
- Log window internally caches messages to avoid opening/closing the log file when shown.
- When the program is named XC_Launch.exe both LOG and INI default to "UnrealTournament"
- Can specify fullscreen resolution by adding it to the command line (ex: ut.exe -1920x1080)


XC_Core interfaces:

== FMallocThreadedProxy:
Uses spinlocks to prevent multiple threads from using the game's allocator.
Implemented in XC_Launch without importing from XC_Core.dll

== FOutputDeviceFileXC:
Improved log output device for launchers and UCC apps.
Safe to log lines of any char length.
Uses Windows \r\n newline characters regardless of platform.
Adding -logflush to the app's command line will force flush after every line.
The log file can be opened in read-only mode while the app is still running.
If two apps attempt to use the same filename, another file with a '_2' appended to it will be used.
