/*=============================================================================
	EditorAdds.cpp: 
	Unreal Editor addons.

	Revision history:
		* Created by Higor
=============================================================================*/

#include "XC_Core.h"
#include "XC_CoreGlobals.h"
#include "Engine.h"

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

