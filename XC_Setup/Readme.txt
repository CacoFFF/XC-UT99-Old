=======================================
XC_Setup: XC tools installer commandlet
=======================================

The XC_Setup commandlet is a simple unrealscript commandlet that can be
used to easily activate or deactivate some of XC_Engine's components.

=============
Introduction:

As with all other commadlets, UCC is required to run this installer
By running UCC as follows we'll be able to get more info on how it works

Win32:
UCC.exe help xc_setup

Linux:
./ucc-bin help xc_setup

The helper shows us a brief description on how to use this commandlet
You must also know that the '-ini=inifile.ini' parameter is valid and
will alter the target ini file on which you'll be applying you changes.

======
Usage:

There are 3 modes:
[*] Status
[+] Add 
[-] Remove

When you append one of the valid keywords to one of these mode chars
the commandlet will execute the corresponding action associated to
said keyword, the keywords are:

engine
netdriver
editor

Every parameter except -LOG is processed in the specified order, this
means that we can do various operations on the same keyword.

Example: (inform of editor addons, then install)
"ucc xc_setup *editor +editor"
