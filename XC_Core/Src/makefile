CXX = gcc-2.95

SONAME = XC_Core.so

CXXFLAGS = -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -fpermissive -D_REENTRANT -fPIC -fsigned-char -pipe -DGPackage=XC_Core -Werror -I. -I../Inc -I../../Core/Inc -I../../Engine/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/

LDFLAGS = -shared -Wl,-rpath,. -export-dynamic -Wl,--eh-frame-hdr -Wl,--traditional-format -Wl,-z,defs -lm -lc -ldl -lnsl -lpthread -Wl,-z,defs -Wl,-soname,$(SONAME)

OUTPUT = ../../System/$(SONAME)

LIBS = ../../System/Core.so ../../System/Engine.so 

OBJDIR = Obj/


SRCS = XC_CoreScript.cpp	\
	XC_Networking.cpp	\
	XC_LZMA.cpp	\
	XC_Globals.cpp	\
	XC_Generic.cpp	\
	Devices.cpp	\
	CacusLibCompat.cpp	\
	PathBuilder.cpp	\
	RouteMapper.cpp	\
	Math.cpp	\
	Ticker.cpp

OBJS = $(SRCS:%.cpp=$(OBJDIR)%.o)

DEPS = $(SRCS:%.cpp=$(OBJDIR)%.d)

.PHONY: all
all: $(OUTPUT)

#Link
$(OUTPUT) : $(OBJS)
	$(CXX) -o $@ $(LDFLAGS) $^ $(LIBS)
	strip --strip-all --discard-all $(OUTPUT)

#Compile
$(OBJS) : $(OBJDIR)%.o : %.cpp
	$(CXX) -c $(CXXFLAGS) $(INCLUDES) -o $@ $< > $(OBJDIR)$*.lst


#Generate dependancies
#%.d : %.cpp
$(DEPS) : $(OBJDIR)%.d : %.cpp
	@echo $(@:%.d=%.o) $@ : \\ > $@
	@/bin/sh -ec '$(CXX) -MM $(CXXFLAGS) $< | \
		sed -e '\''s/.*://'\'' >> $@'

include $(DEPS)

.PHONY: clean
clean:
	-${RM} -f ${OBJS} $(SRCS:%.cpp=$(OBJDIR)%.lst) $(SRCS:%.cpp=$(OBJDIR)%.d)


