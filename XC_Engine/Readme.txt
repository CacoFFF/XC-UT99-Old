XC_Engine - XC_GameEngine extension for UT99 by Higor.


===========
Setting up:
===========
** REQUIRES AT LEAST XC_CORE VERSION 9
Place XC_Engine files in your ~UT/System/ directory.

/** Auto-installer scripts

Run XC_Enable.bat/XC_Enable_nohome.sh scripts in order to auto-config XC_Engine stuff
The scripts will enable the engine, net driver and editor addons.

See "XC_Setup.txt" for more info.
**/

In case the above fails, or a different setup is needed, follow these steps.
The new GameEngine we want to load has to be specified in UnrealTournament.ini (or it's server equivalent) as follows.

[Engine.Engine]
;GameEngine=Engine.GameEngine
GameEngine=XC_Engine.XC_GameEngine
;NetworkDevice=IpDrv.TcpNetDriver
NetworkDevice=XC_IpDrv.XC_TcpNetDriver

Be adviced, when editing ServerPackages and ServerActors in a XC_Engine server, find the [XC_Engine.XC_GameEngine] entry!!!
Either remove it (and apply on GameEngine), or apply the changes on said (XC_GameEngine) entry instead.

Safe to use in v436-v451, and on ACE servers since most hacks are reverted during online sessions.
In v436 Linux, make sure you're using the Core.so build that exports "_9__Context.Env" symbol.
Just avoid AnthChecker servers until they have whitelisted this binary.


=================
Features:
=================

- Global
Version 451 GET and SET command functionality + overflow crashfix.
Makes several properties from native only classes visible to UnrealScript, player commands and edit windows (win32). Below table for more info.
Collision Grid replacing the old hash, loaded from CollisionGrid (.dll/.so)
Cleaner map switch by nulling out potentially dangerous actor references to the main level.
Lower memory usage and faster map cleanup on long games by recycling actor names.
Log file size reduction by grouping log spam and displaying how much log messages repeat.
UnrealScript patcher for servers and offline play, allows replacement of code in runtime.

- Server
Moving Brush Tracker in Dedicated servers (movers block visibility checks), specific maps can be ignored.
See "Server Exploits" for a list of patched exploits.
See "Enhanced Netcode" for changes in server netcode.
See "TravelManager" for info on coop server enhancements.
Ability to send maps marked as 'no download' (Unreal SP content for example).
Sliding player bug workaround for clients with S3TC textures.

- Linux
Server/Client communication no longer borks strings with non-standard characters.
Added SIGSEGV and SIGIOT handlers, crash logs display the call history almost like windows UT.

- Client / Player:
Ingame cache converter, see "AutoCacheConverter.txt" for more info.
Prevents servers from using 'Open' and 'ClientTravel' commands to open local files on the client.
Clients no longer send options 'Game' and 'Mutator' in their login string.
In most cases of package mismatch when joining, clients will load/download from other sources instead of failing to connect.
More info displayed during file download: amount of files, data pending installation.


====================
Other documentation:
====================
- LZMA
- Editor
- S3TC in Editor
- Paths Builder
- Raw Input
- Framerate limiter
- Object properties
- Self Dynamic Loading


================
Extra commands.
Check other documentation files for more commands.
================
- EditObject Name=Objectname Skip=skipcount
Client, Win32 only.
Brings up a property editor dialog of an object with a specified name.
Skip= is optional and can be used to bring up a newer objects with said name.

Example: "EditObject Name=MyLevel Skip=1" Brings up play level's XLevel properties.
Example: "EditObject Name=MyLevel" Brings up Entry level's XLevel properties.

- DumpObject Name=Objectname
Dumps object in question's memory block into a file (with the object's name), only dumps the first object with matching name.
If the object is a UFunction, then it will also save a file name FUNCTIONDATA.bin with the script code (serialized TArray<BYTE>).

- LogFields Name=classname
Logs all of the UnrealScript visible properties of the specified class, with property flags, offset, size and array count.
Boolean properties have their bitmask info logged instead of array size.

- LogClassSizes Outer=packagename(optional)
Prints in log a huge list of classes and their size in memory.
If the Outer=packagename parameter isn't used (or fails), it will print all classes's sizes.

- ToggleTimingFix - TimingFix
Toggles the timing fix on/off.
Timing fix is enabled by default and is saved in [XC_Engine.XC_GameEngine] config entry.

- ToggleDebugLogs - DebugLogs
Toggles additional logging, for developers.
Disabled by default, saved in [XC_Engine.XC_GameEngine] config entry.

- ToggleRelevancy - ToggleRelevant
Requires bUseLevelHook.
Toggles XC_Level relevancy loop on net servers, see "Relevancy loop.txt" for details.

- TimeFactor
Displays the Time Manager's current time scaler, if active.
Values other than 1 (or approximate) indicate that XC_Engine is the one responsible
for keeping your game running at normal speed.



====================================
Functions patched/hooked in runtime:
====================================
See XC_Engine_Actor and XC_Engine_UT99_Actor for a full list of script patches.

Additionally this hook still remains forced by internal code:
UWindowList.Sort		-> Super fast, doesn't crash practice session when map count exceeds ~4000

=================
Credits:
=================
I would like to thank my fellow betatesters
- Chamberly
- ~V~
- Nelsona
- SC]-[LONG_{HoF}
- $carface (and the legions of Siege apes)
- AnthRAX
- SicilianKill

And all of Cham's development server visitors for the help in bugfixing this.
And to the website owners where I downloaded very educational sample codes of Unreal Engine 2 and 3 (lol!)