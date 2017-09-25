#pragma once

#include "PlatformTypes.h"

#include <emmintrin.h>
#include <math.h>


enum EZero    { E_Zero=0 };
enum EStrict  { E_Strict=0 };
enum EInit    { E_Init=0 };
enum ENoZero  { E_NoZero=0 };
enum EStatic3D{ E_Static3D=0 };
enum ENoSSEFPU{ E_NoSSEFPU=0 };
enum EUnsafe  { E_Unsafe=0 };

#define GRIDMATH

//From UE
#define SMALL_NUMBER		(1.e-8f)
#define KINDA_SMALL_NUMBER	(1.e-4f)

struct FVector;

namespace cg
{

	struct Vector;

static uint32 NanMask = 0x7F800000;
typedef MS_ALIGN(16) float floatA GCC_ALIGN(16);
typedef MS_ALIGN(16) int32 intA GCC_ALIGN(16);


inline __m128 _newton_raphson_rsqrtss( __m128 n)
{
	const float three = 3.0f;
	const float onehalf = 0.5f;
	__m128 rsq = _mm_rsqrt_ss( n);
	__m128 b = _mm_mul_ss( _mm_mul_ss(n, rsq), rsq); //N*rsq*rsq
	b = _mm_sub_ss( _mm_load_ss(&three), b); //3-N*rsq*rsq
	return _mm_mul_ss( _mm_load_ss(&onehalf), _mm_mul_ss(rsq, b) ); //0.5 * rsq * (3-N*rsq*rsq)
}

inline __m128 _size_xy_zw( __m128 v)
{
	__m128 vv = _mm_mul_ps( v, v);
	__m128 uu = _mm_castsi128_ps( _mm_shuffle_epi32( _mm_castps_si128(vv), 0b10110001)); //Swap x,y and z,w
	return _mm_add_ss( vv, uu); //xx+yy, yy, zz, ww
}

#define _mm_pshufd_ps(v,i) _mm_castsi128_ps( _mm_shuffle_epi32( _mm_castps_si128(v), i))




//
// 16-aligned SSE integers
//
MS_ALIGN(16) struct DE Integers
{
	int32 i, j, k, l;

	//Constructors
	Integers() {}
	Integers( int32 ii, int32 jj, int32 kk, int32 ll)
		:	i(ii),	j(jj),	k(kk),	l(ll)	{}
	Integers( EZero )
	{	_mm_store_si128( mm(), _mm_setzero_si128() );	}

	const TCHAR* String() const;

	//Accessor
	int32& coord( int32 c)
	{	return (&i)[c];	}

	//This helper function tells the compiler to treat this address as 16-aligned
	inline intA* ia() const
	{
		return (intA*)this;
	}

	inline __m128i* mm() const
	{
		return (__m128i*)this;
	}

	//**************************
	//Basic comparison operators
	bool operator ==(const Integers& I)
	{
		__m128i a, b;
		a = _mm_load_si128(mm());
		b = _mm_load_si128(I.mm());
		__m128i c = _mm_cmpeq_epi32( a, b);
		return _mm_movemask_ps( *(__m128*)&c ) == 0b1111;
	}


	//********************************
	//Basic assignment logic operators
	Integers operator=(const Integers& I)
	{
		_mm_store_si128( mm(), _mm_load_si128( I.mm()) );
		return *this;
	}


	//*********************
	//Basic logic operators
	Integers operator+(const Integers& I) const
	{
		__m128i _V = _mm_add_epi32( _mm_load_si128( mm()), _mm_load_si128(I.mm()));
		return *(Integers*)&_V;
	}

	Integers operator-(const Integers& I) const
	{
		__m128i _V = _mm_sub_epi32( _mm_load_si128( mm()), _mm_load_si128(I.mm()));
		return *(Integers*)&_V;
	}

} GCC_ALIGN(16);


//
// 16-aligned SSE vector
//
MS_ALIGN(16) struct DE Vector
{
	float X, Y, Z, W;

	Vector() 
	{}

	Vector( float iX, float iY, float iZ, float iW = 0)
		: X(iX) , Y(iY) , Z(iZ) , W(iW)
	{}

	Vector( float* f)
	{	_mm_store_ps((float*)this, _mm_loadu_ps(f));	}

	Vector( const FVector& V, EUnsafe)
	{ _mm_store_ps((float*)this, _mm_loadu_ps((float*)&V)); W=0; }

	Vector( float U, EStatic3D)
		: X(U) , Y(U) , Z(U) , W(0)
	{}

	Vector( EZero )
	{
		_mm_store_ps(fa(), _mm_setzero_ps());
	}

	Vector( const __m128& V)
	{
		_mm_store_ps( fa(), V);
	}

	const TCHAR* String() const;

	//This helper function tells the compiler to treat this address as 16-aligned
	inline floatA* fa() const
	{
		return (floatA*)this;
	}

	inline __m128 mm() const
	{
		return *(__m128*)this;
	}

	//*********************
	//Basic arithmetic and logic operators
	Vector operator+(const Vector& V) const
	{
		__m128 _V = _mm_add_ps(_mm_load_ps(fa()), _mm_load_ps(V.fa()));
		return *(Vector*)&_V;
	}

	Vector operator-(const Vector& V) const
	{
		__m128 _V = _mm_sub_ps(_mm_load_ps(fa()), _mm_load_ps(V.fa()));
		return *(Vector*)&_V;
	}

	Vector operator*(const Vector& V) const
	{
		__m128 _V = _mm_mul_ps(_mm_load_ps(fa()), _mm_load_ps(V.fa()));
		return *(Vector*)&_V;
	}

	Vector operator/(const Vector& V) const
	{
		__m128 _V = _mm_div_ps(_mm_load_ps(fa()), _mm_load_ps(V.fa()));
		return *(Vector*)&_V;
	}

	float operator|(const Vector& V) const //DOT4
	{
/*		__m128 _V = _mm_mul_ps(_mm_load_ps(fa()), _mm_load_ps(V.fa()));
		__m128 x = _mm_castsi128_ps( _mm_shuffle_epi32( _mm_castps_si128(_V), 0b11110101)); //Force a PSHUFD (y,y,w,w)
		x = _mm_add_ps( x, _V); //x+y,...,z+w,...
		_V = _mm_movehl_ps( _V, x); //z+w,........
		_V = _mm_add_ss( _V, x);
		float ReturnValue;
		_mm_store_ss( &ReturnValue, _V);
		return ReturnValue;*/
		return X*V.X + Y*V.Y + Z*V.Z;
	}

	Vector operator*(const float F) const
	{
		__m128 _V = _mm_mul_ps(_mm_load_ps(fa()), _mm_load_ps1(&F) );
		return *(Vector*)&_V;
	}

	Vector operator/(const float F) const
	{
		__m128 _V = _mm_div_ps(_mm_load_ps(fa()), _mm_load_ps1(&F) );
		return *(Vector*)&_V;
	}

	Vector operator&(const Integers& I) const
	{
		__m128 _V = _mm_and_ps(_mm_load_ps(fa()), _mm_castsi128_ps(_mm_load_si128( I.mm())) );
		return *(Vector*)&_V;
	}

	Vector operator&(const Vector& V) const
	{
		__m128 _V = _mm_and_ps(_mm_load_ps(fa()), _mm_load_ps(V.fa()) );
		return *(Vector*)&_V;
	}

	//********************************
	//Basic assignment logic operators

	Vector operator-() const
	{
		Integers Mask( 0x80000000, 0x80000000, 0x80000000, 0x80000000);
//		static const __m128 SIGNMASK = _mm_castsi128_ps(_mm_set1_epi32(0x80000000));
		__m128 _V = _mm_xor_ps( _mm_load_ps(((Vector*)(&Mask))->fa()), _mm_load_ps(fa()));
		return *(Vector*)&_V;
	}

	Vector operator=(const Vector& V)
	{
		_mm_store_ps( fa(), _mm_load_ps( V.fa()) );
		return *this;
	}

	Vector operator*=(const Vector& V)
	{	return (*this = *this * V);	}

	Vector operator*=(const float F)
	{	return (*this = *this * F);	}


	//**************************
	//Basic comparison operators
	bool operator<(const Vector& V) const
	{	return _mm_movemask_ps(_mm_cmplt_ps(*(__m128*)this, *(__m128*)&V) ) == 0b1111;	}

	bool operator<=(const Vector& V) const
	{	return _mm_movemask_ps(_mm_cmple_ps(*(__m128*)this, *(__m128*)&V)) == 0b1111;	}


	//**************************
	//Value handling
	//See if contains nan or infinity
	bool IsValid()
	{
		__m128 m = _mm_load_ps1( reinterpret_cast<const float*>(&NanMask) );
		m = _mm_cmpeq_ps( _mm_and_ps( mm(), m), m); //See if (v & m == m)
		return _mm_movemask_ps( m) == 0; //See if none of the 4 values threw a NAN/INF
	}
	//IMPORTANT: SEE IF SSE ORDERED (THAT CHECKS FOR NAN'S) WORKS WITH INFINITY

	//Compute >= in parallel, store in integers
	Integers GreaterThanZeroPS()
	{
		__m128 self = _mm_load_ps( fa() );
		__m128i cmp = _mm_castps_si128( _mm_cmpge_ps(self, _mm_setzero_ps()) );
		cmp = _mm_srli_epi32( cmp, 31);
		return *(Integers*)&cmp;
	}

	//**************************
	//Geometrics

	//Cylinder check against Radius, Height
	bool InCylinder(float Radius, float Height) const //VS2015 generates an unnecessary MOVAPS instruction!
	{
		__m128 v = _mm_load_ps( fa() ); //X,Y,Z,W
		v = _size_xy_zw( v); //XX+YY,YY,ZZ,WW
		__m128 h = _mm_load_ss(&Height); //H,0,0,0
		__m128 r = _mm_load_ss(&Radius); //R,0,0,0
		r = _mm_movelh_ps( r, h); //R,0,H,0
		r = _mm_mul_ps( r, r); //RR,0,HH,0
		v = _mm_cmple_ps( v, r); //C,C,C,C comparison result (C=0 if greater, C=-1 if less or equal)
		return (_mm_movemask_ps(v) & 0b0101) == 0b0101; //See that Horiz,Vert are less than Radius,Height
	}

	//Cylinder check against Radius (infinite height)
	bool InCylinder( float Radius) const
	{
		return X*X+Y*Y < Radius*Radius;
	}

	//Cylinder check against unreal Extent vector
	bool InCylinder( const Vector& Extent) const //FIX THIS
	{
		__m128 v = _mm_load_ps( fa() ); //X,Y,Z,W
		v = _size_xy_zw( v); //XX+YY,YY,ZZ,WW
		__m128 r = _mm_load_ps( Extent.fa() ); //R,R,H,0
		r = _mm_mul_ps( r, r); //RR,RR,HH,0
		v = _mm_cmple_ps( v, r); //C,C,C,C comparison result (C=0 if greater, C=-1 if less or equal)
		return (_mm_movemask_ps(v) & 0b0101) == 0b0101; //See that X,Y,Z are all less or equal
	}

	float SizeSq() const
	{
/*		__m128 v = _mm_load_ps( fa() );
		v = _mm_mul_ps( v, v);
		__m128 w = _mm_pshufd_ps( v, 0b10110001); //Y,X,W,Z
		w = _mm_add_ps( w, w); //Y+X, ..., Z+W, ...
		v = _mm_movehl_ps( v, w);
		v = _mm_add_ss( v, w);
		return v.m128_f32[0];*/
		return X*X+Y*Y+Z*Z;
	}

	uint32 SignBits() //Get sign bits of every component
	{	return _mm_movemask_ps( _mm_load_ps(fa()) );	}

	//**************************
	//Transformations

	Vector Absolute() const
	{
		Integers Mask( 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF);
		__m128 _V = _mm_and_ps( _mm_load_ps(((Vector*)(&Mask))->fa()), _mm_load_ps(fa()) );
		return *(Vector*)&_V;
	}

	//Truncate to 4 integers
	Integers Truncate32()
	{
		__m128 m = _mm_load_ps(fa()); //Load
		__m128i n = _mm_cvttps_epi32( m); //Truncate to integer
		return *(Integers*)&n;
	}

	//Return a normal
	Vector Normal() const
	{
		__m128 a = _mm_load_ps(fa());
		__m128 b = _mm_mul_ps( a, a);
		__m128 c = _mm_shuffle_ps( b, b, 0b00011011);
		c = _mm_add_ps( c, b); //xx+ww, yy+zz, yy+zz, xx+ww
		b = _mm_movehl_ps( b, c);
		c = _mm_add_ss( c, b); //xx+ww+yy+zz
		b = _newton_raphson_rsqrtss( c); //1/sqrt(c)

		 //Need conditional to prevent this from jumping to infinite
		b = _mm_shuffle_ps( b, b, 0b00000000); //Populate YZW with X
		a = _mm_mul_ps( a, b); //Normalized vector
		return *(Vector*)&a;
//		return *this * (1.f/sqrtf(X*X+Y*Y+Z*Z));
	}

	//Return a normal on 2 components
	Vector NormalXY() const
	{
		__m128 a = _mm_load_ps(fa());
		__m128 z = _mm_setzero_ps();
		a = _mm_movelh_ps( a, z); //x,y,0,0
		__m128 b = _mm_mul_ps( a, a); //xx,yy,0,0
		z = _mm_pshufd_ps(b,0b11100001); //yy,xx,0,0
		b = _mm_add_ss( b, z); //c=xx+yy
		b = _newton_raphson_rsqrtss( b); //1/sqrt(c)
										 //Need conditional to prevent this from jumping to infinite
		b = _mm_shuffle_ps( b, b, 0b00000000); //Populate YZW with X
		a = _mm_mul_ps( a, b); //Normalized vector
		return *(Vector*)&a;
		//		return *this * (1.f/sqrtf(X*X+Y*Y+Z*Z));
	}

	//Fast 1/x computation
	Vector Reciprocal()
	{
//		return Vector(1,1,1,0) / (*this);
		__m128 x = _mm_load_ps(fa());
		__m128 z = _mm_rcp_ps(x); //z = 1/x estimate
		__m128 _V = _mm_sub_ps( _mm_add_ps( z, z), _mm_mul_ps( x, _mm_mul_ps( z, z))); //2z-xzz
		return *(Vector*)&_V; //~= 1/x to 0.000012%
	}

	//Transform by a normalized XY dir vector
	Vector TransformByXY( const Vector& Dir) const
	{
		__m128 org = _mm_load_ps( fa()     );
		__m128 dir = _mm_load_ps( Dir.fa() );
		__m128 y = _mm_load_ps( Vector(1,1,-1,1).fa() );

		//result.x = org DOT dir
		//result.y = org DOT rotated_dir
		//result.z = result.z

		//Dir: X,Y
		//Rotated dir: -Y, X
		dir = _mm_castsi128_ps( _mm_shuffle_epi32( _mm_castps_si128(dir), 0b00010100)); //Force a PSHUFD (x,y,y,x)
		dir = _mm_mul_ps( dir, y); //x,y,-y,x

		__m128 opvec = _mm_movelh_ps( org, org); //Get X,Y,X,Y here
		opvec = _mm_mul_ps( opvec, dir); // ox*dx, oy*dy, ox*-dy, oy*dx
		opvec = _mm_castsi128_ps( _mm_shuffle_epi32( _mm_castps_si128(opvec), 0b11011000)); //Force another PSHUFD (x,z,y,w)
		y = _mm_movehl_ps( y, opvec);
		opvec = _mm_add_ps( opvec, y); //ox*dx+oy*dy, ox*-dy+oy*dx
		opvec = _mm_shuffle_ps( opvec, org, 0b11100100); //Mix X,Y of OPVEc and Z,W of ORG

		return *(Vector*)&opvec;
	}


} GCC_ALIGN(16);
//**************


// Members
inline Vector Min( const Vector& A, const Vector& B)
{
	__m128 _V = _mm_min_ps( _mm_load_ps(A.fa()), _mm_load_ps( B.fa()) );
	return *(Vector*) &_V;
}

inline Vector Max( const Vector& A, const Vector& B)
{
	__m128 _V = _mm_max_ps( _mm_load_ps(A.fa()), _mm_load_ps( B.fa()) );
	return *(Vector*) &_V;
}

inline Vector Vectorize( const Integers& i)
{
	__m128 _V = _mm_cvtepi32_ps( _mm_load_si128(i.mm()) ); //Load and truncate to integer
	return *(Vector*)&_V;
}


//
// Simple bounding box type
//
MS_ALIGN(16) struct DE Box
{
	Vector Min, Max;

	//************
	//Constructors

	Box()
	{}

	Box( const Box& B)
		:	Min(B.Min), Max(B.Max) {}

	//Create an empty box
	Box( EZero)
	{
		__m128 m = _mm_setzero_ps();
		_mm_store_ps( Min.fa(), m);
		_mm_store_ps( Max.fa(), m);
	} 

	//Non-strict constructor: used when Min, Max have to be deducted
	Box( const Vector& A, const Vector& B)
		:	Min( cg::Min(A,B))	,	Max( cg::Max(A,B))	{}

	//Strict constructor: used when Min, Max are obvious
	Box( const Vector& InMin, const Vector& InMax, EStrict)
		:	Min( InMin)	,	Max(InMax)	{}

	//Construct a box containing all of Unreal vectors in the list
	Box( FVector* VList, int32 VNum)
	{
		const uint32 imask = 0xFFFFFFFF;
		const float boundmin = -32768.f;
		const float boundmax = 32768.f; //Unreal bounds
		float* fArray = (float*)VList;

		//Load last vector first
		VNum--;
		__m128 mi = _mm_castsi128_ps( _mm_loadl_epi64( (__m128i*)(fArray+3*VNum) )); //X,Y,0,0
		__m128 ma = _mm_load_ss( fArray + 3*VNum + 2 ); //Z,0,0,0
		mi = _mm_movelh_ps( mi, ma); //X,Y,Z,0
		ma = mi;
		//Now expand using other vectors
		for ( int32 i=0 ; i<VNum ; i++ )
		{
			__m128 v = _mm_loadu_ps( fArray);
			mi = _mm_min_ps( mi, v );
			ma = _mm_max_ps( ma, v );
			fArray += 3;
		}
		//Clamp to unreal bounds
		__m128 mb = _mm_load_ps1( &boundmin);
		mi = _mm_max_ps( mi, mb);
		mb = _mm_load_ps1( &boundmax);
		ma = _mm_min_ps( ma, mb);
		//Set W=0
		__m128 mask = _mm_load_ss( (const float*)&imask);
		mask = _mm_pshufd_ps( mask, 0b11000000); //m,m,m,0
		mi = _mm_and_ps( mi, mask);
		ma = _mm_and_ps( ma, mask);
		//Save
		_mm_store_ps( Min.fa(), mi);
		_mm_store_ps( Max.fa(), ma);
	}

	//Give us one of the component vectors
	Vector& Vec( uint32 i)
	{	return (&Min)[i];	}

	//********************************
	//Basic assignment logic operators

	Box operator=(const Box& B)
	{
		Min = B.Min;
		Max = B.Max;
		return *this;
	}

	//*********************
	//Basic logic operators
	Box operator+(const Vector& V) const
	{
		__m128 _V =  _mm_load_ps(V.fa());
		__m128 _m[2] = {	_mm_add_ps(_mm_load_ps(Min.fa()), _V),
							_mm_add_ps(_mm_load_ps(Max.fa()), _V) };
		return *(Box*)_m;
	}

	Box operator-(const Vector& V) const
	{
		__m128 _V =  _mm_load_ps(V.fa());
		__m128 _m[2] = {	_mm_sub_ps(_mm_load_ps(Min.fa()), _V),
							_mm_sub_ps(_mm_load_ps(Max.fa()), _V) };
		return *(Box*)_m;
	}

	Box operator*(const Vector& V) const
	{
		__m128 _V =  _mm_load_ps(V.fa());
		__m128 _m[2] = {	_mm_mul_ps(_mm_load_ps(Min.fa()), _V),
							_mm_mul_ps(_mm_load_ps(Max.fa()), _V) };
		return *(Box*)_m;
	}
	
	//***********************
	//Characteristics queries

	bool IsZero() const
	{
		__m128 cmin, cmax;
		__m128 m = _mm_setzero_ps();
		cmin = _mm_cmpeq_ps( m, Min.mm() );
		cmax = _mm_cmpeq_ps( m, Max.mm() );
		m = _mm_cmpeq_ps( cmin, cmax );
		return _mm_movemask_ps( m) == 0b1111;
	}

	Vector CenterPoint() const
	{
		return (Min + Max) * 0.5;
	}

	bool Intersects( const Box& Other) const
	{
		return (Min <= Other.Max) & (Other.Min <= Max);
	}

	bool Contains( const Vector& Other) const
	{
		return (Min <= Other) & (Other <= Max);
	}

	//**************************
	//Transformations

	Box Expand( const Vector& Towards)
	{
		Min = cg::Min( Min, Towards);
		Max = cg::Max( Max, Towards);
		return *this;
	}

	Box Expand( const Box& By)
	{
		Min = cg::Min( Min, By.Min);
		Max = cg::Max( Max, By.Max);
		return *this;
	}

	Box Expand( const Box& By, ENoZero)
	{
		if ( !By.IsZero() )
		{
			if ( IsZero() )
				(*this = By);
			else
			{
				Min = cg::Min( Min, By.Min);
				Max = cg::Max( Max, By.Max);
			}
		}
		return *this;
	}

	//Enlarge a box by a 'Extent' vector
	void ExpandBounds( const Vector& By) 
	{
		__m128 by = _mm_load_ps( By.fa() );
		_mm_store_ps( Min.fa(), _mm_sub_ps( _mm_load_ps(Min.fa()),by) );
		_mm_store_ps( Max.fa(), _mm_add_ps( _mm_load_ps(Max.fa()),by) );
	}

} GCC_ALIGN(16);




} //Namespace cg - end


template<class T> inline T Max( const T A, const T B )
{
	return (A>=B) ? A : B;
}
template<class T> inline T Min( const T A, const T B )
{
	return (A<=B) ? A : B;
}

template<class T> inline T Clamp( const T X, const T Min, const T Max )
{
	return X<Min ? Min : X<Max ? X : Max;
}

template<class T> inline void Exchange( T& A, T& B )
{
	for ( uint32 i=0 ; i<sizeof(T)/4 ; i++ )
	{
		uint32 Buf = ((uint32*)&A)[i];
		((uint32*)&A)[i] = ((uint32*)&B)[i];
		((uint32*)&B)[i] = Buf;
	}
}