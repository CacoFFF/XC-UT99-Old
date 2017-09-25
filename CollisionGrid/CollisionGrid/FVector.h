#pragma once

#include "PlatformTypes.h"

class DE FVector
{
public:
	// Variables.
	float X, Y, Z;

	// Constructors.
	FVector()
	{}

	FVector(float InX, float InY, float InZ)
		: X(InX), Y(InY), Z(InZ)
	{}

	// Binary math operators.
	FVector operator^(const FVector& V) const
	{
		return FVector
			(
				Y * V.Z - Z * V.Y,
				Z * V.X - X * V.Z,
				X * V.Y - Y * V.X
				);
	}
	float operator|(const FVector& V) const
	{
		return X*V.X + Y*V.Y + Z*V.Z;
	}
	friend FVector operator*(float Scale, const FVector& V)
	{
		return FVector(V.X * Scale, V.Y * Scale, V.Z * Scale);
	}
	FVector operator+(const FVector& V) const
	{
		return FVector(X + V.X, Y + V.Y, Z + V.Z);
	}
	FVector operator-(const FVector& V) const
	{
		return FVector(X - V.X, Y - V.Y, Z - V.Z);
	}
	FVector operator*(float Scale) const
	{
		return FVector(X * Scale, Y * Scale, Z * Scale);
	}
	FVector operator/(float Scale) const
	{
		float RScale = 1.f / Scale;
		return FVector(X * RScale, Y * RScale, Z * RScale);
	}
	FVector operator*(const FVector& V) const
	{
		return FVector(X * V.X, Y * V.Y, Z * V.Z);
	}

	// Binary comparison operators.
	UBOOL operator==(const FVector& V) const
	{
		return X == V.X && Y == V.Y && Z == V.Z;
	}
	UBOOL operator!=(const FVector& V) const
	{
		return X != V.X || Y != V.Y || Z != V.Z;
	}

	// Unary operators.
	FVector operator-() const
	{
		return FVector(-X, -Y, -Z);
	}

	// Assignment operators.
	FVector operator+=(const FVector& V)
	{
		X += V.X; Y += V.Y; Z += V.Z;
		return *this;
	}
	FVector operator-=(const FVector& V)
	{
		X -= V.X; Y -= V.Y; Z -= V.Z;
		return *this;
	}
	FVector operator*=(float Scale)
	{
		X *= Scale; Y *= Scale; Z *= Scale;
		return *this;
	}
	FVector operator/=(float V)
	{
		float RV = 1.f / V;
		X *= RV; Y *= RV; Z *= RV;
		return *this;
	}
	FVector operator*=(const FVector& V)
	{
		X *= V.X; Y *= V.Y; Z *= V.Z;
		return *this;
	}
	FVector operator/=(const FVector& V)
	{
		X /= V.X; Y /= V.Y; Z /= V.Z;
		return *this;
	}

	// Simple functions.
	float Size() const
	{
		return appSqrt(X*X + Y*Y + Z*Z);
	}
	float SizeSquared() const
	{
		return X*X + Y*Y + Z*Z;
	}
	float Size2D() const
	{
		return appSqrt(X*X + Y*Y);
	}
	float SizeSquared2D() const
	{
		return X*X + Y*Y;
	}
	int IsNearlyZero() const
	{
		return
			Abs(X)<KINDA_SMALL_NUMBER
			&&	Abs(Y)<KINDA_SMALL_NUMBER
			&&	Abs(Z)<KINDA_SMALL_NUMBER;
	}
	UBOOL IsZero() const
	{
		return X == 0.f && Y == 0.f && Z == 0.f;
	}
	UBOOL Normalize()
	{
		float SquareSum = X*X + Y*Y + Z*Z;
		if (SquareSum >= SMALL_NUMBER)
		{
			float Scale = 1.f / appSqrt(SquareSum);
			X *= Scale; Y *= Scale; Z *= Scale;
			return 1;
		}
		else return 0;
	}
	FVector Projection() const
	{
		float RZ = 1.f / Z;
		return FVector(X*RZ, Y*RZ, 1);
	}
	FVector UnsafeNormal() const
	{
		float Scale = 1.f / appSqrt(X*X + Y*Y + Z*Z);
		return FVector(X*Scale, Y*Scale, Z*Scale);
	}
	FVector GridSnap(const FVector& Grid)
	{
		return FVector(FSnap(X, Grid.X), FSnap(Y, Grid.Y), FSnap(Z, Grid.Z));
	}
	FVector BoundToCube(float Radius)
	{
		return FVector
			(
				Clamp(X, -Radius, Radius),
				Clamp(Y, -Radius, Radius),
				Clamp(Z, -Radius, Radius)
				);
	}
	void AddBounded(const FVector& V, float Radius = MAXSWORD)
	{
		*this = (*this + V).BoundToCube(Radius);
	}
	float& Component(int32 Index)
	{
		return (&X)[Index];
	}

	// Return a boolean that is based on the vector's direction.
	// When      V==(0,0,0) Booleanize(0)=1.
	// Otherwise Booleanize(V) <-> !Booleanize(!B).
	UBOOL Booleanize()
	{
		return
			X >  0.f ? 1 :
			X <  0.f ? 0 :
			Y >  0.f ? 1 :
			Y <  0.f ? 0 :
			Z >= 0.f ? 1 : 0;
	}

	// Transformation.
	FVector TransformVectorBy(const FCoords& Coords) const;
	FVector TransformPointBy(const FCoords& Coords) const;
	FVector MirrorByVector(const FVector& MirrorNormal) const;
	FVector MirrorByPlane(const FPlane& MirrorPlane) const;
	FVector PivotTransform(const FCoords& Coords) const;

	// Complicated functions.
	FRotator Rotation();
	void FindBestAxisVectors(FVector& Axis1, FVector& Axis2);
	FVector SafeNormal() const; //warning: Not inline because of compiler bug.

								// Friends.
	friend float FDist(const FVector& V1, const FVector& V2);
	friend float FDistSquared(const FVector& V1, const FVector& V2);
	friend UBOOL FPointsAreSame(const FVector& P, const FVector& Q);
	friend UBOOL FPointsAreNear(const FVector& Point1, const FVector& Point2, float Dist);
	friend float FPointPlaneDist(const FVector& Point, const FVector& PlaneBase, const FVector& PlaneNormal);
	friend FVector FLinePlaneIntersection(const FVector& Point1, const FVector& Point2, const FVector& PlaneOrigin, const FVector& PlaneNormal);
	friend FVector FLinePlaneIntersection(const FVector& Point1, const FVector& Point2, const FPlane& Plane);
	friend UBOOL FParallel(const FVector& Normal1, const FVector& Normal2);
	friend UBOOL FCoplanar(const FVector& Base1, const FVector& Normal1, const FVector& Base2, const FVector& Normal2);

	// Serializer.
	friend FArchive& operator<<(FArchive& Ar, FVector& V)
	{
		return Ar << V.X << V.Y << V.Z;
	}
};
