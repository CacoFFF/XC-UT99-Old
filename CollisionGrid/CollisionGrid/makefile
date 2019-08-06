CXX = g++

SONAME = CollisionGrid.so

CXXFLAGS = -std=gnu++11 -m32 -msse -msse2 -O3 -mfpmath=sse -rdynamic -fPIC -flto -fomit-frame-pointer -fpermissive -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-strict-aliasing -ffunction-sections -fvisibility=hidden -Wall

LDFLAGS = -shared -export-dynamic -Wl,--gc-sections -Wl,-soname,$(SONAME)

OUTPUT = ../../System/$(SONAME)

LIBS = ../../System/Core.so ../../System/Engine.so 

OBJDIR = Obj/

SRCS = API_Generic.cpp CollisionGrid.cpp ContainerLogic.cpp GridQueries.cpp UEImports.cpp

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

