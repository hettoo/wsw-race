bool PatternMatch( String str, String pattern, bool wildcard = false ) {
    if( wildcard && ( pattern == "*" || pattern == "" ) ) return true;
    return str.locate( pattern, 0 ) < str.length();
}

String[] GetMapsByPattern( String@ pattern, String@ ignore = null ) {
    String[] maps;

    const String@ map;
    pattern = pattern.removeColorTokens().tolower();
    if( pattern == "*" )
        pattern = "";
    
    uint i = 0;
    while( true ) {
        @map = ML_GetMapByNum( i++ );
        if( @map == null )
            break;
        String clean_map = map.removeColorTokens().tolower();
        if( @ignore != null && map == ignore )
            continue;
        if( PatternMatch( clean_map, pattern ) ) {
            maps.insertLast( map );
        }
    }

    return maps;
}
