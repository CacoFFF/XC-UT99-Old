/*=============================================================================
	UnTemplateEx.h:
	Author: Fernando Velázquez
	
	Expands UE1's templates
=============================================================================*/

//XC_Core should export this in future builds
#if UNICODE
inline int32 appStrlen( const ANSICHAR* String)
{
	int32 len = 0;
	while ( String[len] )
		len++;
	return len;
}
#endif


class FStringEx : public FString
{
public:

#if UNICODE
	inline FStringEx( const ANSICHAR* In )
	{
		Data = nullptr;
		ArrayMax = ArrayNum = *In ? appStrlen(In)+1 : 0;
		if( ArrayNum )
		{
			Realloc( sizeof(TCHAR) );
			TCHAR* UniString = &(*this)(0);
			for ( int32 i=0 ; i<ArrayNum ; i++ )
				UniString[i] = FromAnsi(In[i]);
		}
	}


	inline FStringEx& operator=( const ANSICHAR* Other )
	{
		ArrayNum = ArrayMax = *Other ? appStrlen(Other)+1 : 0;
		Realloc( sizeof(TCHAR) );
		if( ArrayNum )
		{
			TCHAR* UniString = &(*this)(0);
			for ( int32 i=0 ; i<ArrayNum ; i++ )
				UniString[i] = FromAnsi(Other[i]);
		}
		return *this;
	}
#endif
};

