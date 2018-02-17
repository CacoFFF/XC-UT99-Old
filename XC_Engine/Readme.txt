XC_Engine - XC_GameEngine extension for UT99 by Higor.


===========
Setting up:
===========
** REQUIRES AT LEAST XC_CORE VERSION 8
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

- Server
Moving Brush Tracker in Dedicated servers (movers block visibility checks), specific maps can be ignored.
Various exploits patched, see "Server exploits.txt" for more info.
New Relevancy loop code, see "Relevancy loop.txt" for more info.
Enhanced coop/SP games in online play, see "TravelManager.txt" for more info.
Ability to send maps marked as 'no download'.
LZMA autocompressor can be run on a separate thread as soon as a map is loaded.
(Experimental) Sliding player bug workaround by reordering the package order, putting textures last.

- Server / Player ** these are selectively disabled upon joining a server **
Runtime UnrealScript/Native function replacer plus existing premade replacements (bugfixes, optimizations).
Big collection of new native functions to use, check the UnrealScript source for documentation.
XC_Core natives have their numbered opcodes enabled for use without package dependancy.
Thread safe memory allocator (if not running XC_Launcher)

- Linux
Server/Client communication no longer borks strings with non-standard characters.
Added SIGSEGV and SIGIOT handlers, crash logs display the call history almost like windows UT.

- Editor:
Enhanced navigation network builder, see "XC_PathBuilder.txt" for more info.
New Unreal Editor addons added to the brush builder pane.

- Client / Player:
Built-in framerate limiter, see "Framerate limiter.txt" for more info.
Ingame cache converter, see "AutoCacheConverter.txt" for more info.
Prevents servers from using 'Open' and 'ClientTravel' commands to open local files on the client.
Clients no longer send options 'Game' and 'Mutator' in their login string.
In most cases of package mismatch when joining, clients will load/download from other sources instead of failing to connect.
More info displayed during file download: amount of files, data pending installation.


=================
XC_IpDrv
Enhanced Net Driver and file downloaders.
=================
Net Driver:
- ICMP unreachable exploit patched.
- Connection limit, kills dataless connections.

HTTP LZMA file downloader.
- (Experimental) Can connect to redirects via proxy.


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


===================
Exposed properties:
===================
Additional properties are now visible on certain native classes and their subclasses, these increase the potential functionality of servers and clients running mods coded to access them via GetPropertyText() or GET commands.
See "Relevancy loop.txt" for extra properties in Actor.
= CLASS -> CPP_PropertyName -> UScript_PropertyName (type) (flags)

- GameEngine		-> GLevel		-> Level   (Level)   (const, editconst)
- GameEngine		-> GEntry		-> Entry   (Level)   (const, editconst)
- DemoRecDriver		-> DemoFileName		-> DemoFileName   (string)   (const, editconst)
- LevelBase		-> NetDriver		-> NetDriver   (obj NetDriver)   (const, editconst)
- LevelBase		-> DemoRecDriver	-> DemoRecDriver   (obj NetDriver)   (const, editconst)
- LevelBase		-> Engine		-> Engine   (obj Engine)   (const, editconst)
- LevelBase		-> URL.Protocol		-> URL_Protocol   (string)   (const, editconst)
- LevelBase		-> URL.Host		-> URL_Host   (string)   (const, editconst)
- LevelBase		-> URL.Port		-> URL_Port   (int)   (const, editconst)
- LevelBase		-> URL.Map		-> URL_Map   (string)   (const, editconst)
- LevelBase		-> URL.Op		-> URL_Options   (array<string>)   (const, editconst)
- LevelBase		-> URL.Portal		-> URL_Portal   (string)   (const, editconst)
- LevelBase		-> Actors.Num()		-> ActorListSize   (int)   (const, editconst)
- Level			-> iFirstDynamicActor	-> iFirstDynamicActor   (int)   (const, editconst)
- Level			-> iFirstNetRelevantActor -> iFirstNetRelevantActor   (int)   (const, editconst)
- NetDriver		-> ClientConnections	-> ClientConnections   (array<obj NetConnection>)   (const, editconst)
- NetDriver		-> ServerConnection	-> ServerConnection   (obj NetConnection)   (const, editconst)

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