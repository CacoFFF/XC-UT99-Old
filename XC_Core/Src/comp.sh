rm ../../System/XC_Core.so
rm XC_LZMA.o
rm XC_Networking.o
rm XC_CoreScript.o
rm XC_Globals.o
rm XC_Generic.o
rm XC_Visuals.o
rm Devices.o

#You may need to put crti.o, crtn.o in this directory

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Core -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Core/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/ \
-o../../XC_Core/Src/XC_CoreScript.o XC_CoreScript.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Core -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Core/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/ \
-o../../XC_Core/Src/XC_Networking.o XC_Networking.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Core -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Core/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/ \
-o../../XC_Core/Src/XC_LZMA.o XC_LZMA.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Core -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Core/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/ \
-o../../XC_Core/Src/XC_Globals.o XC_Globals.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Core -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Core/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/ \
-o../../XC_Core/Src/XC_Generic.o XC_Generic.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Core -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Core/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/ \
-o../../XC_Core/Src/XC_Visuals.o XC_Visuals.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Core -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Core/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/ \
-o../../XC_Core/Src/Devices.o Devices.cpp

# COMPAT OBJECT
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Core -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Core/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/ \
-o../../XC_Core/Src/CacusLibCompat.o CacusLibCompat.cpp


# link with UT libs
gcc-2.95  -shared -o ../../System/XC_Core.so -Wl,-rpath,. \
-export-dynamic -Wl,-soname,XC_Core.so \
-Wl,--eh-frame-hdr \
-Wl,--traditional-format \
-Wl,-z,defs \
-lm -lc -ldl -lnsl -lpthread ./XC_CoreScript.o ./XC_Networking.o ./XC_LZMA.o ./XC_Globals.o ./XC_Generic.o ./XC_Visuals.o ./Devices.o ./CacusLibCompat.o \
../../System/Core.so ../../System/Engine.so 

strip --strip-all --discard-all ../../System/XC_Core.so
cp -f ../../System/XC_Core.so ../../../ut-server/System/XC_Core.so

# remove temporary files

