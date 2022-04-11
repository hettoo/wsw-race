Cvar race_toplists( "race_toplists", "", CVAR_ARCHIVE );

bool Cmd_GametypeMenu( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    client.execGameCommand( "meop racemod_main" );
    return true;
}

bool Cmd_Gametype( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    String response = "";
    Cvar fs_game( "fs_game", "", 0 );
    String manifest = gametype.manifest;

    response += "\n";
    response += "Gametype " + gametype.name + " : " + gametype.title + "\n";
    response += "----------------\n";
    response += "Version: " + gametype.version + "\n";
    response += "Author: " + gametype.author + "\n";
    response += "Mod: " + fs_game.string + ( !manifest.empty() ? " (manifest: " + manifest + ")" : "" ) + "\n";
    response += "----------------\n";

    G_PrintMsg( client.getEnt(), response );
    return true;
}

bool Cmd_CvarInfo( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
    return true;
}

String randmap;
String randmap_passed = "";
uint randmap_matches;
uint randmap_time = 0;
const uint RANDMAP_DELAY_MIN = 80;
const uint RANDMAP_DELAY_MAX = 1100;

bool Cmd_CallvoteValidate( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    String votename = argsString.getToken( 0 );

    if ( votename == "randmap" )
    {
        if ( levelTime - randmap_time > RANDMAP_DELAY_MAX )
        {
            Player@ player = RACE_GetPlayer( client );
            randmap = player.randomMap( argsString.getToken( 1 ), false );
            if ( randmap == "" )
                return false;
            randmap_matches = player.randmapMatches;
        }

        if ( levelTime - randmap_time < RANDMAP_DELAY_MIN )
        {
            G_PrintMsg( null, S_COLOR_YELLOW + "Chosen map: " + S_COLOR_WHITE + randmap + S_COLOR_YELLOW + " (out of " + S_COLOR_WHITE + randmap_matches + S_COLOR_YELLOW + " matches)\n" );
            return true;
        }

        randmap_time = levelTime;
    }
    else
    {
        client.printMessage( "Unknown callvote " + votename + "\n" );
        return false;
    }

    return true;
}

bool Cmd_CallvotePassed( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    String votename = argsString.getToken( 0 );

    if ( votename == "randmap" )
    {
        randmap_passed = randmap;
        match.launchState( MATCH_STATE_POSTMATCH );
    }

    return true;
}

const int MAX_FLOOD_MESSAGES = 32;

bool Cmd_PrivateMessage( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    if ( client.muted > 0 )
    {
        G_PrintMsg( client.getEnt(), "You are muted.\n" );
        return false;
    }

    Player@ player = RACE_GetPlayer( client );
    if ( player.messageLock > realTime )
    {
        G_PrintMsg( client.getEnt(), "You can't talk for " + ( ( player.messageLock - realTime ) / 1000 ) + " more seconds.\n" );
        return false;
    }

    String pattern = argsString.getToken( 0 );
    Player@ match = player.oneMatchingPlayer( pattern );
    if ( @match == null )
        return false;

    String message = "";
    String token;
    int i = 1;
    do
    {
        token = argsString.getToken( i );
        if ( i++ > 1 )
            message += " ";
        message += token;
    }
    while ( token != "" );

    if ( i == 2 )
    {
        G_PrintMsg( client.getEnt(), "Empty message.\n" );
        return false;
    }

    Cvar maxMessages( "g_floodprotection_messages", "", 0 );
    Cvar maxMessageTime( "g_floodprotection_seconds", "", 0 );
    uint ref = player.messageTimes[MAX_FLOOD_MESSAGES - maxMessages.integer];
    if ( ref > 0 && ref + uint( maxMessageTime.integer * 1000 ) > realTime )
    {
        Cvar lockTime( "g_floodprotection_delay", "", 0 );
        player.messageLock = realTime + lockTime.integer * 1000;
        G_PrintMsg( client.getEnt(), "Flood protection: You can't talk for " + lockTime.integer + " seconds.\n" );
        return false;
    }

    G_PrintMsg( match.client.getEnt(), client.name + S_COLOR_MAGENTA + " >>> " + message + "\n" );
    if ( match.firstMessage )
    {
        G_PrintMsg( match.client.getEnt(), "Use /m with part of the player name to reply.\n" );
        match.firstMessage = false;
    }
    G_PrintMsg( client.getEnt(), match.client.name + S_COLOR_MAGENTA + " <<< " + message + "\n" );

    for ( i = 0; i < MAX_FLOOD_MESSAGES - 1; i++ )
        player.messageTimes[i] = player.messageTimes[i + 1];
    player.messageTimes[MAX_FLOOD_MESSAGES - 1] = realTime;

    return true;
}

bool Cmd_RaceRestart( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    Player@ player = RACE_GetPlayer( client );

    // for accuracy, reset scores.
    target_score_init( client );

    if ( pending_endmatch || match.getState() >= MATCH_STATE_POSTMATCH )
    {
        if ( !( player.inRace || player.postRace ) )
            return true;
    }

    bool recalled = player.recalled;
    player.cancelRace();
    player.recalled = recalled;

    Entity@ ent = client.getEnt();
    if ( player.practicing && ent.health > 0 && !ent.isGhosting() && client.team != TEAM_SPECTATOR )
    {
        if ( ent.moveType == MOVETYPE_NONE )
            player.toggleNoclip();

        if ( player.loadPosition( "", Verbosity_Silent ) )
        {
            if ( player.recalled || ent.moveType == MOVETYPE_NOCLIP )
            {
                player.noclipWeapon = player.savedPosition().weapon;
                if ( player.recalled )
                {
                    ent.moveType = MOVETYPE_NONE;
                    player.updateHelpMessage();
                    player.release = player.recallHold;
                    return true;
                }
            }
            else
                player.respawn();
        }
        else
            player.respawn();

        if ( ent.moveType == MOVETYPE_NOCLIP )
            ent.velocity = Vec3();
    }
    else
    {
        if ( client.team == TEAM_SPECTATOR )
        {
            client.team = TEAM_PLAYERS;
            G_PrintMsg( null, client.name + S_COLOR_WHITE + " joined the " + G_GetTeam( client.team ).name + S_COLOR_WHITE + " team.\n" );
        }
        player.respawn();
    }

    return true;
}

bool Cmd_Practicemode( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    RACE_GetPlayer( client ).togglePracticeMode();
    return true;
}

bool Cmd_Noclip( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    Player@ player = RACE_GetPlayer( client );
    return player.toggleNoclip();
}

bool Cmd_Position( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    String action = argsString.getToken( 0 );
    Player@ player = RACE_GetPlayer ( client );
    if ( action == "save" )
        return player.savePosition( argsString.getToken( 1 ) );
    else if ( action == "load" )
        return player.loadPosition( argsString.getToken( 1 ), Verbosity_Verbose );
    else if ( action == "list" )
    {
        player.listPositions();
        return true;
    }
    else if ( action == "find" )
        return player.findPosition( argsString.getToken( 1 ), argsString.getToken( 2 ) );
    else if ( action == "join" )
        return player.joinPosition( argsString.getToken( 1 ) );
    else if ( action == "recall" )
    {
        String option = argsString.getToken( 1 ).tolower();
        if ( option == "exit" )
            return player.recallExit();
        else if ( option == "best" )
            return player.recallBest( argsString.getToken( 2 ) );
        else if ( option == "current" )
            return player.recallCurrent( argsString.getToken( 2 ) );
        else if ( option == "fake" )
            return player.recallFake( argsString.getToken( 2 ).toInt() );
        else if ( option == "interval" )
            return player.recallInterval( argsString.getToken( 2 ) );
        else if ( option == "delay" )
            return player.recallDelay( argsString.getToken( 2 ) );
        else if ( option == "start" )
            return player.recallStart();
        else if ( option == "end" )
            return player.recallEnd();
        else if ( option == "extend" )
            return player.recallExtend( argsString.getToken( 2 ).tolower() );
        else if ( option.substr( 0, 2 ) == "cp" )
        {
            int cp = option.substr( 2 ).toInt();
            return player.recallCheckpoint( cp );
        }
        else if ( option == "rl" || option == "pg" || option == "gl" )
        {
            uint weapon = 0;
            if ( option == "rl" )
                weapon = WEAP_ROCKETLAUNCHER;
            if ( option == "pg" )
                weapon = WEAP_PLASMAGUN;
            if ( option == "gl" )
                weapon = WEAP_GRENADELAUNCHER;
            return player.recallWeapon( weapon );
        }
        else
            return player.recallPosition( option.toInt() );
    }
    else if ( action == "speed" && argsString.getToken( 1 ) != "" )
    {
        String speedStr = argsString.getToken( 1 );
        return player.positionSpeed( speedStr, argsString.getToken( 2 ) );
    }
    else if ( action == "clear" )
        return player.clearPosition( argsString.getToken( 1 ) );
    else
    {
        G_PrintMsg( client.getEnt(), "position <save | load | list | find | join | speed <value> | recall | clear>\n" );
        return false;
    }
}

void showTop( Client@ client, const String &mapName, bool full )
{
    RecordTime[]@ records;
    if ( mapName == "" )
    {
        if ( full )
        {
            topRequestRecords = levelRecords;
            @records = topRequestRecords;

            for ( int i = 0; i < MAX_RECORDS && otherVersionRecords[i].saved; i++ )
                RACE_AddTopScore( records, otherVersionRecords[i] );
        }
        else
            @records = levelRecords;
    }
    else
    {
        @records = topRequestRecords;
        RACE_LoadTopScores( records, mapName, 0, "" );
    }

    RecordTime@ top = records[0];
    if ( !top.saved )
    {
        client.printMessage( S_COLOR_RED + "No records yet.\n" );
    }
    else
    {
        Table table( "r r r l ll" );
        for ( int i = 0; i < DISPLAY_RECORDS; i++ )
        {
            RecordTime@ record = records[i];
            if ( record.saved )
            {
                table.addCell( ( i + 1 ) + "." );
                table.addCell( S_COLOR_GREEN + RACE_TimeToString( record.finishTime ) );
                table.addCell( S_COLOR_YELLOW + "[+" + RACE_TimeToString( record.finishTime - top.finishTime ) + "]" );
                table.addCell( S_COLOR_WHITE + record.playerName );
                if ( record.login != "" )
                    table.addCell( S_COLOR_WHITE + "(" + S_COLOR_YELLOW + record.login + S_COLOR_WHITE + ")" );
                else
                    table.addCell( "" );
                if ( full )
                    table.addCell( " " + S_COLOR_WHITE + record.version );
                else
                    table.addCell( "" );
            }
        }
        uint rows = table.numRows();
        for ( uint i = 0; i < rows; i++ )
            client.printMessage( table.getRow( i ) + "\n" );
    }
}

bool Cmd_Top( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    String mapName = argsString.getToken( 0 ).tolower().replace( "/", "" );
    showTop( client, mapName, false );
    return true;
}

bool Cmd_FullTop( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    showTop( client, "", true );
    return true;
}

bool Cmd_CPs( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    return RACE_GetPlayer( client ).showCPs( argsString.getToken( 0 ), argsString.getToken( 1 ), false );
}

bool Cmd_CPsFull( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    return RACE_GetPlayer( client ).showCPs( argsString.getToken( 0 ), argsString.getToken( 1 ), true );
}

bool Cmd_LastRecs( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    return lastRecords.show( client.getEnt() );
}

const uint MAPS_PER_PAGE = 30;
uint[] maplist_page( maxClients );

bool Cmd_Maplist( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    String arg1 = argsString.getToken( 0 ).tolower();
    String arg2 = argsString.getToken( 1 ).tolower();
    uint old_page = maplist_page[client.playerNum];
    int page;
    int last_page;

    if ( arg1 == "" )
    {
        client.printMessage( "maplist <* | pattern> [<page# | prev | next>]\n" );
        return false;
    }

    String pattern = arg1;

    if ( arg2 == "next" )
        page = old_page + 1;
    else if ( arg2 == "prev" )
        page = old_page - 1;
    else if ( arg2.isNumeric() )
        page = arg2.toInt() - 1;
    else if ( arg2 == "" )
        page = 0;
    else
    {
        client.printMessage( "Page must be a number, \"prev\" or \"next\".\n" );
        return false;
    }

    String[] maps = GetMapsByPattern( pattern );

    if ( maps.length() == 0 )
    {
        client.printMessage( "No matching maps\n" );
        return false;
    }

    Table maplist("l l l");

    last_page = maps.length() / MAPS_PER_PAGE;

    if ( page < 0 || page > last_page )
    {
        client.printMessage( "Page doesn't exist.\n" );
        return false;
    }
    maplist_page[client.playerNum] = page;

    uint start = MAPS_PER_PAGE * page;
    uint end = MAPS_PER_PAGE * ( page + 1 );
    if ( end > maps.length() )
    end = maps.length();

    for ( uint i = start; i < end; i++ )
    {
        if ( i >= maps.length() )
            break;
        maplist.addCell( S_COLOR_WHITE + maps[i] );
    }

    client.printMessage( S_COLOR_YELLOW + "Found " + S_COLOR_WHITE + maps.length() + S_COLOR_YELLOW + " maps" +
    S_COLOR_WHITE + " (" + (start+1) + "-" + end + "), " + S_COLOR_YELLOW + "page " + S_COLOR_WHITE + (page+1) + "/" + (last_page+1) + "\n" );

    for ( uint i = 0; i < maplist.numRows(); i++ )
        client.printMessage( maplist.getRow(i) + "\n" );

    return true;
}

bool Cmd_PreRandmap( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    Player@ player = RACE_GetPlayer( client );
    String pattern = argsString.getToken( 0 );
    if ( pattern == "" )
    {
        client.printMessage( "Usage: /prerandmap <* | pattern>\n" );
        return false;
    }

    String result = player.randomMap( pattern, true );
    if ( result == "" )
        return false;

    client.printMessage( S_COLOR_YELLOW + "Showing top for " + S_COLOR_WHITE + result + "\n" );
    showTop( client, result.tolower(), false );

    client.printMessage( S_COLOR_YELLOW + "Chosen map: " + S_COLOR_WHITE + result + S_COLOR_YELLOW + " (out of " + S_COLOR_WHITE + player.randmapMatches + S_COLOR_YELLOW + " matches)\n" );
    return true;
}

bool Cmd_Help( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    String command = argsString.getToken( 0 ).tolower();
    String subcommand = argsString.getToken( 1 ).tolower();

    if ( command == "" )
    {
        Table cmdlist( S_COLOR_YELLOW + "l " + S_COLOR_WHITE + "l" );
        cmdlist.addCell( "/kill /racerestart" );
        cmdlist.addCell( "Respawns you." );

        cmdlist.addCell( "/practicemode" );
        cmdlist.addCell( "Toggles between race and practicemode." );

        cmdlist.addCell( "/noclip" );
        cmdlist.addCell( "Lets you move freely through the world whilst in practicemode." );

        cmdlist.addCell( "/position save [name]" );
        cmdlist.addCell( "Saves your position including your weapons as the new spawn position." );

        cmdlist.addCell( "/position load [name]" );
        cmdlist.addCell( "Teleports you to your saved position." );

        cmdlist.addCell( "/position list" );
        cmdlist.addCell( "Lists saved position names." );

        cmdlist.addCell( "/position find" );
        cmdlist.addCell( "Teleports you to a matching entity." );

        cmdlist.addCell( "/position join" );
        cmdlist.addCell( "Teleports you to a player." );

        cmdlist.addCell( "/position speed" );
        cmdlist.addCell( "Sets the speed at which you spawn in practicemode." );

        cmdlist.addCell( "/position recall" );
        cmdlist.addCell( "Cycle through positions of your last run in practicemode." );

        cmdlist.addCell( "/position clear [name]" );
        cmdlist.addCell( "Resets your weapons and spawn position to their defaults." );

        cmdlist.addCell( "/top" );
        cmdlist.addCell( "Shows the top record times for the current map." );

        cmdlist.addCell( "/topfull" );
        cmdlist.addCell( "Shows the top record times for the current map, including records from previous versions." );

        cmdlist.addCell( "/cps" );
        cmdlist.addCell( "Shows your times between checkpoints for the current map." );

        cmdlist.addCell( "/lastrecs" );
        cmdlist.addCell( "Shows the last records made on previous recent maps." );

        cmdlist.addCell( "/m" );
        cmdlist.addCell( "Lets you send a private message." );

        cmdlist.addCell( "/mark" );
        cmdlist.addCell( "Places a marker at your current position." );

        cmdlist.addCell( "/maplist" );
        cmdlist.addCell( "Lets you search available maps." );

        cmdlist.addCell( "/callvote map" );
        cmdlist.addCell( "Calls a vote for the specified map." );

        cmdlist.addCell( "/callvote randmap" );
        cmdlist.addCell( "Calls a vote for a random map in the current mappool." );

        cmdlist.addCell( "/prerandmap" );
        cmdlist.addCell( "Picks a map for your next randmap vote in advance." );

        for ( uint i = 0; i < cmdlist.numRows(); i++ )
            client.printMessage( cmdlist.getRow(i) + "\n" );

        client.printMessage( S_COLOR_WHITE + "use " + S_COLOR_YELLOW + "/help <cmd> " + S_COLOR_WHITE + "for additional information." + "\n");
    }
    else if ( command == "m" )
    {
        client.printMessage( S_COLOR_YELLOW + "/m name message" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Sends a private message to the player whose name matches." + "\n" );
    }
    else if ( command == "kill" || command == "racerestart" )
    {
        client.printMessage( S_COLOR_YELLOW + "/kill /racerestart" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Respawns you. I mean srsly.. that's it." + "\n" );
    }
    else if ( command == "practicemode" )
    {
        client.printMessage( S_COLOR_YELLOW + "/practicemode" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Toggles between race and practicemode. Race mode is the only mode in which your time will" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  be recorded. Practicemode is used to practice specific parts of the map. Some commands are" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  restricted to practicemode." + "\n" );
    }
    else if ( command == "noclip" )
    {
        client.printMessage( S_COLOR_YELLOW + "/noclip" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Lets you move freely through the world whilst in practicemode. Use this command to get more" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  control over your position when using /position save. Only works in practicemode." + "\n" );
    }
    else if ( command == "position" && subcommand == "save" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position save [name]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Saves your position including your weapons as the new spawn position. You can save a separate" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  position for prerace and practicemode, depending on which mode you are in when using the command." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Note: Using this command during race will save your position for practicemode." + "\n" );
    }
    else if ( command == "position" && subcommand == "load" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position load [name]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Teleports you to your saved position depending on which mode you are in." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Note: This command does not work during race." + "\n" );
    }
    else if ( command == "position" && subcommand == "list" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position list" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Lists your saved position names." + "\n" );
    }
    else if ( command == "position" && subcommand == "find" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position find <start|finish|rl|gl|pg|push|door|button|tele|slick> [info]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Teleports you to a matching entity." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Note: This command does not work during race." + "\n" );
    }
    else if ( command == "position" && subcommand == "join" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position join <pattern>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Teleports you to the player whose name matches pattern." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Note: This command does not work during race." + "\n" );
    }
    else if ( command == "position" && subcommand == "speed" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position speed <value> [name]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Example: /position speed 1000 - Sets your spawn speed to 1000." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Sets the speed at which you spawn in practicemode. This does not affect prerace speed. Prefix with + or - to change the speed relative to the currently set one." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Use /position speed 0 to reset. Note: You don't get spawn speed while in noclip mode." + "\n" );
    }
    else if ( command == "position" && subcommand == "clear" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position clear [name]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Resets your weapons and spawn position to their defaults." + "\n" );
    }
    else if ( command == "position" && subcommand == "recall" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position recall exit" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Leave recall mode." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall best [player]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Loads positions from your best run, or a matching player." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall current <player>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Loads current positions from a matching player." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall fake [time]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Makes the currently saved position a recall position with timestamp time in ms, 0 by default." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall interval [interval]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows/sets the interval at which positions are recorded." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall delay [delay]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows/sets the delay in frames before the start of a recall run." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall <start|end>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Moves to the first or last recalled position." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall extend" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Toggles automatically extending recall runs and enabling the start timer in practicemode." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall cpX" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Moves to the first position past checkpoint X." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall <rl|pg|gl>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Moves to the first position with the given weapon." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall <offset>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Cycles through automatically saved positions from your previous run." + "\n" );
    }
    else if ( command == "top" )
    {
        client.printMessage( S_COLOR_YELLOW + "/top" + " [mapname]\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows a list of the top record times for the current/provided map along with the names and time" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  difference compared to the number 1 time." + "\n" );
        if ( race_toplists.string != "" )
            client.printMessage( S_COLOR_WHITE + "  To see all lists visit: " + race_toplists.string + "." + "\n" );
    }
    else if ( command == "topfull" )
    {
        client.printMessage( S_COLOR_YELLOW + "/topfull" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows a list of the top record times for the current map along with the names and time" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  difference compared to the number 1 time, including times from other game versions." + "\n" );
    }
    else if ( command == "cps" )
    {
        client.printMessage( S_COLOR_YELLOW + "/cps [target pattern] [reference pattern]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows your times between checkpoints on the current map and compares to the best recorded times" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  of players matching target pattern. If a reference pattern is given, the result is shown relative" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  to the matching player from the top list instead of you." + "\n" );
    }
    else if ( command == "cpsfull" )
    {
        client.printMessage( S_COLOR_YELLOW + "/cpsfull [target pattern] [reference pattern]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows your times between checkpoints on the current map and compares to the best recorded times from /topfull" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  of players matching target pattern. If a reference pattern is given, the result is shown relative" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  to the matching player from the top list instead of you." + "\n" );
    }
    else if ( command == "lastrecs" )
    {
        client.printMessage( S_COLOR_YELLOW + "/lastrecs" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows a list of records made on previous recently played maps." + "\n" );
    }
    else if ( command == "maplist" )
    {
        client.printMessage( S_COLOR_YELLOW + "/maplist <* | pattern> [<page# | prev | next>]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows a list of available maps. Use wildcard '*' to list all maps. Alternatively, specify a" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  pattern keyword for a list of maps containing the pattern as a partial match. The second" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  argument is optional and is used to browse multiple pages of results." + "\n" );
    }
    else if ( command == "callvote" && subcommand == "map" )
    {
        client.printMessage( S_COLOR_YELLOW + "/callvote map <mapname>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Calls a vote for the specified map. You can use /maplist to search for a map." + "\n" );
    }
    else if ( command == "callvote" && subcommand == "randmap" )
    {
        client.printMessage( S_COLOR_YELLOW + "/callvote randmap <* | pattern>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Calls a vote for a random map in the current mappool. Use wildcard '*' to match any map." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Alternatively, specify a pattern keyword for a map containing the pattern as a partial match." + "\n" );
    }
    else if ( command == "prerandmap" )
    {
        client.printMessage( S_COLOR_YELLOW + "/prerandmap <* | pattern>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Picks a random map for your next randmap vote." + "\n" );
    }
    else if ( command == "mark" )
    {
        client.printMessage( S_COLOR_YELLOW + "/mark [player]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Spawn a dummy model at your current position, only visible to you. Copies from the player if provided." + "\n" );
    }
    else
    {
        client.printMessage( S_COLOR_WHITE + "Command not found.\n");
    }

    return true;
}

bool Cmd_Rules( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    RACE_ShowRules(client, 0);
    return true;
}

bool Cmd_Mark( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    return RACE_GetPlayer( client ).setMarker( argsString.getToken( 0 ) );
}

bool RACE_HandleCommand( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "gametypemenu" )
        return Cmd_GametypeMenu( client, cmdString, argsString, argc );
    else if ( cmdString == "gametype" )
        return Cmd_Gametype( client, cmdString, argsString, argc );
    else if ( cmdString == "cvarinfo" )
        return Cmd_CvarInfo( client, cmdString, argsString, argc );
    else if ( cmdString == "callvotevalidate" )
        return Cmd_CallvoteValidate( client, cmdString, argsString, argc );
    else if ( cmdString == "callvotepassed" )
        return Cmd_CallvotePassed( client, cmdString, argsString, argc );
    else if ( cmdString == "m" )
        return Cmd_PrivateMessage( client, cmdString, argsString, argc );
    else if ( cmdString == "racerestart" || cmdString == "kill" || cmdString == "join" )
        return Cmd_RaceRestart( client, cmdString, argsString, argc );
    else if ( cmdString == "practicemode" )
        return Cmd_Practicemode( client, cmdString, argsString, argc );
    else if ( cmdString == "noclip" )
        return Cmd_Noclip( client, cmdString, argsString, argc );
    else if ( cmdString == "position" )
        return Cmd_Position( client, cmdString, argsString, argc );
    else if ( cmdString == "top" )
        return Cmd_Top( client, cmdString, argsString, argc );
    else if ( cmdString == "topfull" )
        return Cmd_FullTop( client, cmdString, argsString, argc );
    else if ( cmdString == "cps" )
        return Cmd_CPs( client, cmdString, argsString, argc );
    else if ( cmdString == "cpsfull" )
        return Cmd_CPsFull( client, cmdString, argsString, argc );
    else if ( cmdString == "lastrecs" )
        return Cmd_LastRecs( client, cmdString, argsString, argc );
    else if ( cmdString == "maplist" )
        return Cmd_Maplist( client, cmdString, argsString, argc );
    else if ( cmdString == "prerandmap" )
        return Cmd_PreRandmap( client, cmdString, argsString, argc );
    else if ( cmdString == "help" )
        return Cmd_Help( client, cmdString, argsString, argc );
    else if ( cmdString == "rules")
        return Cmd_Rules( client, cmdString, argsString, argc );
    else if ( cmdString == "mark" )
        return Cmd_Mark( client, cmdString, argsString, argc );

    G_PrintMsg( null, "unknown: " + cmdString + "\n" );

    return false;
}

void RACE_RegisterCommands()
{
    G_RegisterCommand( "gametype" );
    G_RegisterCommand( "gametypemenu" );
    G_RegisterCommand( "m" );
    G_RegisterCommand( "racerestart" );
    G_RegisterCommand( "kill" );
    G_RegisterCommand( "join" );
    G_RegisterCommand( "practicemode" );
    G_RegisterCommand( "noclip" );
    G_RegisterCommand( "position" );
    G_RegisterCommand( "top" );
    G_RegisterCommand( "topfull" );
    G_RegisterCommand( "cps" );
    G_RegisterCommand( "cpsfull" );
    G_RegisterCommand( "lastrecs" );
    G_RegisterCommand( "maplist" );
    G_RegisterCommand( "prerandmap" );
    G_RegisterCommand( "help" );
    G_RegisterCommand( "rules" );
    G_RegisterCommand( "mark" );
}
