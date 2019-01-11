/*=============================================================================
	EditorAdds.cpp: 
	Unreal Editor addons.

	Revision history:
		* Created by Higor
=============================================================================*/

#include "XC_Core.h"
#include "XC_CoreGlobals.h"
#include "Engine.h"
#include "API_FunctionLoader.h"
#include "UnRender.h"


struct EditorHookHelper_XC_CORE;
typedef void (EditorHookHelper_XC_CORE::*_draw_func_)(UViewport*,UBOOL,BYTE*,INT*);
typedef void (EditorHookHelper_XC_CORE::*_draw_lb_func_)(FSceneNode*,INT,INT,INT);
static _draw_func_ Draw_Org;
static _draw_lb_func_ DrawLevelBrushes_Org;
static int DrawPaths;
static UViewport* Viewport;
static uint32 Funcs[158]; //30 is Draw, 155 is DrawLevelBrushes


struct EditorHookHelper_XC_CORE
{
	EditorHookHelper_XC_CORE()
	{
		if ( !GIsEditor || !GIsClient || !GIsServer ) 
			return; //Not Unreal Editor launcher

		static int Initialized = 0;
		if ( Initialized++ )
			return; //Prevent multiple recursion

		UEngine* Editor = FindObject<UEngine>( ANY_PACKAGE, TEXT("EditorEngine0") );
		if ( !Editor )
			return; //No Editor engine

#if _WINDOWS
		appMemcpy( Funcs, *(void**)Editor, 0x2F4 - 0x07C);
		_draw_func_    FuncDraw   = &EditorHookHelper_XC_CORE::Draw;
		_draw_lb_func_ FuncDrawLB = &EditorHookHelper_XC_CORE::DrawLevelBrushes;
		appMemcpy( &Draw_Org,             Funcs +  30, 4);
		appMemcpy( &DrawLevelBrushes_Org, Funcs + 155, 4);
		appMemcpy( Funcs +  30, &FuncDraw,   4);
		appMemcpy( Funcs + 155, &FuncDrawLB, 4);
		*(uint32**)Editor = Funcs;

#endif
	}
	
	void Draw( UViewport* Viewport, UBOOL Blit=1, BYTE* HitData=NULL, INT* HitSize=NULL )
	{
		::Viewport = Viewport;
		int32 OldShowFlags = Viewport->Actor->ShowFlags;
		DrawPaths = 0;
		if ( (Viewport->Actor->RendMap < REN_TexView) && (Viewport->Actor->ShowFlags & SHOW_Paths) )
			DrawPaths = 1;
		(this->*Draw_Org)(Viewport, Blit, HitData, HitSize);
		Viewport->Actor->ShowFlags = OldShowFlags; //Reset flags
		DrawPaths = 0;
	}

	void DrawLevelBrushes( FSceneNode* Node, INT A, INT B, INT C)
	{
		(this->*DrawLevelBrushes_Org)( Node, A, B, C);
		if ( DrawPaths )
		{
			TArray<FReachSpec>& ReachSpecs = Node->Level->ReachSpecs;
			for( int32 i=0; i<ReachSpecs.Num(); i++ )
			{
				FReachSpec& Spec = ReachSpecs(i);
				if( Spec.Start && Spec.End && !Spec.bPruned )
				{
					//Draw straight line
					FVector Offset(0,0,4);
					if ( Spec.Start < Spec.End )
						Offset.Z = -4;

					float Alpha = (float) Clamp( Spec.CollisionHeight + Spec.CollisionRadius, 50, 100) / 100.0;
					FPlane LineColor( 0, Alpha, 0, 1);
					if ( Spec.Start->bSelected )
						LineColor.Z = 0.5;
					if ( Spec.reachFlags & 8 ) //R_JUMP >> yellow
						LineColor.X = LineColor.Y;
					else if ( Spec.reachFlags & 2 ) //R_FLY >> red
						Exchange(LineColor.X, LineColor.Y);
					else if ( Spec.reachFlags & 32 ) //R_SPECIAL >> blue
					{
						LineColor.Z += 0.5;
						LineColor.Y *= 0.5;
					}
					FVector StartPos = Spec.Start->Location + Offset;
					FVector EndPos = Spec.End->Location + Offset;

					Viewport->RenDev->Draw3DLine( Node, LineColor, LINE_DepthCued, StartPos, EndPos);
					FVector Dir = EndPos-StartPos;
					FVector ArrowHeadPoint = StartPos + Dir * 0.3;
					float Size = Dir | Dir.SafeNormal();
					Dir = Dir *16 / Max(Size,128.f);
					FVector DirH( -Dir.Y, Dir.X, Dir.Z);
					Viewport->RenDev->Draw3DLine( Node, LineColor, LINE_DepthCued, ArrowHeadPoint, ArrowHeadPoint-(Dir+DirH));
					Viewport->RenDev->Draw3DLine( Node, LineColor, LINE_DepthCued, ArrowHeadPoint, ArrowHeadPoint-(Dir-DirH));
				}
			}
		}
		Viewport->Actor->ShowFlags &= ~SHOW_Paths; //Clear this flag to prevent old drawing method
	}
};
static EditorHookHelper_XC_CORE Helper; //Makes C runtime init construct this object


//============== Cleans up actor list and hidden faces
//
XC_CORE_API FString CleanupLevel( ULevel* Level)
{
	FString Result;
	if ( GIsEditor )
	{
		guard(ShrinkActorList);
		int32 OldSize = Level->Actors.Num();
		Level->CleanupDestroyed(1);
		Level->CompactActors();
		if ( Level->Actors.Num() != OldSize )
			Result += FString::Printf( TEXT("Actor list size shrunk from %i to %i elements.\r\n"), OldSize, Level->Actors.Num() );
		unguard

		guard(RemoveUnusedTextures)
		int32 i;
		TMap<UTexture*,int32> TextureMap;
		//Cleanup all textures from brushes
		for ( i=2 ; i<Level->Actors.Num() ; i++ ) //Doesn't include brush builder
		{
			ABrush* Brush = Cast<ABrush>(Level->Actors(i));
			if ( Brush && !Brush->bIsMover && Brush->Brush && Brush->Brush->Polys )
			{
				TTransArray<FPoly>& Polys = Brush->Brush->Polys->Element;
				for ( int32 j=0 ; j<Polys.Num() ; j++ )
					if ( Polys(j).Texture )
					{
						TextureMap.Set( Polys(j).Texture, 0);
						Polys(j).Texture = NULL;
					}
			}
		}
		//Find and restore textures from level into brushes
		if ( Level->Model )
		{
			for ( i=0 ; i<Level->Model->Surfs.Num() ; i++ )
			{
				FBspSurf& Surf = Level->Model->Surfs(i);
				if ( Surf.Actor && Surf.Texture )
				{
					TextureMap.Set( Surf.Texture, 1);
					for ( int32 j=Surf.iBrushPoly ; j<Surf.Actor->Brush->Polys->Element.Num() ; j++ )
					{
						FPoly& ActorPoly = Surf.Actor->Brush->Polys->Element(j);
						//Because a single surface can have multiple linked polys
						if ( j==Surf.iBrushPoly || ActorPoly.iLink==Surf.iBrushPoly ) //Is first condition necessary?
							ActorPoly.Texture = Surf.Texture;
					}
				}
			}
		}
		int32 Restored = 0;
		typedef TMap<UTexture*,int32>::TIterator Iterator;
		for ( Iterator It=Iterator(TextureMap) ; (UBOOL)It ; ++It )
			Restored += It.Value();
		if ( Restored != TextureMap.Num() )
			Result += FString::Printf( TEXT("Unreferenced a %i textures from brushes.\r\n"), TextureMap.Num() - Restored);
		unguard
	}
	return Result;
}

