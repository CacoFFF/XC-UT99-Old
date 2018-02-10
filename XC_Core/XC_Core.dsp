# Microsoft Developer Studio Project File - Name="XC_Core" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Dynamic-Link Library" 0x0102

CFG=XC_Core - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "XC_Core.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "XC_Core.mak" CFG="XC_Core - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "XC_Core - Win32 Release" (based on "Win32 (x86) Dynamic-Link Library")
!MESSAGE "XC_Core - Win32 Debug" (based on "Win32 (x86) Dynamic-Link Library")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""$/Unreal/XC_Core", CUDBAAAA"
# PROP Scc_LocalPath "."
CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "XC_Core - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release"
# PROP Intermediate_Dir "Release"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /MT /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /D "_USRDLL" /D "XC_CORE_EXPORTS" /YX /FD /c
# ADD CPP /nologo /Zp4 /MD /W4 /WX /vd0 /GX /O2 /I "..\Core\Inc" /I "..\Engine\Inc" /I ".\Inc" /I ".\Inc\win32lzma" /D "NDEBUG" /D ThisPackage=XC_Core /D "WIN32" /D "_WINDOWS" /D "UNICODE" /D "_UNICODE" /D _WIN32_WINNT=0x0501 /FR /FD /c
# SUBTRACT CPP /YX
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /dll /machine:I386
# ADD LINK32 ..\Core\Lib\Core.lib ..\Engine\Lib\Engine.lib /nologo /dll /incremental:yes /machine:I386 /out:"..\System\XC_Core.dll"

!ELSEIF  "$(CFG)" == "XC_Core - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "XC_Core___Win32_Debug"
# PROP BASE Intermediate_Dir "XC_Core___Win32_Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "XC_Core___Win32_Debug"
# PROP Intermediate_Dir "XC_Core___Win32_Debug"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /MTd /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /D "_USRDLL" /D "XC_CORE_EXPORTS" /YX /FD /GZ /c
# ADD CPP /nologo /Zp4 /MDd /W4 /WX /vd0 /GX /Zi /Od /I "..\Core\Inc" /I "..\Engine\Inc" /I "Inc" /D "_DEBUG" /D ThisPackage=XC_Core /D "WIN32" /D "_WINDOWS" /D "UNICODE" /D "_UNICODE" /FD /GZ /c
# SUBTRACT CPP /YX
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /dll /debug /machine:I386 /pdbtype:sept
# ADD LINK32 ..\Core\Lib\Core.lib ..\Engine\Lib\Engine.lib /nologo /dll /debug /machine:I386 /out:"..\System\XC_Core.dll" /pdbtype:sept

!ENDIF 

# Begin Target

# Name "XC_Core - Win32 Release"
# Name "XC_Core - Win32 Debug"
# Begin Group "Header"

# PROP Default_Filter "h"
# Begin Source File

SOURCE=.\Inc\Devices.h
# End Source File
# Begin Source File

SOURCE=.\Inc\XC_Core.h
# End Source File
# Begin Source File

SOURCE=.\Inc\XC_CoreGlobals.h
# End Source File
# Begin Source File

SOURCE=.\Inc\XC_Networking.h
# End Source File
# End Group
# Begin Source File

SOURCE=.\Src\Devices.cpp
# End Source File
# Begin Source File

SOURCE=.\Src\XC_CoreScript.cpp
# End Source File
# Begin Source File

SOURCE=.\Src\XC_Generic.cpp
# End Source File
# Begin Source File

SOURCE=.\Src\XC_Globals.cpp
# End Source File
# Begin Source File

SOURCE=.\Src\XC_LZMA.cpp
# End Source File
# Begin Source File

SOURCE=.\Src\XC_Networking.cpp
# End Source File
# Begin Source File

SOURCE=.\Src\XC_Visuals.cpp
# End Source File
# End Target
# End Project
