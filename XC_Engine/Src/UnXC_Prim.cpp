
#include "XC_Engine.h"

//====================================================
//====================================================
// Fast relevancy traces
//====================================================
//====================================================

#include "UnXC_Col.h"
#include "UnXC_Lev.h"

IMPLEMENT_CLASS(AXC_PrimitiveActor);
IMPLEMENT_CLASS(AXC_PrimitiveSphere);
IMPLEMENT_CLASS(AXC_PrimitivePlane);
IMPLEMENT_CLASS(AXC_PrimitiveMesh);


/*
inline FVector FLinePlaneIntersection
(
	const FVector &Point1,
	const FVector &Point2,
	const FPlane  &Plane
)
{
	return
		Point1
	+	(Point2-Point1)
	*	((Plane.W - (Point1|Plane))/((Point2 - Point1)|Plane));
}
*/

/*
	FPlane( FVector A, FVector B, FVector C )
	:	FVector( ((B-A)^(C-A)).SafeNormal() )
	,	W( A | ((B-A)^(C-A)).SafeNormal() )
	{}
*/

/*
	// Binary math operators.
	FVector operator^( const FVector& V ) const
	{
		return FVector
		(
			Y * V.Z - Z * V.Y,
			Z * V.X - X * V.Z,
			X * V.Y - Y * V.X
		);
	}
*/


//Move this to XC_Core
void* appMallocAligned( DWORD Size, DWORD Align)
{
	//Align must be power of 2, I won't do exception checking here
	void* BasePtr = appMalloc( Size + Align, NULL);
	if ( !BasePtr )
		return NULL;
	void* Result = (void*) (((INT)BasePtr+(Align))&~(Align-1)); //If pointer is already aligned, still advance 'align' bytes
	//Store BasePtr before result for 'free'
	((void**)Result)[-1] = BasePtr;
	return Result;
}

void* appFreeAligned( void* Ptr)
{
	if ( Ptr )
		appFree( ((void**)Ptr)[-1] );
	return NULL;
}


//====================================================
//====================================================
//	Primitive actor!!!!
//====================================================
//====================================================

//Implement later
/*INT* AXC_PrimitiveActor::GetOptimizedRepList( BYTE* InDefault, FPropertyRetirement* Retire, INT* Ptr, UPackageMap* Map, INT NumReps )
{
	return AActor::GetOptimizedRepList( InDefault, Retire, Ptr, Map, NumReps );
}*/



inline FVector ClipLineToZ( const FPrecomputedRay& Ray, FLOAT Z)
{
	FLOAT Mult = (Z - Ray.Org.Z) * _Reciprocal(Ray.Dir.Z);
	return Ray.Org + Ray.Dir * Mult;
}


//====================================================
//	Primitive Mesh
//====================================================

inline void TansformMeshVerts( FVector4* VArr, const FVector4* VOffset, INT Count)
{
#if ASM
	__asm
	{
		mov      eax,[VOffset] //Get offset (transform)
		movaps   xmm2,[eax] //x2: Offset
		andps    xmm2,FVector3Mask //x2: Zero (W)
		
		mov      eax,[VArr]	//Get address of array
		mov      esi,Count	//Get Count
		xor      edi,edi	//Prepare Counter
	NextVector:
		cmp      edi,esi
		jge      EndLoop
		mov      ecx,edi	//Copy counter to ECX
		shl      ecx,4		//Multiply ECX counter by 16
		movaps   xmm0,[eax+ecx] //x0: V1
		addps    xmm0,xmm2	//x0: V + Offset
		movaps   [eax+ecx],xmm0 //x0 to VOut
		
		inc      edi //i++
		jmp      NextVector
	EndLoop:
	}
#elif ASMLINUX
	for ( INT i=0 ; i<Count ; i++ )
		VArr[i] -= *VOffset;
#endif
}

inline void TansformAnimMeshVerts( FVector4* VArr1, FVector4* VArr2, FVector4* VOffset, FLOAT Alpha, INT Count)
{
	//CachedVerts[i] = V1 + (V2-V1)*Alpha + Offset;
	// Requirements: both array's W values should be pre-streamed and identical
	// Example: -1.f makes the vector ready for SSE PlaneDot operations
	VOffset->W = 0.f;
#if ASM
	__asm
	{
		movss    xmm3,Alpha //Store alpha in lower value of x7
		shufps   xmm3,xmm3,0	//x3: Fill SSE register, (Alpha,Alpha,Alpha,Alpha)

		mov      eax,[VOffset] //Get offset (transform)
		movaps   xmm2,[eax] //x2: Offset

		mov      eax,[VArr1] //Get address of array 1
		mov      edx,[VArr2] //Get address of array 2
		
		mov      esi,Count
		xor      edi,edi
	NextVector:
		cmp      edi,esi
		jge      EndLoop
		mov      ecx,edi //Copy counter to ECX
		shl      ecx,4 //Multiply ECX counter by 16
		movaps   xmm0,[eax+ecx] //x0: V1
		movaps   xmm1,[edx+ecx] //x1: V2
		subps    xmm1,xmm0 //x1: V2-V1
		mulps    xmm1,xmm3 //x1: (V2-V1)*Alpha
		addps    xmm1,xmm2 //x1: (V2-V1)*Alpha + Offset
		addps    xmm1,xmm0 //x1: V1 + (V2-V1)*Alpha + Offset
		movaps   [eax+ecx],xmm1 //x1 to VOut
		
		inc      edi //i++
		jmp      NextVector
	EndLoop:
	}
#elif ASMLINUX

#endif
}

void AXC_PrimitiveMesh::Destroy()
{
	if ( TVerts )
		debugf( TEXT("Attempting to deallocate collision cache for %s"), GetName() );
	appFreeAligned( TVerts);
	Super::Destroy();
}

UBOOL AXC_PrimitiveMesh::VerifyInternals()
{
	//Inconsistancy scanner
	if ( !HitActor->Mesh )
		return 0;
	if ( !TVerts 
		|| (Mesh           != HitActor->Mesh)
		|| (DrawScale      != HitActor->DrawScale) 
		|| (Rotation.Pitch != HitActor->Rotation.Pitch)
		|| (Rotation.Roll  != HitActor->Rotation.Roll)
		|| (AnimSequence   != HitActor->AnimSequence)
		|| (AnimFrame      != HitActor->AnimFrame))
	{
		//Setup mesh, get frames
		//Tweening not supported
		//MESHES STORE ALL POLYS, MUST SEPARATE IN FRAMES! (should be FrameVerts * AnimFrames)
		Mesh = HitActor->Mesh;
		AnimSequence = HitActor->AnimSequence;
		AnimFrame = HitActor->AnimFrame;
		Rotation.Yaw = 0;
		Rotation.Pitch = HitActor->Rotation.Pitch;
		Rotation.Roll = HitActor->Rotation.Roll;
		DrawScale = HitActor->DrawScale;

		UBOOL bLodMesh = Mesh->IsA(ULodMesh::StaticClass());
		
		if ( !bLodMesh )
			Mesh->Tris.Load(); //Lazy arrays need to be loaded
		Mesh->Verts.Load();
		
		//Allocate vertex and plane data arrays
		guard(AllocateMeshData);
		INT NewTVertsCount = Mesh->FrameVerts;
		INT NewTPlanesCount = bLodMesh ? ((ULodMesh*)Mesh)->Faces.Num() : Mesh->Tris.Num();
		if ( NewTVertsCount != TVertsCount || NewTPlanesCount != TPlanesCount )
		{
			appFreeAligned( TVerts);
			TVertsCount = NewTVertsCount;
			TPlanesCount = NewTPlanesCount;
			TVerts = (FVector4*) appMallocAligned( (TVertsCount+TPlanesCount) * 16 + TPlanesCount * (16), 16);
			TPlanes = (FVector4*) ((DWORD)TVerts + TVertsCount*16); //Contiguous space
			TVertices = (FFacePoints*) ((DWORD)TPlanes + TPlanesCount*16); //Contiguous space
			debugf( TEXT("Allocated %i bytes for %s"), (TVertsCount+TPlanesCount) * 16 + TPlanesCount * (16+4) + 16, GetName() );
		}
		unguard;

	
		//Something with bAnimOwner... ShieldBelt comes to mind (?)
		INT Frames[2] = {0,0}; //Need both frames to interpolate the anim, or collision will not be right
		FLOAT FrameAlpha = 0.f;
		FMeshAnimSeq* Sequence = Mesh->GetAnimSeq( AnimSequence );
		FVector4 Offset( -Mesh->Origin, 0.f);
		
		//VECTORIZE THIS
		FCoords Coords = GMath.UnitCoords * /*(Owner->Location + Owner->PrePivot) * */Rotation * Mesh->RotOrigin * FScale(Mesh->Scale * DrawScale,0.0,SHEER_None);

		//Testing alternate operations
		FCoords _Coords = GMath.UnitCoords;
//		_Coords *= Rotation;


		// Apply pitch rotation.
		_Coords *= FCoords
		(	
			FVector( 0.f, 0.f, 0.f ),
			FVector( +GMath.CosTab(Rotation.Pitch), +0.f, +GMath.SinTab(Rotation.Pitch) ),
			FVector( +0.f, +1.f, +0.f ),
			FVector( -GMath.SinTab(Rotation.Pitch), +0.f, +GMath.CosTab(Rotation.Pitch) )
		);
		// Apply roll rotation.
		_Coords *= FCoords
		(	
			FVector( 0.f, 0.f, 0.f ),
			FVector( +1.f, +0.f, +0.f ),
			FVector( +0.f, +GMath.CosTab(Rotation.Roll), -GMath.SinTab(Rotation.Roll) ),
			FVector( +0.f, +GMath.SinTab(Rotation.Roll), +GMath.CosTab(Rotation.Roll) )
		);
		
		_Coords *= Mesh->RotOrigin;
		//Vectorize here
		FVector Scale = Mesh->Scale * DrawScale;
//		debugf( TEXT("MeshScale: (%f,%f,%f)"), Mesh->Scale.X, Mesh->Scale.Y, Mesh->Scale.Z);
//		debugf( TEXT("MeshOrigin: (%f,%f,%f)"), Mesh->Origin.X, Mesh->Origin.Y, Mesh->Origin.Z);
		_Coords.XAxis *= Scale;
		_Coords.YAxis *= Scale;
		_Coords.ZAxis *= Scale;

		
//		_Coords *= FScale(Mesh->Scale * DrawScale,0.0,SHEER_None);

		
		if( Sequence )
		{
			//AnimFrame above 1.0? Expect anything!! (by looking at ASM it appears to be a possibility)
			//What about negative frames?
			FrameAlpha = Max( HitActor->AnimFrame,0.f) * Sequence->NumFrames;
			Frames[0] = appFloor( FrameAlpha);
			FrameAlpha = FrameAlpha - Frames[0];
			Frames[0] = Frames[0] % Sequence->NumFrames; //This frame
			if ( FrameAlpha > 0.001 )
				Frames[1] = (Frames[0]+1) % Sequence->NumFrames; //Next frame
			else
				Frames[1] = Frames[0]; //This is horrendous, i don't care
		}

		//Stream and extract frame 0 onto TVerts
		INT i;
		FMeshVert* RawVerts = &Mesh->Verts( Frames[0] );
		for( i=0; i<TVertsCount; i++ )
			TVerts[i] = FVector4( RawVerts[i].Vector(), -1.f ); //-1 added for SSE PlaneDot

		//Frames not the same, ASM interpolate the entire array
		if ( Frames[0] != Frames[1] )
		{
//			debugf( TEXT("Lerp animated frames: %i <-> %i"), Frames[0], Frames[1]);
			//Stream into a temporary table
			RawVerts = &Mesh->Verts( Frames[1] );
			FVector4* TVerts2 = (FVector4*) appMallocAligned( TVertsCount * 16, 16);
			for( i=0; i<TVertsCount; i++ )
				TVerts2[i] = FVector4( RawVerts[i].Vector(), -1.f );
//			debugf( TEXT("(%03.f,%03.f,%03.f) (%03.f,%03.f,%03.f)"), TVerts[1].X, TVerts[1].Y, TVerts[1].Z, TVerts2[1].X, TVerts2[1].Y, TVerts2[1].Z);
			TansformAnimMeshVerts( TVerts, TVerts2, &Offset, FrameAlpha, TVertsCount);
//			debugf( TEXT("INTO (%03.f,%03.f,%03.f) (A=%f) O(%03.f,%03.f,%03.f)"), TVerts[1].X, TVerts[1].Y, TVerts[1].Z, FrameAlpha, Offset.X, Offset.Y, Offset.Z);
			appFreeAligned( TVerts2);
		}
		else
			TansformMeshVerts( TVerts, &Offset, TVertsCount); //Offset the array then

		for ( i=0 ; i<TVertsCount ; i++ )
		{
			TVerts[i] = TVerts[i].TransformVectorBy(Coords); //Ignore origin
			TVerts[i].W = -1.f; //Something's not going right, fix here
		}
		
		//Cache Tris
		if ( !bLodMesh )
		{	for ( i=0 ; i<TPlanesCount ; i++ )
				TVertices[i] = Mesh->Tris(i);
		}
		else //LOD mesh uses wedges
		{	for ( i=0 ; i<TPlanesCount ; i++ )
			{
				ULodMesh* LODMesh = (ULodMesh*) Mesh;
				FMeshFace* Face = &LODMesh->Faces(i);
				for ( INT j=0 ; j<3 ; j++ )
					TVertices[i].Vertex[j] = LODMesh->Wedges( Face->iWedge[j] ).iVertex;
			}
		}

		//Cache planes post transformation
		for ( i=0 ; i<TPlanesCount ; i++ )
		{
			INT* Vertex = TVertices[i].Vertex;
			for ( INT j=0 ; j<3 ; j++ )
			{
				Vertex[j] = Vertex[j] % TVertsCount; //Some LOD meshes are giving me overflowing vertex positions
				if ( Vertex[j] >= TVertsCount )
					debugf( TEXT("Attempted to use invalid vertex index [%i/%i] at %i.%i"), Vertex[j], TVertsCount, i, j);
			}
			SSE_MakeFPlaneA( &TVerts[Vertex[0]], &TVerts[Vertex[1]], &TVerts[Vertex[2]], &TPlanes[i] );
			TVertices[i].HNorm = TPlanes[i].NormXY();
		}
		
		
		
	}
	if ( !TPlanesCount ) //No surfaces have been cached!
		return false;
	return true;
}


UBOOL AXC_PrimitiveMesh::InContact( FMemStack& Mem, FVector InLoc, FVector Extent, FCheckResult* Hit)
{
	if ( !VerifyInternals() )
		return 0;
	return 0;
}


#pragma warning (push)
#pragma warning (disable : 4035)
#pragma warning (disable : 4715)
struct FTempHitData_PMesh
{
	FLOAT MaxLength;
//	UBOOL SideTrace;
//	UBOOL UpTrace;
//	UBOOL DownTrace;
	FVector Normal;
	FLOAT Dist[2]; //Computed from DoublePlaneDot	 | O=16
	FLOAT CylBounds; //Per-poly stat				 | O=24
	
	//Preprocess important vectors and values
	FTempHitData_PMesh( FVector4* Start, FVector4* End, FVector4* Dir)
	: MaxLength( LengthUsingDirA( Start, End, Dir))
//	, SideTrace( (Dir->NormXY() != 0.f))
//	, UpTrace( Dir->Z > 0.f)
//	, DownTrace( Dir->Z < 0.f)
	{
		Start->W = -1.f;
		End->W = -1.f;
		Dir->W = 0.f;
	}
	
	//ZNorm must be abs'ed earlier
	inline UBOOL CylinderBoundsOverlap( const FVector4* Extent, FLOAT HNorm, FLOAT ZNorm)
	{
#if ASM
	__asm
	{
		mov          eax,Extent
		movaps       xmm0,[eax]
		movss        xmm1,HNorm
		movss        xmm2,ZNorm

		mov          eax,this
		movss        xmm3,[eax+16] //x3=Dist[0]

		movlhps      xmm1,xmm2 //[HNorm,XXX,ZNorm,YYY]
		mulps        xmm1,xmm0 //Extent * norms
		movhlps      xmm0,xmm1 //x0=Z x1=H
		addss        xmm1,xmm0 //x1=H+Z
		movss        [eax+24],xmm1 //Save to CylBounds
		
		//Compare Dist[0] with CylBounds
		cmpss        xmm3,xmm1,1 //x3 = (x3 < x1) [0xFFFFFFFF]
		movd         eax,xmm3 //Return value
	}
#else
		CylBounds = Abs(ZNorm) * Extent->Z + HNorm * Extent->X; 
		return Dist[0] < CylBounds;
#endif
	}
};
#pragma warning (pop)


inline UBOOL PMesh_ZTriSlabTest( const FVector4* CC, FLOAT ExtZ, FVector4** Points)
{
	FLOAT HighZ = CC->Z + ExtZ;
	FLOAT LowZ = CC->Z - ExtZ;
	for ( INT i=0 ; i<3 ; i++ )
		if ( Points[i]->Z >= LowZ && Points[i]->Z <= HighZ )
			return 1;
	return 0;
}
inline UBOOL PMesh_CylInTri( const FVector4* CC, const FVector4* Extent, FVector4** rPoints, FVector4* Plane, FLOAT PlaneDist, UBOOL bLog=0)
{
	//Expensive
	FVector4 Points[3] = { *rPoints[0], *rPoints[1] ,*rPoints[2]};
	FVector4 Offset( -CC->X, -CC->Y, -CC->Z, 0.f);
	TansformMeshVerts( Points, &Offset, 3);

	INT i;
	//Check 1: points in triangle
	for ( i=0 ; i<3 ; i++ )
		if ( Points[i].InCylinder( Extent) )
			return 1;

	FLOAT ZClip = Extent->Z * -fast_sign_nozero( Plane->Z);
	guard(WTF);
	//Check 2: nearest of line to cylinder in triangle
	for ( i=0 ; i<3 ; i++ )
	{
		INT j = (i+1) % 3;

/*		FVector Segment = Points[i] - Points[j];
		FVector4 SegmentNormal( Segment.X, Segment.Y, 0.f, 0.f);
		if ( SegmentNormal.IsZero() )
			continue;
		SegmentNormal.Normalize();
		FVector4 Nearest( FLinePlaneIntersection( Points[i], Points[j], SegmentNormal), -1.f);
		FLOAT TotalDist = Segment | SegmentNormal;
		FLOAT Dist = (Nearest - Points[j]) | SegmentNormal;
		if ( Dist < 0.f || Dist > TotalDist )
			continue;
		if ( Nearest.InCylinder( Extent) )
			return 1;

		//Intersect lines with cylinder cap!!!
		FVector4 Intersect_n( FLinePlaneIntersection( Points[i], Points[j],  FPlane( 0.f, 0.f, 1.f, ZClip)), -1.f );
		if ( Intersect_n.InCylinder( Extent) )
			return 1;
*/
		//New code, way less FPU ops
		FLOAT SegX = Points[j].X - Points[i].X;
		FLOAT SegY = Points[j].X - Points[i].X;
		if ( SegX == 0.f && SegY == 0.f ) //Vertical segment, NEED a check here!!!
		{
			continue;
		}
		FLOAT Alpha = -((Points[i].X * SegX + Points[i].Y * SegY) * _Reciprocal(SegX*SegX + SegY*SegY));
		if ( Alpha < 0 || Alpha > 1.f ) //Out of line
			continue;
		FVector4 Nearest( Points[i].X + SegX * Alpha, Points[i].Y + SegY * Alpha, Points[i].Z + (Points[j].Z - Points[i].Z) * Alpha, -1.f);
		if ( Nearest.InCylinder( Extent) )
			return 1;
		
		//Intersect lines with cylinder cap!!!
		Alpha = ((ZClip - Points[i].Z) * _Reciprocal(Points[j].Z - Points[i].Z));
		if ( Square(Points[i].X + SegX * Alpha) + Square(Points[i].Y + SegY * Alpha) <= Square( Extent->X) )
			return 1;
	}
	unguard;
	

	//Check 3: trace a horizontal line towards the plane
	FVector4 EndPoint( Plane->X, Plane->Y, ZClip, 0.f);
	//Change plane proximity (aka, transform plane to locals)
	FLOAT PW = Plane->W;
	Plane->W = -PlaneDist;
	FVector4 Intersection( FLinePlaneIntersection( EndPoint, FVector(0.f,0.f,ZClip), *Plane), -1.f);
	Plane->W = PW;

	return PointInTriangle( &Intersection, Points, Points+1, Points+2);
}

static UBOOL PMesh_CylLine_TriPass( const FVector4* Start, FVector4* End, const FVector4* Extent, FVector4** rPoints, FVector4* Plane, FLOAT HNorm, FTempHitData_PMesh* TData)
{
	//Get distance between cylinder edge to plane
	//SSE this check and move it to general loop
//	FLOAT PlaneToCylDist = Abs(Plane->Z) * Extent->Z + HNorm * Extent->X; 
//	if ( TData->Dist[1] > PlaneToCylDist ) //Trace doesn't reach the plane
//		return 0;
	//Dist now marks the cyl/plane hit distances
	TData->Dist[0] -= TData->CylBounds;
	TData->Dist[1] -= TData->CylBounds;

	//Get Cyl-to-Plane HitLocation, use as local start later if necessary (optimization)
	FVector4 CC = FLinePlaneIntersectDist( Start, End, TData->Dist);
	
//General trace
	//Trace already hits plane, now we need to see if it hits within triangle
	FLOAT Div = (HNorm == 0.f) ? 0.0f : _Reciprocal( HNorm); //GET RID OF THIS BRANCH
	FLOAT EZ = Extent->Z * fast_sign_nozero(Plane->Z); //Important to keep around
	FVector4 Projected( CC.X - Plane->X * Extent->X * Div, CC.Y - Plane->Y * Extent->X * Div, CC.Z - EZ, -1.f );
	if ( PointInTriangle( &Projected, rPoints[0], rPoints[1], rPoints[2]) )
	{
		*End = FVector4( CC, CC.W);
		TData->Normal = *Plane;
		return 1;
	}
	
	//Can reach this point
	//Attempt to hit the triangle vert sides, consider all sides (tri must not be vertical)
	//Modifying Local-Start (CC) makes earlier rejects hit more
	guard(WTF);
	static INT LogEvery = 0;
	UBOOL bLog = 0;
	LogEvery++;
	if ( Extent->Z == 12.f)
		bLog = 1;
	if ( Plane->Z != 0 )
	{
		for ( INT i=0 ; i<3 ; i++ )
		{
			INT j = (i+1) % 3;
			INT k = (i+2) % 3;
			FVector Segment = *rPoints[i] - *rPoints[j];
//			if ( Segment.X == 0.f || rPoints[i]->X < 0.f || rPoints[i]->X > 120.f )
//				bLog = 0;
			if ( Abs(Segment.X * Segment.Y) > 2 )
				bLog = 0;
			if ( appRound(rPoints[i]->Z) != -13 )
				bLog = 0;
			if ( Abs(appRound(rPoints[i]->X)) != 102 )
				bLog = 0;
			//Get a vertical plane
			FVector4 PseudoPlane;
			PseudoPlane.X = -Segment.Y;
			PseudoPlane.Y = Segment.X;
			PseudoPlane.NormalizeXY();
			PseudoPlane.W = PseudoPlane.Dot2( *rPoints[i] );
			FLOAT Dist[4];
			DoublePlaneDotU( &PseudoPlane, &CC, rPoints[k], Dist); //Test local start with opposite point of triangle [dS,dO]
			if ( bLog )
			{
				debugf( TEXT("_%i_ Point %i vs LocalStart: (%f,%f) [%i,%i,%i]"), LogEvery%200, k, Dist[0],Dist[1], appRound(rPoints[i]->X), appRound(rPoints[i]->Y), appRound(rPoints[i]->Z) );
				debugf( TEXT("_%i_ Segment [%i,%i,%i] Z=%f W=%f"), LogEvery%200, appRound(Segment.X), appRound(Segment.Y), appRound(Segment.Z), PseudoPlane.Z, PseudoPlane.W);
			}
			if ( (*(INT*)&Dist[0] ^ *(INT*)&Dist[1]) < 0 ) //Different signs = not a backface
			{
				//Eliminating a branch here, if plane is aiming at wrong side (Dist < 0), flip it
				//Also, keeps these values from being loaded into the FPU stack (we're inbetween SSE operations)
				INT Mask = (*(INT*)&Dist[1] & 0x80000000) ^ 0x80000000; //If third point is in front of plane we have 0x80000000
				*(INT*)&PseudoPlane.X ^= Mask; //Bitwise XOR, reverse sign bit if above is != 0
				*(INT*)&PseudoPlane.Y ^= Mask; //Otherwise nothing happens
				*(INT*)&PseudoPlane.W ^= Mask;
				DoublePlaneDotU( &PseudoPlane, &CC, End, Dist);
				if ( bLog )
					debugf( TEXT("PASS: %i,%i: plane %f to %f XY:(%f,%f,W:%f)"), i, j, Dist[0], Dist[1], PseudoPlane.X, PseudoPlane.Y, PseudoPlane.W);
				if ( Dist[1] > Dist[0] ) //Tracing away from supposed front plane... we're way past the triangle
					return 0;
				if ( Dist[1] <= Extent->X ) //End point reaches the line
				{
					if ( bLog )
						debugf( TEXT("Point %i,%i: plane reachable %f to %f XY:(%f,%f,W:%f)"), i, j, Dist[0], Dist[1], PseudoPlane.X, PseudoPlane.Y, PseudoPlane.W);
					Dist[0] -= Extent->X;
					Dist[1] -= Extent->X;
					CC = FLinePlaneIntersectDist( &CC, End, TData->Dist); //Reposition 'hit' point so it touches the edge plane
					Projected.X = CC.X - PseudoPlane.X * Extent->X; //Project hit onto the edge plane
					Projected.Y = CC.Y - PseudoPlane.Y * Extent->X;
					//Now I have to find Z (should be in the triangle plane, or segment)
					INT ci = (Segment.X == 0.f) & 1; //Use Y instead
					FLOAT ZAlpha = (rPoints[i]->GetComp(ci) - CC.GetComp(ci)) * _Reciprocal( (&(Segment.X))[ci] );
					if ( ZAlpha >= 0.f && ZAlpha <= 1.f )
					{
						if ( bLog )
							debugf( TEXT("Alpha is %f"), ZAlpha);
						Projected.Z = rPoints[i]->Z + Segment.Z * ZAlpha;
						if ( (Projected.Z <= CC.Z + Extent->Z) && (Projected.Z >= CC.Z - Extent->Z) ) //SIDE CYLINDER <-> TRIANGLE EDGE HIT!!!
						{
							if ( bLog )
								debugf( TEXT("Hit detected"));
							*End = FVector4( CC, CC.W);
							TData->Normal = PseudoPlane;
							return 1;
						}
					}
				}
			}
		}
	}
	else //Vertical plane
	{
		//Create vertical line (contact point is Projected), intersect with all 3 edges of triangles
		//Need to create a vertical plane that cuts the triangle in 2
		FPlane VertPlane( -Plane->Y, Plane->X, 0, Projected.X * (-Plane->Y) + Projected.Y * Plane->X);
		INT IntersectCount = 0;
		FLOAT IntersectZ[3]; //Third intersect Z is out there as overflow protection, we're not fact checking that we'll get only TWO intersections
		//Intersect all 3 lines
		FLOAT Dist[2];
		for ( INT i=0 ; i<3 ; i++ )
		{
			INT j = (i+1) % 3;
			DoublePlaneDotU( &VertPlane, rPoints[i], rPoints[j], Dist);
			if ( (*(INT*)&Dist[0] ^ *(INT*)&Dist[1]) < 0 ) //Different signs: there's intersection
				IntersectZ[IntersectCount++] = rPoints[i]->Z - (rPoints[j]->Z - rPoints[i]->Z) * Dist[0] * _Reciprocal(Dist[1]-Dist[0]); //Start - (End-Start)*alpha
		}
		if ( IntersectCount >= 2 ) //Should be 0 or 2, but we can't trust CPU maths
		{
			if ( IntersectZ[0] > IntersectZ[1] )
				Exchange( IntersectZ[0], IntersectZ[1] );
			if ( (Projected.Z >= IntersectZ[0]) && (Projected.Z <= IntersectZ[1]) )
			{
				*End = FVector4( CC, CC.W);
				TData->Normal = *Plane;
				return 1;
			}
		}
	}
	unguard;
	return 0;
}


//Modifies End to make rejects a lot faster
FCheckResult* AXC_PrimitiveMesh::ExtentCheck( FMemStack& Mem, FVector4* Start, FVector4* End, FVector4* Dir, const FVector4* Extent)
{
	const FLOAT BackReject = -0.001f;
	const FLOAT SphereWidth = Extent->NormXZ();
	FCheckResult* Result = NULL;
	FCheckResult* Overlapping = NULL;
	
	//Preprocess important vectors and values
	FTempHitData_PMesh TempData( Start, End, Dir);

	static INT LogEvery = 0;
	UBOOL bLog = 0;
	if ( Extent->Z == 39.f )
	{
		LogEvery++;
		if ( LogEvery % 200 == 1 )
			bLog = 1;
	}


	for ( INT i=0 ; i<TPlanesCount ; i++ )
	{
		//Compute distance from trace ends to plane
		DoublePlaneDotU( &TPlanes[i], Start, End, TempData.Dist);
		
		//Facing outwards = reject
		if ( TempData.Dist[0] <= TempData.Dist[1] )
			continue;

		//SSE compute cylinder bounds size (plane wise)
		
		
		//See that we're not overlapping already
		//Overlap only valid if not behind backreject
		//Func below also sets CylBounds (and performs the check in SSE)
		if ( TempData.CylinderBoundsOverlap( Extent, TVertices[i].HNorm, Abs(TPlanes[i].Z)) && (TempData.Dist[0] > BackReject) )
		{
			//Utilize precomputed Norm of X,Y components of plane normal
			//Overlap reject: cylinder not touching plane
//			FLOAT PlaneToCylDist = Abs(TPlanes[i].Z) * Extent->Z + TVertices[i].HNorm * Extent->X; 
//			if ( TempData.Dist[0] < PlaneToCylDist )
//			{
				//Get points now, do Slab test
				FVector4* Points[3] = { &TVerts[ TVertices[i].Vertex[0]], &TVerts[ TVertices[i].Vertex[1]], &TVerts[ TVertices[i].Vertex[2]] };
				if ( PMesh_ZTriSlabTest( Start, Extent->Z, &Points[0] ) )
				{
					if ( PMesh_CylInTri( Start, Extent, &Points[0], TPlanes + i, TempData.Dist[0], bLog) )
					{
						if ( bLog )
							debugf( TEXT("Plane %i: Overlapping"), i);
						//Setup overlap return, normalize later!
						if ( !Overlapping )
						{
							Overlapping = new(Mem) FCheckResult;
							Overlapping->Location = *Start;
						}
						Overlapping->Normal += TPlanes[i];
						Overlapping->Time += 1.f;
					}
				}
//			}
		}
		//Found an overlap hit, reject everything else
		if ( Overlapping || TempData.Dist[0] < -SphereWidth )
			continue;

		//Target point within ez plane reach
		if ( TempData.Dist[1] <= TempData.CylBounds )
		{
			FVector4* Points[3] = { &TVerts[ TVertices[i].Vertex[0]], &TVerts[ TVertices[i].Vertex[1]], &TVerts[ TVertices[i].Vertex[2]] };
			//
			if ( PMesh_CylLine_TriPass( Start, End, Extent, &Points[0], &TPlanes[i], TVertices[i].HNorm, &TempData) )
			{
				if ( !Result )
				{
					Result = new(Mem) FCheckResult;
					Result->Time = TempData.MaxLength;
				}
				FLOAT Time = LengthUsingDirA( Start, End, Dir);
				if ( bLog )
					debugf( TEXT("Plane %i: Trace HIT with %f/%f"), i, Time, Result->Time);
				if ( Time < Result->Time )
				{
					Result->Location = *End;
					Result->Time = Time;
					Result->Normal = TPlanes[i];
				}
			}
		}

	}
	if ( Overlapping )
	{
		if ( Overlapping->Time > 1.f )
			Overlapping->Normal = Overlapping->Normal.SafeNormal();
		return Overlapping;
	}
	return Result;
}

//Processes mass amount of PlaneDot's and performs appropiate checks
//Simple line checks for now
FCheckResult* AXC_PrimitiveMesh::ZeroExtentCheck( FMemStack& Mem, FVector4* Start, FVector4* End, FVector4* Dir)
{
	const FLOAT BackReject = -0.001f;
	FCheckResult* Result = NULL;
	
	//Preprocess important vectors and values
	Start->W = -1.f;
	End->W = -1.f;
	Dir->W = 0.f;

//	static int LogEvery = 0;
//	LogEvery++;
	INT HitIdx = -1;
	for ( INT i=0 ; i<TPlanesCount ; i++ )
	{
		FLOAT Dist[2];
		DoublePlaneDotU( &TPlanes[i], Start, End, Dist);
		//Cull:
		// -Does not reach triangle (End adjustment will make this more powerful as loop count goes up)
		// -Starts 'under' the triangle
		// -Goes away from triangle
		if ( Dist[1] > 0.f || Dist[0] < BackReject || Dist[0] <= Dist[1] )
			continue;
		FVector4* A = &TVerts[ TVertices[i].Vertex[0]];
		FVector4* B = &TVerts[ TVertices[i].Vertex[1]];
		FVector4* C = &TVerts[ TVertices[i].Vertex[2]];

		//NEW FORMULA: Intersection(CAC) = Start - (End-Start) * (Dist[0] / (Dist[1]-Dist[0]));
		FVector4 Intersection = FLinePlaneIntersectDist( Start, End, Dist);
//		UBOOL bLog = LogEvery % 200 == 1 && TPlanes[i].Z < -0.97;
//		if ( bLog )
//			debugf( TEXT("Plane %i: D(%f,%f) P(%03.1f,%03.1f,%03.1f,%03.1f)"), i, Dist[0], Dist[1], TPlanes[i].X , TPlanes[i].Y, TPlanes[i].Z, TPlanes[i].W);
		if ( !PointInTriangle( &Intersection, A, B, C) )
			continue;

		//Shrink trace if we hit a tri, makes future loops faster
		End->X = Intersection.X;
		End->Y = Intersection.Y;
		End->Z = Intersection.Z;
		HitIdx = i;
	}

	if ( HitIdx >= 0 )
	{
		Result = new(Mem) FCheckResult;
		Result->Time = LengthUsingDirA( Start, End, Dir);
		Result->Location = *End; //Optimize this shit
		Result->Normal = TPlanes[HitIdx];
	}
	
	return Result;
}

UBOOL AXC_PrimitiveMesh::RayTrace( FMemStack& Mem, const FPrecomputedRay& Ray, FVector* HitLoc, FVector* HitNorm)
{
	if ( !VerifyInternals() )
		return 0;
	
	//Transform tracer by primitive YAW (YAW can be rotated without recache!!)
	FCoords TestCoords = GMath.UnitCoords;
	AActor* Actor = HitActor;

/*	// Apply yaw transformation.
	TestCoords *= FCoords
	(	
		FVector( 0.f, 0.f, 0.f ),
		FVector( +GMath.CosTab(HitActor->Rotation.Yaw), +GMath.SinTab(HitActor->Rotation.Yaw), +0.f ),
		FVector( -GMath.SinTab(HitActor->Rotation.Yaw), +GMath.CosTab(HitActor->Rotation.Yaw), +0.f ),
		FVector( +0.f, +0.f, +1.f )
	);*/
	FVector4 TStart( Ray.Org, -1.f);
	FVector4 TEnd( Ray.End, -1.f);
	FVector4 THitLoc( *HitLoc, -1.f);
#if ASM
	__asm
	{
		mov       eax,Actor //Load HitActor pointer in EAX
		add       eax,208 //Move offset to HitActor->Location
		movups    xmm7,[eax] //Load HitActor->Location
		add       eax,112 //Move offset to HitActor->PrePivot (320)
		movups    xmm6,[eax] //Load HitActor->PrePivot
		addps     xmm6,xmm7 //x6: DrawOffset (sum of location and prepivot)
		andps     xmm6,FVector3Mask //Remove 4th DWORD (junk data, becomes 0x00000000)
		//Now load the trace vectors and substract DrawOffset from them (moving the trace to local coordinates)
		movaps    xmm0,TStart
		movaps    xmm1,TEnd
		movaps    xmm2,THitLoc
		subps     xmm0,xmm6
		subps     xmm1,xmm6
		subps     xmm2,xmm6
		movaps    TStart,xmm0 //Store
		movaps    TEnd,xmm1
		movaps    THitLoc,xmm2
	}
#endif
	static int LogEvery = 0;
	LogEvery++;
	
	// Apply inverse yaw transformation.
	TestCoords *= FCoords
	(
		FVector( 0.f, 0.f, 0.f ),
		FVector( +GMath.CosTab(HitActor->Rotation.Yaw), -GMath.SinTab(HitActor->Rotation.Yaw), -0.f ),
		FVector( +GMath.SinTab(HitActor->Rotation.Yaw), +GMath.CosTab(HitActor->Rotation.Yaw), +0.f ),
		FVector( -0.f, +0.f, +1.f )
	);
	//Vectorize this shit
	TStart = TransformPointByXY( TestCoords, TStart);
	THitLoc = TransformPointByXY( TestCoords, THitLoc);
	TEnd = TransformPointByXY( TestCoords, TEnd);
	FVector4 TDir( TransformPointByXY( TestCoords, Ray.Dir)); //Need TransformVector implementation
	

	//No extent yet
	FCheckResult* Hit;
	if ( bForceZeroExtent || Ray.Extent.IsZero() )
		Hit = ZeroExtentCheck( Mem, &THitLoc, &TEnd, &TDir);
	else
		Hit = ExtentCheck( Mem, &THitLoc, &TEnd, &TDir, &Ray.Extent);
	if ( !Hit )
		return 0;

	//Detransform normal and hit
	TestCoords.XAxis.Y *= -1.f; //X now goes opposite side by opposing X.Y
	TestCoords.YAxis.X = -TestCoords.XAxis.Y;
	TestCoords.YAxis.Y = TestCoords.XAxis.X; //This could go away...
//		*HitNorm = TPlanes[ BestHit];
	*HitNorm = TransformPointByXY( TestCoords, Hit->Normal);
	*HitLoc += Ray.Dir * (Hit->Time + 0.05f) + *HitNorm * 0.25f; //Optimize later
	return 1;
//	return 0;
}

//====================================================
//	Primitive Plane
//====================================================

void AXC_PrimitivePlane::VerifyInternals()
{
	AActor* LocationActor = bUseMyLocation ? this : HitActor;
	AActor* RotationActor = bUseMyRotation ? this : HitActor;
	if ( CachedLocation == LocationActor->Location && CachedRotation == RotationActor->Rotation )
		return;
	CachedLocation = LocationActor->Location;
	CachedRotation = RotationActor->Rotation;
	iPlane = CachedRotation.Vector();
	iPlane.W = CachedLocation | iPlane;
	iHAxis = appSqrt(iPlane.X * iPlane.X + iPlane.Y * iPlane.Y);
}

UBOOL AXC_PrimitivePlane::InContact( FMemStack& Mem, FVector InLoc, FVector Extent, FCheckResult* Hit)
{
	VerifyInternals();

	FVector4 StartLoc( InLoc, -1.f);
	FLOAT Dist = iPlane.PlaneDot( StartLoc);

	//Inside solid block, do not correct
	if ( bSolidifyBehindPlane && (Dist < 0) )
		return 1;

	FLOAT ExtraW;
	if ( bForceZeroExtent )
	{
		Extent.X = 0.f;
		Extent.Z = 0.f;
		ExtraW = 0.f;
	}
	else
		ExtraW = (Extent.X * iHAxis + Extent.Z * iPlane.Z);

	//Out of plane
	if ( Abs(Dist) > ExtraW )
		return 0;

	FLOAT DSign = fast_sign_nozero(Dist);

	if ( Hit )
	{
		Hit->Normal = (FVector)iPlane * DSign; //CHECK!!
		Hit->Location += Hit->Normal * (ExtraW-Dist*DSign); //Move outside of wall
	}
	
	return 1;
}


//Clip line to plane
//Here the line already touches the cylinder!
UBOOL AXC_PrimitivePlane::RayTrace( FMemStack& Mem, const FPrecomputedRay& Ray, FVector* HitLoc, FVector* HitNorm)
{
	VerifyInternals();
	
	FVector4 StartLoc( *HitLoc, -1.f);
	FLOAT Dist1 = iPlane.PlaneDot( StartLoc);
	FLOAT Dist2 = iPlane.PlaneDot( Ray.End);
	FLOAT ExtraW = bForceZeroExtent ? 0.f : (Ray.Extent.X * iHAxis + Ray.Extent.Z * iPlane.Z);

	//Super early hit
	if ( bSolidifyBehindPlane && (Dist1 < 0) && (Dist2 > Dist1) )
	{
		*HitNorm = _UnsafeNormal( *HitNorm - Ray.Dir); //Correct normal a bit just to see what happens
		return 1;
	}

	//One directional rejects
	if ( !bBlockOutgoing && (Dist1 >= Dist2) )
		return 0;
	if ( !bBlockIncoming && (Dist1 <= Dist2) )
		return 0;

	FLOAT D1Sign = fast_sign_nozero(Dist1);
	FLOAT AbsD1 = Dist1*D1Sign;
	//Stuck into wall
	if ( AbsD1 >= 0 && AbsD1 < ExtraW )
	{
		if ( AbsD1 > Dist2*D1Sign ) //Trying to get inside wall
		{
			*HitNorm = (FVector)iPlane * D1Sign; //CHECK!!
			*HitLoc += *HitNorm * (ExtraW-AbsD1); //Move outside of wall
//			if ( Ray.Extent.Z > 37.f )
	//			debugf( TEXT("STUCK INTO WALL %f < %f"), AbsD1, ExtraW);
			return 1;
		}
		return 0;
	}
	
	//Extrude plane
	Dist1 -= ExtraW * D1Sign;
	Dist2 -= ExtraW * D1Sign;


	if ( fast_sign_nozero(Dist1) == fast_sign_nozero(Dist2) ) //Same sign, same sides
	{
//		if ( Abs(Dist2) < ExtraW ) //THIS IS BAD
//			if ( Ray.Extent.Z > 37.f )
//				debugf( TEXT("IDENTICAL SIGNS, %f and %f"), Dist1, Dist2);
		return 0;
	}
	FLOAT OldW = iPlane.W;
	iPlane.W += ExtraW * D1Sign;
	FVector Projection = FLinePlaneIntersection( StartLoc, Ray.End, iPlane);
	iPlane.W = OldW;
	
	FLOAT EX = bForceZeroExtent ? 0.f : Ray.Extent.Z;
	if ( Abs(Projection.Z-CachedLocation.Z) > HitActor->CollisionHeight + EX ) 
		return 0;
	EX = bForceZeroExtent ? 0.f : Ray.Extent.X;
	if ( Square(Projection.X-CachedLocation.X) + Square(Projection.Y-CachedLocation.Y) > Square(HitActor->CollisionRadius + EX) )
		return 0;
	*HitLoc = Projection;
	*HitNorm = (FVector)iPlane * D1Sign; //CHECK!!
	return 1;
}





//====================================================
//	Primitive Sphere
//====================================================

UBOOL AXC_PrimitiveSphere::InContact( FMemStack& Mem, FVector InLoc, FVector Extent, FCheckResult* Hit)
{
	guard(AXC_PrimitiveSphere::PointCheck);

	if ( bHollow && bNoHollowFrontHits )
		return 0;

	FLOAT CollisionRadiusSq = HitActor->CollisionRadius * HitActor->CollisionRadius;
	FVector RelativeStart = InLoc - HitActor->Location;
	FLOAT RelSq = RelativeStart.SizeSquared();
	UBOOL bZeroExtent = bForceZeroExtent || Extent.X == 0.f;

	if ( RelSq > CollisionRadiusSq )
	{
		if ( bZeroExtent ) //Instant reject
			return 0;

		FLOAT EncapsulatedExtentZ = Max(Extent.Z - Extent.X, 0.f);
		FLOAT ColRadius = HitActor->CollisionRadius + Min( Extent.Z, Extent.X); //Recompute sphere using extent
		CollisionRadiusSq = ColRadius * ColRadius;
		if ( Abs(RelativeStart.Z) < EncapsulatedExtentZ ) //Cylinder side hit, partially...
		{
			if ( RelativeStart.SizeSquared2D() > CollisionRadiusSq )
				return 0;
			if ( Hit )
			{
				Hit->Normal = _UnsafeNormal2D( RelativeStart);
				Hit->Location = Hit->Normal * ColRadius + HitActor->Location;
			}
			return 1;
		}

		FVector TraceOffset = FVector( 0.f, 0.f, -EncapsulatedExtentZ * fast_sign_nozero( RelativeStart.Z) );
		RelativeStart += TraceOffset;
		RelSq = RelativeStart.SizeSquared(); //Recompute
		if ( RelSq > CollisionRadiusSq ) //Adjusted point out of sphere's touch
			return 0;
		if ( Hit )
		{
			Hit->Normal = _UnsafeNormal(RelativeStart);
			Hit->Location = Hit->Normal * ColRadius + HitActor->Location - TraceOffset;
		}
		return 1;
	}

	if ( Hit ) //Normalization is expensive... handle this differently!!!
		Hit->Location = InLoc;

		//No escape
	if ( !bHollow )
		return 1;
	
	CollisionRadiusSq = Square( HitActor->CollisionRadius - 1.f);
	if ( RelSq >= CollisionRadiusSq ) //Actor within that 1 unit gap
		return 1;
	
	FLOAT FExtent = bForceZeroExtent ? 0.f : appSqrt( Square(Extent.X) + Square(Extent.Z) );
	FLOAT ReducedSphere = HitActor->CollisionRadius - (1.f + FExtent);
	if ( ReducedSphere <= 0.f )
	{
		if ( Hit )
			Hit->Location = HitActor->Location; //Actor doesn't fit, stick to center
		return 1;
	}
	
	if ( RelSq > Square(ReducedSphere) ) //Actor touching inner border
	{
		if ( Hit )
		{
			Hit->Normal = _UnsafeNormal(RelativeStart);
			Hit->Location = Hit->Normal * ReducedSphere + HitActor->Location;
		}
		return 1;
	}
	return 0;
	unguard;
}

/**
 * Cylinder to Cylinder reject has been applied already
 * Therefore start point is VERY near the sphere
*/
UBOOL AXC_PrimitiveSphere::RayTrace( FMemStack& Mem, const FPrecomputedRay& Ray, FVector* HitLoc, FVector* HitNorm)
{
	guard( AXC_PrimitiveSphere::RayTrace);

	//Global steps, should optimize using SSE
	FLOAT CollisionRadiusSq = HitActor->CollisionRadius * HitActor->CollisionRadius;
	FVector RelativeStart = *HitLoc - HitActor->Location;
	FLOAT RelSq = RelativeStart.SizeSquared();
	UBOOL bZeroExtent = bForceZeroExtent || Ray.Extent.X == 0.f;


	UBOOL bUseSolidOuterTrace = !(bHollow && bNoHollowFrontHits) && (RelSq >= CollisionRadiusSq || !bHollow);
	if ( bUseSolidOuterTrace ) //Can hit front
	{
		guard( OutSphere);
		
		if ( (Ray.Dir | RelativeStart) > 0.f ) //Trace going away from center
			return 0;

		FVector TraceOffset;
		FVector RelativeNearest;
		
		if ( bZeroExtent )
		{
			TraceOffset = FVector(0.f,0.f,0.f);
			RelativeNearest = *HitLoc + Ray.Dir * ( Ray.Dir | (HitActor->Location - *HitLoc)) - HitActor->Location;
		}
		else
		{	//Super cheap, attempt a side capsule cast
			FLOAT EncapsulatedExtentZ = Max(Ray.Extent.Z - Ray.Extent.X, 0.f);
			if ( Abs(RelativeStart.Z) < EncapsulatedExtentZ ) //Cylinder side hit, partially...
			{
				RelativeStart.Z = 0.f;
				*HitNorm = _UnsafeNormal( RelativeStart);
				return 1;
			}
			TraceOffset = FVector( 0.f, 0.f, -EncapsulatedExtentZ * fast_sign_nozero( RelativeStart.Z) );
			FVector NewOrg = *HitLoc + TraceOffset;
			RelativeNearest = NewOrg + Ray.Dir * ( Ray.Dir | (HitActor->Location - NewOrg)) - HitActor->Location;

			RelativeStart += TraceOffset;
			RelSq = RelativeStart.SizeSquared(); //Recompute
			CollisionRadiusSq = Square(HitActor->CollisionRadius + Min( Ray.Extent.Z, Ray.Extent.X)); //Expand sphere
		}
	
		if ( RelSq < CollisionRadiusSq )
		{
			*HitNorm = _UnsafeNormal( RelativeStart);
			return 1;
		}
		FLOAT RelNearestSq = RelativeNearest.SizeSquared();
		if ( RelNearestSq > CollisionRadiusSq ) //Nearest point out of sphere
			return 0;
		FVector HitLocation = RelativeNearest - Ray.Dir * appSqrt( CollisionRadiusSq - RelNearestSq );
		if ( ((HitActor->Location + HitLocation - (*HitLoc+TraceOffset)) | Ray.Dir) <= 0.f ) //Checking that HitLocation isn't further than End (from Start)
			return 0;
		*HitNorm = _UnsafeNormal( HitLocation);
		*HitLoc = HitActor->Location + HitLocation /*+ (Ray.Dir + *HitNorm) * 0.1f*/ - TraceOffset;
		return 1;

		unguard;
	}

	//Backtraces only, single sphere using MAX as extent
	FLOAT Extent = bForceZeroExtent ? 0.f : appSqrt( Square(Ray.Extent.X) + Square(Ray.Extent.Z) );
	FLOAT ReducedSphere = HitActor->CollisionRadius - (1.f + Extent);
	if ( ReducedSphere <= 0.f ) //Reject backtrace if tracer is bigger
		return 0;

	//Trace starts inside of sphere, easy reject
	if ( RelSq < CollisionRadiusSq )
	{
		FVector RelativeEnd = Ray.End - HitActor->Location;
		if ( RelativeEnd.SizeSquared() < Square(ReducedSphere) ) //End inside sphere, no hit at all
			return 0;
		FVector Nearest = Ray.Org + Ray.Dir * ( Ray.Dir | (HitActor->Location - Ray.Org) );
		*HitLoc = Nearest + Ray.Dir * appSqrt( Square(ReducedSphere) - RelSq );
		*HitNorm = _UnsafeNormal( HitActor->Location - *HitLoc);
		return 1;
	}
	
	//Trace starts outside of sphere
	if ( (Ray.Dir | RelativeStart) > 0.f ) //Trace going away from center
		return 0;
	FVector RelativeNearest = Ray.Org + Ray.Dir * ( Ray.Dir | (HitActor->Location - Ray.Org) ) - HitActor->Location;
	CollisionRadiusSq = Square(ReducedSphere); //Transform sphere
	if ( (RelativeNearest | RelativeNearest) > CollisionRadiusSq ) //Nearest point out of sphere
			return 0;
	FVector HitLocation = RelativeNearest + Ray.Dir * appSqrt( CollisionRadiusSq - RelativeNearest.SizeSquared() );
	if ( ((HitActor->Location + HitLocation - *HitLoc) | Ray.Dir) <= 0.f ) //Checking that HitLocation isn't further than End (from Start)
		return 0;
	*HitNorm = _UnsafeNormal( -HitLocation);
	*HitLoc = HitActor->Location + HitLocation + (Ray.Dir + *HitNorm) * 0.01f;
	return 1;
	
	unguard;
}




//====================================================
//====================================================
//	Rendering !!!!
//====================================================
//====================================================

#if XC_RENDER_API

#include "UnXC_Render.h"

static UBOOL UXPR_VTBL_INIT = 0;
static INT* UXC_Mesh_vtbl[2];

void HookRender()
{

}

XC_ENGINE_API void HookMeshes()
{
	
	if ( !UXPR_VTBL_INIT )
	{
		UXPR_VTBL_INIT = 1;
		UMesh_Hack* testMesh = new UMesh_Hack;
		ULodMesh_Hack* testLodMesh = new ULodMesh_Hack;
		UXC_Mesh_vtbl[0] = *(INT**) testMesh;
		UXC_Mesh_vtbl[1] = *(INT**) testLodMesh;
		delete testMesh;
		delete testLodMesh;
	}

	for ( TObjectIterator<UMesh> It; It; ++It )
	{
		if ( It->GetClass() == UMesh::StaticClass() )
		{
			UMesh* Model = *It;
			INT** Model_raw = (INT**)Model;
			Model_raw[0] = UXC_Mesh_vtbl[0];
			Model->CurVertex = 0;
		}
		else if ( It->GetClass() == ULodMesh::StaticClass() )
		{
			ULodMesh* Model = (ULodMesh*) *It;
			INT** Model_raw = (INT**)Model;
			Model_raw[0] = UXC_Mesh_vtbl[1];
			Model->CurVertex = 0;
		}
	}

}

void UMesh_Hack::Destroy()
{
	UObject::Destroy();
}

void UMesh_Hack::GetFrame
(
	FVector*	ResultVerts,
	INT			Size,
	FCoords		Coords,
	AActor*		Owner
)
{
	guard(UMesh_Hack::GetFrame);

	// Make sure lazy-loadable arrays are ready.
	Verts.Load();
	Tris.Load();
	Connects.Load();
	VertLinks.Load();

	AActor* AnimOwner = (Owner->bAnimByOwner && Owner->Owner) ? Owner->Owner : Owner;

	// Create or get cache memory.
	FCacheItem* Item = NULL;
	UBOOL WasCached  = 1;
	QWORD CacheID    = MakeCacheID( CID_TweenAnim, Owner, NULL );
	BYTE* Mem        = GCache.Get( CacheID, Item );
	if( Mem==NULL || *(UMesh**)Mem!=this )
	{
		if( Mem != NULL )
		{
			// Actor's mesh changed.
			Item->Unlock();
			GCache.Flush( CacheID );
		}
		Mem = GCache.Create( CacheID, Item, sizeof(UMesh*) + sizeof(FLOAT) + sizeof(FName) + FrameVerts * sizeof(FVector) );
		WasCached = 0;
	}
	UMesh*& CachedMesh  = *(UMesh**)Mem; Mem += sizeof(UMesh*);
	FLOAT&  CachedFrame = *(FLOAT *)Mem; Mem += sizeof(FLOAT );
	FName&  CachedSeq   = *(FName *)Mem; Mem += sizeof(FName);
	if( !WasCached )
	{
		CachedMesh  = this;
		CachedSeq   = NAME_None;
		CachedFrame = 0.0;
	}

	// Get stuff.
	FLOAT    DrawScale      = AnimOwner->bParticles ? 1.0 : Owner->DrawScale;
	FVector* CachedVerts    = (FVector*)Mem;
	Coords                  = Coords * (Owner->Location + Owner->PrePivot) * Owner->Rotation * RotOrigin * FScale(Scale * DrawScale,0.0,SHEER_None);
	const FMeshAnimSeq* Seq = GetAnimSeq( AnimOwner->AnimSequence );

	// Transform all points into screenspace.
	if( AnimOwner->AnimFrame>=0.0 || !WasCached )
	{
		// Compute interpolation numbers.
		FLOAT Alpha=0.0;
		INT iFrameOffset1=0, iFrameOffset2=0;
		if( Seq )
		{
			FLOAT Frame   = ::Max(AnimOwner->AnimFrame,0.f) * Seq->NumFrames;
			INT iFrame    = appFloor(Frame);
			Alpha         = Frame - iFrame;
			iFrameOffset1 = (Seq->StartFrame + ((iFrame + 0) % Seq->NumFrames)) * FrameVerts;
			iFrameOffset2 = (Seq->StartFrame + ((iFrame + 1) % Seq->NumFrames)) * FrameVerts;
		}

		// Interpolate two frames.
		FMeshVert* MeshVertex1 = &Verts( iFrameOffset1 );
		FMeshVert* MeshVertex2 = &Verts( iFrameOffset2 );
		for( INT i=0; i<FrameVerts; i++ )
		{
			FVector V1( MeshVertex1[i].X, MeshVertex1[i].Y, MeshVertex1[i].Z );
			FVector V2( MeshVertex2[i].X, MeshVertex2[i].Y, MeshVertex2[i].Z );
			CachedVerts[i] = V1 + (V2-V1)*Alpha;
			*ResultVerts = (CachedVerts[i] - Origin).TransformPointBy(Coords);
			*(BYTE**)&ResultVerts += Size;
		}
	}
	else
	{
		// Compute tweening numbers.
		FLOAT StartFrame = Seq ? (-1.0 / Seq->NumFrames) : 0.0;
		INT iFrameOffset = Seq ? Seq->StartFrame * FrameVerts : 0;
		FLOAT Alpha = 1.0 - AnimOwner->AnimFrame / CachedFrame;
		if( CachedSeq!=AnimOwner->AnimSequence || Alpha<0.0 || Alpha>1.0)
		{
			CachedSeq   = AnimOwner->AnimSequence;
			CachedFrame = StartFrame;
			Alpha       = 0.0;
		}

		// Tween all points.
		FMeshVert* MeshVertex = &Verts( iFrameOffset );
		for( INT i=0; i<FrameVerts; i++ )
		{
			FVector V2( MeshVertex[i].X, MeshVertex[i].Y, MeshVertex[i].Z );
			CachedVerts[i] += (V2 - CachedVerts[i]) * Alpha;
			*ResultVerts = (CachedVerts[i] - Origin).TransformPointBy(Coords);
			*(BYTE**)&ResultVerts += Size;
		}

		// Update cached frame.
		CachedFrame = AnimOwner->AnimFrame;
	}
	Item->Unlock();
	unguardobj;
}







// Cached frame header struct for temp cached meshes.
struct CFLodHeader
{
	UMesh	*CachedMesh;
	FLOAT	CachedFrame;
	FName	CachedSeq;	
	INT     CachedLodVerts;
	FLOAT   TweenIndicator;
};	

void ULodMesh_Hack::Destroy()
{
	UObject::Destroy();
}

void ULodMesh_Hack::GetFrame
(
	FVector*	ResultVerts, //So renderer expects Vector3 format... shit
	INT			Size,
	FCoords		Coords,
	AActor*		Owner,
	INT&		LODRequest
)
{
	guard(UMesh_Hack::GetFrame);

	// Make sure any used lazy-loadable arrays are ready.
	Verts.Load();

	AActor* AnimOwner = (Owner->bAnimByOwner && Owner->Owner) ? Owner->Owner : Owner;

	// Determine how many vertices to lerp; in case of tweening, we're limited 
	// by the previous cache size also.
	INT VertsRequested = Min(LODRequest + SpecialVerts, FrameVerts);	
	INT VertexNum = VertsRequested;

	// Create or get cache memory.
	FCacheItem* Item = NULL;
	UBOOL WasCached  = 1;
	QWORD CacheID    = MakeCacheID( CID_TweenAnim, Owner, NULL );
	BYTE* Mem = GCache.Get( CacheID, Item );
	CFLodHeader* FrameHdr = (CFLodHeader*)Mem;

	if( Mem==NULL || FrameHdr->CachedMesh !=this )
	{
		if( Mem != NULL )
		{
			// Actor's mesh changed.
			Item->Unlock();
			GCache.Flush( CacheID );
		}
		// Full size cache (for now.) We don't want to have to realloc every time our LOD scales up a bit...
		Mem = GCache.Create( CacheID, Item, sizeof(CFLodHeader) + FrameVerts * sizeof(FVector) );		
		FrameHdr = (CFLodHeader*)Mem;
		WasCached = 0;
		FrameHdr->TweenIndicator = 1.0f;
	}

	if( !WasCached )
	{
		FrameHdr->CachedMesh  = this;
		FrameHdr->CachedSeq   = NAME_None;
		FrameHdr->CachedFrame = 0.0;
		FrameHdr->CachedLodVerts = 0;
	}

	// Get stuff.
	FLOAT    DrawScale      = AnimOwner->bParticles ? 1.0 : Owner->DrawScale;
	FVector* CachedVerts    = (FVector*)((BYTE*)Mem + sizeof(CFLodHeader));
	Coords                  = Coords * (Owner->Location + Owner->PrePivot) * Owner->Rotation * RotOrigin * FScale(Scale * DrawScale,0.0,SHEER_None);
	const FMeshAnimSeq* Seq = GetAnimSeq( AnimOwner->AnimSequence );


	if( AnimOwner->AnimFrame>=0.0  || !WasCached )
	{
		LODRequest = VertexNum - SpecialVerts; // How many regular vertices returned.
		FrameHdr->CachedLodVerts = VertexNum;  //

		// Compute interpolation numbers.
		FLOAT Alpha=0.0;
		INT iFrameOffset1=0, iFrameOffset2=0;
		if( Seq )
		{
			FLOAT Frame   = ::Max(AnimOwner->AnimFrame,0.f) * Seq->NumFrames;
			INT iFrame    = appFloor(Frame);
			Alpha         = Frame - iFrame;
			iFrameOffset1 = (Seq->StartFrame + ((iFrame + 0) % Seq->NumFrames)) * FrameVerts;
			iFrameOffset2 = (Seq->StartFrame + ((iFrame + 1) % Seq->NumFrames)) * FrameVerts;
		}
		

		// Special case Alpha 0. 
		if ( Alpha <= 0.0f)
		{
			// Initialize a single frame.
			FMeshVert* MeshVertex1 = &Verts( iFrameOffset1 );

			for( INT i=0; i<VertexNum; i++ )
			{
				// Expand new vector from stored compact integers.
				CachedVerts[i] = FVector( MeshVertex1[i].X, MeshVertex1[i].Y, MeshVertex1[i].Z );
				// Transform all points into screenspace.
				*ResultVerts = (CachedVerts[i] - Origin).TransformPointBy(Coords);
				*(BYTE**)&ResultVerts += Size;
			}	
		}
		else
		{	
			// Interpolate two frames.
			FMeshVert* MeshVertex1 = &Verts( iFrameOffset1 );
			FMeshVert* MeshVertex2 = &Verts( iFrameOffset2 );
			for( INT i=0; i<VertexNum; i++ )
			{
				FVector V1( MeshVertex1[i].X, MeshVertex1[i].Y, MeshVertex1[i].Z );
				FVector V2( MeshVertex2[i].X, MeshVertex2[i].Y, MeshVertex2[i].Z );
				CachedVerts[i] = V1 + (V2-V1)*Alpha;
				*ResultVerts = (CachedVerts[i] - Origin).TransformPointBy(Coords);
				*(BYTE**)&ResultVerts += Size;
			}
		}	
	}
	else // Tween: cache present, and starting from Animframe < 0.0
	{
		// Any requested number within CACHE limit is ok, since 
		// we cannot tween more than we have in the cache.
		VertexNum  = Min(VertexNum,FrameHdr->CachedLodVerts);
		FrameHdr->CachedLodVerts = VertexNum;
		LODRequest = VertexNum - SpecialVerts; // how many regular vertices returned.

		// Compute tweening numbers.
		FLOAT StartFrame = Seq ? (-1.0 / Seq->NumFrames) : 0.0;
		INT iFrameOffset = Seq ? Seq->StartFrame * FrameVerts : 0;
		FLOAT Alpha = 1.0 - AnimOwner->AnimFrame / FrameHdr->CachedFrame;

		if( FrameHdr->CachedSeq!=AnimOwner->AnimSequence )
		{
			FrameHdr->TweenIndicator = 0.0f;
		}
		
		// Original:
		if( FrameHdr->CachedSeq!=AnimOwner->AnimSequence || Alpha<0.0f || Alpha>1.0f)
		{
			FrameHdr->CachedFrame = StartFrame; 
			Alpha       = 0.0f;
			FrameHdr->CachedSeq = AnimOwner->AnimSequence;
		}
				
		// Tween indicator says destination has been (practically) reached ?
		FrameHdr->TweenIndicator += (1.0f - FrameHdr->TweenIndicator) * Alpha;
		if( FrameHdr->TweenIndicator > 0.97f ) 
		{
			// We can set Alpha=0 (faster).
			Alpha = 0.0f;

			// LOD fix: if the cache has too little vertices, 
			// now is the time to fill it out to the requested number.
			if (VertexNum < VertsRequested )
			{
				FMeshVert* MeshVertex = &Verts( iFrameOffset );
				for( INT i=VertexNum; i<VertsRequested; i++ )
				{
					CachedVerts[i]= FVector( MeshVertex[i].X, MeshVertex[i].Y, MeshVertex[i].Z );
				}
				VertexNum = VertsRequested;
				LODRequest = VertexNum - SpecialVerts; 
				FrameHdr->CachedLodVerts = VertexNum;   
			}
		}
		
		// Special case Alpha 0.
		if (Alpha <= 0.0f)
		{
			for( INT i=0; i<VertexNum; i++ )
			{
				*ResultVerts = (CachedVerts[i] - Origin).TransformPointBy(Coords);
				*(BYTE**)&ResultVerts += Size;
			}
		}
		else
		{
			// Tween all points between cached value and new one.
			FMeshVert* MeshVertex = &Verts( iFrameOffset );
			for( INT i=0; i<VertexNum; i++ )
			{
				FVector V2( MeshVertex[i].X, MeshVertex[i].Y, MeshVertex[i].Z );
				CachedVerts[i] += (V2 - CachedVerts[i]) * Alpha;
				*ResultVerts = (CachedVerts[i] - Origin).TransformPointBy(Coords);
				*(BYTE**)&ResultVerts += Size;
			}
		}
		// Update cached frame.
		FrameHdr->CachedFrame = AnimOwner->AnimFrame;
	}

	Item->Unlock();
	unguardobj;
}
#endif //XC_RENDER_API

