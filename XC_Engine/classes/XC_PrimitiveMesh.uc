// This is going to be a drag...

// Given we're ditching box collision, we'll transform the trace using XY
// Sure, it's one more transformation but it saves the code from transforming
// the entire mesh

//I'll avoid tracing both sides of a surface, that's just an insane amount of effort

/*
What to cache:
- The whole base mesh exists already..
- So we apply any transformation excepting yaw, because yaw doesn't alter cylinder collision
- Transform vertices, cache vertices using original indices
- Caching should be done using FVector4 (fplane here)
- The array has to be manually allocated using 16 bit alignment
- I should allocate triangle planes too using FVector4
- To do that i have to allocate a dynamic array of vertex indices


*/

class XC_PrimitiveMesh expands XC_PrimitiveActor
	native;


// Rotation is CachedRotation
// AnimSequence is cached animseq
// Mesh is the mesh we're allowed to operate on (set after first collision check)

//Internally allocated to fit 16-bit alignment rules
var transient const int TVerts; //Address of vertex array (appMallocFree returns this)
var transient const int TVertsCount;
var transient const int TPlanes; //Address of plane array (TVerts + TVertsCount * 16)
var transient const int TPlanesCount;
var transient const int TVertices; //Pointer to vertex indices and HComp of plane normal 
								 // (X,Y,Z,h) (TVerts + TVertsCount * 16 + TPlanesCount * 16)
var transient const int TPlaneDots; //Preallocated array of faces that pass the trace's mass PlaneDot checks

//var native const array<Plane> TransformVertices;
//var native const array<Plane> TransformPlanes;


