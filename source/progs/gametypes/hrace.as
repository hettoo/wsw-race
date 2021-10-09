/*
Copyright (C) 2009-2010 Chasseur de bots

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

enum Verbosity {
    Verbosity_Silent,
    Verbosity_Verbose,
};

int numCheckpoints = 0;
bool demoRecording = false;

// ch : MM
const uint RECORD_SEND_INTERVAL = 5 * 60 * 1000; // 5 minutes
uint lastRecordSent = 0;

// msc: practicemode message
uint practiceModeMsg, defaultMsg;

// the player has finished the race. This entity times his automatic respawning
void race_respawner_think( Entity@ respawner )
{
    Client@ client = G_GetClient( respawner.count );

    // for accuracy, reset scores.
    target_score_init( client );

    // the client may have respawned on their own, so check if they are in postRace
    if ( RACE_GetPlayer( client ).postRace && client.team != TEAM_SPECTATOR )
        client.respawn( false );

    respawner.freeEntity(); // free the respawner
}

///*****************************************************************
/// LOCAL FUNCTIONS
///*****************************************************************

Client@[] RACE_GetSpectators( Client@ client )
{
    Client@[] speclist;
    for ( int i = 0; i < maxClients; i++ )
    {
        Client@ specClient = @G_GetClient(i);

        if ( specClient.chaseActive && specClient.chaseTarget == client.getEnt().entNum )
            speclist.push_back( @specClient );
    }
    return speclist;
}

// a player has just died. The script is warned about it so it can account scores
void RACE_playerKilled( Entity@ target, Entity@ attacker, Entity@ inflicter )
{
    if ( @target == null || @target.client == null )
        return;

    // for accuracy, reset scores.
    target_score_init( target.client );

    RACE_GetPlayer( target.client ).cancelRace();
}

void RACE_SetUpMatch()
{
    int i, j;
    Entity@ ent;
    Team@ team;

    gametype.shootingDisabled = false;
    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = true;

    gametype.pickableItemsMask = gametype.spawnableItemsMask;
    gametype.dropableItemsMask = gametype.spawnableItemsMask;

    // clear player stats and scores, team scores

    for ( i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
    {
        @team = G_GetTeam( i );
        team.stats.clear();
    }

    G_RemoveDeadBodies();

    // ch : clear last recordSentTime
    lastRecordSent = levelTime;
}

uint[] rules_timestamp( maxClients );
void RACE_ShowRules(Client@ client, int delay)
{
    if ( delay > 0 )
    {
        rules_timestamp[client.playerNum] = levelTime + delay;
        return;
    }
    rules_timestamp[client.playerNum] = 0;

    //client.printMessage( S_COLOR_WHITE + "Due to recent events, this server will enforce the following rules:\n" );
    //client.printMessage( S_COLOR_WHITE + "\n" );
    client.printMessage( S_COLOR_WHITE + "\u2022 Be respectful towards other players\n" );
    client.printMessage( S_COLOR_WHITE + "\u2022 No bigotry or hate speech\n" );
    client.printMessage( S_COLOR_WHITE + "\u2022 No threats or provocative behaviour towards players or admins\n" );
    client.printMessage( S_COLOR_WHITE + "\u2022 No attempts to cause lag on the server by any means\n" );
    client.printMessage( S_COLOR_WHITE + "\u2022 No forced attacks against livesow or warsow affiliated services\n" );
    client.printMessage( S_COLOR_WHITE + "\u2022 No spreading of harmful software\n" );
    client.printMessage( S_COLOR_WHITE + "\u2022 No promoting of illegal activities\n" );
    client.printMessage( S_COLOR_WHITE + "\u2022 No evading of bans or mutes\n" );
    client.printMessage( S_COLOR_WHITE + "\u2022 All hail our duck overlords\n" );
    client.printMessage( S_COLOR_WHITE + "\n" );
    client.printMessage( S_COLOR_WHITE + "Breaking any of these rules can result in a ban.\n" );
    client.printMessage( S_COLOR_WHITE + "If you are banned or have any objection towards these rules,\n" );
    client.printMessage( S_COLOR_WHITE + "feel free to contact an admin on #livesow @ irc.quakenet.org\n" );

    G_Print("Showing rules to: "+client.name+"\n");
}

void RACE_ShowIntro(Client@ client)
{
    if ( client.getUserInfoKey("racemod_seenintro").toInt() == 0 )
    {
        client.execGameCommand("meop racemod_main");
    }
}

///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************

bool GT_Command( Client@ client, const String &cmdString, const String &argsString, int argc )
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
    else if ( cmdString == "maplist" )
        return Cmd_Maplist( client, cmdString, argsString, argc );
    else if ( cmdString == "help" )
        return Cmd_Help( client, cmdString, argsString, argc );
    else if ( cmdString == "rules")
        return Cmd_Rules( client, cmdString, argsString, argc );

    G_PrintMsg( null, "unknown: " + cmdString + "\n" );

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( Entity@ self )
{
    return false; // let the default code handle it itself
}

// select a spawning point for a player
Entity@ GT_SelectSpawnPoint( Entity@ self )
{
    return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
}

String@ GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    Team@ team;
    Player@ player;
    Player@ best;
    int i;
    uint minTime;
    int minPos;
    //int readyIcon;

    @team = G_GetTeam( TEAM_PLAYERS );

    // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
    entry = "&t " + int( TEAM_PLAYERS ) + " 0 " + team.ping + " ";
    if ( scoreboardMessage.length() + entry.length() < maxlen )
        scoreboardMessage += entry;

    minTime = 0;
    minPos = -1;

    do
    {
        @best = null;

        // find the next best time
        for ( i = 0; @team.ent( i ) != null; i++ )
        {
            @player = RACE_GetPlayer( team.ent( i ).client );

            if ( player.hasTime &&
                    ( player.bestFinishTime > minTime || ( player.bestFinishTime == minTime && player.pos >= minPos ) ) &&
                    ( @best == null || player.bestFinishTime < best.bestFinishTime || ( player.bestFinishTime == best.bestFinishTime && player.pos < best.pos ) ) )
                @best = player;
        }
        if ( @best != null )
        {
            entry = best.scoreboardEntry();
            if ( scoreboardMessage.length() + entry.length() < maxlen )
                scoreboardMessage += entry;
            minTime = best.bestFinishTime;
            minPos = best.pos + 1;
        }
    }
    while ( @best != null );

    // add players without time
    for ( i = 0; @team.ent( i ) != null; i++ )
    {
        @player = RACE_GetPlayer( team.ent( i ).client );

        if ( !player.hasTime )
        {
            entry = player.scoreboardEntry();
            if ( scoreboardMessage.length() + entry.length() < maxlen )
                scoreboardMessage += entry;
        }
    }

    return scoreboardMessage;
}

// Some game actions trigger score events. These are events not related to killing
// oponents, like capturing a flag
// Warning: client can be null
void GT_ScoreEvent( Client@ client, const String &score_event, const String &args )
{
    if ( score_event == "dmg" )
    {
    }
    else if ( score_event == "kill" )
    {
        Entity@ attacker = null;

        if ( @client != null )
            @attacker = client.getEnt();

        int arg1 = args.getToken( 0 ).toInt();
        int arg2 = args.getToken( 1 ).toInt();

        // target, attacker, inflictor
        RACE_playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
    }
    else if ( score_event == "award" )
    {
    }
    else if ( score_event == "enterGame" )
    {
        if ( @client != null )
        {
            RACE_GetPlayer( client ).clear();
            RACE_UpdateHUDTopScores();
        }

        RACE_ShowRules(client, 2000);

        // ch : begin fetching records over interweb
        // MM_FetchRaceRecords( client.getEnt() );
    }
    else if ( score_event == "userinfochanged" )
    {
        if ( @client != null )
        {
            String login = client.getMMLogin();
            if ( login != "" )
            {
                Player@ player = RACE_GetPlayer( client );
                // find out if he holds a record better than his current time
                for ( int i = 0; i < MAX_RECORDS; i++ )
                {
                    if ( !levelRecords[i].saved )
                        break;
                    if ( levelRecords[i].login == login
                            && ( !player.hasTime || levelRecords[i].finishTime < player.bestFinishTime ) )
                    {
                        player.setBestTime( levelRecords[i].finishTime, 0 );
                        player.updatePos();
                        for ( int j = 0; j < numCheckpoints; j++ )
                            player.bestSectorTimes[j] = levelRecords[i].sectorTimes[j];
                        break;
                    }
                }
            }
        }
    }
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity@ ent, int old_team, int new_team )
{
    if ( pending_endmatch )
    {
        if ( ent.client.team != TEAM_SPECTATOR )
        {
          ent.client.team = TEAM_SPECTATOR;
          ent.client.respawn(false);
        }

        if ( !Pending_AnyRacing() )
        {
          pending_endmatch = false;
          match.launchState(MATCH_STATE_POSTMATCH);
        }

        return;
    }

    Player@ player = RACE_GetPlayer( ent.client );
    player.cancelRace();

    player.setQuickMenu();
    player.updateScore();
    if ( old_team != TEAM_PLAYERS && new_team == TEAM_PLAYERS )
        player.updatePos();

    if ( ent.isGhosting() )
        return;

    // set player movement to pass through other players
    ent.client.pmoveFeatures = ent.client.pmoveFeatures | PMFEAT_GHOSTMOVE;

    if ( gametype.isInstagib )
        ent.client.inventoryGiveItem( WEAP_INSTAGUN );
    else
        ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );

    // select rocket launcher if available
    if ( ent.client.canSelectWeapon( WEAP_ROCKETLAUNCHER ) )
        ent.client.selectWeapon( WEAP_ROCKETLAUNCHER );
    else
        ent.client.selectWeapon( -1 ); // auto-select best weapon in the inventory

    G_RemoveProjectiles( ent );
    RS_ResetPjState( ent.client.playerNum );

    player.loadPosition( Verbosity_Silent );

    // msc: permanent practicemode message
    Client@ ref = ent.client;
    if ( ref.team == TEAM_SPECTATOR && ref.chaseActive && ref.chaseTarget != 0 )
        @ref = G_GetEntity( ref.chaseTarget ).client;
    if ( RACE_GetPlayer( ref ).practicing && ref.team != TEAM_SPECTATOR )
        ent.client.setHelpMessage( practiceModeMsg );
    else
        ent.client.setHelpMessage( defaultMsg );

    if ( player.noclipSpawn )
    {
        if ( player.practicing )
        {
            ent.moveType = MOVETYPE_NOCLIP;
            ent.velocity = Vec3(0,0,0);
            player.noclipWeapon = ent.client.pendingWeapon;
        }
        player.noclipSpawn = false;
    }
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
        match.launchState( match.getState() + 1 );

    if ( match.getState() >= MATCH_STATE_POSTMATCH )
        return;

    GENERIC_Think();

    if ( match.getState() == MATCH_STATE_PLAYTIME )
    {
        // if there is no player in TEAM_PLAYERS finish the match and restart
        if ( G_GetTeam( TEAM_PLAYERS ).numPlayers == 0 && demoRecording )
        {
            match.stopAutorecord();
            demoRecording = false;
        }
        else if ( !demoRecording && G_GetTeam( TEAM_PLAYERS ).numPlayers > 0 )
        {
            match.startAutorecord();
            demoRecording = true;
        }
    }

    // set all clients race stats
    Client@ client;
    Player@ player;

    for ( int i = 0; i < maxClients; i++ )
    {
        @client = G_GetClient( i );
        if ( client.state() < CS_SPAWNED )
            continue;

        //delayed rules
        if ( rules_timestamp[i] < levelTime && rules_timestamp[i] != 0 )
        {
            RACE_ShowRules(client, 0);
            RACE_ShowIntro(client);
        }

        // disable gunblade autoattack
        client.pmoveFeatures = client.pmoveFeatures & ~PMFEAT_GUNBLADEAUTOATTACK;

        // always clear all before setting
        client.setHUDStat( STAT_PROGRESS_SELF, 0 );
        //client.setHUDStat( STAT_PROGRESS_OTHER, 0 );
        client.setHUDStat( STAT_IMAGE_SELF, 0 );
        client.setHUDStat( STAT_IMAGE_OTHER, 0 );
        client.setHUDStat( STAT_PROGRESS_ALPHA, 0 );
        client.setHUDStat( STAT_PROGRESS_BETA, 0 );
        client.setHUDStat( STAT_IMAGE_ALPHA, 0 );
        client.setHUDStat( STAT_IMAGE_BETA, 0 );
        client.setHUDStat( STAT_MESSAGE_SELF, 0 );
        client.setHUDStat( STAT_MESSAGE_OTHER, 0 );
        client.setHUDStat( STAT_MESSAGE_ALPHA, 0 );
        client.setHUDStat( STAT_MESSAGE_BETA, 0 );

        // all stats are set to 0 each frame, so it's only needed to set a stat if it's going to get a value
        @player = RACE_GetPlayer( client );
        if ( player.inRace || ( player.practicing && player.recalled && client.getEnt().health > 0 ) )
        {
            if ( client.getEnt().moveType == MOVETYPE_NONE )
                client.setHUDStat( STAT_TIME_SELF, player.savedPosition().currentTime / 100 );
            else
                client.setHUDStat( STAT_TIME_SELF, player.raceTime() / 100 );
        }

        client.setHUDStat( STAT_TIME_BEST, player.bestFinishTime / 100 );
        client.setHUDStat( STAT_TIME_RECORD, levelRecords[0].finishTime / 100 );

        client.setHUDStat( STAT_TIME_ALPHA, -9999 );
        client.setHUDStat( STAT_TIME_BETA, -9999 );

        if ( levelRecords[0].playerName.length() > 0 )
            client.setHUDStat( STAT_MESSAGE_OTHER, CS_GENERAL );
        if ( levelRecords[1].playerName.length() > 0 )
            client.setHUDStat( STAT_MESSAGE_ALPHA, CS_GENERAL + 1 );
        if ( levelRecords[2].playerName.length() > 0 )
            client.setHUDStat( STAT_MESSAGE_BETA, CS_GENERAL + 2 );

        player.saveRunPosition();
        player.checkNoclipAction();
        player.updateMaxSpeed();

        // hettoo: force practicemode message on spectators
        if ( client.team == TEAM_SPECTATOR )
        {
            Client@ ref = client;
            if ( ref.chaseActive && ref.chaseTarget != 0 )
                @ref = G_GetEntity( ref.chaseTarget ).client;
            if ( RACE_GetPlayer( ref ).practicing && ref.team != TEAM_SPECTATOR )
            {
                client.setHelpMessage( practiceModeMsg );
            }
            else
            {
                if ( client.getEnt().isGhosting() )
                    client.setHelpMessage( 0 );
                else
                    client.setHelpMessage( defaultMsg );
            }
        }

        // msc: temporary MAX_ACCEL replacement
        if ( frameTime > 0 )
        {
          float cgframeTime = float(frameTime)/1000;
          int base_speed = int(client.pmoveMaxSpeed);
          float base_accel = base_speed * cgframeTime;
          float speed = HorizontalSpeed( client.getEnt().velocity );
          int max_accel = int( ( sqrt( speed*speed + base_accel * ( 2 * base_speed - base_accel ) ) - speed ) / cgframeTime );
          client.setHUDStat( STAT_PROGRESS_SELF, max_accel );
        }

        Entity@ ent = @client.getEnt();
        if ( ent.client.state() >= CS_SPAWNED && ent.team != TEAM_SPECTATOR )
        {
            if ( ent.health > ent.maxHealth )
            {
                ent.health -= ( frameTime * 0.001f );
                // fix possible rounding errors
                if ( ent.health < ent.maxHealth )
                {
                    ent.health = ent.maxHealth;
                }
            }
        }
    }

    // ch : send intermediate results
    if ( ( lastRecordSent + RECORD_SEND_INTERVAL ) >= levelTime )
    {

    }
}

bool pending_endmatch = false;

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    if ( incomingMatchState == MATCH_STATE_WAITEXIT )
    {
        match.stopAutorecord();
        demoRecording = false;

        // ch : also send rest of results
        RACE_WriteTopScores();
        RACE_UpdatePosValues();

        G_CmdExecute("set g_inactivity_maxtime 90\n");
        G_CmdExecute("set g_disable_vote_remove 1\n");

        if ( randmap_passed != "" )
            G_CmdExecute( "map " + randmap_passed );
    }

    if ( incomingMatchState == MATCH_STATE_POSTMATCH )
    { // msc: check for overtime
      G_CmdExecute("set g_inactivity_maxtime 5\n");
      G_CmdExecute("set g_disable_vote_remove 0\n");
      if ( Pending_AnyRacing(true) )
      {
        G_AnnouncerSound( null, G_SoundIndex( "sounds/announcer/overtime/overtime" ), GS_MAX_TEAMS, false, null );
        pending_endmatch = true;
        return false;
      }
    }

    return true;
}

bool Pending_AnyRacing(bool respawn = false)
{
    bool any_racing = false;
    for ( int i = 0; i < maxClients; i++ )
    {
        Client@ client = G_GetClient( i );
        if ( client.state() < CS_SPAWNED )
            continue;

        Player@ player = RACE_GetPlayer( client );
        if ( player.inRace && !player.postRace && client.team != TEAM_SPECTATOR )
        {
            any_racing = true;
        }
        else
        {
            if ( client.team != TEAM_SPECTATOR )
            {
                client.team = TEAM_SPECTATOR;
                if ( respawn )
                    client.respawn( false );
            }
        }
    }
    return any_racing;
}

// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{
    // hettoo : skip warmup and countdown
    if ( match.getState() < MATCH_STATE_PLAYTIME )
    {
        match.launchState( MATCH_STATE_PLAYTIME );
        return;
    }

    switch ( match.getState() )
    {
        case MATCH_STATE_PLAYTIME:
            RACE_SetUpMatch();
            break;

        case MATCH_STATE_POSTMATCH:
            gametype.pickableItemsMask = 0;
            gametype.dropableItemsMask = 0;
            GENERIC_SetUpEndMatch();
            break;

        default:
            break;
    }
}

// the gametype is shutting down cause of a match restart or map change
void GT_Shutdown()
{
}

// The map entities have just been spawned. The level is initialized for
// playing, but nothing has yet started.
void GT_SpawnGametype()
{
    //G_Print( "numCheckPoints: " + numCheckpoints + "\n" );

    //TODO: fix in source, /kill should reset touch timeouts.
    for ( int i = 0; i < numEntities; i++ )
    {
        Entity@ ent = G_GetEntity(i);
        if ( ent.classname == "trigger_multiple" )
        {
            Entity@[] targets = ent.findTargets();
            for ( uint j = 0; j < targets.length; j++ )
            {
                Entity@ target = targets[j];
                if ( target.classname == "target_starttimer" )
                {
                    ent.wait = 0;
                    break;
                }
            }
        }
    }

    // setup the checkpoints arrays sizes adjusted to numCheckPoints
    for ( int i = 0; i < maxClients; i++ )
        players[i].setupArrays( numCheckpoints );

    Cvar mapNameVar( "mapname", "", 0 );
    RACE_LoadTopScores( levelRecords, mapNameVar.string.tolower(), numCheckpoints );

    RACE_UpdateHUDTopScores();
}

float GT_VotePower( Client@ client, String& votename, bool voted, bool yes )
{
    Player@ player = @RACE_GetPlayer(client);
    if ( player.hasTime && voted && !yes )
    {
        return 2.0;
    }

    return 1.0;
}

// Important: This function is called before any entity is spawned, and
// spawning entities from it is forbidden. If you want to make any entity
// spawning at initialization do it in GT_SpawnGametype, which is called
// right after the map entities spawning.

void GT_InitGametype()
{
    gametype.title = "Race";
    gametype.version = "1.02";
    gametype.author = "Warsow Development Team";

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"\" // list of maps in automatic rotation\n"
                 + "set g_maprotation \"0\"   // 0 = same map, 1 = in order, 2 = random\n"
                 + "\n// game settings\n"
                 + "set g_scorelimit \"0\"\n"
                 + "set g_timelimit \"0\"\n"
                 + "set g_warmup_timelimit \"0\"\n"
                 + "set g_match_extendedtime \"0\"\n"
                 + "set g_allow_falldamage \"0\"\n"
                 + "set g_allow_selfdamage \"0\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"0\"\n"
                 + "set g_teams_maxplayers \"0\"\n"
                 + "set g_teams_allow_uneven \"0\"\n"
                 + "set g_countdown_time \"5\"\n"
                 + "set g_maxtimeouts \"0\" // -1 = unlimited\n"
                 + "set g_challengers_queue \"0\"\n"
                 + "\necho " + gametype.name + ".cfg executed\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

    gametype.spawnableItemsMask = ( IT_WEAPON | IT_AMMO | IT_ARMOR | IT_POWERUP | IT_HEALTH );
    if ( gametype.isInstagib )
        gametype.spawnableItemsMask &= ~uint( G_INSTAGIB_NEGATE_ITEMMASK );

    gametype.respawnableItemsMask = gametype.spawnableItemsMask;
    gametype.dropableItemsMask = 0;
    gametype.pickableItemsMask = ( gametype.spawnableItemsMask | gametype.dropableItemsMask );

    gametype.isTeamBased = false;
    gametype.isRace = true;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.ammoRespawn = 1;
    gametype.armorRespawn = 1;
    gametype.weaponRespawn = 1;
    gametype.healthRespawn = 1;
    gametype.powerupRespawn = 1;
    gametype.megahealthRespawn = 1;
    gametype.ultrahealthRespawn = 1;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = true;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = true;
    gametype.canForceModels = true;
    gametype.canShowMinimap = false;
    gametype.teamOnlyMinimap = true;

    gametype.spawnpointRadius = 0;

    if ( gametype.isInstagib )
        gametype.spawnpointRadius *= 2;

    gametype.inverseScore = true;

    // set spawnsystem type
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %s 32 %t 80 %s 36 %s 48 %l 40 %s 48" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Pos Time Diff Speed Ping Racing" );

    // add commands
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
    G_RegisterCommand( "maplist" );
    G_RegisterCommand( "help" );
    G_RegisterCommand( "rules" );

    // add votes
    G_RegisterCallvote( "randmap", "<* | pattern>", "string", "Changes to a random map" );

    // msc: practicemode message
    practiceModeMsg = G_RegisterHelpMessage(S_COLOR_CYAN + "Practicing");
    defaultMsg = G_RegisterHelpMessage(" ");

    // msc: force pk3 download
    G_SoundIndex( "racemod_ui_v3.txt", true );
    G_SoundIndex( "missing_tex.txt", true );

    demoRecording = false;

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
