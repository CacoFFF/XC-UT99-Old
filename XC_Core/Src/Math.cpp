
#include "XC_Core.h"
#include "UnXC_Math.h"
#include "Cacus/Math/Constants.h"


static CFVector4 WMinusOne( 0, 0, 0, -1);

// Does PlaneDot on both Start and End on the same plane (Unaligned plane)
// Dist must be a FLOAT[2] array
void DoublePlaneDot( const FPlane& Plane, const CFVector4& Start, const CFVector4& End, FLOAT* Dist2)
{
#if ASMLINUX
	__asm__ __volatile__(
		"movups         %0,%%xmm0 \n"
		"movups         %1,%%xmm1 \n"
		"movups    (%%eax),%%xmm4 \n" : : "m"(WMinusOne), "m"(CIVector4::MASK_3D), "a"(&Plane) );
	__asm__ __volatile__(
		"movups    (%%eax),%%xmm2 \n" : : "a"(&Start) );
	__asm__ __volatile__(
		"movups    (%%eax),%%xmm3 \n" : : "a"(&End) );
	__asm__ __volatile__(
		"andps      %%xmm1,%%xmm2 \n"
		"orps       %%xmm0,%%xmm2 \n"
		"mulps      %%xmm4,%%xmm2 \n"

		"andps      %%xmm1,%%xmm3 \n"
		"orps       %%xmm0,%%xmm3 \n"
		"mulps      %%xmm4,%%xmm3 \n"

		"movaps     %%xmm2,%%xmm0 \n"
		"shufps $177,%%xmm2,%%xmm0 \n"
		"movaps     %%xmm0,%%xmm1 \n"
		"addps      %%xmm2,%%xmm1 \n"
		"movhlps    %%xmm1,%%xmm0 \n"
		"addss      %%xmm0,%%xmm1 \n"
		"movss      %%xmm1,0(%%eax) \n"

		"movaps     %%xmm3,%%xmm0 \n"
		"shufps $177,%%xmm3,%%xmm0 \n"
		"movaps     %%xmm0,%%xmm1 \n"
		"addps      %%xmm3,%%xmm1 \n"
		"movhlps    %%xmm1,%%xmm0 \n"
		"addss      %%xmm0,%%xmm1 \n"
		"movss      %%xmm1,4(%%eax) \n" : : "a"(Dist2) : "memory");
#else
	CFVector4 VPlane( &Plane.X);
	CFVector4 VStart = _mm_or_ps( _mm_and_ps( Start, CIVector4::MASK_3D), WMinusOne); // Set W to -1
	CFVector4 VEnd   = _mm_or_ps( _mm_and_ps( End  , CIVector4::MASK_3D), WMinusOne); // ORPS has very low latency and CPI
	Dist2[0] = VStart | VPlane;
	Dist2[1] = VEnd   | VPlane;
#endif
}



//Obtains intersection using distances to plane as alpha (optimal for traces)
//Use DoublePlaneDot to obtain the Dist array
CFVector4 LinePlaneIntersectDist( const CFVector4& Start, const CFVector4& End, FLOAT* Dist2)
{
	CFVector4 Middle;
#if ASMLINUX
	__asm__ __volatile__(
		"movups         %0,%%xmm0 \n" //Load End
		"movups         %1,%%xmm1 \n" //Load Start
		"movss    0(%%eax),%%xmm2 \n"
		"movss    4(%%eax),%%xmm3 \n"
		"subss      %%xmm2,%%xmm3 \n"
		"divss      %%xmm3,%%xmm2 \n"
		"shufps  $0,%%xmm2,%%xmm2 \n"
		"subps      %%xmm1,%%xmm0 \n"
		"mulps      %%xmm0,%%xmm2 \n"
		"subps      %%xmm2,%%xmm1 \n" : : "m"(End), "m"(Start), "a" (Dist2) : "memory"	);
	__asm__ __volatile__(	"movups      %%xmm1,%0 \n" : "=m" (Middle) );
#else
	float Alpha = Dist2[0] / (Dist2[1] - Dist2[0]);
	Middle = Start - (End - Start) * Alpha;
#endif
	return Middle;
}

