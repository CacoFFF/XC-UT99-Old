/*=============================================================================
	UnXC_Math.h: XC_Core shared FPU/SSE math library
=============================================================================*/

#ifndef INC_XC_MATH
#define INC_XC_MATH

/** This instruction copies the first element of an array onto the xmm0 register once populated
movss xmm0, [a]
shufps xmm0, xmm0, 0
(generates a,a,a,a )
*/


//Use unaligned loading
enum EUnsafe   {E_Unsafe  = 1};


#define appInvSqrt(a) _appInvSqrt(a)

MS_ALIGN(16) struct SSEMask
{
	DWORD Vectors[4];
	SSEMask( DWORD inX=0 , DWORD inY=0, DWORD inZ=0, DWORD inW=0)
	{
		Vectors[0] = inX;
		Vectors[1] = inY;
		Vectors[2] = inZ;
		Vectors[3] = inW;
	}
} GCC_ALIGN(16);

static SSEMask FVector3Mask		= SSEMask(0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF); //AndPS
static SSEMask PlaneDotMask		= SSEMask(0x00000000,0x00000000,0x00000000,0xBF800000); //OrPS
static SSEMask XYMask			= SSEMask(0xFFFFFFFF,0xFFFFFFFF); //AndPS
static SSEMask BadNormal		= SSEMask(0x00000000,0x00000000,0x3DCCCCCD); //MovaPS ( 0.0, 0.0, 0.1, 0.0)

//Align a FVector4 in GCC (bug workaround)
#define GCC_FVector4_ref(a) FLOAT Data_##a[8]; FVector4* a = (FVector4*) (((INT)&Data_##a[4]) & 0xFFFFFFF0);

enum EAxis
{
	AXIS_None	= 0,
	AXIS_X		= 1,
	AXIS_Y		= 2,
	AXIS_Z		= 4,
	AXIS_XY		= AXIS_X|AXIS_Y,
	AXIS_XZ		= AXIS_X|AXIS_Z,
	AXIS_YZ		= AXIS_Y|AXIS_Z,
	AXIS_XYZ	= AXIS_X|AXIS_Y|AXIS_Z,
};

inline FLOAT fast_sign_nozero(FLOAT f)
{
    FLOAT r = 1.0f;
    (INT&)r |= ((INT&)f & 0x80000000); // mask sign bit in f, set it in r if necessary
    return r;
}

// returns 1.0f for positive floats, -1.0f for negative floats, 0.0f for zero
inline FLOAT fast_sign(FLOAT f)
{
	if (((INT&)f & 0x7FFFFFFF)==0)
    	return 0.f; // test exponent & mantissa bits: is input zero?
	else
	{
		FLOAT r = 1.0f;
		(INT&)r |= ((INT&)f & 0x80000000); // mask sign bit in f, set it in r if necessary
		return r;
    }
}

inline FLOAT _Reciprocal( FLOAT F)
{
#if ASM
	FLOAT z;
	__asm
	{
		rcpss    xmm0, F           // x0: z ~= 1/x
		movss    xmm2, F           // x2: x
		movss    xmm1, xmm0        // x1: z ~= 1/x
		addss    xmm0, xmm0        // x0: 2z
		mulss    xmm1, xmm1        // x1: z^2
		mulss    xmm1, xmm2        // x1: xz^2
		subss    xmm0, xmm1        // x0: z' ~= 1/x to 0.000012%
		movss    z, xmm0          
    }
    return z;
#elif ASMLINUX
	//Higor: finally got this working on GCC 2.95
	FLOAT z;
	__asm__ __volatile__("rcpss    %0,%%xmm0\n"
			"movss    %0,%%xmm2\n"
			"movss    %%xmm0,%%xmm1\n"
			"addss    %%xmm0,%%xmm0\n"
			"mulss    %%xmm1,%%xmm1\n"
			"mulss    %%xmm2,%%xmm1\n"
			"subss    %%xmm1,%%xmm0\n" : : "m" (F) );
	__asm__ __volatile__("movss    %%xmm0,%0\n" : "=m" (z) );
	return z;
#else
	return 1.f/F; //ALL ABOARD THE SLOW TRAIN
#endif
}


#if ASM
inline void ASMTransformXY(const FCoords &Coords, const FVector &InVector, FVector &OutVector)
{
	// FCoords is a structure of 4 vectors: Origin, X, Y, Z
	//				 	  x  y  z
	// FVector	Origin;   0  4  8
	// FVector	XAxis;   12 16 20 <= z=0
	// FVector  YAxis;   24 28 32 <= z=0
	// FVector  ZAxis;   36 40 44 <= unused
	//
	//	task:	Temp = ( InVector - Coords.Origin );
	//			Outvector.X = (Temp | Coords.XAxis);
	//			Outvector.Y = (Temp | Coords.YAxis);
	//			Outvector.Z = (Temp);
	// Basically, move(X,Y,Z) and rotate(X,Y) a point
	// This is super fast
	__asm
	{
		mov     esi,[InVector]
		mov     edx,[Coords]     
		mov     edi,[OutVector]

		// get source
		fld     dword ptr [esi+0]
		fld     dword ptr [esi+4]
		fld     dword ptr [esi+8] // z y x
		fxch    st(2)     // xyz

		// subtract origin
		fsub    dword ptr [edx + 0]  // xyz
		fxch    st(1)  
		fsub	dword ptr [edx + 4]  // yxz
		fxch    st(2)
		fsub	dword ptr [edx + 8]  // zxy

		fstp	dword ptr [edi+8] // store z, xy
		// duplicate X for transforming
		fld		st(0)			// X X Y
		fmul	dword ptr [edx+12]	//Xx X Y
		fxch	st(1)			//X Xx Y
		fmul	dword ptr [edx+24]	//Xy Xx Y

		// duplicate Y for transforming
		fxch	st(2)			//Y Xx Xy
		fld		st(0)			//Y Y Xx Xy
		fmul	dword ptr [edx+28]	//Yy Y Xx Xy
		fxch	st(1)			//Y Yy Xx Xy
		fmul	dword ptr [edx+16]	//Yx Yy Xx Xy
		
		// sum results (Xx+Yx and Xy+Yy)
		faddp	st(2),st(0)		//Yy  Yx+Xx  Xy
		faddp	st(2),st(0)		//Yx+Xx  Yy+Xy

		// store
		fstp	dword ptr [edi+0]
		fstp	dword ptr [edi+4]
	}
}
#elif ASMLINUX
inline void ASMTransformXY(const FCoords &Coords, const FVector &InVector, FVector &OutVector)
{
	__asm__ __volatile__ ("
		# Get source.
		flds	0(%%esi);			# x
		flds	4(%%esi);			# y x
		flds	8(%%esi);			# z y x
		fxch	%%st(2);

		# Subtract origin.
		fsubs	0(%1);
		fxch	%%st(1);
		fsubs	4(%1);
		fxch	%%st(2);
		fsubs	8(%1);				# z x y

		fstps	8(%%edi);			# store z, xy
		# duplicate X for transforming
		fld		%%st(0); 			# X X Y
		fmuls	12(%1);				# Xx X Y
		fxch	%%st(1);			# X Xx Y
		fmuls	24(%1);				# Xy Xx Y

		# duplicate Y for transforming
		fxch	%%st(2);			# Y Xx Xy
		fld		%%st(0);			# Y Y Xx Xy
		fmuls	28(%1);				# Yy Y Xx Xy
		fxch	%%st(1);			# Y Yy Xx Xy
		fmuls	16(%1);				# Yx Yy Xx Xy

		# sum results (Xx+Yx and Xy+Yy)
		faddp	%%st(0),%%st(2);	# Yy  Yx+Xx  Xy
		faddp	%%st(0),%%st(2);	# Yx+Xx  Yy+Xy

		# store
		fstps	0(%%edi);
		fstps	4(%%edi);
	"
	:
	:	"S" (&InVector),
		"q" (&Coords),
		"D" (&OutVector)
	: "memory"
	);
}
#endif

/**
  a	%eax
  b 	%ebx
  c 	%ecx
  d 	%edx
  S	%esi
  D	%edi
*/


//Substracts origin, need version without it
inline FVector TransformPointByXY( const FCoords &Coords, const FVector& Point )
{
#if ASM
	FVector Temp;
	ASMTransformXY( Coords, Point, Temp);
	return Temp;
#elif ASMLINUX
	static FVector VTemp;
	ASMTransformXY( Coords, Point, VTemp);
	return VTemp;
#else
	FVector Temp = Point - Coords.Origin;
	return FVector(	Temp | Coords.XAxis, Temp | Coords.YAxis, Temp);
#endif
}


inline FLOAT _appInvSqrt( FLOAT F )
{
#if ASM
	const FLOAT fThree = 3.0f;
	const FLOAT fOneHalf = 0.5f;
	FLOAT temp;

	__asm
	{
		movss	xmm1,[F]
		rsqrtss	xmm0,xmm1			// 1/sqrt estimate (12 bits)

		// Newton-Raphson iteration (X1 = 0.5*X0*(3-(Y*X0)*X0))
		movss	xmm3,[fThree]
		movss	xmm2,xmm0
		mulss	xmm0,xmm1			// Y*X0
		mulss	xmm0,xmm2			// Y*X0*X0
		mulss	xmm2,[fOneHalf]		// 0.5*X0
		subss	xmm3,xmm0			// 3-Y*X0*X0
		mulss	xmm3,xmm2			// 0.5*X0*(3-Y*X0*X0)
		movss	[temp],xmm3
	}
	return temp;
#elif ASMLINUX
	//Higor: finally got this working on GCC 2.95
	const FLOAT fThree = 3.0f;
	const FLOAT fOneHalf = 0.5f;
	FLOAT temp;

	__asm__ __volatile__("movss    %0,%%xmm1\n"
			"rsqrtss    %%xmm1,%%xmm0\n"
			"movss    %1,%%xmm3\n"
			"movss    %%xmm0,%%xmm2\n"
			"mulss    %%xmm1,%%xmm0\n"
			"mulss    %%xmm2,%%xmm0\n"
			"mulss    %2,%%xmm2\n"
			"subss    %%xmm0,%%xmm3\n"
			"mulss    %%xmm2,%%xmm3\n" : : "m" (F), "m" (fThree), "m" (fOneHalf) );
	__asm__ __volatile__("movss    %%xmm3,%0\n" : "=m" (temp) );
	return temp;
#else
	return 1.0f / appSqrt( F);
#endif
}


inline FVector _UnsafeNormal( const FVector& V)
{
	const FLOAT Scale = _appInvSqrt(V.X*V.X+V.Y*V.Y+V.Z*V.Z);
	return FVector( V.X*Scale, V.Y*Scale, V.Z*Scale );
}

inline FVector _UnsafeNormal2D( const FVector& V)
{
	const FLOAT Scale = _appInvSqrt(V.X*V.X+V.Y*V.Y);
	return FVector( V.X*Scale, V.Y*Scale, 0.f);
}

inline FVector _UnsafeNormal2D( const FLOAT& X, const FLOAT& Y)
{
	const FLOAT Scale = _appInvSqrt(X*X+Y*Y);
	return FVector( X*Scale, Y*Scale, 0.f);
}


///////////////////////////////////////////////////////////////////////
// SSE Vector 4 math
///////////////////////////////////////////////////////////////////////

//Aligned version of FVector
//For use with SSE instructions
#pragma warning (push)
#pragma warning (disable : 4035)
#pragma warning (disable : 4715)
MS_ALIGN(16) class XC_CORE_API FVector4 : public FPlane
{
public:
	FORCEINLINE FVector4() {};
	FORCEINLINE FVector4( FVector inVec, FLOAT inW=0.f)
	: FPlane(inVec,inW)
	{};
	FORCEINLINE FVector4( FLOAT inX, FLOAT inY, FLOAT inZ, FLOAT inW)
	: FPlane( inX, inY, inZ, inW)
	{};
	
	FORCEINLINE FVector4( FLOAT* x, EUnsafe)
	{
		
	}
	
	
		// Accessors.
	FLOAT& GetComp( int i )
	{
		return (&X)[i];
	}
	const FLOAT& GetComp( int i ) const
	{
		return (&X)[i];
	}
	
	FORCEINLINE void SetA( const FVector4& V)
	{
	#if ASM
		__asm
		{
			mov     eax,[this]
			movaps  xmm0,V
			movaps  [eax],xmm0
		}
	#else
		(*this) = FVector4( V.X, V.Y, V.Z, V.W);
	#endif
	}
	
	FORCEINLINE FLOAT Dot4( const FVector4& V) const
	{
		FLOAT Result;
	#if ASM
		__asm
		{
			mov     eax,[V]
			mov     ecx,[this]
			movaps  xmm0,[eax]
			movaps  xmm1,[ecx]
			mulps   xmm0,xmm1
			//Sum all scalars in register x0 (using x1 temp)
			pshufd  xmm1,xmm0,49 // 1->0, 3->2 ...0b00110001 | 0x31
			addps   xmm0,xmm1 // 0+1, xx, 2+3, xx
			pshufd  xmm1,xmm0,2 // 2->0 ...0b00000010 | 0x02
			addss   xmm0,xmm1
			movss   Result,xmm0
		}
/*	#elif ASMLINUX
		__asm__ __volatile__("movaps    (%%eax),%%xmm0 \n"
							"movaps     (%%ecx),%%xmm1 \n"
							"mulps       %%xmm1,%%xmm0 \n"
							"pshufd  $49,%%xmm0,%%xmm1 \n"
							"addps       %%xmm1,%%xmm0 \n"
							"pshufd   $2,%%xmm0,%%xmm1 \n"
							"addss       %%xmm1,%%xmm0 \n" : : "a" (&V), "c" (&X) : "memory"	);
		__asm__ __volatile__("movss      %%xmm0,%0\n" : "=m" (Result) );*/
	#else
		Result = X*V.X + Y*V.Y + Z*V.Z + W*V.W;
	#endif
		return Result;
	}
	
	//Not tested, slower than Dot4?
	FORCEINLINE FLOAT Dot3( const FVector4& V) const
	{
		FLOAT Result;
	#if ASM
		__asm
		{
			mov     eax,[V]
			mov     ecx,[this]
			movaps  xmm0,[eax]
			movaps  xmm1,[ecx]
			mulps   xmm0,xmm1 //All values multiplied
			
			pshufd  xmm2,xmm0,0xE5 //11100101, 1->0
			addss   xmm2,xmm0
			movhlps xmm0,xmm0 //2,3->0,1
			addss   xmm2,xmm0
			movss   Result,xmm0
		}
	#else
		Result = X*V.X + Y*V.Y + Z*V.Z;
	#endif
		return Result;
	}
	
	//Horizontal dot, good for simple orientation checks
	FORCEINLINE FLOAT Dot2( const FVector4& V) const
	{
		FLOAT Result;
	#if ASM
		__asm
		{
			mov     eax,[V]
			mov     ecx,[this]
			movlps  xmm0,[eax]
			movlps  xmm1,[ecx]
			mulps   xmm0,xmm1 //All values multiplied
			
			//Sum all scalars in register x0 (using x1 temp)
			pshufd  xmm1,xmm0,1 // 1->0 ...0b00000001 | 0x01
			addss   xmm0,xmm1 // 0+1
			movss   Result,xmm0
		}
	#else
		Result = X*V.X + Y*V.Y;
	#endif
		return Result;
	}
	
	//Aligned fast SSE Norm of horizontal coordinates
	//Useful for Z gravity problems and cylinder physics
	FORCEINLINE FLOAT NormXY() const
	{
	#if ASM
		FLOAT Result;
		__asm
		{
			mov      eax,[this]
			movlps   xmm0,[eax]
			mulps    xmm0,xmm0
			pshufd   xmm1,xmm0,1	// 1->0 ... 0b00000001 | 0x01 | send Y(0) into X(1)
			addss    xmm1,xmm0
			sqrtss   xmm1,xmm1
			movss    Result,xmm1
		}
		return Result;
	#else
		return Size2D();
	#endif
	}
	
	//Aligned fast SSE Norm of coordinates
	//Useful for getting the Sphere radius of a Cylinder extent
	FORCEINLINE FLOAT NormXZ() const
	{
	#if ASM
		FLOAT Result;
		__asm
		{
			mov      eax,[this]
			movaps   xmm0,[eax]
			mulps    xmm0,xmm0
			pshufd   xmm1,xmm0,2	// 2->0 ... 0b00000010 | 0x02 | send Z(0) into X(1)
			addss    xmm1,xmm0
			sqrtss   xmm1,xmm1
			movss    Result,xmm1
		}
		return Result;
	#else
		return appSqrt(X*X+Z*Z);
	#endif
	}

	//No FPU allocation, faster than _UnsafeNormal
	FORCEINLINE FVector4 UnsafeNormal3( FLOAT InW=0.f)
	{
	#if ASM
		const FLOAT fThree = 3.0f;
		const FLOAT fOneHalf = 0.5f;
		FVector4 Result;
		__asm
		{
			mov     eax,[this]
			movaps  xmm4,[eax]
			andps   xmm4,FVector3Mask //Eliminate W
			movaps  xmm1,xmm4
			mulps   xmm1,xmm1 //x1: V*V
			//Sum all scalars in register x1 (using x2 temp)
			pshufd  xmm2,xmm1,49 // 1->0, 3->2 ...0b00110001 | 0x31
			addps   xmm1,xmm2 // 0+1, xx, 2+3, xx
			pshufd  xmm2,xmm1,2 // 2->0 ...0b00000010 | 0x02
			addss   xmm1,xmm2
			//InvSqrt now
			rsqrtss	xmm0,xmm1			// 1/sqrt estimate (12 bits)
			// Newton-Raphson iteration (X1 = 0.5*X0*(3-(Y*X0)*X0))
			movss	xmm3,[fThree]
			movss	xmm2,xmm0
			mulss	xmm0,xmm1			// Y*X0
			mulss	xmm0,xmm2			// Y*X0*X0
			mulss	xmm2,[fOneHalf]		// 0.5*X0
			subss	xmm3,xmm0			// 3-Y*X0*X0
			mulss	xmm3,xmm2			// 0.5*X0*(3-Y*X0*X0)
			shufps  xmm3,xmm3,0	//x3: Broadcast to all DWORDs
			mulps   xmm4,xmm3
			movaps  Result,xmm4
		}
		Result.W = InW;
		return Result;
//	#elif ASMLINUX
	//PORT THIS!!!!
	#else
		return FVector4( UnsafeNormal(), InW);
	#endif
	}
	
	//Attempt to safely normalize this Vector4 into a (x,y,0,0)
	FORCEINLINE UBOOL NormalizeXY()
	{
	#if ASM
		const FLOAT Delta = DELTA;
		const FLOAT fThree = 3.0f;
		const FLOAT fOneHalf = 0.5f;
		__asm
		{
			mov      ecx,[this]
			movaps   xmm4,[ecx]		//this
			movaps   xmm0,xmm4
			mulps    xmm0,xmm0		//V*V
			pshufd   xmm1,xmm0,1	// 1->0 ... 0b00000001 | 0x01 | send Y(0) into X(1)
			addss    xmm0,xmm1		//x*x + y*y
			movss    xmm1,xmm0		//x*x + y*y (copy)
			cmpss    xmm0,Delta,5	//x0: Not less than: (xx+yy >= Delta) = 0xFFFFFFFF
			movd     eax,xmm0		//Return value
			test     eax,eax		//Bitwise and
			jz       EndFunction	//xx+yy < Delta, do not normalize
			
			andps    xmm4,XYMask	//Remove z,w
			rsqrtss  xmm0,xmm1		// 1/sqrt estimate (12 bits)

			// Newton-Raphson iteration (X1 = 0.5*X0*(3-(Y*X0)*X0))
			movss	xmm3,[fThree]
			movss	xmm2,xmm0
			mulss	xmm0,xmm1			// Y*X0
			mulss	xmm0,xmm2			// Y*X0*X0
			mulss	xmm2,[fOneHalf]		// 0.5*X0
			subss	xmm3,xmm0			// 3-Y*X0*X0
			mulss	xmm3,xmm2			// 0.5*X0*(3-Y*X0*X0)
			shufps  xmm3,xmm3,0			// Fill up xmm3
			mulps   xmm4,xmm3
			movaps  [ecx],xmm4			//Store X,Y normalized vector4
		EndFunction:
		}
	#else
		FLOAT SquareSum = (X*X+Y*Y);
		if ( SquareSum < DELTA )
		{
			SetA( *(FVector4*)&BadNormal);
			return 0;
		}
		*this = _UnsafeNormal2D( *this);
		W = 0.f;
		return 1;
	#endif
	}
	//Completely ignores W
	FORCEINLINE UBOOL InCylinder( const FVector4* CC, const FVector4* Extent) const
	{
	#if ASM
		__asm
		{
			mov      eax,[this]
			mov      ecx,[CC]
			mov      edx,[Extent]
			movaps   xmm0,[eax]
			movaps   xmm1,[ecx]
			movaps   xmm2,[edx]
			subps    xmm0,xmm1		//x0: relative point
			mulps    xmm2,xmm2		//x2: relative point squared
			mulps    xmm0,xmm0		//x0: extent squared
			pshufd   xmm1,xmm0,1	//x1: 1->0 | 0b00000001 | 0x01 | send Y to X
			addss    xmm0,xmm1		//x0: sq(x) + sq(x) on X, sq(z) on Z
			cmpps    xmm0,xmm2,5	//x0: Not less than: (Check >= Extent) = 0xFFFFFFFF
			pshufd   xmm1,xmm0,2	//x1: 2->0 | 0b00000010 | 0x02 | send Z to X
			cmpss    xmm0,xmm1,7	//x0: 0xFFFFFFFF if both are zero (Check < Extent)
			movd     eax,xmm0		//Return value
		}
	#else
		return ( Square( X - CC->X) + Square( Y - CC->Y) < Square( Extent->X)) &&
				(Square( CC->Z - Z) < Square( Extent->Z) );
	#endif
	}
	FORCEINLINE UBOOL InCylinder( const FVector4* Extent) const
	{
	#if ASM
		__asm
		{
			mov      eax,[this]
			mov      edx,[Extent]
			movaps   xmm0,[eax]
			movaps   xmm2,[edx]
			mulps    xmm0,xmm0		//x2: relative point squared
			mulps    xmm2,xmm2		//x0: extent squared
			pshufd   xmm1,xmm0,1	//x1: 1->0 | 0b00000001 | 0x01 | send Y to X
			addss    xmm0,xmm1		//x0: sq(x) + sq(x) on X, sq(z) on Z
			cmpps    xmm0,xmm2,5	//x0: Not less than: (Check >= Extent) = 0xFFFFFFFF
			pshufd   xmm1,xmm0,2	//x1: 2->0 | 0b00000010 | 0x02 | send Z to X
			cmpss    xmm0,xmm1,7	//x0: 0xFFFFFFFF if both are zero (Check < Extent)
			movd     eax,xmm0		//Return value
		}
	#else
		return ( Square( X) + Square( Y) < Square( Extent->X)) && (Square( Z) < Square( Extent->Z) );
	#endif
	}
} GCC_ALIGN(16);
#pragma warning (pop)

#pragma warning (push)
#pragma warning (disable : 4035)
#pragma warning (disable : 4715)
//Checks if a given point is within a triangle ABC, make sure all have same W.
inline UBOOL PointInTriangle( const FVector4* P, const FVector4* A, const FVector4* B, const FVector4* C)
{
#if ASM
	const FLOAT fZero = 0.f;
	const FLOAT fOne = 1.f;
	__asm
	{
		mov      eax,[A]
		mov      ecx,[B]
		mov      edx,[C]
		mov      edi,[P]
		movaps   xmm0,[eax]		//x0: A
		movaps   xmm1,[ecx]		//x1: B
		movaps   xmm2,[edi]		//x2: P
		movaps   xmm3,[edx]		//x3: C
		subps    xmm1,xmm0		//x1: B-A (v1)
		subps    xmm2,xmm0		//x2: P-A (v2)
		subps    xmm3,xmm0		//x3: C-A (v0)
		//Smart calculation of v*v while eliminating unused variables at the same time
		movaps   xmm0,xmm3		//x0: v0
		movaps   xmm4,xmm2		//x4: v2
		mulps    xmm2,xmm0		//x2: v0*v2
		mulps    xmm4,xmm1		//x4: v1*v2
		movaps   xmm3,xmm1		//x3: v1
		mulps    xmm3,xmm3		//x3: v1*v1
		mulps    xmm1,xmm0		//x1: v0*v1
		mulps    xmm0,xmm0		//x0: v0*v0
		
		//Sum all scalars in registers (x0-x4) using x5 temp
		pshufd   xmm5,xmm0,49
		addps    xmm0,xmm5
		pshufd   xmm5,xmm0,2
		addss    xmm0,xmm5		//x0: Dot(v0,v0)
		pshufd   xmm5,xmm1,49
		addps    xmm1,xmm5
		pshufd   xmm5,xmm1,2
		addss    xmm1,xmm5		//x1: Dot(v0,v1)
		pshufd   xmm5,xmm2,49
		addps    xmm2,xmm5
		pshufd   xmm5,xmm2,2
		addss    xmm2,xmm5		//x2: Dot(v0,v2)
		pshufd   xmm5,xmm3,49
		addps    xmm3,xmm5
		pshufd   xmm5,xmm3,2
		addss    xmm3,xmm5		//x3: Dot(v1,v1)
		pshufd   xmm5,xmm4,49
		addps    xmm4,xmm5
		pshufd   xmm5,xmm4,2
		addss    xmm4,xmm5		//x4: Dot(v1,v2)

		movss    xmm5,xmm0
		movss    xmm6,xmm1
		mulss    xmm5,xmm3		//x5: dot00*dot11
		mulss    xmm6,xmm6		//x6: dot01*dot01
		subss    xmm5,xmm6		//x5: dot00*dot11 - dot01*dot01
		rcpss    xmm5,xmm5		//x5: invdenom (1/x5)
		mulss    xmm3,xmm2		//x3: dot11*dot02 (dot11 not used anymore)
		mulss    xmm2,xmm1		//x2: dot01*dot02 (dot02 not used anymore)
		mulss    xmm1,xmm4		//x1: dot01*dot12 (dot01 not used anymore)
		mulss    xmm4,xmm0		//x4: dot00*dot12 (dot00 and dot12 not used anymore)
		subss    xmm3,xmm1		//x3: dot11*dot02 - dot01*dot12
		subss    xmm4,xmm2		//x4: dot00*dot12 - dot01*dot02
		mulss    xmm3,xmm5		//x3: u
		mulss    xmm4,xmm5		//x4: v
		movss    xmm5,xmm4
		addss    xmm5,xmm3		//x5: u+v
		
		cmpss    xmm5,fOne,5	//x5: !(u+v < 1)
		cmpss    xmm3,fZero,1	//x3: (u < 0)
		cmpss    xmm4,fZero,1	//x4: (v < 0)
		//Positive results mean -1.#QNAN (0xFFFFFFFF)
		//Since we're doing reverse evaluation, we expect 0x00000000 on all 3 results
		cmpss    xmm5,xmm4,3	//x5: (x5 == NaN || x4 == Nan) >>> 0x00000000 if no NaN's
		cmpss    xmm5,xmm3,7	//x5: (x5 != NaN && x3 != Nan) >>> 0xFFFFFFFF if no NaN's
		movd     eax,xmm5		//Return value
	}
#else
	FVector v0( C->X - A->X, C->Y - A->Y, C->Z - A->Z);
	FVector v1( B->X - A->X, B->Y - A->Y, B->Z - A->Z);
	FVector v2( P->X - A->X, P->Y - A->Y, P->Z - A->Z);
	FLOAT dot00 = v0 | v0;
	FLOAT dot01 = v0 | v1;
	FLOAT dot02 = v0 | v2;
	FLOAT dot11 = v1 | v1;
	FLOAT dot12 = v1 | v2;
	FLOAT invDenom = 1 / (dot00 * dot11 - dot01 * dot01);
	FLOAT u = (dot11 * dot02 - dot01 * dot12) * invDenom;
	FLOAT v = (dot00 * dot12 - dot01 * dot02) * invDenom;
	return (u >= 0) && (v >= 0) && (u + v < 1);
#endif
}
#pragma warning (pop)


// Measure a line using a Dir vector, all data needs to be 16-aligned
// Make sure Dir.W = 0, or Start.W = End.W
inline FLOAT LengthUsingDirA( const FVector4* Start, const FVector4* End, const FVector4* Dir)
{
	FLOAT MaxDist;
#if ASM
	__asm
	{
		mov      eax,[Start]
		mov      ecx,[End]
		mov      edx,[Dir]
		movaps   xmm0,[eax]
		movaps   xmm1,[ecx]
		movaps   xmm2,[edx]
		subps    xmm1,xmm0
		mulps    xmm1,xmm2
		//Sum all scalars in register x1 (using x2 temp)
		pshufd   xmm2,xmm1,49 // 1->0, 3->2 ...0b00110001 | 0x31
		addps    xmm1,xmm2 // 0+1, xx, 2+3, xx
		pshufd   xmm2,xmm1,2 // 2->0 ...0b00000010 | 0x02
		addss    xmm1,xmm2
		movss    MaxDist,xmm1
	}
/*#elif ASMLINUX
	__asm__ __volatile__("movaps    (%%eax),%%xmm0 \n"
						"movaps     (%%ecx),%%xmm1 \n"
						"movaps     (%%edx),%%xmm2 \n"
						"subps       %%xmm0,%%xmm1 \n"
						"mulps       %%xmm2,%%xmm1 \n"
						"pshufd  $49,%%xmm1,%%xmm2 \n"
						"addps       %%xmm2,%%xmm1 \n"
						"pshufd   $2,%%xmm1,%%xmm2 \n"
						"addss       %%xmm2,%%xmm1 \n" : : "a" (Start), "c" (End), "d" (Dir) : "memory"	);
	__asm__ __volatile__("movss      %%xmm1,%0\n" : "=m" (MaxDist) );*/
#else
	MaxDist = (End->X-Start->X)*Dir->X
			+ (End->Y-Start->Y)*Dir->Y
			+ (End->Z-Start->Z)*Dir->Z;
#endif
	return MaxDist;
}

// Measure a line using a Dir vector, all data needs to be 16-aligned (except Dir)
// Make sure Dir.W = 0, or Start.W = End.W
inline FLOAT LengthUsingDir2D( const FVector4* Start, const FVector4* End, const FVector* Dir)
{
	FLOAT MaxDist;
#if ASM
	__asm
	{
		mov      eax,[Start]
		mov      ecx,[End]
		mov      edx,[Dir]
		movaps   xmm0,[eax]
		movaps   xmm1,[ecx]
		movlps   xmm2,[edx]
		subps    xmm1,xmm0
		mulps    xmm1,xmm2
		//Sum low 2 scalars in register x1 (using x2 temp)
		pshufd   xmm2,xmm1,1 // 1->0 ...0b00000001 | 0x01
		addss    xmm1,xmm2 // 0+1
		movss    MaxDist,xmm1
	}
#else
	MaxDist = (End->X-Start->X)*Dir->X
			+ (End->Y-Start->Y)*Dir->Y;
#endif
	return MaxDist;
}

//Use this overload with care
inline FLOAT LengthUsingDir2D( const FVector4* Start, const FVector4* End, const FLOAT* Dir)
{
	return LengthUsingDir2D( Start, End, (FVector*)Dir);
}

// Does PlaneDot on both Start and End on the same plane (Unaligned plane)
// Dist must be a FLOAT[2] array
inline void DoublePlaneDotU( const FPlane* Plane, const FVector4* Start, const FVector4* End, FLOAT* Dist)
{
#if ASM
		__asm
		{
			mov      eax,[End]		//Get address of End vector
			mov      edi,[Start]	//Get address of Start vector
			mov      ecx,[Plane]	//Get address of node Plane
			mov      edx,[Dist]		//Get address of Dist array
			movaps   xmm0,[eax]		//x0: End
			movaps   xmm1,[edi]		//x1: Start
			movups   xmm2,[ecx]		//x2: Plane, not aligned
			mulps    xmm0,xmm2		//x0: (End * Plane)(X,Y,Z,W) >>>> [E]
			mulps    xmm1,xmm2		//x1: (Start * Plane)(X,Y,Z,W) >> [S]

			//Sum all scalars in register x0 (using x2 temp)
			pshufd xmm2,xmm0,49 // 1->0, 3->2 ...0b00110001 | 0x31
			addps xmm0,xmm2 // 0+1, xx, 2+3, xx
			movhlps xmm2,xmm0 //2,3 -> 0,1
			addss xmm0,xmm2
			
			//Sum all scalars in register x1 (using x2 temp)
			pshufd xmm2,xmm1,49 // 1->0, 3->2 ...0b00110001 | 0x31
			addps xmm1,xmm2 // 0+1, xx, 2+3, xx
			movhlps xmm2,xmm1 //2,3 -> 0,1
			addss xmm1,xmm2
			
			movss [edx+0],xmm1
			movss [edx+4],xmm0

/*			movhlps   xmm2,xmm0		//x2: | E.Z | E.W | ... | ... |
			movlhps   xmm0,xmm1		//x0: | E.X | E.Y | S.X | S.Y |
			movlps    xmm1,xmm2		//x1: | E.Z | E.W | S.Z | S.W |
			addps     xmm0,xmm1		//x0: |EX+EZ|EY+EW|SX+SZ|SY+SW|
			shufps    xmm0,xmm0,114	//x0: |SX+SZ|EX+EZ|SY+SW|EY+EW| (0b01110010) (0>1)(1>3)(2>0)(3>2)
			movhlps   xmm2,xmm0		//x2: |SY+SW|EY+EE| ... | ... |
			addps     xmm0,xmm2		//x0+x2: |S|E|.|.|
			movlps   [edx],xmm0		//Store: D[0]=S, D[1]=E
*/		}
#elif ASMLINUX
		__asm__ __volatile__("movaps    (%%eax),%%xmm0 \n"
							"movaps     (%%edi),%%xmm1 \n"
							"movups     (%%ecx),%%xmm2 \n"
							"mulps       %%xmm2,%%xmm0 \n"
							"mulps       %%xmm2,%%xmm1 \n"
							"pshufd  $49,%%xmm0,%%xmm2 \n"
							"addps       %%xmm2,%%xmm0 \n"
							"movhlps     %%xmm0,%%xmm2 \n"
							"addss       %%xmm2,%%xmm0 \n"
							"pshufd  $49,%%xmm1,%%xmm2 \n"
							"addps       %%xmm2,%%xmm1 \n"
							"movhlps     %%xmm1,%%xmm2 \n"
							"addss       %%xmm2,%%xmm1 \n"
							"movss       %%xmm1,0(%%edx)\n"
							"movss       %%xmm0,4(%%edx)\n" //Bah, there was a bug here
		: :	"a" (End), "D" (Start), "c" (Plane), "d" (Dist) : "memory"	);
//		__asm__ __volatile__("movss      %%xmm1,%0 \n"	: "=m" (Dist1) );
//		__asm__ __volatile__("movss      %%xmm0,%0 \n"	: "=m" (Dist2) );
#else
		Dist[0] = Plane->PlaneDot(*Start);
		Dist[1] = Plane->PlaneDot(*End  );
#endif
}


// Does PlaneDot on both Start and End on the same plane (Aligned plane)
// Dist must be a FLOAT[2] array
inline void DoublePlaneDotA( const FVector4* Plane, const FVector4* Start, const FVector4* End, FLOAT* Dist)
{
#if ASM
		__asm
		{
			mov      eax,[End]		//Get address of End vector
			mov      edi,[Start]	//Get address of Start vector
			mov      ecx,[Plane]	//Get address of node Plane
			mov      edx,[Dist]		//Get address of Dist array
			movaps   xmm0,[eax]		//x0: End
			movaps   xmm1,[edi]		//x1: Start
			movaps   xmm2,[ecx]		//x2: Plane, not aligned
			mulps    xmm0,xmm2		//x0: (End * Plane)(X,Y,Z,W)
			mulps    xmm1,xmm2		//x1: (Start * Plane)(X,Y,Z,W)

			//Sum all scalars in register x0 (using x2 temp)
			pshufd xmm2,xmm0,49 // 1->0, 3->2 ...0b00110001 | 0x31
			addps xmm0,xmm2 // 0+1, xx, 2+3, xx
			movhlps xmm2,xmm0 //2,3 -> 0,1
			addss xmm0,xmm2
			
			//Sum all scalars in register x1 (using x2 temp)
			pshufd xmm2,xmm1,49 // 1->0, 3->2 ...0b00110001 | 0x31
			addps xmm1,xmm2 // 0+1, xx, 2+3, xx
			movhlps xmm2,xmm1 //2,3 -> 0,1
			addss xmm1,xmm2
			
			movss [edx+0],xmm1
			movss [edx+4],xmm0 
		}
#elif ASMLINUX
		__asm__ __volatile__("movaps    (%%eax),%%xmm0 \n"
							"movaps     (%%edi),%%xmm1 \n"
							"movaps     (%%ecx),%%xmm2 \n"
							"mulps       %%xmm2,%%xmm0 \n"
							"mulps       %%xmm2,%%xmm1 \n"
							"pshufd  $49,%%xmm0,%%xmm2 \n"
							"addps       %%xmm2,%%xmm0 \n"
							"movhlps     %%xmm0,%%xmm2 \n"
							"addss       %%xmm2,%%xmm0 \n"
							"pshufd  $49,%%xmm1,%%xmm2 \n"
							"addps       %%xmm2,%%xmm1 \n"
							"movhlps     %%xmm1,%%xmm2 \n"
							"addss       %%xmm2,%%xmm1 \n"
							"movss       %%xmm1,0(%%edx)\n"
							"movss       %%xmm0,4(%%edx)\n"
		: :	"a" (End), "D" (Start), "c" (Plane), "d" (Dist) : "memory"	);
//		__asm__ __volatile__("movss      %%xmm1,%0 \n"	: "=m" (Dist1) );
//		__asm__ __volatile__("movss      %%xmm0,%0 \n"	: "=m" (Dist2) );*/
#else
		Dist[0] = Plane->PlaneDot(*Start);
		Dist[1] = Plane->PlaneDot(*End  );
#endif
}

//Obtains intersection using distances to plane as alpha (optimal for traces), W = -1.f by default
//Use DoublePlaneDot to obtain the Dist array
inline FVector4 FLinePlaneIntersectDist( const FVector4* Start, const FVector4* End, FLOAT* Dist, FLOAT W=-1.f)
{
#if ASM
	FVector4 Middle;
	__asm
	{
		mov      eax,[End]		//Get address of End vector
		mov      ecx,[Start]	//Get address of Start vector
		mov      edx,[Dist]		//Get address of Dist array
		movaps   xmm0,[eax]		//x0: End
		movaps   xmm1,[ecx]		//x1: Start
		movss    xmm2,[edx+0]	//x2: Dist[0]
		movss    xmm3,[edx+4]	//x3: Dist[1]

		subss    xmm3,xmm2		//x3: Dist[1]-Dist[0]
		divss    xmm2,xmm3		//x2: Dist[0] / (Dist[1]-Dist[0]) >>>> Low prec
		shufps   xmm2,xmm2,0	//x2: Populate all DWORDS
		subps    xmm0,xmm1		//x0: End-Start
		mulps    xmm2,xmm0		//x2: End-Start * (Dist[0] / (Dist[1]-Dist[0]))
		subps    xmm1,xmm2		//x1: Intersection
		movaps   Middle,xmm1
	}
#elif ASMLINUX
	static FVector4 Middle; //Unaligned in GCC (?)
	__asm__ __volatile__(
		"movaps    (%%eax),%%xmm0 \n"
		"movaps    (%%ecx),%%xmm1 \n"
		"movss    0(%%edx),%%xmm2 \n"
		"movss    4(%%edx),%%xmm2 \n"
		"subss      %%xmm2,%%xmm3 \n"
		"divss      %%xmm3,%%xmm2 \n"
		"shufps  $0,%%xmm2,%%xmm2 \n"
		"subps      %%xmm1,%%xmm0 \n"
		"mulps      %%xmm0,%%xmm2 \n"
		"subps      %%xmm2,%%xmm1 \n" : : "a" (End), "c" (Start), "d" (Dist) : "memory"	);
	__asm__ __volatile__(	"movups      %%xmm1,%0 \n" : "=m" (Middle) );
#else
	FLOAT Alpha = Dist[0] * _Reciprocal(Dist[1]-Dist[0]);
	FVector4 Middle;
	Middle.X    = Start->X - (End->X-Start->X) * Alpha;
	Middle.Y    = Start->Y - (End->Y-Start->Y) * Alpha;
	Middle.Z    = Start->Z - (End->Z-Start->Z) * Alpha;
#endif
	Middle.W = W;
	return Middle;
}


//Construct a FVector4 plane using SSE instructions
inline void SSE_MakeFPlaneA( FVector4* A, FVector4* B, FVector4* C, FVector4* Plane)
{
	
#if ASM
	const FLOAT AvoidUnsafe = 0.0001f;
	const FLOAT fThree = 3.0f;
	const FLOAT fOneHalf = 0.5f;
	__asm
	{
		mov      eax,[A]
		mov      ecx,[B]
		mov      edx,[C]
		movaps   xmm0,[eax]		//x0: A
		movaps   xmm1,[ecx]		//x1: B
		movaps   xmm2,[edx]		//x2: C
		subps    xmm1,xmm0		//x1: B-A
		subps    xmm2,xmm0		//x2: C-A
		movaps   xmm3,xmm1		//x3: x1 copy
		movaps   xmm4,xmm2		//x4: x2 copy

		shufps   xmm1,xmm1,0xD8	// 11 01 10 00  Flip the middle elements of x1
		shufps   xmm2,xmm2,0xE1	// 11 10 00 01  Flip first two elements of x2
		mulps    xmm1,xmm2		//x1: First part of cross product
		shufps   xmm3,xmm3,0xE1	// 11 10 00 01  Flip first two elements of the x1 copy
		shufps   xmm4,xmm4,0xD8	// 11 01 10 00  Flip the middle elements of the x2 copy
		mulps    xmm3,xmm4		//x3: Substract part of cross product
              
		subps    xmm1,xmm3		//x1: (B-A)^(C-A)
		andps    xmm1,FVector3Mask //x1: Zero 4th coord
		
		//Debug:
		shufps   xmm1,xmm1,0xC6	//x1: Swap X and Z (bad shuffles above, fixing here)
		
		//Normalize:
		movaps   xmm2,xmm1		//x2: x1 copy
		mulps    xmm2,xmm1		//x2: x1 squared coordinates
			//Sum all scalars in register x2 (using x3 temp)
		pshufd   xmm3,xmm2,49	// 1->0, 3->2 ...0b00110001 | 0x31
		addps    xmm2,xmm3		// 0+1, xx, 2+3, xx
		movhlps  xmm3,xmm2		// 2,3 -> 0,1
//		pshufd   xmm3,xmm2,2	// 2->0 ...0b00000010 | 0x02
		addps    xmm2,xmm3		//x2: VSizeSQ( (B-A)^(C-A) )
		addss    xmm2,AvoidUnsafe //Make normalization safe

		rsqrtss  xmm5,xmm2		//x5: 1/VSize( (B-A)^(C-A) ) -> low prec
		
		// Newton-Raphson iteration (X1 = 0.5*X0*(3-(Y*X0)*X0))
		movss    xmm3,fThree
		movss    xmm4,xmm5
		mulss    xmm5,xmm2
		mulss    xmm5,xmm4
		mulss    xmm4,fOneHalf
		subss    xmm3,xmm5
		mulss    xmm3,xmm4
		movss    xmm2,xmm3 //x2: high prec now
		//movss    xmm2,xmm5

		shufps   xmm2,xmm2,0	//x2: Populate all DWords in the register
		mulps    xmm1,xmm2		//x1: Normalize cross product
		mov      eax,[Plane]	//EAX: plane address
		movaps   [eax],xmm1     //Store the plane normal
		mulps    xmm0,xmm1		//x0: (A * CrossNorm)

			//Sum all scalars in register x0 (using x3 temp)
		pshufd   xmm3,xmm0,49	// 1->0, 3->2 ...0b00110001 | 0x31
		addps    xmm0,xmm3		// 0+1, xx, 2+3, xx
		movhlps  xmm3,xmm0		// 2,3 -> 0,1
//		pshufd   xmm3,xmm0,2	// 2->0 ...0b00000010 | 0x02
		addps    xmm0,xmm3		//x0: (A dot CrossNorm)
		add      eax,12			//EAX: Plane.W address
		movss    [eax],xmm0
	}
#else
	*Plane = FPlane(*A,*B,*C);
#endif
}

/** Linux constraints
  a	%eax
  b	%ebx
  c	%ecx
  d	%edx
  S	%esi
  D	%edi
*/

#endif