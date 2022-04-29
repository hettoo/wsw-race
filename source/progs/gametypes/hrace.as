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

Vec3 playerMins( -16.0, -16.0, -24.0 );
Vec3 playerMaxs( 16.0, 16.0, 40.0 );

Cvar race_servername( "race_servername", "server", CVAR_ARCHIVE );
Cvar race_rulesFile( "race_rulesfile", "", CVAR_ARCHIVE );
Cvar race_forceFiles( "race_forcefiles", "", CVAR_ARCHIVE );
Cvar race_otherVersions( "race_otherversions", "", CVAR_ARCHIVE );

enum Verbosity {
    Verbosity_Silent,
    Verbosity_Verbose,
};

int numCheckpoints = 0;
bool demoRecording = false;

const float HITBOX_EPSILON = 0.01f;

// ch : MM
const uint RECORD_SEND_INTERVAL = 5 * 60 * 1000; // 5 minutes
uint lastRecordSent = 0;

// msc: practicemode message
uint practiceModeMsg, noclipModeMsg, recallModeMsg, prejumpMsg, defaultMsg;

EntityFinder entityFinder;

const uint SLICK_ABOVE = 32;
const uint SLICK_BELOW = 2048;

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
    String filename = race_rulesFile.string;
    if ( filename == "" )
        return;

    if ( delay > 0 )
    {
        rules_timestamp[client.playerNum] = levelTime + delay;
        return;
    }
    rules_timestamp[client.playerNum] = 0;

    G_Print( "Showing rules to: " + client.name + "\n" );

    String messages = G_LoadFile( filename );
    int len = messages.length();
    int i = 0;
    while ( i < len )
    {
        int current = 0;
        while ( i + current < len && messages.substr( i + current, 1 ) != "\n" )
            current++;
        client.printMessage( S_COLOR_WHITE + messages.substr( i, current ) + "\n" );
        i += current + 1;
    }
}

void RACE_ShowIntro(Client@ client)
{
    if ( client.getUserInfoKey("racemod_seenintro").toInt() == 0 )
    {
        client.execGameCommand("meop racemod_main");
    }
}

void RACE_ForceFiles()
{
    // msc: force pk3 download
    String token = race_forceFiles.string.getToken( 0 );
    for ( int i = 1; token != ""; i++ )
    {
        G_SoundIndex( token, true );
        token = race_forceFiles.string.getToken( i );
    }
}

///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************

bool GT_Command( Client@ client, const String &cmdString, const String &argsString, int argc )
{
    return RACE_HandleCommand( client, cmdString, argsString, argc );
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
                    ( player.bestRun.finishTime > minTime || ( player.bestRun.finishTime == minTime && player.pos >= minPos ) ) &&
                    ( @best == null || player.bestRun.finishTime < best.bestRun.finishTime || ( player.bestRun.finishTime == best.bestRun.finishTime && player.pos < best.pos ) ) )
                @best = player;
        }
        if ( @best != null )
        {
            entry = best.scoreboardEntry();
            if ( scoreboardMessage.length() + entry.length() < maxlen )
                scoreboardMessage += entry;
            minTime = best.bestRun.finishTime;
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

        RACE_GetPlayer( client ).showMapStats();
    }
    else if ( score_event == "userinfochanged" )
    {
        if ( @client != null )
            RACE_GetPlayer( client ).loadStoredTime();
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

    RACE_GetPlayer( ent.client ).spawn( old_team, new_team );
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

        RACE_GetPlayer( client ).think();
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
    {
        // msc: check for overtime
        G_CmdExecute("set g_inactivity_maxtime 5\n");
        G_CmdExecute("set g_disable_vote_remove 0\n");
        if ( Pending_AnyRacing(true) )
        {
            G_AnnouncerSound( null, G_SoundIndex( "sounds/announcer/overtime/overtime" ), GS_MAX_TEAMS, false, null );
            pending_endmatch = true;
            return false;
        }

        lastRecords.toFile();
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
            any_racing = true;
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
    Cvar cm_mapHeader("cm_mapHeader", "", 0);

    //G_Print( "numCheckPoints: " + numCheckpoints + "\n" );

    //TODO: fix in source, /kill should reset touch timeouts.
    for ( int i = 0; i < numEntities; i++ )
    {
        Entity@ ent = G_GetEntity(i);

        if ( ent.classname == "target_teleporter" ) {
            if( cm_mapHeader.string != "FBSP" && ( ent.spawnFlags & 1 ) != 0 ) {
                ent.spawnFlags = ent.spawnFlags & ~1;
            }
        }

        Vec3 centre = Centre( ent );
        if ( entityFinder.slicks.length() < 1 )
        {
            Trace slick;
            Vec3 slick_above = ent.origin;
            slick_above.z += SLICK_ABOVE;
            Vec3 slick_below = ent.origin;
            slick_below.z -= SLICK_BELOW;
            if ( slick.doTrace( slick_above, playerMins, playerMaxs, slick_below, ent.entNum, MASK_DEADSOLID ) && ( slick.surfFlags & SURF_SLICK ) > 0 )
            {
                entityFinder.add( "slick", null, slick.endPos );
            }
            else
            {
                slick_above = centre;
                slick_above.z += SLICK_ABOVE;
                slick_below = centre;
                slick_below.z -= SLICK_BELOW;
                if ( slick.doTrace( slick_above, playerMins, playerMaxs, slick_below, ent.entNum, MASK_DEADSOLID ) && ( slick.surfFlags & SURF_SLICK ) > 0 )
                    entityFinder.add( "slick", null, slick.endPos );
            }
        }
        if ( ent.classname == "target_starttimer" )
            entityFinder.addTriggering( "start", ent, false, true, null );
        else if ( ent.classname == "target_stoptimer" )
            entityFinder.addTriggering( "finish", ent, false, false, null );
        else if ( ent.classname == "info_player_deathmatch" || ent.classname == "info_player_start" )
        {
            Vec3 start = ent.origin;
            Vec3 end = ent.origin;
            Vec3 mins = playerMins;
            Vec3 maxs = playerMaxs;
            mins.x += HITBOX_EPSILON;
            mins.y += HITBOX_EPSILON;
            maxs.x -= HITBOX_EPSILON;
            maxs.y -= HITBOX_EPSILON;
            Trace tr;
            if ( tr.doTrace( start, mins, maxs, end, ent.entNum, MASK_DEADSOLID ) )
            {
                mins.z = 0;
                maxs.z = 0;
                start.z += playerMaxs.z;
                end.z += playerMins.z;
                if ( tr.doTrace( start, mins, maxs, end, ent.entNum, MASK_DEADSOLID ) && !tr.startSolid )
                {
                    Vec3 origin = tr.get_endPos();
                    origin.z -= playerMins.z;
                    ent.set_origin( origin );
                }
            }
        }
        else if ( ent.classname == "weapon_rocketlauncher" )
            entityFinder.addTriggering( "rl", ent, true, false, null );
        else if ( ent.classname == "weapon_grenadelauncher" )
            entityFinder.addTriggering( "gl", ent, true, false, null );
        else if ( ent.classname == "weapon_plasmagun" )
            entityFinder.addTriggering( "pg", ent, true, false, null );
        else if ( ent.classname == "trigger_push" || ent.classname == "trigger_push_velocity" )
            entityFinder.add( "push", ent, centre );
        else if ( ent.classname == "target_speed" )
            entityFinder.addTriggering( "push", ent, false, false, null );
        else if ( ent.classname == "func_door" || ent.classname == "func_door_rotating" )
            entityFinder.add( "door", ent, centre );
        else if ( ent.classname == "func_button" )
            entityFinder.add( "button", ent, centre );
        else if ( ent.classname == "misc_teleporter_dest" || ent.classname == "target_teleporter" )
            entityFinder.add( "tele", ent, centre );
    }

    // setup the checkpoints arrays sizes adjusted to numCheckPoints
    for ( int i = 0; i < maxClients; i++ )
        players[i].resizeCPs( numCheckpoints );

    Cvar mapNameVar( "mapname", "", 0 );
    RACE_LoadTopScores( levelRecords, mapNameVar.string.tolower(), numCheckpoints, "" );

    for ( int i = 0; i < MAX_RECORDS; i++ )
        otherVersionRecords[i].setupArrays( numCheckpoints );

    String version = race_otherVersions.string.getToken( 0 );
    for ( int i = 1; version != ""; i++ )
    {
        RACE_LoadTopScores( otherVersionRecords, mapNameVar.string.tolower(), numCheckpoints, version );
        version = race_otherVersions.string.getToken( i );
    }

    RACE_UpdateHUDTopScores();

    lastRecords.fromFile();
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

    RACE_RegisterCommands();

    // add votes
    G_RegisterCallvote( "randmap", "<* | pattern>", "string", "Changes to a random map" );

    // msc: practicemode message
    practiceModeMsg = G_RegisterHelpMessage(S_COLOR_CYAN + "Practicing");
    noclipModeMsg = G_RegisterHelpMessage(S_COLOR_CYAN + "Practicing - Noclip");
    recallModeMsg = G_RegisterHelpMessage(S_COLOR_CYAN + "Practicing - Recall Mode");
    prejumpMsg = G_RegisterHelpMessage(S_COLOR_RED + "Prejumping!");
    defaultMsg = G_RegisterHelpMessage(" ");

    RACE_ForceFiles();

    demoRecording = false;

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
