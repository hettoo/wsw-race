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
const int MAX_RECORDS = 50;
const int DISPLAY_RECORDS = 20;
const int HUD_RECORDS = 3;

uint[] levelRecordSectors;
uint levelRecordFinishTime;
String levelRecordPlayerName;

// ch : MM
const uint RECORD_SEND_INTERVAL = 5 * 60 * 1000; // 5 minutes
uint lastRecordSent = 0;

// msc: practicemode message
uint practiceModeMsg, defaultMsg;

enum eMenuItems
{
    MI_EMPTY,
    MI_RESTART_RACE,
    MI_ENTER_PRACTICE,
    MI_LEAVE_PRACTICE,
    MI_NOCLIP_ON,
    MI_NOCLIP_OFF,
    MI_SAVE_POSITION,
    MI_LOAD_POSITION,
    MI_CLEAR_POSITION
};

array<const String @> menuItems = {
    '"" ""',
    '"Restart race" "racerestart"',
    '"Enter practice mode" "practicemode" ',
    '"Leave practice mode" "practicemode" ',
    '"Enable noclip mode" "noclip" ',
    '"Disable noclip mode" "noclip" ',
    '"Save position" "position save" ',
    '"Load saved position" "position load" ',
    '"Clear saved position" "position clear" '
};

class RecordTime
{
    bool saved;
    uint[] sectorTimes;
    uint finishTime;
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
        this.saved = false;
        this.arraysSetUp = false;
        this.finishTime = 0;
    }

    ~RecordTime() {}

    void clear()
    {
        this.saved = false;
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

        this.saved = other.saved;
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

        this.saved = true;
        this.finishTime = player.finishTime;
        this.playerName = client.name;
        this.login = client.getMMLogin();
        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = player.sectorTimes[i];
    }
}

RecordTime[] levelRecords( MAX_RECORDS );

class Position
{
    bool saved;
    Vec3 location;
    Vec3 angles;
    bool skipWeapons;
    int weapon;
    bool[] weapons;
    int[] ammos;
    float speed;

    Position()
    {
        this.weapons.resize( WEAP_TOTAL );
        this.ammos.resize( WEAP_TOTAL );
        this.clear();
    }

    ~Position() {}

    void clear()
    {
        this.saved = false;
        this.speed = 0;
    }

    void set( Vec3 location, Vec3 angles )
    {
        this.saved = true;
        this.location = location;
        this.angles = angles;
    }
}

class Table
{
    uint columns;
    bool[] lefts;
    String[] seps;
    uint[] maxs;
    String[] items;

    Table( String format )
    {
        columns = 0;
        seps.insertLast( "" );
        for ( uint i = 0; i < format.length(); i++ )
        {
            String c = format.substr( i, 1 );
            if ( c == "l" || c == "r" )
            {
                this.columns++;
                this.lefts.insertLast( c == "l" );
                this.seps.insertLast( "" );
                this.maxs.insertLast( 0 );
            }
            else
            {
                this.seps[this.seps.length() - 1] += c;
            }
        }
    }

    ~Table() {}

    void clear()
    {
        this.items.resize( 0 );
    }

    void reset()
    {
        this.clear();
        for ( uint i = 0; i < this.columns; i++ )
            this.maxs[i] = 0;
    }

    void addCell( String cell )
    {
        int column = this.items.length() % this.columns;
        uint len = cell.removeColorTokens().length();
        if ( len > this.maxs[column] )
            this.maxs[column] = len;
        this.items.insertLast( cell );
    }

    uint numRows()
    {
        int rows = this.items.length() / this.columns;
        if ( this.items.length() % this.columns != 0 )
            rows++;
        return rows;
    }

    String getRow( uint n )
    {
        String row = "";
        for ( uint i = 0; i < this.columns; i++ )
        {
            uint j = n * this.columns + i;
            if ( j < this.items.length() )
            {
                row += this.seps[i];

                int d = this.maxs[i] - this.items[j].removeColorTokens().length();
                String pad = "";
                for ( int k = 0; k < d; k++ )
                    pad += " ";

                if ( !this.lefts[i] )
                    row += pad;

                row += this.items[j];

                if ( this.lefts[i] )
                    row += pad;
            }
        }
        row += this.seps[this.columns];
        return row;
    }
}

class Player
{
    Client @client;
    uint[] sectorTimes;
    uint[] bestSectorTimes;
    uint startTime;
    uint finishTime;
    bool hasTime;
    uint bestFinishTime;
    bool noclipSpawn;
    Table report( S_COLOR_ORANGE + "l " + S_COLOR_WHITE + "r " + S_COLOR_ORANGE + "/ l r " + S_COLOR_ORANGE + "/ l r" );
    int currentSector;
    bool inRace;
    bool postRace;
    bool practicing;
    uint practicemodeFinishTime;
    bool arraysSetUp;

    bool heardReady;
    bool heardGo;

    // hettoo : practicemode
    int noclipWeapon;
    Position practicePosition;
    Position preRacePosition;

    void setupArrays( int size )
    {
        this.sectorTimes.resize( size );
        this.bestSectorTimes.resize( size );
        this.arraysSetUp = true;
        this.clear();
    }

    void clear()
    {
        @this.client = null;
        this.currentSector = 0;
        this.inRace = false;
        this.postRace = false;
        this.practicing = false;
        this.practicemodeFinishTime = 0;
        this.startTime = 0;
        this.finishTime = 0;
        this.hasTime = false;
        this.bestFinishTime = 0;
        this.noclipSpawn = false;

        this.heardReady = false;
        this.heardGo = false;

        this.practicePosition.clear();
        this.preRacePosition.clear();

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

    void setBestTime( uint time )
    {
        this.hasTime = true;
        this.bestFinishTime = time;
        this.updateScore();
    }

    void updateScore()
    {
        this.client.stats.setScore( this.bestFinishTime / 10 );
    }

    String @scoreboardEntry()
    {
        Entity @ent = this.client.getEnt();
        int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;
        String racing;

        if ( this.practicing )
            racing = S_COLOR_CYAN + "No";
        else if ( this.inRace )
            racing = S_COLOR_GREEN + "Yes";
        else
            racing = S_COLOR_RED + "No";
        String diff;
        if ( this.hasTime && levelRecords[0].saved && this.bestFinishTime >= levelRecords[0].finishTime )
        {
            if ( this.bestFinishTime == levelRecords[0].finishTime )
                diff = S_COLOR_GREEN + "0";
            else if ( this.bestFinishTime >= levelRecords[0].finishTime + 1000 )
                diff = S_COLOR_RED + "+";
            else
                diff = S_COLOR_YELLOW + ( this.bestFinishTime - levelRecords[0].finishTime );
        }
        else
        {
            diff = "-";
        }
        return "&p " + playerID + " " + ent.client.clanName + " " + this.bestFinishTime + " " + diff + " " + ent.client.ping + " " + racing + " ";
    }

    bool preRace()
    {
        return !this.inRace && !this.practicing && !this.postRace && this.client.team != TEAM_SPECTATOR;
    }

    void setQuickMenu()
    {
        String s = '';
        Position @position = this.savedPosition();

        s += menuItems[MI_RESTART_RACE];
        if ( this.practicing )
        {
            s += menuItems[MI_LEAVE_PRACTICE];
            if ( this.client.team != TEAM_SPECTATOR )
            {
                if ( this.client.getEnt().moveType == MOVETYPE_NOCLIP )
                    s += menuItems[MI_NOCLIP_OFF];
                else
                    s += menuItems[MI_NOCLIP_ON];
            }
            else
            {
                s += menuItems[MI_EMPTY];
            }
            s += menuItems[MI_SAVE_POSITION];
            if ( position.saved )
                s += menuItems[MI_LOAD_POSITION] +
                     menuItems[MI_CLEAR_POSITION];
        }
        else
        {
            s += menuItems[MI_ENTER_PRACTICE] +
                 menuItems[MI_EMPTY] +
                 menuItems[MI_SAVE_POSITION];
            if ( position.saved && ( this.preRace() || this.client.team == TEAM_SPECTATOR ) )
                s += menuItems[MI_LOAD_POSITION] +
                     menuItems[MI_CLEAR_POSITION];
        }

        GENERIC_SetQuickMenu( this.client, s );
    }

    bool toggleNoclip()
    {
        Entity @ent = this.client.getEnt();
        if ( !this.practicing )
        {
            G_PrintMsg( ent, "Noclip mode is only available in practice mode.\n" );
            return false;
        }
        if ( this.client.team == TEAM_SPECTATOR )
        {
            G_PrintMsg( ent, "Noclip mode is not available for spectators.\n" );
            return false;
        }

        String msg;
        if ( ent.moveType == MOVETYPE_PLAYER )
        {
            ent.moveType = MOVETYPE_NOCLIP;
            this.noclipWeapon = ent.weapon;
            msg = "Noclip mode enabled.";
        }
        else
        {
            ent.moveType = MOVETYPE_PLAYER;
            this.client.selectWeapon( this.noclipWeapon );
            msg = "Noclip mode disabled.";
        }

        G_PrintMsg( ent, msg + "\n" );

        this.setQuickMenu();

        return true;
    }

    Position @savedPosition()
    {
        if ( this.preRace() )
            return preRacePosition;
        else
            return practicePosition;
    }

    bool loadPosition( bool verbose )
    {
        Entity @ent = this.client.getEnt();
        if ( !this.practicing && this.client.team != TEAM_SPECTATOR && !this.preRace() )
        {
            if ( verbose )
                G_PrintMsg( ent, "Position loading is not available during a race.\n" );
            return false;
        }

        Position @position = this.savedPosition();

        if ( !position.saved )
        {
            if ( verbose )
                G_PrintMsg( ent, "No position has been saved yet.\n" );
            return false;
        }

        ent.origin = position.location;
        ent.angles = position.angles;

        if ( !position.skipWeapons )
        {
            for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
            {
                if ( position.weapons[i] )
                    this.client.inventoryGiveItem( i );
                Item @item = G_GetItem( i );
                this.client.inventorySetCount( item.ammoTag, position.ammos[i] );
            }
            this.client.selectWeapon( position.weapon );
        }

        if ( this.practicing )
        {
            if ( ent.moveType != MOVETYPE_NOCLIP )
            {
                Vec3 a, b, c;
                position.angles.angleVectors( a, b, c );
                a.z = 0;
                a.normalize();
                a *= position.speed;
                ent.set_velocity( a );
            } else {
                ent.set_velocity( Vec3() );
            }
        }
        else if ( this.preRace() )
        {
            ent.set_velocity( Vec3() );
        }

        return true;
    }

    bool savePosition()
    {
        Client @ref = this.client;
        if ( this.client.team == TEAM_SPECTATOR && this.client.chaseActive )
            @ref = G_GetEntity( this.client.chaseTarget ).client;
        Entity @ent = ref.getEnt();

        if ( this.preRace() )
        {
            Vec3 mins, maxs;
            ent.getSize( mins, maxs );
            Vec3 down = ent.origin;
            down.z -= 1;
            Trace tr;
            if ( !tr.doTrace( ent.origin, mins, maxs, down, ent.entNum, MASK_PLAYERSOLID ) )
            {
                G_PrintMsg( this.client.getEnt(), "You can only save your prerace position on solid ground.\n" );
                return false;
            }
            if ( maxs.z < 40 )
            {
                G_PrintMsg( this.client.getEnt(), "You can't save your prerace position while crouched.\n" );
                return false;
            }
        }

        Position @position = this.savedPosition();
        position.set( ent.origin, ent.angles );

        if ( ref.team == TEAM_SPECTATOR )
        {
            position.skipWeapons = true;
        }
        else
        {
            position.skipWeapons = false;
            for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
            {
                position.weapons[i] = ref.canSelectWeapon( i );
                Item @item = G_GetItem( i );
                position.ammos[i] = ref.inventoryCount( item.ammoTag );
            }
            position.weapon = ent.moveType == MOVETYPE_NOCLIP ? this.noclipWeapon : ref.weapon;
        }
        this.setQuickMenu();

        return true;
    }

    bool clearPosition()
    {
        if ( !this.practicing && this.client.team != TEAM_SPECTATOR && !this.preRace() )
        {
            G_PrintMsg( this.client.getEnt(), "Position clearing is not available during a race.\n" );
            return false;
        }

        this.savedPosition().clear();
        this.setQuickMenu();

        return true;
    }

    uint timeStamp()
    {
        return this.client.uCmdTimeStamp;
    }

    bool startRace()
    {
        if ( !this.preRace() )
            return false;

        if ( RS_QueryPjState( this.client.playerNum )  )
        {
          this.client.addAward( S_COLOR_RED + "Prejumped!" );
          
            // for accuracy, reset scores.
            target_score_init( this.client );
            
          this.client.respawn( false );
          RS_ResetPjState( this.client.playerNum );
          return false;
        }

        this.currentSector = 0;
        this.inRace = true;
        this.startTime = this.timeStamp();

        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = 0;

        this.report.reset();

        this.client.newRaceRun( numCheckpoints );

        this.setQuickMenu();

        return true;
    }

    bool validTime()
    {
        return this.timeStamp() >= this.startTime;
    }

    uint raceTime()
    {
        return this.timeStamp() - this.startTime;
    }

    void cancelRace()
    {
        if ( this.inRace && this.currentSector > 0 )
        {
            Entity @ent = this.client.getEnt();
            uint rows = this.report.numRows();
            for ( uint i = 0; i < rows; i++ )
                G_PrintMsg( ent, this.report.getRow( i ) + "\n" );
            G_PrintMsg( ent, S_COLOR_ORANGE + "Race cancelled\n" );
        }

        this.inRace = false;
        this.postRace = false;
        this.finishTime = 0;
    }

    void completeRace()
    {
        uint delta;
        String str;

        if ( !this.validTime() ) // something is very wrong here
            return;

        this.client.addAward( S_COLOR_CYAN + "Race Finished!" );

        this.finishTime = this.raceTime();
        this.inRace = false;
        this.postRace = true;

        // send the final time to MM
        this.client.setRaceTime( -1, this.finishTime );

        str = "Current: " + RACE_TimeToString( this.finishTime );

        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            if ( !levelRecords[i].saved )
                break;
            if ( this.finishTime <= levelRecords[i].finishTime )
            {
                str += " (" + S_COLOR_GREEN + "#" + ( i + 1 ) + S_COLOR_WHITE + ")"; // extra id when on server record beating time
                break;
            }
        }

        Entity @ent = this.client.getEnt();

        G_CenterPrintMsg( ent, str + "\n" + RACE_TimeDiffString( this.finishTime, this.bestFinishTime, true ) );


        Client@[] specs = RACE_GetSpectators(this.client);
        for ( uint i = 0; i < specs.length; i++ )
        {
          Player@ spec_player = @RACE_GetPlayer(specs[i]);
          String line1 = "";
          String line2 = "";

          if ( this.hasTime )
          {
            line1 += "\u00A0   Current: " + RACE_TimeToString( this.finishTime ) + "   \u00A0";
            line2 += "\u00A0           " + RACE_TimeDiffString(this.finishTime, this.bestFinishTime, true) + "           \u00A0";
          } else {
            line1 += "\u00A0   Current: " + RACE_TimeToString( this.finishTime ) + "   \u00A0";
            line2 += "\u00A0           " + "                    " + "           \u00A0";
          }

          if ( spec_player.hasTime )
          {
            line1 = "\u00A0  Personal:    " + "          " + line1;
            line2 = RACE_TimeDiffString(this.finishTime, spec_player.bestFinishTime, true) + "          " + line2;
          } else if ( levelRecords[0].finishTime != 0 ) {
            line1 = "\u00A0                                " + line1;
            line2 = "\u00A0                                " + line2;
          }

          if ( levelRecords[0].finishTime != 0 )
          {
            line1 += "\u00A0          " + "Server:     \u00A0";
            line2 += "\u00A0      " + RACE_TimeDiffString(this.finishTime, levelRecords[0].finishTime, true) + "\u00A0";
          }

          G_CenterPrintMsg(specs[i].getEnt(), line1 + "\n" + line2);
        }

        //G_CenterPrintMsg( ent, str + "\n" + RACE_TimeDiffString( this.finishTime, this.bestFinishTime, true ) );
        this.report.addCell( "Race finished:" );
        this.report.addCell( RACE_TimeToString( this.finishTime ) );
        this.report.addCell( "Personal:" );
        this.report.addCell( RACE_TimeDiffString( this.finishTime, this.bestFinishTime, false ) );
        this.report.addCell( "Server:" );
        this.report.addCell( RACE_TimeDiffString( this.finishTime, levelRecords[0].finishTime, false ) );
        uint rows = this.report.numRows();
        for ( uint i = 0; i < rows; i++ )
            G_PrintMsg( ent, this.report.getRow( i ) + "\n" );

        if ( !this.hasTime || this.finishTime < this.bestFinishTime )
        {
            this.client.addAward( S_COLOR_YELLOW + "Personal record!" );
            // copy all the sectors into the new personal record backup
            this.setBestTime( this.finishTime );
            for ( int i = 0; i < numCheckpoints; i++ )
                this.bestSectorTimes[i] = this.sectorTimes[i];
        }

        // see if the player improved one of the top scores
        for ( int top = 0; top < MAX_RECORDS; top++ )
        {
            if ( !levelRecords[top].saved || this.finishTime < levelRecords[top].finishTime )
            {
                String cleanName = this.client.name.removeColorTokens().tolower();
                String login = this.client.getMMLogin();

                if ( top == 0 )
                {
                    this.client.addAward( S_COLOR_GREEN + "Server record!" );

                    uint prevTime = 0;

                    if ( levelRecords[0].finishTime != 0 )
                        prevTime = levelRecords[0].finishTime;

                    if ( levelRecords[0].finishTime == 0 )
                    {
                      G_PrintMsg( null, this.client.name + S_COLOR_YELLOW + " set a new ^2livesow.net ^3record: "
                              + S_COLOR_GREEN + RACE_TimeToString( this.finishTime ) + "\n" );
                    }
                    else
                    {
                      G_PrintMsg( null, this.client.name + S_COLOR_YELLOW + " set a new ^2livesow.net ^3record: "
                              + S_COLOR_GREEN + RACE_TimeToString( this.finishTime ) + " " + S_COLOR_YELLOW + "[-" + RACE_TimeToString( levelRecords[0].finishTime - this.finishTime ) + "]\n" );
                    }
                }

                int remove = MAX_RECORDS - 1;
                for ( int i = 0; i < MAX_RECORDS; i++ )
                {
                    if ( ( login == "" && levelRecords[i].login == "" && levelRecords[i].playerName.removeColorTokens().tolower() == cleanName )
                            || ( login != "" && levelRecords[i].login == login ) )
                    {
                        if ( i < top )
                            remove = -1; // he already has a better time, don't save it
                        else
                            remove = i;
                        break;
                    }
                    if ( login == "" && levelRecords[i].login != "" && levelRecords[i].playerName.removeColorTokens().tolower() == cleanName && i < top )
                    {
                        remove = -1; // he already has a better time, don't save it
                        break;
                    }
                }

                if ( remove != -1 )
                {
                    // move the other records down
                    for ( int i = remove; i > top; i-- )
                        levelRecords[i].Copy( levelRecords[i - 1] );

                    levelRecords[top].Store( this.client );

                    if ( login != "" )
                    {
                        // there may be authed and unauthed records for a
                        // player; remove the unauthed if it is worse than the
                        // authed one
                        bool found = false;
                        for ( int i = top + 1; i < MAX_RECORDS; i++ )
                        {
                            if ( levelRecords[i].login == "" && levelRecords[i].playerName.removeColorTokens().tolower() == cleanName )
                                found = true;
                            if ( found && i < MAX_RECORDS - 1 )
                                levelRecords[i].Copy( levelRecords[i + 1] );
                        }
                        if ( found )
                            levelRecords[MAX_RECORDS - 1].clear();
                    }

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
        respawner.count = this.client.playerNum;

        G_AnnouncerSound( this.client, G_SoundIndex( "sounds/misc/timer_ploink" ), GS_MAX_TEAMS, false, null );
    }

    bool touchCheckPoint( int id )
    {
        uint delta;
        String str;

        if ( id < 0 || id >= numCheckpoints )
            return false;

        if ( !this.inRace )
            return false;

        if ( this.sectorTimes[id] != 0 ) // already past this checkPoint
            return false;

        if ( !this.validTime() ) // something is very wrong here
            return false;

        this.sectorTimes[id] = this.raceTime();

        // send this checkpoint to MM
        this.client.setRaceTime( id, this.sectorTimes[id] );

        // print some output and give awards if earned

        str = "Current: " + RACE_TimeToString( this.sectorTimes[id] );

        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            if ( this.sectorTimes[id] <= levelRecords[i].sectorTimes[id] )
            {
                str += " (" + S_COLOR_GREEN + "#" + ( i + 1 ) + S_COLOR_WHITE + ")"; // extra id when on server record beating time
                break;
            }
        }

        Entity @ent = this.client.getEnt();

        G_CenterPrintMsg( ent, str + "\n" + RACE_TimeDiffString( this.sectorTimes[id], this.bestSectorTimes[id], true ) );


        Client@[] specs = RACE_GetSpectators(this.client);
        for ( uint i = 0; i < specs.length; i++ )
        {
          Player@ spec_player = @RACE_GetPlayer(specs[i]);
          String line1 = "";
          String line2 = "";

          if ( this.hasTime && this.sectorTimes[id] != 0 )
          {
            line1 += "\u00A0   Current: " + RACE_TimeToString( this.sectorTimes[id] ) + "   \u00A0";
            line2 += "\u00A0           " + RACE_TimeDiffString(this.sectorTimes[id], this.bestSectorTimes[id], true) + "           \u00A0";
          } else {
            line1 += "\u00A0   Current: " + RACE_TimeToString( this.sectorTimes[id] ) + "   \u00A0";
            line2 += "\u00A0           " + "                    " + "           \u00A0";
          }

          if ( spec_player.hasTime && spec_player.bestSectorTimes[id] != 0 )
          {
            line1 = "\u00A0  Personal:    " + "          " + line1;
            line2 = RACE_TimeDiffString(this.sectorTimes[id], spec_player.bestSectorTimes[id], true) + "          " + line2;
          } else if ( levelRecords[0].finishTime != 0 ) {
            line1 = "\u00A0                                " + line1;
            line2 = "\u00A0                                " + line2;
          }

          if ( levelRecords[0].finishTime != 0 && levelRecords[0].sectorTimes[id] != 0 )
          {
            line1 += "\u00A0          " + "Server:     \u00A0";
            line2 += "\u00A0      " + RACE_TimeDiffString(this.sectorTimes[id], levelRecords[0].sectorTimes[id], true) + "\u00A0";
          }

          G_CenterPrintMsg(specs[i].getEnt(), line1 + "\n" + line2);
        }

        //G_CenterPrintMsg( ent, str + "\n" + RACE_TimeDiffString( this.sectorTimes[id], this.bestSectorTimes[id], true ) );
        this.report.addCell( "Sector " + this.currentSector + ":" );
        this.report.addCell( RACE_TimeToString( this.sectorTimes[id] ) );
        this.report.addCell( "Personal:" );
        this.report.addCell( RACE_TimeDiffString( this.sectorTimes[id], this.bestSectorTimes[id], false ) );
        this.report.addCell( "Server:" );
        this.report.addCell( RACE_TimeDiffString( this.sectorTimes[id], levelRecords[0].sectorTimes[id], false ) );

        // if beating the level record on this sector give an award
        if ( this.sectorTimes[id] < levelRecords[0].sectorTimes[id] )
        {
            this.client.addAward( "Sector record on sector " + this.currentSector + "!" );
        }
        // if beating his own record on this sector give an award
        else if ( this.sectorTimes[id] < this.bestSectorTimes[id] )
        {
            // ch : does racesow apply sector records only if race is completed?
            this.client.addAward( "Personal record on sector " + this.currentSector + "!" );
            //this.bestSectorTimes[id] = this.sectorTimes[id];
        }

        this.currentSector++;

        G_AnnouncerSound( this.client, G_SoundIndex( "sounds/misc/timer_bip_bip" ), GS_MAX_TEAMS, false, null );

        return true;
    }

    void enterPracticeMode()
    {
        if ( this.practicing )
            return;

        this.practicing = true;
        G_CenterPrintMsg( this.client.getEnt(), S_COLOR_CYAN + "Entered practice mode" );
        // msc: practicemode message
        client.setHelpMessage(practiceModeMsg);
        this.cancelRace();
        this.setQuickMenu();
    }

    void leavePracticeMode()
    {
        if ( !this.practicing )
            return;

        // for accuracy, reset scores.
        target_score_init( this.client );

        this.practicing = false;
        G_CenterPrintMsg( this.client.getEnt(), S_COLOR_CYAN + "Left practice mode" );
        // msc: practicemode message
        client.setHelpMessage(defaultMsg);
        if ( this.client.team != TEAM_SPECTATOR )
            this.client.respawn( false );
        this.setQuickMenu();
    }

    void togglePracticeMode()
    {
        if ( pending_endmatch )
            this.client.printMessage("Can't join practicemode in overtime.\n");
        else if ( this.practicing )
            this.leavePracticeMode();
        else
            this.enterPracticeMode();
    }
}

Player[] players( maxClients );

Player @RACE_GetPlayer( Client @client )
{
    if ( @client == null || client.playerNum < 0 )
        return null;

    Player @player = players[client.playerNum];
    @player.client = client;

    return player;
}

// the player has finished the race. This entity times his automatic respawning
void race_respawner_think( Entity @respawner )
{
    Client @client = G_GetClient( respawner.count );
    
    // for accuracy, reset scores.
    target_score_init( client );

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

    if ( player.touchCheckPoint( self.count ) )
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

    if ( player.practicing && player.practicemodeFinishTime < levelTime )
    {
      activator.client.addAward( S_COLOR_CYAN + "Finished the map in practicemode!" );
      player.practicemodeFinishTime = levelTime + 5000;
    }

    if ( !player.inRace )
        return;

    player.completeRace();

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

    if ( player.startRace() )
    {
        if ( !player.heardGo )
        {
            int soundIndex = G_SoundIndex( "sounds/announcer/countdown/go0" + (1 + (rand() & 1)) );
            G_AnnouncerSound( activator.client, soundIndex, GS_MAX_TEAMS, false, null );
            player.heardGo = true;
        }

        self.useTargets( activator );

        if ( @activator.client == null )
          return;

        Vec3 vel = activator.velocity;
        vel.z = 0;
        int speed = int(vel.length());
        activator.client.setHUDStat( STAT_PROGRESS_OTHER, speed );
        activator.client.printMessage( S_COLOR_ORANGE + "Starting speed: " + S_COLOR_WHITE + speed + "\n" );
    }
}

// doesn't need to do anything at all, just sit there, waiting
void target_starttimer( Entity @ent )
{
    @ent.use = target_starttimer_use;
    ent.wait = 0;
}

void target_startTimer( Entity @ent )
{
    target_starttimer( ent );
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
    {
      speclist.push_back(@specClient);
    }
  }
  return speclist;
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

void RACE_UpdateHUDTopScores()
{
    for ( int i = 0; i < HUD_RECORDS; i++ )
    {
        G_ConfigString( CS_GENERAL + i, "" ); // somehow it is not shown the first time if it isn't initialized like this
        if ( levelRecords[i].saved && levelRecords[i].playerName.length() > 0 )
            G_ConfigString( CS_GENERAL + i, "#" + ( i + 1 ) + " - " + levelRecords[i].playerName + " - " + RACE_TimeToString( levelRecords[i].finishTime ) );
    }
}

void RACE_WriteTopScores()
{
    String topScores;
    Cvar mapNameVar( "mapname", "", 0 );
    String mapName = mapNameVar.string.tolower();

    topScores = "//" + mapName + " top scores\n\n";

    for ( int i = 0; i < MAX_RECORDS; i++ )
    {
        if ( levelRecords[i].saved && levelRecords[i].playerName.length() > 0 )
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

    G_WriteFile( "topscores/race/" + mapName + ".txt", topScores );
}

void RACE_LoadTopScores()
{
    String topScores;
    Cvar mapNameVar( "mapname", "", 0 );
    String mapName = mapNameVar.string.tolower();

    topScores = G_LoadFile( "topscores/race/" + mapName + ".txt" );

    if ( topScores.length() > 0 )
    {
        String timeToken, loginToken, nameToken, sectorToken;
        int count = 0;
        uint sep;

        int i = 0;
        while ( i < MAX_RECORDS )
        {
            timeToken = topScores.getToken( count++ );
            if ( timeToken.length() == 0 )
                break;

            sep = timeToken.locate( "|", 0 );
            if ( sep == timeToken.length() )
            {
                loginToken = "";
            }
            else
            {
                loginToken = timeToken.substr( sep + 1 );
                timeToken = timeToken.substr( 0, sep );
            }

            nameToken = topScores.getToken( count++ );
            if ( nameToken.length() == 0 )
                break;

            sectorToken = topScores.getToken( count++ );
            if ( sectorToken.length() == 0 )
                break;

            int numSectors = sectorToken.toInt();

            // store this one
            for ( int j = 0; j < numSectors; j++ )
            {
                sectorToken = topScores.getToken( count++ );
                if ( sectorToken.length() == 0 )
                    break;

                levelRecords[i].sectorTimes[j] = uint( sectorToken.toInt() );
            }

            // check if he already has a score
            String cleanName = nameToken.removeColorTokens().tolower();
            bool exists = false;
            for ( int j = 0; j < i; j++ )
            {
                if ( ( loginToken != "" && levelRecords[j].login == loginToken )
                        || ( loginToken == "" && levelRecords[j].playerName.removeColorTokens().tolower() == cleanName ) )
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

            levelRecords[i].saved = true;
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

    // for accuracy, reset scores.
    target_score_init( target.client );

    RACE_GetPlayer( target.client ).cancelRace();
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

String randmap;
String randmap_passed = "";
uint randmap_time = 0;
uint randmap_matches;

uint[] maplist_page( maxClients );

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "gametypemenu" )
    {
        client.execGameCommand("meop racemod_main");
        return true;
    }
    else if ( cmdString == "gametype" )
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
            String[] maps;
            const String @map;
            String lmap;
            int i = 0;

            if ( levelTime - randmap_time > 1100 )
            {
              if ( pattern == "*" )
                  pattern = "";

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
                          for ( p = 0; p < map.length(); p++ )
                          {
                              uint eq = 0;
                              while ( eq < pattern.length() && p + eq < lmap.length() )
                              {
                                  if ( lmap[p + eq] != pattern[eq] )
                                      break;
                                  eq++;
                              }
                              if ( eq == pattern.length() )
                              {
                                  match = true;
                                  break;
                              }
                          }
                      }
                      if ( match && map != current )
                          maps.insertLast( map );
                  }
                  i++;
              }
              while ( @map != null );

              if ( maps.length() == 0 )
              {
                  client.printMessage( "No matching maps\n" );
                  return false;
              }

              randmap = maps[rand() % maps.length()];
              randmap_matches = maps.length();
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
    else if ( cmdString == "callvotepassed" )
    {
        String votename = argsString.getToken( 0 );

        if ( votename == "randmap" )
        {
            randmap_passed = randmap;
            match.launchState( MATCH_STATE_POSTMATCH );
        }

        return true;
    }
    else if ( cmdString == "racerestart" || cmdString == "kill" || cmdString == "join" )
    {
        if ( @client != null )
        {
            Player @player = RACE_GetPlayer( client );

            // for accuracy, reset scores.
            target_score_init( client );

            if ( pending_endmatch || match.getState() >= MATCH_STATE_POSTMATCH )
            {
              if ( !(player.inRace || player.postRace) )
                return true;
            }

            if ( player.inRace )
                player.cancelRace();

            if ( client.team != TEAM_SPECTATOR && player.client.getEnt().moveType == MOVETYPE_NOCLIP )
            {
                if ( player.loadPosition( false ) )
                {
                    player.noclipWeapon = player.savedPosition().weapon;
                }
                else
                {
                    player.noclipSpawn = true;
                    client.respawn( false );
                }
            }
            else
            {
                if ( client.team == TEAM_SPECTATOR )
                {
                    if ( gametype.isTeamBased )
                        return false;

                    client.team = TEAM_PLAYERS;
                    G_PrintMsg( null, client.name + S_COLOR_WHITE + " joined the " + G_GetTeam( client.team ).name + S_COLOR_WHITE + " team.\n" );
                }
                client.respawn( false );
            }
        }

        return true;
    }
    else if ( cmdString == "practicemode" )
    {
        RACE_GetPlayer( client ).togglePracticeMode();
        return true;
    }
    else if ( cmdString == "noclip" )
    {
        Player @player = RACE_GetPlayer( client );
        return player.toggleNoclip();
    }
    else if ( cmdString == "position" )
    {
        String action = argsString.getToken( 0 );
        if ( action == "save" )
        {
            return RACE_GetPlayer( client ).savePosition();
        }
        else if ( action == "load" )
        {
            return RACE_GetPlayer( client ).loadPosition( true );
        }
        else if ( action == "speed" && argsString.getToken( 1 ) != "" )
        {
            Position @position = RACE_GetPlayer( client ).savedPosition();
            String speed = argsString.getToken( 1 );
            if ( speed.locate( "+", 0 ) == 0 )
                position.speed += speed.substr( 1 ).toFloat();
            else if ( speed.locate( "-", 0 ) == 0 )
                position.speed -= speed.substr( 1 ).toFloat();
            else
                position.speed = speed.toFloat();
        }
        else if ( action == "clear" )
        {
            return RACE_GetPlayer( client ).clearPosition();
        }
        else
        {
            G_PrintMsg( client.getEnt(), "position <save | load | speed <value> | clear>\n" );
            return false;
        }

        return true;
    }
    else if ( cmdString == "top" )
    {
        RecordTime @top = levelRecords[0];
        if ( !top.saved )
        {
            client.printMessage( S_COLOR_RED + "No records yet.\n" );
        }
        else
        {
            Table table( "r r r l l" );
            for ( int i = 0; i < DISPLAY_RECORDS; i++ )
            {
                RecordTime @record = levelRecords[i];
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
    else if ( cmdString == "maplist" )
    {
      String arg1 = argsString.getToken( 0 ).tolower();
      String arg2 = argsString.getToken( 1 ).tolower();
      String pattern;
      uint old_page = maplist_page[client.playerNum];
      int page;
      int last_page;

      if ( arg1 == "" )
      {
        client.printMessage( "maplist <* | pattern> [<page# | prev | next>]\n" );
        return false;
      }

      pattern = arg1;

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

      String[] maps;
      const String @map;
      String lmap;
      uint i = 0;

      if ( pattern == "*" )
          pattern = "";

      uint longest = 0;
      String longest_name;

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
                  for ( p = 0; p < map.length(); p++ )
                  {
                      uint eq = 0;
                      while ( eq < pattern.length() && p + eq < lmap.length() )
                      {
                          if ( lmap[p + eq] != pattern[eq] )
                              break;
                          eq++;
                      }
                      if ( eq == pattern.length() )
                      {
                          match = true;
                          break;
                      }
                  }
              }
              if ( match )
                  maps.insertLast( map );

              if ( map.length() > longest )
              {
                longest = map.length();
                longest_name = map;
              }
          }
          i++;
      }
      while ( @map != null );

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

      for ( i = start; i < end; i++ )
      {
        if ( i >= maps.length() )
          break;
        maplist.addCell( S_COLOR_WHITE + maps[i] );
      }

      client.printMessage( S_COLOR_YELLOW + "Found " + S_COLOR_WHITE + maps.length() + S_COLOR_YELLOW + " maps" +
        S_COLOR_WHITE + " (" + (start+1) + "-" + end + "), " + S_COLOR_YELLOW + "page " + S_COLOR_WHITE + (page+1) + "/" + (last_page+1) + "\n" );

      for ( i = 0; i < maplist.numRows(); i++ )
        client.printMessage( maplist.getRow(i) + "\n" );

      return true;
    }
    else if ( cmdString == "help" )
    {
      String arg1 = argsString.getToken( 0 ).tolower();
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
    else if ( cmdString == "rules")
    {
        RACE_ShowRules(client, 0);
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
    int i;
    uint minTime, currentTime;
    bool playerFound;
    //int readyIcon;

    @team = G_GetTeam( TEAM_PLAYERS );

    // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
    entry = "&t " + int( TEAM_PLAYERS ) + " 0 " + team.ping + " ";
    if ( scoreboardMessage.length() + entry.length() < maxlen )
        scoreboardMessage += entry;

    minTime = 0;

    do
    {
        playerFound = false;
        currentTime = 0;

        // find the next best time
        for ( i = 0; @team.ent( i ) != null; i++ )
        {
            @ent = team.ent( i );
            @player = RACE_GetPlayer( ent.client );

            if ( player.hasTime && player.bestFinishTime >= minTime && ( !playerFound || player.bestFinishTime < currentTime ) )
            {
                playerFound = true;
                currentTime = player.bestFinishTime;
            }
        }
        if ( playerFound )
        {
            // add all players with this time
            for ( i = 0; @team.ent( i ) != null; i++ )
            {
                @ent = team.ent( i );
                @player = RACE_GetPlayer( ent.client );

                if ( player.hasTime && player.bestFinishTime == currentTime )
                {
                    entry = player.scoreboardEntry();
                    if ( scoreboardMessage.length() + entry.length() < maxlen )
                        scoreboardMessage += entry;
                }
            }
            minTime = currentTime + 1;
        }
    }
    while ( playerFound );

    // add players without time
    for ( i = 0; @team.ent( i ) != null; i++ )
    {
        @ent = team.ent( i );
        @player = RACE_GetPlayer( ent.client );

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
                Player @player = RACE_GetPlayer( client );
                // find out if he holds a record better than his current time
                for ( int i = 0; i < MAX_RECORDS; i++ )
                {
                    if ( !levelRecords[i].saved )
                        break;
                    if ( levelRecords[i].login == login
                            && ( !player.hasTime || levelRecords[i].finishTime < player.bestFinishTime ) )
                    {
                        player.setBestTime( levelRecords[i].finishTime );
                        for ( int j = 0; j < numCheckpoints; j++ )
                            player.bestSectorTimes[j] = levelRecords[i].sectorTimes[j];
                        break;
                    }
                }
            }
        }
    }
    /* else if ( score_event == "pickup" )
    {
      Item@ item = @G_GetItemByClassname(args.getToken(0));
      if ( client.canSelectWeapon(item.tag) )
        client.selectWeapon(item.tag);
    }*/
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
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

    Player @player = RACE_GetPlayer( ent.client );
    player.cancelRace();

    player.setQuickMenu();
    player.updateScore();

    if ( ent.isGhosting() )
        return;

    // set player movement to pass through other players
    ent.client.pmoveFeatures = ent.client.pmoveFeatures | PMFEAT_GHOSTMOVE;

    if ( gametype.isInstagib )
        ent.client.inventoryGiveItem( WEAP_INSTAGUN );
    else
    {
        ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );
        /*ent.client.inventorySetCount( WEAP_MACHINEGUN, 1 );
        ent.client.inventorySetCount( AMMO_BULLETS, 1 );*/
    }

    // select rocket launcher if available
    if ( ent.client.canSelectWeapon( WEAP_ROCKETLAUNCHER ) )
        ent.client.selectWeapon( WEAP_ROCKETLAUNCHER );
    /*else if ( !( ent.client.canSelectWeapon( WEAP_ROCKETLAUNCHER )
              && ent.client.canSelectWeapon( WEAP_GRENADELAUNCHER )
              && ent.client.canSelectWeapon( WEAP_PLASMAGUN ) ) )
        ent.client.selectWeapon( WEAP_GUNBLADE );*/
    else
        ent.client.selectWeapon( -1 ); // auto-select best weapon in the inventory

    G_RemoveProjectiles( ent );
    RS_ResetPjState( ent.client.playerNum );

    player.loadPosition( false );

    // msc: permanent practicemode message
    if ( player.practicing )
    {
      ent.client.setHelpMessage(practiceModeMsg);
    } else {
      ent.client.setHelpMessage(defaultMsg);
    }

    if ( player.noclipSpawn )
    {
        if ( player.practicing )
        {
            ent.moveType = MOVETYPE_NOCLIP;
            ent.velocity = Vec3(0,0,0);
            player.noclipWeapon = ent.weapon;
        }
        player.noclipSpawn = false;
    }
    else
    {
        // add a teleportation effect
        // ent.respawnEffect();

        if ( !player.practicing && !player.heardReady )
        {
            int soundIndex = G_SoundIndex( "sounds/announcer/countdown/ready0" + (1 + (rand() & 1)) );
            G_AnnouncerSound( ent.client, soundIndex, GS_MAX_TEAMS, false, null );
            player.heardReady = true;
        }
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
        if ( player.inRace )
            client.setHUDStat( STAT_TIME_SELF, player.raceTime() / 100 );

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

        // msc: temporary MAX_ACCEL replacement
        if ( frameTime > 0 )
        {
          float cgframeTime = float(frameTime)/1000;
          int base_speed = int(client.pmoveMaxSpeed);
          float base_accel = base_speed * cgframeTime;
          Vec3 vel = client.getEnt().velocity;
          vel.z = 0;
          float speed = vel.length();
          int max_accel = int( ( sqrt( speed*speed + base_accel * ( 2 * base_speed - base_accel ) ) - speed ) / cgframeTime );
          client.setHUDStat( STAT_PROGRESS_SELF, max_accel );
        }

    Entity @ent = @client.getEnt();
        if ( ent.client.state() >= CS_SPAWNED && ent.team != TEAM_SPECTATOR )
        {
            if ( ent.health > ent.maxHealth ) {
                ent.health -= ( frameTime * 0.001f );
                // fix possible rounding errors
                if( ent.health < ent.maxHealth ) {
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
    Client @client = G_GetClient( i );
    if ( client.state() < CS_SPAWNED )
        continue;

    Player@ player = RACE_GetPlayer( client );
    if ( player.inRace && !player.postRace && client.team != TEAM_SPECTATOR )
    {
      any_racing = true;
    } else {
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

    for ( int i = 0; i < MAX_RECORDS; i++ )
        levelRecords[i].setupArrays( numCheckpoints );

    RACE_LoadTopScores();
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
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %t 96 %s 48 %l 48 %s 52" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Time Diff Ping Racing" );

    // add commands
    G_RegisterCommand( "gametype" );
    G_RegisterCommand( "gametypemenu" );
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
    G_SoundIndex( "racemod_ui_v2.txt", true );
    G_SoundIndex( "missing_tex.txt", true );

    demoRecording = false;

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
