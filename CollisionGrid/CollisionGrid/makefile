CXX = g++ -std=gnu++14 -msse2 -m32 -fpermissive -rdynamic -fno-strict-aliasing -O2 -Wall -fvisibility=hidden  

OTHERSTUFF = -Wl,--version-script=CG_Exports.txt
CFLAGS = 
LDFLAGS = $(CFLAGS) -shared
TARGET_LIB = CollisionGrid.so

SRCS = API_Generic.cpp CollisionGrid.cpp ContainerLogic.cpp GridQueries.cpp UEImports.cpp
OBJS = $(SRCS:.cpp=.o)

.PHONY: all
all: ${TARGET_LIB}

$(TARGET_LIB): $(OBJS)
	$(CXX) ${LDFLAGS} -o $@ $^

$(SRCS:.cpp=.d):%.d:%.cpp
	$(CXX) ${CFLAGS} -MM $< >$@

include $(SRCS:.cpp=.d)

.PHONY: clean
clean:
	-${RM} ${TARGET_LIB} ${OBJS} $(SRCS:.cpp=.o)
	-${RM} ${TARGET_LIB} ${OBJS} $(SRCS:.cpp=.d)

