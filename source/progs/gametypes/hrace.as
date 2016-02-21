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
int numCheckpoints = 0;
bool demoRecording = false;
const int MAX_RECORDS = 100;

uint[] levelRecordSectors;
uint   levelRecordFinishTime;
String levelRecordPlayerName;

// ch : MM
const uint RECORD_SEND_INTERVAL = 5 * 60 * 1000; // 5 minutes
uint lastRecordSent = 0;

uint practiceModeMsg, defaultMsg;

class RecordTime
{
    uint[] sectorTimes;
    uint   finishTime;
    String playerName;
    String login;
    bool arraysSetUp;

    void setupArrays( int size )
    {
        this.sectorTimes.resize( size );

        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = 0;

        this.arraysSetUp = true;
    }

    RecordTime()
    {
        this.arraysSetUp = false;
        this.finishTime = 0;
    }

    ~RecordTime() {}

    void clear()
    {
        this.playerName = "";
        this.login = "";
        this.finishTime = 0;

        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = 0;
    }

    void Copy( RecordTime &other )
    {
        if ( !this.arraysSetUp )
            return;

        this.finishTime = other.finishTime;
        this.playerName = other.playerName;
        this.login = other.login;
        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = other.sectorTimes[i];
    }

    void Store( Client @client )
    {
        if ( !this.arraysSetUp )
            return;

        Player @player = RACE_GetPlayer( client );

        this.finishTime = player.finishTime;
        this.playerName = client.name;
        if ( client.getUserInfoKey( "cl_mm_session" ).toInt() > 0 )
            this.login = client.getUserInfoKey( "cl_mm_login" );
        else
            this.login = "";
        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = player.sectorTimes[i];
    }
}

RecordTime[] levelRecords( MAX_RECORDS );

class Player
{
    uint[] sectorTimes;
    uint[] bestSectorTimes;
    uint startTime;
    uint finishTime;
    uint bestFinishTime;
    int currentSector;
    bool inRace;
    bool postRace;
    bool practicing;
    bool arraysSetUp;

    bool heardReady;
    bool heardGo;

    // hettoo : practicemode
    int noclipWeapon;
    Vec3 savedPosition;
    Vec3 savedAngles;
    int savedWeapon;
    bool[] savedWeapons;
    int[] savedAmmos;
    float savedSpeed;

    // MSC : seperate prerace
    Vec3 preracePosition;
    Vec3 preraceAngles;
    int preraceWeapon;
    bool[] preraceWeapons;
    int[] preraceAmmos;

    void setupArrays( int size )
    {
        this.sectorTimes.resize( size );
        this.bestSectorTimes.resize( size );
        this.arraysSetUp = true;
        this.clear();
    }

    void clear()
    {
        this.currentSector = 0;
        this.inRace = false;
        this.postRace = false;
        this.practicing = false;
        this.startTime = 0;
        this.finishTime = 0;
        this.bestFinishTime = 0;

        this.heardReady = false;
        this.heardGo = false;

        this.savedPosition = Vec3();
        this.savedWeapons.resize( WEAP_TOTAL );
        this.savedAmmos.resize( WEAP_TOTAL );
        this.savedSpeed = 0;

        // MSC : seperate prerace
        this.preracePosition = Vec3();
        this.preraceWeapons.resize( WEAP_TOTAL );
        this.preraceAmmos.resize( WEAP_TOTAL );

        if ( !this.arraysSetUp )
            return;

        for ( int i = 0; i < numCheckpoints; i++ )
        {
            this.sectorTimes[i] = 0;
            this.bestSectorTimes[i] = 0;
        }
    }

    Player()
    {
        this.arraysSetUp = false;
        this.clear();
    }

    ~Player() {}

    bool preRace( Client @client )
    {
        return !this.inRace && !this.practicing && !this.postRace && client.team != TEAM_SPECTATOR;
    }

    bool loadPosition( Client @client, bool verbose )
    {
        Entity @ent = client.getEnt();
        if ( !this.practicing && client.team != TEAM_SPECTATOR && !this.preRace( client ) )
        {
            if ( verbose )
                G_PrintMsg( ent, "Position load is only available in practicemode or prerace.\n" );
            return false;
        }

        if ( this.practicing )
        {
            if ( this.savedPosition == Vec3() )
            {
                if ( verbose )
                    G_PrintMsg( ent, "No position has been saved yet.\n" );
                return false;
            }

            ent.origin = this.savedPosition;
            ent.angles = this.savedAngles;

            for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
            {
                if ( this.savedWeapons[i] )
                    client.inventoryGiveItem( i );
                Item @item = G_GetItem( i );
                client.inventorySetCount( item.ammoTag, this.savedAmmos[i] );
            }
            client.selectWeapon( this.savedWeapon );

            if ( ent.moveType != MOVETYPE_NOCLIP )
            {
                Vec3 a, b, c;
                this.savedAngles.angleVectors( a, b, c );
                a.z = 0;
                a.normalize();
                a *= this.savedSpeed;
                ent.set_velocity( a );
            }
        } else {
            if ( this.preracePosition == Vec3() )
            {
                if ( verbose )
                    G_PrintMsg( ent, "No position has been saved yet.\n" );
                return false;
            }

            ent.origin = this.preracePosition;
            ent.angles = this.preraceAngles;

            for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
            {
                if ( this.preraceWeapons[i] )
                    client.inventoryGiveItem( i );
                Item @item = G_GetItem( i );
                client.inventorySetCount( item.ammoTag, this.preraceAmmos[i] );
            }
            client.selectWeapon( this.preraceWeapon );
        }

        if ( this.preRace( client ) )
        {
            ent.set_velocity( Vec3() );
        }

        return true;
    }

    void savePosition( Client @client )
    {
        Entity @ent = client.getEnt();

        if ( !this.preRace( client ) )
        {
          this.savedPosition = ent.origin;
          this.savedAngles = ent.angles;
          for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
          {
              this.savedWeapons[i] = client.canSelectWeapon( i );
              Item @item = G_GetItem( i );
              this.savedAmmos[i] = client.inventoryCount( item.ammoTag );
          }
          if ( ent.moveType == MOVETYPE_NOCLIP )
              this.savedWeapon = this.noclipWeapon;
          else
              this.savedWeapon = client.weapon;
        }
        else if ( this.preRace( client ) ) // MSC : seperate prerace
        {
          this.preracePosition = ent.origin;
          this.preraceAngles = ent.angles;
          for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
          {
              this.preraceWeapons[i] = client.canSelectWeapon( i );
              Item @item = G_GetItem( i );
              this.preraceAmmos[i] = client.inventoryCount( item.ammoTag );
          }
          this.preraceWeapon = client.weapon;
        } else {
            G_PrintMsg( ent, "Position save is only available in practicemode or prerace.\n" );
        }
    }

    void clearPosition( Client @client )
    {
      Entity @ent = client.getEnt();

      if ( this.practicing )
      {
        if ( this.savedPosition == Vec3() )
        {
          G_PrintMsg( ent, "No practicemode position has been saved yet.\n" );
          return;
        }
        this.savedPosition = Vec3();
        this.savedWeapons.resize( WEAP_TOTAL );
        this.savedAmmos.resize( WEAP_TOTAL );
        this.savedSpeed = 0;

        G_PrintMsg( ent, "Practicemode position has been cleared.\n" );
        return;
      } else if ( !this.practicing )
      {
        if ( this.preracePosition == Vec3() )
        {
          G_PrintMsg( ent, "No prerace position has been saved yet.\n" );
          return;
        }
        this.preracePosition = Vec3();
        this.preraceWeapons.resize( WEAP_TOTAL );
        this.preraceAmmos.resize( WEAP_TOTAL );

        G_PrintMsg( ent, "Prerace position has been cleared.\n" );
        return;
      }

        this.preracePosition = Vec3();
        this.preraceWeapons.resize( WEAP_TOTAL );
        this.preraceAmmos.resize( WEAP_TOTAL );
    }

    bool startRace( Client @client )
    {
        if ( !this.preRace( client ) )
            return false;

        this.currentSector = 0;
        this.inRace = true;
        this.startTime = levelTime;

        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = 0;

        client.newRaceRun( numCheckpoints );

        return true;
    }

    void cancelRace( Client @client )
    {
        if ( this.inRace && this.currentSector > 0 )
            G_PrintMsg( client.getEnt(), S_COLOR_ORANGE + "Race canceled\n" );

        this.inRace = false;
        this.postRace = false;
        this.finishTime = 0;
    }

    void completeRace( Client @client )
    {
        uint delta;
        String str;

        if ( this.startTime > levelTime ) // something is very wrong here
            return;

        client.addAward( S_COLOR_CYAN + "Race Finished!" );

        this.finishTime = levelTime - this.startTime;
        this.inRace = false;
        this.postRace = true;

        // send the final time to MM
        client.setRaceTime( -1, this.finishTime );

        str = "";
        if ( this.bestFinishTime != 0 )
        {
            // print the time differences with the best race of this player
            // green if player's best time at this sector, red if not improving previous best time
            if ( this.finishTime <= this.bestFinishTime )
            {
                delta = this.bestFinishTime - this.finishTime;
                str = S_COLOR_GREEN + "-";
            }
            else
            {
                delta = this.finishTime - this.bestFinishTime;
                str = S_COLOR_RED + "+";
            }
            str += RACE_TimeToString( delta );
        }

        Entity @ent = client.getEnt();
        RACE_CenterPrintMsg( ent, "Current: " + RACE_TimeToString( this.finishTime ) + "\n" + str );

        G_PrintMsg( ent, S_COLOR_ORANGE + "Race finished: " + S_COLOR_WHITE + RACE_TimeToString( this.finishTime )
                       + S_COLOR_ORANGE + " / Personal: " + RACE_TimeDiffString( this.finishTime, this.bestFinishTime )
                       + S_COLOR_ORANGE + " / Server: " + RACE_TimeDiffString( this.finishTime, levelRecords[0].finishTime ) + "\n" );

        if ( this.bestFinishTime == 0 || this.finishTime < this.bestFinishTime )
        {
            client.addAward( S_COLOR_YELLOW + "Personal record!" );
            // copy all the sectors into the new personal record backup
            this.bestFinishTime = this.finishTime;
            for ( int i = 0; i < numCheckpoints; i++ )
                this.bestSectorTimes[i] = this.sectorTimes[i];
        }

        // see if the player improved one of the top scores
        for ( int top = 0; top < MAX_RECORDS; top++ )
        {
            if ( levelRecords[top].finishTime == 0 || levelRecords[top].finishTime > this.finishTime )
            {
                String cleanName = client.name.removeColorTokens().tolower();
                String login = "";
                if ( client.getUserInfoKey( "cl_mm_session" ).toInt() > 0 )
                    login = client.getUserInfoKey( "cl_mm_login" );

                if ( top == 0 )
                {
                    client.addAward( S_COLOR_GREEN + "Server record!" );
                    G_PrintMsg( null, client.name + S_COLOR_YELLOW + " made a new server record: "
                            + S_COLOR_WHITE + RACE_TimeToString( this.finishTime ) + "\n" );
                }

                int remove = MAX_RECORDS - 1;
                for ( int i = 0; i < MAX_RECORDS; i++ )
                {
                    if ( levelRecords[i].login == "" ? levelRecords[i].playerName.removeColorTokens().tolower() == cleanName : levelRecords[i].login == login )
                    {
                        if ( i < top )
                        {
                            remove = -1; // he already has a better time, don't save it
                            break;
                        }

                        remove = i;
                    }
                }

                if ( remove != -1 )
                {
                    // move the other records down
                    for ( int i = remove; i > top; i-- )
                        levelRecords[i].Copy( levelRecords[i - 1] );

                    levelRecords[top].Store( client );

                    RACE_WriteTopScores();
                    RACE_UpdateHUDTopScores();
                }

                break;
            }
        }

        // set up for respawning the player with a delay
        Entity @respawner = G_SpawnEntity( "race_respawner" );
        respawner.nextThink = levelTime + 5000;
        @respawner.think = race_respawner_think;
        respawner.count = client.playerNum;

        G_AnnouncerSound( client, G_SoundIndex( "sounds/misc/timer_ploink" ), GS_MAX_TEAMS, false, null );
    }

    bool touchCheckPoint( Client @client, int id )
    {
        uint delta;
        String str;

        if ( id < 0 || id >= numCheckpoints )
            return false;

        if ( !this.inRace )
            return false;

        if ( this.sectorTimes[id] != 0 ) // already past this checkPoint
            return false;

        if ( this.startTime > levelTime ) // something is very wrong here
            return false;

        this.sectorTimes[id] = levelTime - this.startTime;

        // send this checkpoint to MM
        client.setRaceTime( id, this.sectorTimes[id] );

        // print some output and give awards if earned

        str = "";
        if ( this.bestSectorTimes[id] == 0 )
        {
            str = S_COLOR_GREEN + str;
        }
        else
        {
            // green if player's best time at this sector, red if not improving previous best time
            // '-' means improved / equal, '+' means worse
            if ( this.sectorTimes[id] <= this.bestSectorTimes[id] )
            {
                delta = this.bestSectorTimes[id] - this.sectorTimes[id];
                str = S_COLOR_GREEN + str + "-";
            }
            else
            {
                delta = this.sectorTimes[id] - this.bestSectorTimes[id];
                str = S_COLOR_RED + str + "+";
            }
            str += RACE_TimeToString( delta );
        }

        Entity @ent = client.getEnt();
        RACE_CenterPrintMsg( ent, "Current: " + RACE_TimeToString( this.sectorTimes[id] ) + "\n" + str );

        G_PrintMsg( ent, S_COLOR_ORANGE + "Sector " + this.currentSector + ": " + S_COLOR_WHITE + RACE_TimeToString( this.sectorTimes[id] )
                       + S_COLOR_ORANGE + " / Personal: " + RACE_TimeDiffString( this.sectorTimes[id], this.bestSectorTimes[id] )
                       + S_COLOR_ORANGE + " / Server: " + RACE_TimeDiffString( this.sectorTimes[id], levelRecords[0].sectorTimes[id] ) + "\n" );

        // if beating the level record on this sector give an award
        if ( this.sectorTimes[id] < levelRecords[0].sectorTimes[id] )
        {
            client.addAward( "Sector record on sector " + this.currentSector + "!" );
        }
        // if beating his own record on this sector give an award
        else if ( this.sectorTimes[id] < this.bestSectorTimes[id] )
        {
            // ch : does racesow apply sector records only if race is completed?
            client.addAward( "Personal record on sector " + this.currentSector + "!" );
            this.bestSectorTimes[id] = this.sectorTimes[id];
        }

        this.currentSector++;

        G_AnnouncerSound( client, G_SoundIndex( "sounds/misc/timer_bip_bip" ), GS_MAX_TEAMS, false, null );

        return true;
    }

    void enterPracticeMode( Client @client )
    {
        if ( this.practicing )
            return;

        this.practicing = true;
        G_CenterPrintMsg( client.getEnt(), S_COLOR_CYAN + "Entered practicemode" );
        client.setHelpMessage(practiceModeMsg);
        this.cancelRace( client );
    }

    void leavePracticeMode( Client @client )
    {
        if ( !this.practicing )
            return;

        this.practicing = false;
        G_CenterPrintMsg( client.getEnt(), S_COLOR_CYAN + "Left practicemode" );
        client.setHelpMessage(defaultMsg);
        if ( client.team != TEAM_SPECTATOR )
            client.respawn( false );
    }

    void togglePracticeMode( Client @client )
    {
        if ( this.practicing )
            this.leavePracticeMode( client );
        else
            this.enterPracticeMode( client );
    }
}

Player[] players( maxClients );

Player @RACE_GetPlayer( Client @client )
{
    if ( @client == null || client.playerNum < 0 )
        return null;

    return @players[client.playerNum];
}

// the player has finished the race. This entity times his automatic respawning
void race_respawner_think( Entity @respawner )
{
    Client @client = G_GetClient( respawner.count );

    // the client may have respawned on their own, so check if they are in postRace
    if ( RACE_GetPlayer( client ).postRace && client.team != TEAM_SPECTATOR )
        client.respawn( false );

    respawner.freeEntity(); // free the respawner
}

///*****************************************************************
/// NEW MAP ENTITY DEFINITIONS
///*****************************************************************

/**
 * Cgg - defrag support
 * target_init are meant to reset the player hp, armor and inventory.
 * spawnflags can be used to limit the effects of the target to certain types of items :
 *   - spawnflag 1 prevents the armor from being removed.
 *   - spawnflag 2 prevents the hp from being reset.
 *   - spawnflag 4 prevents the weapons and ammo from being removed.
 *   - spawnflag 8 prevents the powerups from being removed.
 *   - spawnflag 16 used to prevent the removal of the holdable items (namely the
 *     medkit and teleport) from the player inventory.
 */
void target_init_use( Entity @self, Entity @other, Entity @activator )
{
    int i;

    if ( @activator.client == null )
        return;

    // armor
    if ( ( self.spawnFlags & 1 ) == 0 )
        activator.client.armor = 0;

    // health
    if ( ( self.spawnFlags & 2 ) == 0 )
    {
        activator.health = activator.maxHealth;
    }

    // weapons
    if ( ( self.spawnFlags & 4 ) == 0 )
    {
        for ( i = WEAP_GUNBLADE; i < WEAP_TOTAL; i++ )
        {
            activator.client.inventorySetCount( i, 0 );
        }

        for ( i = AMMO_WEAK_GUNBLADE; i < AMMO_TOTAL; i++ )
        {
            activator.client.inventorySetCount( i, 0 );
        }

        activator.client.inventorySetCount( WEAP_GUNBLADE, 1 );
        activator.client.selectWeapon( WEAP_GUNBLADE );
    }

    // powerups
    if ( ( self.spawnFlags & 8 ) == 0 )
    {
        for ( i = POWERUP_QUAD; i < POWERUP_TOTAL; i++ )
            activator.client.inventorySetCount( i, 0 );
    }
}

// doesn't need to do anything at all, just sit there, waiting
void target_init( Entity @self )
{
    @self.use = target_init_use;
}

void target_checkpoint_use( Entity @self, Entity @other, Entity @activator )
{
    if ( @activator.client == null )
        return;

    Player @player = RACE_GetPlayer( activator.client );

    if ( !player.inRace )
        return;

    if ( player.touchCheckPoint( activator.client, self.count ) )
        self.useTargets( activator );
}

void target_checkpoint( Entity @self )
{
    self.count = numCheckpoints;
    @self.use = target_checkpoint_use;
    numCheckpoints++;
}

void target_stoptimer_use( Entity @self, Entity @other, Entity @activator )
{
    if ( @activator.client == null )
        return;

    Player @player = RACE_GetPlayer( activator.client );

    if ( !player.inRace )
        return;

    player.completeRace( activator.client );

    self.useTargets( activator );
}

// This sucks: some defrag maps have the entity classname with pseudo camel notation
// and classname->function is case sensitive

void target_stoptimer( Entity @self )
{
    @self.use = target_stoptimer_use;
}

void target_stopTimer( Entity @self )
{
    target_stoptimer( self );
}

void target_starttimer_use( Entity @self, Entity @other, Entity @activator )
{
    if ( @activator.client == null )
        return;

    Player @player = RACE_GetPlayer( activator.client );

    if ( player.inRace )
        return;

    if ( player.startRace( activator.client ) )
    {
        if ( !player.heardGo )
        {
            int soundIndex = G_SoundIndex( "sounds/announcer/countdown/go0" + (1 + (rand() & 1)) );
            G_AnnouncerSound( activator.client, soundIndex, GS_MAX_TEAMS, false, null );
            player.heardGo = true;
        }

        self.useTargets( activator );
    }
}

// doesn't need to do anything at all, just sit there, waiting
void target_starttimer( Entity @ent )
{
    @ent.use = target_starttimer_use;
}

void target_startTimer( Entity @ent )
{
    target_starttimer( ent );
}

///*****************************************************************
/// LOCAL FUNCTIONS
///*****************************************************************

String[] scoreboardMessages(maxClients);
bool[] scoreboardCustom(maxClients);
uint scoreboard_time;

void RACE_ScoreboardMessage()
{
  int i;

  for ( i = 0; i < maxClients; i++ )
  {
    if ( !scoreboardCustom[i] )
      continue;

    G_GetClient(i).execGameCommand("scb \"" + scoreboardMessages[i] + "\"");
  }

  if ( scoreboard_time + 1000 >= realTime )
    return;
  scoreboard_time = realTime;

  uint maxlen = 1022;

  String scoreboardMessage = "";
  String entry;
  Team @team;
  Entity @ent;
  Player @player;
  int playerID;
  String racing;

  @team = G_GetTeam( TEAM_PLAYERS );

  // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
  entry = "&t " + int( TEAM_PLAYERS ) + " 0 " + team.ping + " ";
  if ( scoreboardMessage.len() + entry.len() < maxlen )
      scoreboardMessage += entry;

  // "Name Time Ping Racing"
  for ( i = 0; @team.ent( i ) != null; i++ )
  {
      @ent = team.ent( i );

      @player = RACE_GetPlayer( ent.client );
      if ( player.practicing )
          racing = S_COLOR_CYAN + "No";
      else if ( player.inRace )
          racing = S_COLOR_GREEN + "Yes";
      else
          racing = S_COLOR_RED + "No";

      playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;
      entry = "&p " + playerID + " " + ent.client.clanName + " "
              + player.bestFinishTime + " "
              + ent.client.ping + " " + racing + " ";

      if ( scoreboardMessage.len() + entry.len() < maxlen )
          scoreboardMessage += entry;
  }

  for ( i = 0; i < maxClients; i++ )
  {
    Client@ client = @G_GetClient(i);
    if ( client.state() < CS_SPAWNED )
    {
        scoreboardCustom[i] = false;
        continue;
    }

    Client@[] speclist = RACE_GetSpectators(client);

    String customScoreboardMessage = scoreboardMessage;

    if ( speclist.length > 0 )
    {
      entry = "&w ";
      customScoreboardMessage += entry;
      for ( uint j = 0; j < speclist.length; j++ )
      {
        @ent = @speclist[j].getEnt();
        entry = ent.playerNum + " " + ent.client.ping + " ";
        if ( customScoreboardMessage.len() + entry.len() < maxlen )
            customScoreboardMessage += entry;
      }
      scoreboardCustom[i] = true;
    } else {
      scoreboardCustom[i] = false;
      continue;
    }

    @team = G_GetTeam( TEAM_SPECTATOR );

    entry = "&s ";
    if ( customScoreboardMessage.len() + entry.len() < maxlen )
        customScoreboardMessage += entry;

    // "Name Ping"
    for ( int j = 0; @team.ent( j ) != null; j++ )
    {
        @ent = team.ent( j );
        bool skip = false;
        for ( uint k = 0; k < speclist.length; k++ )
        {
          if ( speclist[k].getEnt().entNum == ent.entNum )
            skip = true;
        }
        if ( skip )
          continue;
        playerID = ent.playerNum;
        entry = playerID + " " + ent.client.ping + " ";

        if ( customScoreboardMessage.len() + entry.len() < maxlen )
            customScoreboardMessage += entry;
    }

    scoreboardMessages[i] = customScoreboardMessage;
  }
}

Client@[] RACE_GetSpectators( Client@ client )
{
  Client@[] speclist;

  for ( int i = 0; i < maxClients; i++ )
  {
    Client@ specClient = @G_GetClient(i);

    if ( specClient.chaseActive && specClient.chaseTarget == client.getEnt().entNum )
    {
      speclist.push_back(@specClient);
    }
  }
  return speclist;
}

void RACE_CenterPrintMsg( Entity@ ent, String msg )
{
  G_CenterPrintMsg( ent, msg );
  for ( int i = 0; i < maxClients; i++ )
  {
    Client@ specClient = @G_GetClient(i);

    if ( specClient.chaseActive && specClient.chaseTarget == ent.entNum )
    {
      G_CenterPrintMsg( specClient.getEnt(), msg );
    }
  }
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

String RACE_TimeDiffString( uint time, uint reference )
{
    String result;

    if ( reference == 0 )
        result = S_COLOR_WHITE + " --:--.---";
    else if ( time == reference )
        result = S_COLOR_WHITE + " " + RACE_TimeToString( 0 );
    else if ( time < reference )
        result = S_COLOR_GREEN + "-" + RACE_TimeToString( reference - time );
    else
        result = S_COLOR_RED + "+" + RACE_TimeToString( time - reference );

    return result;
}

void RACE_UpdateHUDTopScores()
{
    for ( int i = 0; i < MAX_RECORDS; i++ )
    {
        G_ConfigString( CS_GENERAL + i, "" ); // somehow it is not shown the first time if it isn't initialized like this
        if ( levelRecords[i].finishTime > 0 && levelRecords[i].playerName.len() > 0 )
            G_ConfigString( CS_GENERAL + i, "#" + ( i + 1 ) + " - " + levelRecords[i].playerName + " - " + RACE_TimeToString( levelRecords[i].finishTime ) );
    }
}

void RACE_WriteTopScores()
{
    String topScores;
    Cvar mapName( "mapname", "", 0 );

    topScores = "//" + mapName.string + " top scores\n\n";

    for ( int i = 0; i < MAX_RECORDS; i++ )
    {
        if ( levelRecords[i].finishTime > 0 && levelRecords[i].playerName.len() > 0 )
        {
            topScores += "\"" + int( levelRecords[i].finishTime );
            if ( levelRecords[i].login != "" )
                topScores += "|" + levelRecords[i].login; // optionally storing it in a token with another value provides backwards compatibility
            topScores += "\" \"" + levelRecords[i].playerName + "\" ";

            // add the sectors
            topScores += "\"" + numCheckpoints+ "\" ";

            for ( int j = 0; j < numCheckpoints; j++ )
                topScores += "\"" + int( levelRecords[i].sectorTimes[j] ) + "\" ";

            topScores += "\n";
        }
    }

    G_WriteFile( "topscores/hrace/" + mapName.string.tolower() + ".txt", topScores );
}

void RACE_LoadTopScores()
{
    String topScores;
    Cvar mapName( "mapname", "", 0 );

    topScores = G_LoadFile( "topscores/hrace/" + mapName.string.tolower() + ".txt" );

    if ( topScores.len() > 0 )
    {
        String timeToken, loginToken, nameToken, sectorToken;
        int count = 0;
        uint sep;

        int i = 0;
        while ( i < MAX_RECORDS )
        {
            timeToken = topScores.getToken( count++ );
            if ( timeToken.len() == 0 )
                break;

            sep = timeToken.locate( "|", 0 );
            if ( sep == timeToken.len() )
            {
                loginToken = "";
            }
            else
            {
                loginToken = timeToken.substr( sep + 1 );
                timeToken = timeToken.substr( 0, sep );
            }

            nameToken = topScores.getToken( count++ );
            if ( nameToken.len() == 0 )
                break;

            sectorToken = topScores.getToken( count++ );
            if ( sectorToken.len() == 0 )
                break;

            int numSectors = sectorToken.toInt();

            // store this one
            for ( int j = 0; j < numSectors; j++ )
            {
                sectorToken = topScores.getToken( count++ );
                if ( sectorToken.len() == 0 )
                    break;

                levelRecords[i].sectorTimes[j] = uint( sectorToken.toInt() );
            }

            // check if he already has a score
            String cleanName = nameToken.removeColorTokens().tolower();
            bool exists = false;
            for ( int j = 0; j < i; j++ )
            {
                if ( ( loginToken != "" && levelRecords[j].login == loginToken )
                        || levelRecords[j].playerName.removeColorTokens().tolower() == cleanName )
                {
                    exists = true;
                    break;
                }
            }
            if ( exists )
            {
                levelRecords[i].clear();
                continue;
            }

            levelRecords[i].finishTime = uint( timeToken.toInt() );
            levelRecords[i].playerName = nameToken;
            levelRecords[i].login = loginToken;

            i++;
        }

        RACE_UpdateHUDTopScores();
    }
}

// a player has just died. The script is warned about it so it can account scores
void RACE_playerKilled( Entity @target, Entity @attacker, Entity @inflicter )
{
    if ( @target == null || @target.client == null )
        return;

    RACE_GetPlayer( target.client ).cancelRace( target.client );
}

void RACE_SetUpMatch()
{
    int i, j;
    Entity @ent;
    Team @team;

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

///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************

String randmap;
uint randmap_matches;
uint randmap_time = 0;

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "gametype" )
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
    else if ( cmdString == "cvarinfo" )
    {
        GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
        return true;
    }
    else if ( cmdString == "callvotevalidate" )
    {
        String votename = argsString.getToken( 0 );

        if ( votename == "randmap" )
        {
            Cvar mapname( "mapname", "", 0 );
            String current = mapname.string.tolower();
            String pattern = argsString.getToken( 1 ).tolower();
            bool anyMap = false;
            if ( pattern == "any" )
              anyMap = true;
            int size = 64;
            String[] maps( size );
            const String @map;
            String lmap;
            int i = 0;
            int matches = 0;

            if ( levelTime - randmap_time > 1100 )
            {
              do
              {
                  @map = ML_GetMapByNum( i );
                  if ( @map != null)
                  {
                      lmap = map.tolower();
                      uint p;
                      bool match = false;
                      if ( pattern == "" )
                      {
                          match = true;
                      }
                      else
                      {
                          for ( p = 0; p < map.len(); p++ )
                          {
                              uint eq = 0;
                              while ( eq < pattern.len() && p + eq < lmap.len() )
                              {
                                  if ( lmap[p + eq] != pattern[eq] )
                                      break;
                                  eq++;
                              }
                              if ( eq == pattern.len() )
                              {
                                  match = true;
                                  break;
                              }
                          }
                      }
                      if ( ( match && map != current) || anyMap )
                      {
                          maps[matches++] = map;
                          if ( matches == size )
                          {
                              size *= 2;
                              maps.resize( size );
                          }
                      }
                  }
                  i++;
              }
              while ( @map != null );

              if ( matches == 0 )
              {
                  client.printMessage( "No matching maps\n" );
                  return false;
              }

              randmap = maps[rand() % matches];
              randmap_matches = matches;
            }

            if ( levelTime - randmap_time < 80 )
            {
              if ( anyMap )
              {
                G_PrintMsg( null, S_COLOR_YELLOW + "Chosen map: " + S_COLOR_WHITE + randmap + "\n" );
              } else {
                G_PrintMsg( null, S_COLOR_YELLOW + "Chosen map: " + S_COLOR_WHITE + randmap + S_COLOR_YELLOW + " (out of " + S_COLOR_WHITE + randmap_matches + S_COLOR_YELLOW + " matches)\n" );
              }
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
    else if ( cmdString == "callvotepassed" )
    {
        String votename = argsString.getToken( 0 );

        if ( votename == "randmap" )
        {
          G_CmdExecute("set g_maprotation 1\n");
          G_CmdExecute("set g_maplist \""+randmap+"\"\n");
          match.launchState(MATCH_STATE_POSTMATCH);
          return true;
        }

        return true;
    }
    else if ( ( cmdString == "racerestart" ) || ( cmdString == "kill" ) )
    {
        if ( @client != null )
        {
            Player @player = RACE_GetPlayer( client );
            Entity @ent = client.getEnt();
            if ( player.inRace )
                player.cancelRace( client );

            if ( client.team == TEAM_SPECTATOR && !gametype.isTeamBased )
                client.team = TEAM_PLAYERS;

            if ( ent.moveType == MOVETYPE_NOCLIP )
                player.loadPosition( client, false );  
            else
            client.respawn( false );
        }

        return true;
    }
    else if ( cmdString == "practicemode" )
    {
        RACE_GetPlayer( client ).togglePracticeMode( client );
        return true;
    }
    else if ( cmdString == "noclip" )
    {
        Entity @ent = client.getEnt();
        Player @player = RACE_GetPlayer( client );
        if ( !player.practicing )
        {
            G_PrintMsg( ent, "Noclip is only available in practicemode.\n" );
            return false;
        }
        if ( client.team == TEAM_SPECTATOR )
        {
            G_PrintMsg( ent, "Noclip is not available for spectators.\n" );
            return false;
        }

        String msg;
        if ( ent.moveType == MOVETYPE_PLAYER )
        {
            ent.moveType = MOVETYPE_NOCLIP;
            player.noclipWeapon = ent.weapon;
            msg = "noclip ON";
        }
        else
        {
            ent.moveType = MOVETYPE_PLAYER;
            client.selectWeapon( player.noclipWeapon );
            msg = "noclip OFF";
        }

        G_PrintMsg( ent, msg + "\n" );

        return true;
    }
    else if ( cmdString == "position" )
    {
        String action = argsString.getToken( 0 );
        if ( action == "save" )
        {
            RACE_GetPlayer( client ).savePosition( client );
        }
        else if ( action == "load" )
        {
            return RACE_GetPlayer( client ).loadPosition( client, true );
        }
        else if ( action == "speed" && argsString.getToken( 1 ) != "" )
        {
            Player @player = RACE_GetPlayer( client );
            String speed = argsString.getToken( 1 );
            if ( speed.locate( "+", 0 ) == 0 )
                player.savedSpeed += speed.substr( 1 ).toFloat();
            else if ( speed.locate( "-", 0 ) == 0 )
                player.savedSpeed -= speed.substr( 1 ).toFloat();
            else
                player.savedSpeed = speed.toFloat();
        }
        else if ( action == "clear" )
        {
            RACE_GetPlayer( client ).clearPosition( client );
        }
        else
        {
            G_PrintMsg( client.getEnt(), "position <save | load | clear | speed <value>>\n" );
            return false;
        }

        return true;
    }
    else if ( cmdString == "top" )
    {
      Cvar mapname( "mapname", "", 0 );
      client.printMessage( S_COLOR_ORANGE + "Toplist for " + S_COLOR_YELLOW + mapname.string + S_COLOR_ORANGE + ":\n");

      RecordTime@ top_record = @levelRecords[0];

      if ( top_record.playerName == "" )
      {
        client.printMessage( S_COLOR_ORANGE + "No records for this map yet.\n");
        return true;
      }
      for ( uint i = 0; i < levelRecords.length; i++ )
      {
        if ( i >= 20 )
          break;
        RecordTime@ record = @levelRecords[i];
        if ( record.playerName == "" )
          continue;
        String line = (i+1) + ". " + S_COLOR_GREEN + RACE_TimeToString(record.finishTime);
        line += " " + S_COLOR_YELLOW + "+[" + RACE_TimeToString(record.finishTime - top_record.finishTime) + "] ";
        line += S_COLOR_WHITE + record.playerName + "\n";
        client.printMessage(line);
      }

      return true;
    }
    else if ( cmdString == "bottom" )
    {
      Cvar mapname( "mapname", "", 0 );
      client.printMessage( S_COLOR_ORANGE + "Bottomlist for " + S_COLOR_YELLOW + mapname.string + S_COLOR_ORANGE + ":\n");

      RecordTime@ top_record = @levelRecords[0];

      if ( top_record.playerName == "" )
      {
        client.printMessage( S_COLOR_ORANGE + "No records for this map yet.\n");
        return true;
      }
      uint numRecords = 0;
      for ( uint i = 0; i < levelRecords.length; i++ )
      {
        if ( numRecords >= 20 )
          break;
        RecordTime@ record = @levelRecords[levelRecords.length-1-i];
        if ( record.playerName == "" )
          continue;
        String line = (levelRecords.length-i) + ". " + S_COLOR_GREEN + RACE_TimeToString(record.finishTime);
        line += " " + S_COLOR_YELLOW + "+[" + RACE_TimeToString(record.finishTime - top_record.finishTime) + "] ";
        line += S_COLOR_WHITE + record.playerName + "\n";
        client.printMessage(line);
        numRecords++;
      }

      return true;
    }

    G_PrintMsg( null, "unknown: " + cmdString + "\n" );

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( Entity @self )
{
    return false; // let the default code handle it itself
}

// select a spawning point for a player
Entity @GT_SelectSpawnPoint( Entity @self )
{
    return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
}

String @GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    Team @team;
    Entity @ent;
    Player @player;
    int i, playerID;
    String racing;
    //int readyIcon;

    @team = G_GetTeam( TEAM_PLAYERS );

    // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
    entry = "&t " + int( TEAM_PLAYERS ) + " 0 " + team.ping + " ";
    if ( scoreboardMessage.len() + entry.len() < maxlen )
        scoreboardMessage += entry;

    // "Name Time Ping Racing"
    for ( i = 0; @team.ent( i ) != null; i++ )
    {
        @ent = team.ent( i );

        @player = RACE_GetPlayer( ent.client );
        if ( player.practicing )
            racing = S_COLOR_CYAN + "No";
        else if ( player.inRace )
            racing = S_COLOR_GREEN + "Yes";
        else
            racing = S_COLOR_RED + "No";

        playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;
        entry = "&p " + playerID + " " + ent.client.clanName + " "
                + player.bestFinishTime + " "
                + ent.client.ping + " " + racing + " ";

        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;
    }

    return scoreboardMessage;
}

// Some game actions trigger score events. These are events not related to killing
// oponents, like capturing a flag
// Warning: client can be null
void GT_ScoreEvent( Client @client, const String &score_event, const String &args )
{
    if ( score_event == "dmg" )
    {
    }
    else if ( score_event == "kill" )
    {
        Entity @attacker = null;

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

        // ch : begin fetching records over interweb
        // MM_FetchRaceRecords( client.getEnt() );
    }
    else if ( score_event == "userinfochanged" )
    {
        if ( @client != null )
        {
            if ( client.getUserInfoKey( "cl_mm_session" ).toInt() > 0 )
            {
                String login = client.getUserInfoKey( "cl_mm_login" );
                if ( login != "" )
                {
                    // find out if he holds a record better than his current time
                    Player @player = RACE_GetPlayer( client );
                    for ( int i = 0; i < MAX_RECORDS; i++ )
                    {
                        if ( levelRecords[i].login == login
                                && ( player.bestFinishTime == 0 || levelRecords[i].finishTime < player.bestFinishTime ) )
                        {
                            player.bestFinishTime = levelRecords[i].finishTime;
                            for ( int j = 0; j < numCheckpoints; j++ )
                                player.bestSectorTimes[j] = levelRecords[i].sectorTimes[j];
                            break;
                        }
                    }
                }
            }
            else
            {
                //G_Print("ohai\n");
                // find out if he holds a record better than his current time
                Player @player = RACE_GetPlayer( client );
                for ( int i = 0; i < MAX_RECORDS; i++ )
                {
                    if ( levelRecords[i].playerName.removeColorTokens().tolower() == client.name.removeColorTokens().tolower()
                            && ( player.bestFinishTime == 0 || levelRecords[i].finishTime < player.bestFinishTime ) )
                    {
                        player.bestFinishTime = levelRecords[i].finishTime;
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
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{
    Player @player = RACE_GetPlayer( ent.client );
    player.cancelRace( ent.client );

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

    player.loadPosition( ent.client, false );

    // add a teleportation effect
    ent.respawnEffect();

    if ( !player.practicing && !player.heardReady )
    {
        int soundIndex = G_SoundIndex( "sounds/announcer/countdown/ready0" + (1 + (rand() & 1)) );
        G_AnnouncerSound( ent.client, soundIndex, GS_MAX_TEAMS, false, null );
        player.heardReady = true;
    }

    if ( player.practicing )
    {
      ent.client.setHelpMessage(practiceModeMsg);
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
    Client @client;
    Player @player;

    for ( int i = 0; i < maxClients; i++ )
    {
        @client = G_GetClient( i );
        if ( client.state() < CS_SPAWNED )
            continue;

        // disable gunblade autoattack
        client.pmoveFeatures = client.pmoveFeatures & ~PMFEAT_GUNBLADEAUTOATTACK;

        // always clear all before setting
        client.setHUDStat( STAT_PROGRESS_SELF, 0 );
        client.setHUDStat( STAT_PROGRESS_OTHER, 0 );
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
        if ( player.inRace )
            client.setHUDStat( STAT_TIME_SELF, ( levelTime - player.startTime ) / 100 );

        client.setHUDStat( STAT_TIME_BEST, player.bestFinishTime / 100 );
        client.setHUDStat( STAT_TIME_RECORD, levelRecords[0].finishTime / 100 );

        client.setHUDStat( STAT_TIME_ALPHA, -9999 );
        client.setHUDStat( STAT_TIME_BETA, -9999 );

        if ( levelRecords[0].playerName.len() > 0 )
            client.setHUDStat( STAT_MESSAGE_OTHER, CS_GENERAL );
        if ( levelRecords[1].playerName.len() > 0 )
            client.setHUDStat( STAT_MESSAGE_ALPHA, CS_GENERAL + 1 );
        if ( levelRecords[2].playerName.len() > 0 )
            client.setHUDStat( STAT_MESSAGE_BETA, CS_GENERAL + 2 );
    }

    // ch : send intermediate results
    if ( ( lastRecordSent + RECORD_SEND_INTERVAL ) >= levelTime )
    {

    }

    // MSC : Weapon pickup fixing
    for ( int i = 0; i < numEntities; i++ )
    {
      Entity@ ent = @G_GetEntity(i);
      if ( ent.classname.substr(0,7) == "weapon_" )
      {
        Entity@[] targeting = ent.findTargeting();
        if ( targeting.length > 0 )
          continue;
        ent.svflags &= ~SVF_NOCLIENT;
        ent.solid = SOLID_TRIGGER;
        ent.attenuation = 0.0;
        ent.nextThink = 0;
      }
    }

    RACE_ScoreboardMessage();
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    if ( match.getState() == MATCH_STATE_POSTMATCH )
    {
        match.stopAutorecord();
        demoRecording = false;

        // ch : also send rest of results
        RACE_WriteTopScores();
    }

    return true;
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

    // setup the checkpoints arrays sizes adjusted to numCheckPoints
    for ( int i = 0; i < maxClients; i++ )
        players[i].setupArrays( numCheckpoints );

    for ( int i = 0; i < MAX_RECORDS; i++ )
        levelRecords[i].setupArrays( numCheckpoints );

    RACE_LoadTopScores();

    // MSC: fix "trigger once" start triggers and various other stuff
    for ( int i = 0; i < numEntities; i++ )
    {
      Entity@ ent = @G_GetEntity(i);
      if ( ent.classname == "trigger_multiple" && ent.wait < 0 )
      {
        ent.wait = 0.2;
      }
    }
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

    gametype.spawnableItemsMask = ( IT_AMMO | IT_WEAPON | IT_POWERUP );
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
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %t 96 %l 48 %s 48" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Time Ping Racing" );

    // add commands
    G_RegisterCommand( "gametype" );
    G_RegisterCommand( "racerestart" );
    G_RegisterCommand( "kill" );
    G_RegisterCommand( "practicemode" );
    G_RegisterCommand( "noclip" );
    G_RegisterCommand( "position" );
    G_RegisterCommand( "top" );
    G_RegisterCommand( "bottom" );

    // add votes
    G_RegisterCallvote( "randmap", "<pattern / any>", "string", "Changes to a random map" );
    G_CmdExecute("set g_maprotation 0\n");
    G_CmdExecute("set g_maplist \"\"\n");

    practiceModeMsg = G_RegisterHelpMessage(S_COLOR_CYAN + "Practicing");
    defaultMsg = G_RegisterHelpMessage("");

    demoRecording = false;

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
