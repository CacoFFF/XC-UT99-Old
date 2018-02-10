/*=============================================================================
	XC_Visuals.cpp:
	Graphics and visuals stuff
=============================================================================*/

#include "XC_Core.h"
#include "XC_CoreGlobals.h"
#include "UnXC_Math.h"

#include "Engine.h"


struct FMeshTri_V : public FMeshTri
{
	FVector Normal;
};

struct FVectorUVi : public FVector
{
	union { FLOAT U; FLOAT UV[1]; };
	FLOAT V;
	INT VertexID;

	inline void SetV( FVector Other)
	{
		X = Other.X;
		Y = Other.Y;
		Z = Other.Z;
	}

	static FVectorUVi Lerp( FVectorUVi& Start, FVectorUVi& End, FLOAT alpha)
	{
		FVectorUVi Res;
		FVector& sv = Start;
		FVector& ev = End;
		Res.SetV( sv + (ev-sv)*alpha);
		Res.U = Start.U + (End.U - Start.U) * alpha;
		Res.V = Start.V + (End.V - Start.V) * alpha;
		Res.VertexID = INDEX_NONE;
		return Res;
	}
};

#define MAX_NEW_VERTEX 32768
struct FBrushToMeshInstance
{
	TArray<FVector> Vertex;
	BYTE* Match;
	TArray<FMeshTri_V> Tri;
	TArray<UTexture*> Tex;
	INT Flags;

	FBrushToMeshInstance( INT InFlags)
	: Vertex(0)
	, Match(new(GMem,MEM_Zeroed,MAX_NEW_VERTEX) BYTE)
	, Tri(0)
	, Tex(0)
	, Flags(InFlags)
	{
		Tex.AddItem(NULL);
	}

	INT SelectTexture( UTexture* Texture)
	{
		INT i = Tex.FindItemIndex( Texture);
		if ( i == INDEX_NONE )
			i = Texture ? Tex.AddItem(Texture) : 0;
		return i;
	}

	void FixTextures()
	{
		UBOOL bRemoveNullTex = false;
		if ( Tex(0) == NULL  && Tex.Num() > 2 )
		{
			UBOOL bRemoveNullTex = true;
			for ( INT i=0 ; i<Tri.Num() ; i++ )
				if ( Tri(i).TextureIndex == 0 )
				{
					bRemoveNullTex = false;
					break;
				}
		}
		if ( bRemoveNullTex )
		{
			Tex.Remove(0);
			for ( INT i=0 ; i<Tri.Num() ; i++ )
				Tri(i).TextureIndex--;
		}
		if ( Tex.Num() > 8 )
		{
			Tex.Remove( 8, Tex.Num() - 8);
			for ( INT i=0 ; i<Tri.Num() ; i++ )
				if ( Tri(i).TextureIndex >= 8 )
					Tri(i).TextureIndex = 0;
		}
	}
};

struct FBrushFace
{
	UBOOL bActive;
	FBrushFace* Next;
	FPoly* Poly;
	INT NumVertices;
	INT USize;
	INT VSize;
	FVectorUVi Vertex[1];

	FLOAT HighestUV( INT n) const
	{
		FLOAT High = Vertex[0].UV[n];
		for ( INT i=1 ; i<NumVertices ; i++ )
			High = Max(High,Vertex[i].UV[n]);
		return High;
	}

	//MergeAll mode doesn't cache matches, use with Unlit polys
	void ProcessVertices( FBrushToMeshInstance* Instance)
	{
		INT i;
		if ( Instance->Flags & BM_MergeNone )
		{
		}
		else if ( (Instance->Flags & BM_MergeAll) || (Poly->PolyFlags & PF_Unlit) )
		{
			for ( i=0 ; i<NumVertices ; i++ )
				if ( Vertex[i].VertexID == INDEX_NONE )
					for ( INT j=Instance->Vertex.Num()-1 ; j>=0 ; j-- )
						if ( (Instance->Vertex(j)-Vertex[i]).SizeSquared() < 1.f )
						{
							Vertex[i].VertexID = j;
							break;
						}	
		}
		else
		{

			//Find unassociated vertices and find matches in list if possible
			INT NeedLink = 0;
			for ( i=0 ; i<NumVertices ; i++ )
				if ( Vertex[i].VertexID == INDEX_NONE )
				{
					UBOOL bLink = 0;
					FVector& V = Vertex[i];
					for ( INT j=0 ; j<Instance->Vertex.Num() ; j++ )
						if ( (V-Instance->Vertex(j)).SizeSquared() < 1.f )
						{
							Instance->Match[j] = i+1;
							bLink = 1;
						}
					NeedLink += bLink;
				}

			//Find suitable polygons that may contain any of these vertices (backwards is faster)
			for ( i=Instance->Tri.Num()-1 ; i>=0 && NeedLink>0 ; i-- )
			{
				_WORD* vt = Instance->Tri(i).iVertex;
				if ( (Instance->Match[vt[0]]+Instance->Match[vt[1]]+Instance->Match[vt[2]])
					&& (Poly->Normal | Instance->Tri(i).Normal) > 0.5f )
				{
					for ( INT k=0 ; k<3 ; k++ )
						if ( (Instance->Match[vt[k]] > 0) && (Vertex[Instance->Match[vt[k]]-1].VertexID == INDEX_NONE) )
						{
							Vertex[Instance->Match[vt[k]]-1].VertexID = vt[k];
							NeedLink--;
						}
				}
			}
			appMemzero(Instance->Match, Instance->Vertex.Num());
		}

		//Create new Vertex if unmatched
		for ( i=0 ; i<NumVertices ; i++ )
			if ( Vertex[i].VertexID == INDEX_NONE )
				Vertex[i].VertexID = Instance->Vertex.AddItem( Vertex[i]);
	}

	void AttachToChain( FBrushFace* InNext)
	{
		FBrushFace* Link = this;
		while ( Link->Next )
			Link = Link->Next;
		Link->Next = InNext;
	}

	void NormalizeUV()
	{
		INT i;
		FLOAT LowU = Vertex[0].U;
		FLOAT LowV = Vertex[0].V;
		for ( i=1 ; i<NumVertices ; i++ )
		{
			LowU = Min( LowU, Vertex[i].U);
			LowV = Min( LowV, Vertex[i].V);
		}
		FLOAT SubU = (FLOAT)((appRound(LowU) / 256) * 256);
		FLOAT SubV = (FLOAT)((appRound(LowV) / 256) * 256);
		if ( (LowU -= SubU) <= -0.5f)	SubU -= 256.f;
		if ( (LowV -= SubV) <= -0.5f)	SubV -= 256.f;
		for ( i=0 ; i<NumVertices ; i++ )
		{
			Vertex[i].U -= SubU;
			Vertex[i].V -= SubV;
		}
	}


	UBOOL Split( INT n, FBrushToMeshInstance* Instance) //UV are assumed normalized
	{
		if ( !bActive || n<0 || n>1  )
			return 0;
		if ( appRound(HighestUV(n)) <= 256 )
			return 0;

		//Create new list with different sorting
		INT i;
		INT iBuf = 0;
		INT iSplit = 0; //Second splitter
		FVectorUVi Buffer[18]; //0 is always first splitter
		//YES = goes in first half
		//NO = goes in second half

		//Stage 1: find NO to YES transition, create splitter if necessary
		{	INT j = NumVertices-1;
			INT jU = appRound( Vertex[j].UV[n]);
			for ( i=0 ; i<NumVertices ; j=i++ )
			{
				INT iU = appRound( Vertex[i].UV[n]);
				if ( jU > 256 && iU <= 256 ) //Found
				{
					if ( iU >= 255 ) //THIS VERTEX IS A SPLITTER
						Buffer[iBuf++] = Vertex[i++];
					else //CREATE NEW SPLITTER
					{
						FLOAT alpha = (Vertex[j].UV[n] - 256) / (Vertex[j].UV[n]-Vertex[i].UV[n]); //>0
						Buffer[iBuf] = FVectorUVi::Lerp( Vertex[j], Vertex[i], alpha);
//						Buffer[iBuf].UV[n] = 256;
						iBuf++;
					}
					break;
				}
				jU = iU;
		}	}
		if ( iBuf == 0 ) //Should never happen
			return 0;
		//Stage 2: add YES vertices (may add none due to splitter being YES)
		for ( ; appRound(Vertex[i].UV[n]) <= 256 ; i=(i+1)%NumVertices )
			Buffer[iBuf++] = Vertex[i];
		//Stage 3: add second splitter (Vertex[i] is NO)
		if ( appRound(Buffer[iBuf-1].UV[n]) >= 255 ) //Last added was a splitter!
			iSplit = iBuf-1;
		else
		{
			INT b = iBuf-1;
			FLOAT alpha = (Vertex[i].UV[n] - 256) / (Vertex[i].UV[n]-Buffer[b].UV[n]); //>0
			Buffer[iBuf] = FVectorUVi::Lerp( Vertex[i], Buffer[b], alpha);
//			Buffer[iBuf].UV[n] = 256;
			iSplit=iBuf++;
		}
		//Stage 4: add NO vertices (at least ONE)
		for ( ; appRound(Vertex[i].UV[n]) > 256 ; i=(i+1)%NumVertices )
			Buffer[iBuf++] = Vertex[i];

		INT ChipVertices = iSplit + 1;
		INT RemainVertices = iBuf + 2 - ChipVertices;
		if ( ChipVertices < 3 || RemainVertices < 3 )
			return 0;

		debugf( TEXT("Split (%c) from %i into %i/%i"), 'U'+n, NumVertices, ChipVertices, RemainVertices);
		bActive = false;
		FBrushFace* Chip = FBrushFace::Setup(this,ChipVertices);
		FBrushFace* Remain = FBrushFace::Setup(this,RemainVertices);

		for ( i=0 ; i<ChipVertices ; i++ )
			Chip->Vertex[i] = Buffer[i];
		Chip->ProcessVertices( Instance);
		Buffer[0     ].VertexID = Chip->Vertex[0     ].VertexID;
		Buffer[iSplit].VertexID = Chip->Vertex[iSplit].VertexID;
		Remain->Vertex[0] = Buffer[0];
		for ( i=0 ; i<RemainVertices-1 ; i++ )
			Remain->Vertex[i+1] = Buffer[iSplit+i];

		Chip->NormalizeUV();
		Remain->NormalizeUV();
		return 1;
	}

	static FBrushFace* Setup( FPoly* Poly)
	{
		guard(CreatePolyTemplate);
		INT Size = sizeof( FBrushFace) + sizeof(FVectorUVi) * (Poly->NumVertices-1);
		FBrushFace* Res = (FBrushFace*) (new(GMem,Size/4) INT);
		Res->bActive = 1;
		Res->Next = NULL;
		Res->Poly = Poly;
		Res->NumVertices = Poly->NumVertices;
		Res->VSize = Res->USize = 128;
		if ( Poly->Texture ) //Comes with ST3C rescale fix
		{
			Res->USize = Poly->Texture->UClamp;
			Res->VSize = Poly->Texture->VClamp;
		}
		FLOAT PanU = (FLOAT)(Poly->PanU & (Res->USize-1));
		FLOAT PanV = (FLOAT)(Poly->PanV & (Res->VSize-1));
		FLOAT ScaleU = 256.f / Res->USize;
		FLOAT ScaleV = 256.f / Res->VSize;
		for ( INT i=0 ; i<Res->NumVertices ; i++ )
		{
			Res->Vertex[i].SetV( Poly->Vertex[i]);
			FVector Pos = Res->Vertex[i] - Poly->Base;
			Res->Vertex[i].U = ((Pos | Poly->TextureU) + PanU) * ScaleU;
			Res->Vertex[i].V = ((Pos | Poly->TextureV) + PanV) * ScaleV;
			Res->Vertex[i].VertexID = INDEX_NONE;
		}
		Res->NormalizeUV();
		return Res;
		unguard;
	}

	static FBrushFace* Setup( FBrushFace* Base, INT NewVertices)
	{
		guard(CreateFaceTemplate);
		INT Size = sizeof( FBrushFace) + sizeof(FVectorUVi) * (NewVertices-1);
		FBrushFace* Res = (FBrushFace*) (new(GMem,Size/4) INT);
		Res->bActive = 1;
		Res->Next = NULL;
		Res->Poly = Base->Poly;
		Res->NumVertices = NewVertices;
		Res->USize = Base->USize;
		Res->VSize = Base->VSize;
		Base->AttachToChain(Res);
		return Res;
		unguard;
	}
};



//Taken from Editor
static QSORT_RETURN CDECL CompareTris( const FMeshTri* A, const FMeshTri* B )
{
	if     ( (A->PolyFlags&PF_Translucent) > (B->PolyFlags&PF_Translucent) ) return  1;
	else if( (A->PolyFlags&PF_Translucent) < (B->PolyFlags&PF_Translucent) ) return -1;
	else if( A->TextureIndex               > B->TextureIndex               ) return  1;
	else if( A->TextureIndex               < B->TextureIndex               ) return -1;
	else if( A->PolyFlags                  > B->PolyFlags                  ) return  1;
	else if( A->PolyFlags                  < B->PolyFlags                  ) return -1;
	else                                                                     return  0;
}

//Taken from Editor
static void meshBuildBounds( UMesh* Mesh )
{
	guard(UEditorEngine::meshBuildBounds);

	// Bound all frames.
	TArray<FVector> AllFrames;
	for( INT i=0; i<Mesh->AnimFrames; i++ )
	{
		TArray<FVector> OneFrame;
		for( INT j=0; j<Mesh->FrameVerts; j++ )
		{
			FVector Vertex = Mesh->Verts( i * Mesh->FrameVerts + j ).Vector();
			OneFrame .AddItem( Vertex );
			AllFrames.AddItem( Vertex );
		}
		Mesh->BoundingBoxes  (i) = FBox   ( &OneFrame(0), OneFrame.Num() );
		Mesh->BoundingSpheres(i) = FSphere( &OneFrame(0), OneFrame.Num() );
	}
	Mesh->BoundingBox    = FBox   ( &AllFrames(0), AllFrames.Num() );
	Mesh->BoundingSphere = FSphere( &AllFrames(0), AllFrames.Num() );

	// Display bounds.
	debugf
	(
		NAME_Log,
		TEXT("BoundingBox (%f,%f,%f)-(%f,%f,%f) BoundingSphere (%f,%f,%f) %f"),
		Mesh->BoundingBox.Min.X,
		Mesh->BoundingBox.Min.Y,
		Mesh->BoundingBox.Min.Z,
		Mesh->BoundingBox.Max.X,
		Mesh->BoundingBox.Max.Y,
		Mesh->BoundingBox.Max.Z,
		Mesh->BoundingSphere.X,
		Mesh->BoundingSphere.Y,
		Mesh->BoundingSphere.Z,
		Mesh->BoundingSphere.W
	);
	unguard;
}

#define PF_Relevant (PF_Unlit | PF_Modulated | PF_Translucent | PF_Masked | PF_NoSmooth | PF_TwoSided)
XC_CORE_API void BrushToMesh( ABrush* Brush, UMesh* ApplyTo, DWORD Flags)
{
	guard(BrushToMesh);
	if ( !Brush || !ApplyTo || !Brush->Brush || !Brush->Brush->Polys || ApplyTo->Verts.Num() || !GIsEditor )
	{
		debugf( TEXT("BrushToMesh error"));
		return;
	}
	UPolys* Polys = Brush->Brush->Polys;
	INT BrushFlags = Brush->IsA(ABrush::StaticClass()) ? (Brush->PolyFlags & PF_Relevant) : 0;

	FMemMark Mark(GMem);
	FBrushToMeshInstance* Instance = new(GMem) FBrushToMeshInstance(Flags);

	INT i;

	//Enumerate vertices and polylist
	debugf( TEXT("Found %i polys"), Polys->Element.Num());
	for ( INT _p=0 ; _p<Polys->Element.Num() ; _p++ )
	{
		FPoly* Poly = &Polys->Element(_p);
		if ( Poly->NumVertices < 3 || (Poly->PolyFlags & PF_Invisible) )
			continue;

		INT CurTexture = Instance->SelectTexture( Poly->Texture);

		//Create polygon resource
		FMemMark PolyMark(GMem);
		FBrushFace* PolyList = FBrushFace::Setup(Poly);
		PolyList->ProcessVertices( Instance);

		//Split if tiling is enabled
		if ( Flags & BM_TileTextures )
		{
			FBrushFace* PolyLink;
			for ( PolyLink=PolyList ; PolyLink ; PolyLink=PolyLink->Next )
				while ( PolyLink->Split(0,Instance) ){}
			for ( PolyLink=PolyList ; PolyLink ; PolyLink=PolyLink->Next )
				while ( PolyLink->Split(1,Instance) ){}
		}

		//Process all complex polys
		for ( FBrushFace* PolyLink=PolyList ; PolyLink ; PolyLink=PolyLink->Next )
		{
			if ( !PolyLink->bActive || PolyLink->NumVertices < 3 )
				continue;

			//Split in triangles for mesh formatting
			for ( INT j=2 ; j<PolyLink->NumVertices ; j++ )
			{
				INT vj[3] = {0, j-1, j};

				FMeshTri_V* NewTri = &Instance->Tri(Instance->Tri.Add());
				for ( i=0 ; i<3 ; i++ )
					NewTri->iVertex[i] = PolyLink->Vertex[vj[i]].VertexID;
				if ( Flags & BM_Flip )
					Exchange( NewTri->iVertex[1], NewTri->iVertex[2] );
				NewTri->Normal = Poly->Normal;
				NewTri->PolyFlags = Poly->PolyFlags & PF_Relevant | BrushFlags;
				NewTri->TextureIndex = CurTexture;

				//Clamp the UV's
				FVector UVmaps[3];
				for ( i=0 ; i<3 ; i++ )
					UVmaps[i] = FVector( PolyLink->Vertex[vj[i]].U, PolyLink->Vertex[vj[i]].V, 0);
				FBox UVbox( UVmaps, 3);
				INT BotU = appRound( UVbox.Min.X);
				INT BotV = appRound( UVbox.Min.Y);
				INT TopU = appRound( UVbox.Max.X);
				INT TopV = appRound( UVbox.Max.Y);
#define UMask 255
#define VMask 255
//				INT UMask = PolyLink->USize-1;
//				INT VMask = PolyLink->VSize-1;
				if ( (TopU & UMask) == 0 )	UVbox.Max.X -= 1.f;
				if ( (TopV & VMask) == 0 )	UVbox.Max.Y -= 1.f;
				if ( (BotU & UMask) == UMask )	UVbox.Min.X += 1.f;
				if ( (BotV & VMask) == VMask )	UVbox.Min.Y += 1.f;
				for ( i=0 ; i<3 ; i++ )
				{
					UVmaps[i].X = Clamp( UVmaps[i].X, UVbox.Min.X, UVbox.Max.X);
					UVmaps[i].Y = Clamp( UVmaps[i].Y, UVbox.Min.Y, UVbox.Max.Y);
				}

				for ( i=0 ; i<3 ; i++ )
				{
					NewTri->Tex[i].U = appRound(UVmaps[i].X);
					NewTri->Tex[i].V = appRound(UVmaps[i].Y);
				}

			}
			PolyMark.Pop();
		}
	}

	// If there are no polygons using hardcoded NULL at 0, then remove
	Instance->FixTextures();

	//Adjust vertex containment
	debugf( TEXT("Created %i vertices"),Instance->Vertex.Num());
	
	FBox VBox( &Instance->Vertex(0), Instance->Vertex.Num() );
	FVector CenterOffset = (VBox.Min + VBox.Max) * 0.5f;
	CenterOffset.X = (FLOAT) appRound(CenterOffset.X);
	CenterOffset.Y = (FLOAT) appRound(CenterOffset.Y);
	CenterOffset.Z = (FLOAT) appRound(CenterOffset.Z);
	debugf( TEXT("Box (Original): (%f,%f,%f)(%f,%f,%f)"),VBox.Min.X,VBox.Min.Y,VBox.Min.Z,VBox.Max.X,VBox.Max.Y,VBox.Max.Z);
	VBox.Min -= CenterOffset;
	VBox.Max -= CenterOffset;
	debugf( TEXT("Box offset: (%f,%f,%f)"),CenterOffset.X,CenterOffset.Y,CenterOffset.Z);
	for ( i=0 ; i<Instance->Vertex.Num() ; i++ )
		Instance->Vertex(i) -= CenterOffset;

	check( VBox.Max.X >= 0.f );
	check( VBox.Max.Y >= 0.f );
	check( VBox.Max.Z >= 0.f );

	FVector Scale( 1.f, 1.f, 1.f);
	i=0;
	while ( VBox.Max.X > 1020.f )
	{VBox.Min.X *= 0.5; VBox.Max.X *= 0.5; Scale.X *= 0.5;}
	while ( VBox.Max.X < 500.f && (i++ < 4) )
	{VBox.Min.X *= 2; VBox.Max.X *= 2; Scale.X *= 2;}
	i=0;
	while ( VBox.Max.Y > 1020.f )
	{VBox.Min.Y *= 0.5; VBox.Max.Y *= 0.5; Scale.Y *= 0.5;}
	while ( VBox.Max.Y < 500.f && (i++ < 4) )
	{VBox.Min.Y *= 2; VBox.Max.Y *= 2; Scale.Y *= 2;}
	i=0;
	while ( VBox.Max.Z > 510.f )
	{VBox.Min.Z *= 0.5; VBox.Max.Z *= 0.5; Scale.Z *= 0.5;}
	while ( VBox.Max.Z < 250.f && (i++ < 4) )
	{VBox.Min.Z *= 2; VBox.Max.Z *= 2; Scale.Z *= 2;}

	debugf( TEXT("Box scale: (%f,%f,%f)"),Scale.X,Scale.Y,Scale.Z);

	ApplyTo->Scale.X = 1.0 / Scale.X;
	ApplyTo->Scale.Y = 1.0 / Scale.Y;
	ApplyTo->Scale.Z = 1.0 / Scale.Z;
	ApplyTo->Verts.Add( Instance->Vertex.Num() );
	for ( i=0 ; i<ApplyTo->Verts.Num() ; i++ )
		ApplyTo->Verts(i) = FMeshVert( Instance->Vertex(i) * Scale );

	if ( !ApplyTo->AnimSeqs.Num() )
		ApplyTo->AnimSeqs.Add();
	appMemzero( &ApplyTo->AnimSeqs(0), sizeof(ApplyTo->AnimSeqs(0)) );
	ApplyTo->AnimSeqs(0).Name = NAME_All;
	ApplyTo->AnimSeqs(0).NumFrames = 1;


	ApplyTo->Tris.Add( Instance->Tri.Num() );
	for ( i=0 ; i<ApplyTo->Tris.Num() ; i++ )
	{
		ApplyTo->Tris(i) = (FMeshTri) Instance->Tri(i);
		check( ApplyTo->Tris(i).iVertex[0] < Instance->Vertex.Num() );
		check( ApplyTo->Tris(i).iVertex[1] < Instance->Vertex.Num() );
		check( ApplyTo->Tris(i).iVertex[2] < Instance->Vertex.Num() );
	}
	appQsort( &ApplyTo->Tris(0), ApplyTo->Tris.Num(), sizeof(ApplyTo->Tris(0)), (QSORT_COMPARE)CompareTris );


	ApplyTo->Textures = Instance->Tex;
	ApplyTo->FrameVerts = Instance->Vertex.Num();
	ApplyTo->AnimFrames = 1;

	debugf( TEXT("Generating connections"));

	if( ApplyTo->GetClass() == UMesh::StaticClass() )
	{
		ApplyTo->Connects.Add(ApplyTo->FrameVerts);
		for( i=0; i<ApplyTo->FrameVerts; i++ )
		{
			guard(ImportingVertices);
			ApplyTo->Connects(i).NumVertTriangles = 0;
			ApplyTo->Connects(i).TriangleListOffset = ApplyTo->VertLinks.Num();
			for( INT j=0; j<ApplyTo->Tris.Num(); j++ )
				for( INT k=0; k<3; k++ )
					if( ApplyTo->Tris(j).iVertex[k] == i )
					{
						ApplyTo->VertLinks.AddItem(j);
						ApplyTo->Connects(i).NumVertTriangles++;
					}
			unguard;
		}
		debugf( NAME_Log, TEXT("Made %i links"), ApplyTo->VertLinks.Num() );
	}

	debugf( TEXT("Generating bounds"));
	meshBuildBounds(ApplyTo);

	Mark.Pop();
	unguard;
}
