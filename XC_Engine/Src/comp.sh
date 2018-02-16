rm ../../System/XC_Engine.so

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Engine -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Engine/Inc -I../../XC_Core/Inc -I/usr/include/i386-linux-gnu/ \
-o../../XC_Engine/Src/UnXC_Game.o UnXC_Game.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Engine -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Engine/Inc -I../../XC_Core/Inc -I/usr/include/i386-linux-gnu/ \
-o../../XC_Engine/Src/UnXC_TravelManager.o UnXC_TravelManager.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Engine -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Engine/Inc -I../../XC_Core/Inc -I/usr/include/i386-linux-gnu/ \
-o../../XC_Engine/Src/UnXC_Level.o UnXC_Level.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Engine -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Engine/Inc -I../../XC_Core/Inc -I/usr/include/i386-linux-gnu/ \
-o../../XC_Engine/Src/UnXC_Generics.o UnXC_Generics.cpp

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=XC_Engine -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Engine/Inc -I../../XC_Core/Inc -I/usr/include/i386-linux-gnu/ \
-o../../XC_Engine/Src/UnXC_Prim.o UnXC_Prim.cpp

# link with UT libs
gcc-2.95  -shared -o ../../System/XC_Engine.so -Wl,-rpath,. \
-export-dynamic -Wl,-soname,XC_Engine.so \
-Wl,--eh-frame-hdr \
-Wl,--traditional-format \
-lm -lc -ldl -lnsl -lpthread ./UnXC_Game.o ./UnXC_TravelManager.o ./UnXC_Level.o ./UnXC_Generics.o ./UnXC_Prim.o \
../../System/Core.so ../../System/Engine.so ../../System/XC_Core.so  

cp -f ../../System/XC_Engine.so ../../../ut-server/System/XC_Engine.so

# remove temporary files

