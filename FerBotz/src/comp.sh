rm ../../System/FerBotz.so

# compile and output to this folder -> no linking yet!
gcc-2.95  -c -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -D_REENTRANT -fPIC -fsigned-char -pipe \
-DGPackage=FerBotz -Werror -I../inc -I../../Core/Inc -I../../Engine/Inc -I../../FerBotz/inc -I/usr/include/i386-linux-gnu/ \
-o../../FerBotz/src/FerBotzNative.o FerBotzNative.cpp

# link with UT libs
gcc-2.95  -shared -o ../../System/FerBotz.so -Wl,-rpath,. \
-export-dynamic -Wl,-soname,FerBotz.so \
-Wl,--eh-frame-hdr \
-Wl,--traditional-format \
-lm -lc -ldl -lnsl -lpthread ./FerBotzNative.o \
../../System/Core.so ../../System/Engine.so  

# remove temporary files

