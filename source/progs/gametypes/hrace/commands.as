bool Cmd_GametypeMenu( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    client.execGameCommand( "meop racemod_main" );
    return true;
}

bool Cmd_Gametype( Client@ client, const String &cmdString, const String &argsString, int argc ) {
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

bool Cmd_CvarInfo( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
    return true;
}

String randmap;
String randmap_passed = "";
uint randmap_time = 0;
uint randmap_matches;

bool Cmd_CallvoteValidate( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    String votename = argsString.getToken( 0 );

    if ( votename == "randmap" )
    {

        if ( levelTime - randmap_time > 1100 )
        {
            Cvar mapname( "mapname", "", 0 );
            String current = mapname.string;
            String pattern = argsString.getToken( 1 );

            String[] maps = GetMapsByPattern( pattern, current );

            if ( maps.length() == 0 )
            {
                client.printMessage( "No matching maps\n" );
                return false;
            }

            randmap_matches = maps.length();
            randmap = maps[randrange(randmap_matches)];
        }

        if ( levelTime - randmap_time < 80 )
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

bool Cmd_CallvotePassed( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    String votename = argsString.getToken( 0 );

    if ( votename == "randmap" )
    {
        randmap_passed = randmap;
        match.launchState( MATCH_STATE_POSTMATCH );
    }

    return true;
}

bool Cmd_PrivateMessage( Client@ client, const String &cmdString, const String &argsString, int argc ) {
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
    Player@[] matches = RACE_MatchPlayers( pattern );
    if ( matches.length() == 0 )
    {
        G_PrintMsg( client.getEnt(), "No players matched.\n" );
        return false;
    }
    else if ( matches.length() > 1 )
    {
        G_PrintMsg( client.getEnt(), "Multiple players matched.\n" );
        return false;
    }

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

    G_PrintMsg( matches[0].client.getEnt(), client.name + S_COLOR_MAGENTA + " >>> " + S_COLOR_WHITE + message + "\n" );
    if ( matches[0].firstMessage )
    {
        G_PrintMsg( matches[0].client.getEnt(), "Use /m with part of the player name to reply.\n" );
        matches[0].firstMessage = false;
    }
    G_PrintMsg( client.getEnt(), matches[0].client.name + S_COLOR_MAGENTA + " <<< " + S_COLOR_WHITE + message + "\n" );

    for ( i = 0; i < MAX_FLOOD_MESSAGES - 1; i++ )
        player.messageTimes[i] = player.messageTimes[i + 1];
    player.messageTimes[MAX_FLOOD_MESSAGES - 1] = realTime;

    return true;
}

bool Cmd_RaceRestart( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    Player@ player = RACE_GetPlayer( client );

    // for accuracy, reset scores.
    target_score_init( client );

    if ( pending_endmatch || match.getState() >= MATCH_STATE_POSTMATCH )
    {
        if ( !( player.inRace || player.postRace ) )
            return true;
    }

    player.cancelRace();

    if ( player.practicing && client.team != TEAM_SPECTATOR )
    {
        Entity@ ent = client.getEnt();
        if ( ent.moveType == MOVETYPE_NOCLIP || ent.moveType == MOVETYPE_NONE )
            player.toggleNoclip();

        if ( ent.health >= 0 && player.loadPosition( false ) )
            player.noclipWeapon = player.savedPosition().weapon;
        else
            client.respawn( false );
    }
    else
    {
        if ( client.team == TEAM_SPECTATOR )
        {
            client.team = TEAM_PLAYERS;
            G_PrintMsg( null, client.name + S_COLOR_WHITE + " joined the " + G_GetTeam( client.team ).name + S_COLOR_WHITE + " team.\n" );
        }
        client.respawn( false );
    }

    return true;
}

bool Cmd_Practicemode( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    RACE_GetPlayer( client ).togglePracticeMode();
    return true;
}

bool Cmd_Noclip( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    Player@ player = RACE_GetPlayer( client );
    return player.toggleNoclip();
}

bool Cmd_Position( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    String action = argsString.getToken( 0 );
    Player@ player = RACE_GetPlayer ( client );
    if ( action == "save" )
        return player.savePosition();
    else if ( action == "load" )
        return player.loadPosition( true );
    else if ( action == "recall" )
    {
        String option = argsString.getToken( 1 ).tolower();
        if ( option == "exit" )
            return player.recallExit();
        else if ( option == "steal" )
            return player.recallSteal();
        else if ( option == "best" )
        {
            String pattern = argsString.getToken( 2 );
            return player.recallBest( pattern );
        }
        else if ( option == "start" )
            return player.recallStart();
        else if ( option == "end" )
            return player.recallEnd();
        else if ( option.substr( 0, 2 ) == "cp" )
        {
            int cp = option.substr( 2 ).toInt();
            return player.recallCheckpoint( cp );
        }
        else if ( option == "rl" || option == "pg" || option == "gl" )
        {
            uint weapon = 0;
            if( option == "rl" )
                weapon = WEAP_ROCKETLAUNCHER;
            if( option == "pg" )
                weapon = WEAP_PLASMAGUN;
            if( option == "gl" )
                weapon = WEAP_GRENADELAUNCHER;
            return player.recallWeapon( weapon );
        }
        else
            return player.recallPosition( option.toInt() );
    }
    else if ( action == "speed" && argsString.getToken( 1 ) != "" )
    {
        String speedStr = argsString.getToken( 1 );
        return player.positionSpeed( speedStr );
    }
    else if ( action == "clear" )
        return player.clearPosition();
    else
    {
        G_PrintMsg( client.getEnt(), "position <save | load | speed <value> | recall <offset> | clear>\n" );
        return false;
    }
}

bool Cmd_Top( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    RecordTime@ top = levelRecords[0];
    if ( !top.saved )
    {
        client.printMessage( S_COLOR_RED + "No records yet.\n" );
    }
    else
    {
        Table table( "r r r l l" );
        for ( int i = 0; i < DISPLAY_RECORDS; i++ )
        {
            RecordTime@ record = levelRecords[i];
            if ( record.saved )
            {
                table.addCell( ( i + 1 ) + "." );
                table.addCell( S_COLOR_GREEN + RACE_TimeToString( record.finishTime ) );
                table.addCell( S_COLOR_YELLOW + "[+" + RACE_TimeToString( record.finishTime - top.finishTime ) + "]" );
                table.addCell( S_COLOR_WHITE + record.playerName );
                if ( record.login != "" )
                    table.addCell( "(" + S_COLOR_YELLOW + record.login + S_COLOR_WHITE + ")" );
                else
                    table.addCell( "" );
            }
        }
        uint rows = table.numRows();
        for ( uint i = 0; i < rows; i++ )
            client.printMessage( table.getRow( i ) + "\n" );
    }

    return true;
}

uint[] maplist_page( maxClients );

bool Cmd_Maplist( Client@ client, const String &cmdString, const String &argsString, int argc ) {
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
    {
        page = old_page + 1;
    }
    else if ( arg2 == "prev" )
    {
        page = old_page - 1;
    }
    else if ( arg2.isNumeric() )
    {
        page = arg2.toInt()-1;
    }
    else if ( arg2 == "" )
    {
        page = 0;
    }
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

    last_page = maps.length()/30;

    if ( page < 0 || page > last_page )
    {
        client.printMessage( "Page doesn't exist.\n" );
        return false;
    }
    maplist_page[client.playerNum] = page;

    uint start = 30*page;
    uint end = 30*page+30;
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

bool Cmd_Help( Client@ client, const String &cmdString, const String &argsString, int argc ) {String arg1 = argsString.getToken( 0 ).tolower();
    String arg2 = argsString.getToken( 1 ).tolower();

    if ( arg1 == "" )
    {
        Table cmdlist( S_COLOR_YELLOW + "l " + S_COLOR_WHITE + "l" );
        cmdlist.addCell( "/kill /racerestart" );
        cmdlist.addCell( "Respawns you." );

        cmdlist.addCell( "/practicemode" );
        cmdlist.addCell( "Toggles between race and practicemode." );

        cmdlist.addCell( "/noclip" );
        cmdlist.addCell( "Lets you move freely through the world whilst in practicemode." );

        cmdlist.addCell( "/position save" );
        cmdlist.addCell( "Saves your position including your weapons as the new spawn position." );

        cmdlist.addCell( "/position load" );
        cmdlist.addCell( "Teleports you to your saved position." );

        cmdlist.addCell( "/position speed" );
        cmdlist.addCell( "Sets the speed at which you spawn in practicemode." );

        cmdlist.addCell( "/position clear" );
        cmdlist.addCell( "Resets your weapons and spawn position to their defaults." );

        cmdlist.addCell( "/top" );
        cmdlist.addCell( "Shows the top record times for the current map." );

        cmdlist.addCell( "/m" );
        cmdlist.addCell( "Lets you send a private message." );

        cmdlist.addCell( "/maplist" );
        cmdlist.addCell( "Lets you search available maps." );

        cmdlist.addCell( "/callvote map" );
        cmdlist.addCell( "Calls a vote for the specified map." );

        cmdlist.addCell( "/callvote randmap" );
        cmdlist.addCell( "Calls a vote for a random map in the current mappool." );

        for ( uint i = 0; i < cmdlist.numRows(); i++ )
            client.printMessage( cmdlist.getRow(i) + "\n" );

        client.printMessage( S_COLOR_WHITE + "use " + S_COLOR_YELLOW + "/help <cmd> " + S_COLOR_WHITE + "for additional information." + "\n");
    }
    else if ( arg1 == "m" )
    {
        client.printMessage( S_COLOR_YELLOW + "/m name message" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Sends a private message to the player whose name matches." + "\n" );
    }
    else if ( arg1 == "kill" || arg1 == "racerestart" )
    {
        client.printMessage( S_COLOR_YELLOW + "/kill /racerestart" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Respawns you. I mean srsly.. that's it." + "\n" );
    }
    else if ( arg1 == "practicemode" )
    {
        client.printMessage( S_COLOR_YELLOW + "/practicemode" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Toggles between race and practicemode. Race mode is the only mode in which your time will" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  be recorded. Practicemode is used to practice specific parts of the map. Some commands are" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  restricted to practicemode." + "\n" );
    }
    else if ( arg1 == "noclip" )
    {
        client.printMessage( S_COLOR_YELLOW + "/noclip" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Lets you move freely through the world whilst in practicemode. Use this command to get more" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  control over your position when using /position save. Only works in practicemode." + "\n" );
    }
    else if ( arg1 == "position" && arg2 == "save" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position save" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Saves your position including your weapons as the new spawn position. You can save a separate" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  position for prerace and practicemode, depending on which mode you are in when using the command." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Note: Using this command during race will save your position for practicemode." + "\n" );
    }
    else if ( arg1 == "position" && arg2 == "load" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position load" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Teleports you to your saved position depending on which mode you are in." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Note: This command does not work during race." + "\n" );
    }
    else if ( arg1 == "position" && arg2 == "speed" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position speed <value>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Example: /position speed 1000 - Sets your spawn speed to 1000." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Sets the speed at which you spawn in practicemode. This does not affect prerace speed." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Use /position speed 0 to reset. Note: You don't get spawn speed while in noclip mode." + "\n" );
    }
    else if ( arg1 == "position" && arg2 == "clear" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position clear" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Resets your weapons and spawn position to their defaults." + "\n" );
    }
    else if ( arg1 == "position" && arg2 == "recall" )
    {
        client.printMessage( S_COLOR_YELLOW + "/position recall exit" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Leave recall mode." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall best [player]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Loads positions from your best run, or a matching player." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall steal" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Loads current positions from the player you are spectating." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall start" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Moves to the first recalled position." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall end" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Moves to the last recalled position." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall cpX" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Moves to the first position past checkpoint X." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall rl" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Moves to the first position with a rocket launcher." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall pg" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Moves to the first position with a plasma gun." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall gl" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Moves to the first position with a grenade launcher." + "\n" );
        client.printMessage( S_COLOR_YELLOW + "/position recall <offset>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Cycles through automatically saved positions from your previous run." + "\n" );
    }
    else if ( arg1 == "top" )
    {
        client.printMessage( S_COLOR_YELLOW + "/top" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows a list of the top record times for the current map along with the names and time" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  difference compared to the number 1 time. To see all lists visit: http://livesow.net/race." + "\n" );
    }
    else if ( arg1 == "maplist" )
    {
        client.printMessage( S_COLOR_YELLOW + "/maplist <* | pattern> [<page# | prev | next>]" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Shows a list of available maps. Use wildcard '*' to list all maps. Alternatively, specify a" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  pattern keyword for a list of maps containing the pattern as a partial match. The second" + "\n" );
        client.printMessage( S_COLOR_WHITE + "  argument is optional and is used to browse multiple pages of results." + "\n" );
    }
    else if ( arg1 == "callvote" && arg2 == "map" )
    {
        client.printMessage( S_COLOR_YELLOW + "/callvote map <mapname>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Calls a vote for the specified map. You can use /maplist to search for a map." + "\n" );
    }
    else if ( arg1 == "callvote" && arg2 == "randmap" )
    {
        client.printMessage( S_COLOR_YELLOW + "/callvote randmap <* | pattern>" + "\n" );
        client.printMessage( S_COLOR_WHITE + "- Calls a vote for a random map in the current mappool. Use wildcard '*' to match any map." + "\n" );
        client.printMessage( S_COLOR_WHITE + "  Alternatively, specify a pattern keyword for a map containing the pattern as a partial match." + "\n" );
    }
    else
    {
        client.printMessage( S_COLOR_WHITE + "Command not found.\n");
    }

    return true;
}

bool Cmd_Rules( Client@ client, const String &cmdString, const String &argsString, int argc ) {
    RACE_ShowRules(client, 0);
    return true;
}
