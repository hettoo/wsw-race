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

String RACE_TimeToString( uint time )
{
    // convert times to printable form
    String minsString, secsString, millString;
    uint min, sec, milli;

    milli = time;
    min = milli / 60000;
    milli -= min * 60000;
    sec = milli / 1000;
    milli -= sec * 1000;

    if ( min == 0 )
        minsString = "00";
    else if ( min < 10 )
        minsString = "0" + min;
    else
        minsString = min;

    if ( sec == 0 )
        secsString = "00";
    else if ( sec < 10 )
        secsString = "0" + sec;
    else
        secsString = sec;

    if ( milli == 0 )
        millString = "000";
    else if ( milli < 10 )
        millString = "00" + milli;
    else if ( milli < 100 )
        millString = "0" + milli;
    else
        millString = milli;

    return minsString + ":" + secsString + "." + millString;
}

String RACE_TimeDiffString( uint time, uint reference, bool clean )
{
    if ( reference == 0 && clean )
        return "";
    else if ( reference == 0 )
        return S_COLOR_WHITE + "--:--.---";
    else if ( time == reference )
        return S_COLOR_YELLOW + "+-" + RACE_TimeToString( 0 );
    else if ( time < reference )
        return S_COLOR_GREEN + "-" + RACE_TimeToString( reference - time );
    else
        return S_COLOR_RED + "+" + RACE_TimeToString( time - reference );
}
