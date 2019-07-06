CXX = gcc-2.95

SONAME = XC_Engine.so

CXXFLAGS = -D__LINUX_X86__ -fno-for-scope -O2 -fomit-frame-pointer -march=pentium -fpermissive -D_REENTRANT -fPIC -fsigned-char -pipe -DGPackage=XC_Engine -Werror -I. -I../Inc -I../../Core/Inc -I../../Engine/Inc -I../../XC_Core/Inc -I../../CacusLib -I/usr/include/i386-linux-gnu/

LDFLAGS = -shared -Wl,-rpath,. -export-dynamic -Wl,--eh-frame-hdr -Wl,--traditional-format -Wl,-z,defs -lm -lc -ldl -lnsl -lpthread -Wl,-z,defs -Wl,-soname,$(SONAME)

OUTPUT = ../../System/$(SONAME)

LIBS = ../../System/Core.so ../../System/Engine.so ../../System/XC_Core.so 

OBJDIR = Obj/


SRCS = UnXC_Game.cpp	\
	UnXC_TravelManager.cpp	\
	UnXC_Level.cpp	\
	UnXC_Generics.cpp	\
	UnXC_Prim.cpp	\
	UnXC_NetServer.cpp	\
	UnXC_Script.cpp	\
	UnXC_PenLev.cpp

OBJS = $(SRCS:%.cpp=$(OBJDIR)%.o)

.PHONY: all
all: $(OUTPUT)

#Link
$(OUTPUT) : $(OBJS)
	$(CXX) -o $@ $(LDFLAGS) $^ $(LIBS)
	strip --strip-all --discard-all $(OUTPUT)

#Compile
$(OBJS): $(OBJDIR)%.o : %.cpp
	$(CXX) -c $(CXXFLAGS) $(INCLUDES) -o $@ $< > $(OBJDIR)$*.lst


#Generate dependancies
%.d : %.cpp
	@echo $(@:%.d=%.o) $@ : \\ > $@
	@/bin/sh -ec '$(CXX) -MM $(CXXFLAGS) $< | \
		sed -e '\''s/.*://'\'' >> $@'

#include $(SRCS:.cpp=.d)

.PHONY: clean
clean:
	-${RM} -f ${OBJS} $(SRCS:%.cpp=$(OBJDIR)%.lst) $(SRCS:%.cpp=$(OBJDIR)%.d)


