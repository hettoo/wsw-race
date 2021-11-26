const int MAX_POSITIONS = 400;
const int POSITION_INTERVAL = 500;
const float POSITION_HEIGHT = 24;

const int RECALL_ACTION_TIME = 200;
const int RECALL_ACTION_JUMP = 5;

Player[] players( maxClients );

class Player
{
    Client@ client;
    uint[] messageTimes;
    uint messageLock;
    bool firstMessage;
    int positionInterval;
    uint[] sectorTimes;
    uint[] bestSectorTimes;
    uint startTime;
    uint finishTime;
    bool hasTime;
    int maxSpeed;
    uint bestFinishTime;
    int bestMaxSpeed;
    int pos;
    bool noclipSpawn;
    Table report( S_COLOR_ORANGE + "l " + S_COLOR_WHITE + "r " + S_COLOR_ORANGE + "/ l r " + S_COLOR_ORANGE + "/ l r " + S_COLOR_ORANGE + "/ l " + S_COLOR_WHITE + "r" + S_COLOR_ORANGE + "l r" );
    Table practiceReport( S_COLOR_CYAN + "l " + S_COLOR_WHITE + "r " + S_COLOR_CYAN + "/ l r " + S_COLOR_CYAN + "/ l r " + S_COLOR_CYAN + "/ l " + S_COLOR_WHITE + "r" + S_COLOR_CYAN + "l r" );
    int currentSector;
    bool inRace;
    bool postRace;
    bool practicing;
    bool recalled;
    bool autoRecall;
    int autoRecallStart;
    uint release;
    bool arraysSetUp;

    // hettoo : practicemode
    int noclipWeapon;
    Position practicePosition;
    Position preRacePosition;
    uint practiceFinish;
    Position noclipBackup;
    uint lastNoclipAction;
    Position lerpFrom;
    Position lerpTo;

    Position[] runPositions;
    int runPositionCount;
    Position[] extRunPositions;
    int extRunPositionCount;
    uint nextRunPositionTime;
    int positionCycle;

    Position[] bestRunPositions;
    int bestRunPositionCount;

    void setupArrays( int size )
    {
        this.messageTimes.resize( MAX_FLOOD_MESSAGES );
        this.sectorTimes.resize( size );
        this.bestSectorTimes.resize( size );
        this.runPositions.resize( MAX_POSITIONS );
        this.extRunPositions.resize( MAX_POSITIONS );
        this.bestRunPositions.resize( MAX_POSITIONS );
        this.arraysSetUp = true;
        this.clear();
    }

    void clear()
    {
        @this.client = null;

        this.positionInterval = POSITION_INTERVAL;

        this.currentSector = 0;
        this.inRace = false;
        this.postRace = false;
        this.practicing = false;
        this.recalled = false;
        this.autoRecall = false;
        this.autoRecallStart = -1;
        this.release = 0;
        this.practiceFinish = 0;
        this.startTime = 0;
        this.finishTime = 0;
        this.maxSpeed = 0;
        this.bestMaxSpeed = 0;
        this.runPositionCount = 0;
        this.extRunPositionCount = 0;
        this.nextRunPositionTime = 0;
        this.bestRunPositionCount = 0;
        this.positionCycle = 0;
        this.hasTime = false;
        this.bestFinishTime = 0;
        this.pos = -1;
        this.noclipSpawn = false;

        this.practicePosition.clear();
        this.preRacePosition.clear();
        this.noclipBackup.clear();
        this.lastNoclipAction = 0;
        this.lerpFrom.saved = false;
        this.lerpTo.saved = false;

        if ( !this.arraysSetUp )
            return;

        this.firstMessage = true;
        this.messageLock = 0;
        for ( int i = 0; i < MAX_FLOOD_MESSAGES; i++ )
            this.messageTimes[i] = 0;

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

    void setBestTime( uint time, int maxSpeed )
    {
        this.hasTime = true;
        this.bestFinishTime = time;
        this.bestMaxSpeed = maxSpeed;
        this.updateScore();
    }

    void takeHistory( Player@ other )
    {
        this.runPositionCount = other.runPositionCount;
        this.positionCycle = 0;
        for ( int i = 0; i < this.runPositionCount; i++ )
            this.runPositions[i] = other.runPositions[i];
    }

    void updatePos()
    {
        this.pos = -1;
        if ( this.bestFinishTime == 0 )
            return;

        String cleanName = this.client.name.removeColorTokens().tolower();
        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            if ( !levelRecords[i].saved )
                break;

            if ( this.bestFinishTime == levelRecords[i].finishTime && cleanName == levelRecords[i].playerName.removeColorTokens().tolower() )
            {
                this.pos = i + 1;
                break;
            }
        }
    }

    void updateScore()
    {
        this.client.stats.setScore( this.bestFinishTime / 10 );
    }

    String@ scoreboardEntry()
    {
        Entity@ ent = this.client.getEnt();
        int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;
        String racing;
        String pos = "\u00A0";
        String speed;

        if ( this.practicing && this.recalled && ent.health > 0 && ent.moveType == MOVETYPE_PLAYER )
            racing = S_COLOR_CYAN + "Yes";
        else if ( this.practicing )
            racing = S_COLOR_CYAN + "No";
        else if ( this.inRace )
            racing = S_COLOR_GREEN + "Yes";
        else
            racing = S_COLOR_RED + "No";

        String diff;
        if ( this.hasTime && levelRecords[0].saved && this.bestFinishTime >= levelRecords[0].finishTime )
        {
            uint change = this.bestFinishTime - levelRecords[0].finishTime;
            if ( change == 0 )
                diff = S_COLOR_GREEN + "0";
            else if ( change >= 6000000 )
                diff = S_COLOR_RED + "+";
            else if ( change >= 100000 )
                diff = S_COLOR_RED + ( change / 60000 ) + "m";
            else if ( change >= 1000 && change < 10000 )
                diff = S_COLOR_ORANGE + ( change / 1000 ) + "." + ( ( change % 1000 ) / 100 ) + "s";
            else if ( change >= 1000 )
                diff = S_COLOR_ORANGE + ( change / 1000 ) + "s";
            else
                diff = S_COLOR_YELLOW + change;
            if ( this.pos != -1 )
                pos = this.pos;
        }
        else
        {
            diff = "\u00A0";
        }

        if ( this.hasTime )
            speed = this.bestMaxSpeed + "";
        else
            speed = "\u00A0";

        return "&p " + playerID + " " + ent.client.clanName + " " + pos + " " + this.bestFinishTime + " " + diff + " " + speed + " " + ent.client.ping + " " + racing + " ";
    }

    bool preRace()
    {
        return !this.inRace && !this.practicing && !this.postRace && this.client.team != TEAM_SPECTATOR;
    }

    void setQuickMenu()
    {
        String s = '';
        Position@ position = this.savedPosition();

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
        Entity@ ent = this.client.getEnt();
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
            this.cancelRace();
            ent.moveType = MOVETYPE_NOCLIP;
            this.noclipWeapon = ent.weapon;
            msg = "Noclip mode enabled.";
        }
        else
        {
            uint moveType = ent.moveType;
            ent.moveType = MOVETYPE_PLAYER;
            this.client.selectWeapon( this.noclipWeapon );
            if ( this.recalled && moveType == MOVETYPE_NONE )
            {
                this.startTime = this.timeStamp() - this.savedPosition().currentTime;
                if ( this.lerpTo.saved )
                {
                    this.applyPosition( this.lerpTo );
                    this.lerpFrom.saved = false;
                    this.lerpTo.saved = false;
                }
                else
                {
                    this.applyPosition( this.savedPosition() );
                }
                this.autoRecallStart = this.positionCycle;
            }
            this.noclipBackup.saved = false;
            msg = "Noclip mode disabled.";
        }

        G_PrintMsg( ent, msg + "\n" );

        this.setQuickMenu();

        return true;
    }

    Position@ savedPosition()
    {
        if ( this.preRace() )
            return preRacePosition;
        else
            return practicePosition;
    }

    void applyPosition( Position@ position )
    {
        Entity@ ent = this.client.getEnt();

        ent.origin = position.location;
        ent.angles = position.angles;
        ent.health = position.health;
        this.client.armor = position.armor;
        if ( ent.moveType != MOVETYPE_NOCLIP )
            ent.set_velocity( position.velocity );
        this.currentSector = position.currentSector;

        if ( !position.skipWeapons )
        {
            this.client.inventoryClear();
            for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
            {
                if ( position.weapons[i] )
                    this.client.inventoryGiveItem( i );
                Item@ item = G_GetItem( i );
                this.client.inventorySetCount( item.ammoTag, position.ammos[i] );
            }
            for ( int i = POWERUP_QUAD; i < POWERUP_TOTAL; i++ )
                this.client.inventorySetCount( i, position.powerups[i - POWERUP_QUAD] );
            this.client.selectWeapon( position.weapon );
        }

        ent.teleported = true;
    }

    bool loadPosition( Verbosity verbosity )
    {
        Entity@ ent = this.client.getEnt();
        if ( !this.practicing && this.client.team != TEAM_SPECTATOR && !this.preRace() )
        {
            if ( verbosity == Verbosity_Verbose )
                G_PrintMsg( ent, "Position loading is not available during a race.\n" );
            return false;
        }

        this.noclipBackup.saved = false;

        Position@ position = this.savedPosition();

        if ( !position.saved )
        {
            if ( verbosity == Verbosity_Verbose )
                G_PrintMsg( ent, "No position has been saved yet.\n" );
            return false;
        }

        this.applyPosition( position );

        if ( this.preRace() )
        {
            ent.set_velocity( Vec3() );
        }
        else if ( this.practicing && position.recalled )
        {
            this.cancelRace();
            this.startTime = this.timeStamp() - position.currentTime;
            this.recalled = true;
            this.extRunPositionCount = 0;
            this.nextRunPositionTime = this.timeStamp() + this.positionInterval;
            this.autoRecallStart = this.positionCycle;
        }
        else if ( this.practicing )
        {
            this.recalled = false;
        }

        return true;
    }

    bool recallPosition( int offset )
    {
        Entity@ ent = this.client.getEnt();
        if ( !this.practicing || this.client.team == TEAM_SPECTATOR )
        {
            G_PrintMsg( ent, "Position recall is only available in practice mode.\n" );
            return false;
        }

        if ( this.runPositionCount == 0 )
        {
            G_PrintMsg( ent, "No position found.\n" );
            return false;
        }

        if ( !this.noclipBackup.saved )
        {
            this.noclipBackup.copy( this.currentPosition() );
            this.noclipBackup.saved = true;
            ent.moveType = MOVETYPE_NONE;
            G_CenterPrintMsg( ent, S_COLOR_CYAN + "Entered recall mode" );
        }

        this.positionCycle += offset;
        if ( this.positionCycle < 0 )
            this.positionCycle = ( this.runPositionCount - ( -this.positionCycle % this.runPositionCount ) ) % this.runPositionCount;
        else
            this.positionCycle %= this.runPositionCount;
        Position@ position = this.runPositions[this.positionCycle];

        this.applyPosition( position );
        Position@ saved = this.savedPosition();
        saved.copy( position );
        saved.saved = true;
        saved.recalled = true;
        this.recalled = true;
        this.extRunPositionCount = 0;
        saved.skipWeapons = false;

        this.startTime = this.timeStamp() - position.currentTime;

        this.setQuickMenu();

        return true;
    }

    Position@ currentPosition()
    {
        Position@ result = Position();
        result.saved = false;
        result.recalled = false;
        Client@ ref = this.client;
        if ( this.client.team == TEAM_SPECTATOR && this.client.chaseActive && this.client.chaseTarget != 0 )
            @ref = G_GetEntity( this.client.chaseTarget ).client;
        Entity@ ent = ref.getEnt();
        result.location = ent.origin;
        result.angles = ent.angles;
        result.velocity = ent.get_velocity();
        result.health = ent.health;
        result.armor = ref.armor;
        result.skipWeapons = false;
        result.currentSector = this.currentSector;
        result.currentTime = this.raceTime();
        for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
        {
            result.weapons[i] = ref.canSelectWeapon( i );
            Item@ item = G_GetItem( i );
            result.ammos[i] = ref.inventoryCount( item.ammoTag );
        }
        for ( int i = POWERUP_QUAD; i < POWERUP_TOTAL; i++ )
            result.powerups[i - POWERUP_QUAD] = ref.inventoryCount( i );
        result.weapon = ( ent.moveType == MOVETYPE_NOCLIP || ent.moveType == MOVETYPE_NONE ) ? this.noclipWeapon : ref.pendingWeapon;
        return result;
    }

    bool savePosition()
    {
        Client@ ref = this.client;
        if ( this.client.team == TEAM_SPECTATOR && this.client.chaseActive && this.client.chaseTarget != 0 )
            @ref = G_GetEntity( this.client.chaseTarget ).client;
        Entity@ ent = ref.getEnt();

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

        Position@ position = this.savedPosition();

        position.velocity = HorizontalVelocity( position.velocity );
        float speed;
        if ( position.saved && !position.recalled )
            speed = position.velocity.length();
        else
            speed = 0;

        position.copy( this.currentPosition() );
        position.saved = true;
        position.recalled = false;

        Vec3 a, b, c;
        position.angles.angleVectors( a, b, c );
        a = HorizontalVelocity( a );
        a.normalize();
        position.velocity = a * speed;

        position.skipWeapons = ref.team == TEAM_SPECTATOR;

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

    void checkRelease()
    {
        if ( this.release > 1 )
            this.release -= 1;
        else if ( this.release == 1 )
        {
            this.client.getEnt().moveType = MOVETYPE_PLAYER;
            this.loadPosition( Verbosity_Silent );
            this.release = 0;
        }
    }

    bool startRace()
    {
        if ( !this.preRace() )
            return false;

        this.currentSector = 0;
        this.inRace = true;
        this.startTime = this.timeStamp();
        this.runPositionCount = 0;
        this.positionCycle = 0;
        this.nextRunPositionTime = this.timeStamp() + this.positionInterval;

        if ( RS_QueryPjState( this.client.playerNum )  )
        {
          this.client.addAward( S_COLOR_RED + "Prejumped!" );

            // for accuracy, reset scores.
            target_score_init( this.client );

          this.client.respawn( false );
          RS_ResetPjState( this.client.playerNum );
          return false;
        }

        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = 0;

        this.report.reset();

        this.client.newRaceRun( numCheckpoints );

        this.setQuickMenu();

        return true;
    }

    void saveRunPosition()
    {
        if ( this.runPositionCount + this.extRunPositionCount == MAX_POSITIONS || this.timeStamp() < this.nextRunPositionTime )
            return;

        Entity@ ent = this.client.getEnt();

        if ( !this.inRace && ( !this.recalled || ent.moveType == MOVETYPE_NONE ) )
            return;

        Vec3 mins, maxs;
        ent.getSize( mins, maxs );
        Vec3 down = ent.origin;
        down.z -= POSITION_HEIGHT;
        Trace tr;
        if ( tr.doTrace( ent.origin, mins, maxs, down, ent.entNum, MASK_PLAYERSOLID ) && tr.surfFlags & SURF_SLICK == 0 )
            return;

        if ( !this.inRace && this.autoRecall && this.autoRecallStart >= 0 )
        {
            if ( this.autoRecallStart < this.runPositionCount )
                this.runPositionCount = this.autoRecallStart + 1;
            this.autoRecallStart = -1;
        }

        if ( this.inRace || this.autoRecall )
            this.runPositions[this.runPositionCount++] = this.currentPosition();
        else
            this.extRunPositions[this.extRunPositionCount++] = this.currentPosition();
        this.nextRunPositionTime = this.timeStamp() + this.positionInterval;
    }

    int getSpeed()
    {
        return int( HorizontalSpeed( this.client.getEnt().velocity ) );
    }

    void checkNoclipAction()
    {
        Entity@ ent = this.client.getEnt();

        if ( !this.practicing || this.client.team == TEAM_SPECTATOR || ( ent.moveType != MOVETYPE_NOCLIP && ent.moveType != MOVETYPE_NONE ) || this.release > 0 || ent.health <= 0 )
            return;

        uint keys = this.client.pressedKeys;

        if ( this.runPositionCount == 0 )
        {
            if ( keys & Key_Attack != 0 )
                G_CenterPrintMsg( ent, "No positions saved" );
            return;
        }

        uint passed = levelTime - this.lastNoclipAction;
        if ( passed < RECALL_ACTION_TIME )
        {
            if ( this.lerpTo.saved )
            {
                float lerp = float( passed ) / float( RECALL_ACTION_TIME );
                this.applyPosition( Lerp( this.lerpFrom, lerp, this.lerpTo ) );
            }
            return;
        }

        if ( this.lerpTo.saved )
        {
            this.applyPosition( this.lerpTo );
            this.lerpFrom.saved = false;
            this.lerpTo.saved = false;
        }

        this.lastNoclipAction = levelTime;

        if ( keys & Key_Attack != 0 )
        {
            if ( this.noclipBackup.saved )
            {
                ent.moveType = MOVETYPE_NOCLIP;
                this.applyPosition( this.noclipBackup );
                ent.set_velocity( Vec3() );
                this.noclipBackup.saved = false;
                this.recalled = false;
                G_CenterPrintMsg( ent, S_COLOR_CYAN + "Left recall mode" );
            }
            else
            {
                this.recallPosition( 0 );
            }
        }
        else if ( keys & Key_Backward != 0 && this.noclipBackup.saved )
        {
            if ( this.positionCycle == 0 )
            {
                this.recallPosition( -1 );
            }
            else
            {
                this.lerpFrom.copy( this.savedPosition() );
                this.recallPosition( -1 );
                this.lerpTo.copy( this.savedPosition() );
                this.applyPosition( lerpFrom );
            }
        }
        else if ( keys & Key_Left != 0 && this.noclipBackup.saved )
        {
            if ( this.positionCycle < RECALL_ACTION_JUMP )
            {
                this.recallPosition( -this.positionCycle - 1 );
            }
            else
            {
                this.lerpFrom.copy( this.savedPosition() );
                this.recallPosition( -RECALL_ACTION_JUMP );
                this.lerpTo.copy( this.savedPosition() );
                this.applyPosition( lerpFrom );
            }
        }
        else if ( keys & Key_Forward != 0 && this.noclipBackup.saved )
        {
            this.lerpFrom.copy( this.savedPosition() );
            this.recallPosition( 1 );
            if ( this.positionCycle == 0 )
            {
                this.lerpFrom.saved = false;
            }
            else
            {
                this.lerpTo.copy( this.savedPosition() );
                this.applyPosition( this.lerpFrom );
            }
        }
        else if ( keys & Key_Right != 0 && this.noclipBackup.saved )
        {
            this.lerpFrom.copy( this.savedPosition() );
            this.recallPosition( RECALL_ACTION_JUMP );
            if ( this.positionCycle < RECALL_ACTION_JUMP )
            {
                this.lerpFrom.saved = false;
                this.recallPosition( -this.positionCycle );
            }
            else
            {
                this.lerpTo.copy( this.savedPosition() );
                this.applyPosition( this.lerpFrom );
            }
        }
        else
        {
            this.lastNoclipAction = 0;
        }
    }

    void updateMaxSpeed()
    {
        if ( !this.inRace )
            return;

        int current = this.getSpeed();
        if ( current > this.maxSpeed )
            this.maxSpeed = current;
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
        Entity@ ent = this.client.getEnt();

        if ( this.inRace && this.currentSector > 0 )
        {
            uint rows = this.report.numRows();
            for ( uint i = 0; i < rows; i++ )
                G_PrintMsg( ent, this.report.getRow( i ) + "\n" );
            G_PrintMsg( ent, S_COLOR_ORANGE + "Race cancelled, max speed " + S_COLOR_WHITE + this.maxSpeed + "\n" );
        }

        Position@ position = this.savedPosition();
        if ( this.practicing && this.recalled )
        {
            if ( this.currentSector > position.currentSector && ent.moveType == MOVETYPE_PLAYER )
            {
                uint rows = this.practiceReport.numRows();
                if ( rows > 0 )
                {
                    for ( uint i = 0; i < rows; i++ )
                        G_PrintMsg( ent, this.practiceReport.getRow( i ) + "\n" );
                    G_PrintMsg( ent, S_COLOR_CYAN + "Practice run cancelled\n" );
                }
            }
            else if ( ent.moveType == MOVETYPE_NONE && this.lerpTo.saved )
            {
                this.applyPosition( this.lerpTo );
                this.lerpFrom.saved = false;
                this.lerpTo.saved = false;
            }
            this.autoRecallStart = this.positionCycle;
        }
        this.recalled = false;

        this.practiceReport.reset();
        for ( int i = 0; i < numCheckpoints; i++ )
            this.sectorTimes[i] = 0;

        this.inRace = false;
        this.postRace = false;
        this.finishTime = 0;
        this.maxSpeed = 0;
    }

    void completeRace()
    {
        uint delta;
        String str;

        if ( this.practicing && !this.recalled )
        {
            if ( this.practiceFinish == 0 || this.timeStamp() > this.practiceFinish + 5000 )
            {
                this.client.addAward( S_COLOR_CYAN + "Finished in practicemode!" );
                this.practiceFinish = this.timeStamp();
            }
            return;
        }

        if ( !this.validTime() ) // something is very wrong here
            return;

        if ( this.practicing )
            this.client.addAward( S_COLOR_CYAN + "Practice Run Finished!" );
        else
            this.client.addAward( S_COLOR_CYAN + "Race Finished!" );

        this.practiceFinish = this.timeStamp();

        this.recalled = false;

        this.finishTime = this.raceTime();
        this.updateMaxSpeed();
        this.inRace = false;
        if ( !this.practicing )
            this.postRace = true;

        // send the final time to MM
        if ( !this.practicing )
            this.client.setRaceTime( -1, this.finishTime );

        if ( this.practicing )
            str = S_COLOR_CYAN;
        else
            str = S_COLOR_WHITE;
        str += "Current: " + S_COLOR_WHITE + RACE_TimeToString( this.finishTime );

        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            if ( !levelRecords[i].saved )
                break;
            if ( this.finishTime < levelRecords[i].finishTime )
            {
                str += " (" + S_COLOR_GREEN + "#" + ( i + 1 ) + S_COLOR_WHITE + ")"; // extra id when on server record beating time
                break;
            }
        }

        Entity@ ent = this.client.getEnt();

        G_CenterPrintMsg( ent, str + "\n" + RACE_TimeDiffString( this.finishTime, this.bestFinishTime, true ) );

        Client@[] specs = RACE_GetSpectators( this.client );
        for ( uint i = 0; i < specs.length; i++ )
        {
            Player@ spec_player = @RACE_GetPlayer( specs[i] );
            String line1 = "";
            String line2 = "";

            if ( this.hasTime )
            {
                line1 += "\u00A0   Current: " + RACE_TimeToString( this.finishTime ) + "   \u00A0";
                line2 += "\u00A0           " + RACE_TimeDiffString(this.finishTime, this.bestFinishTime, true) + "           \u00A0";
            }
            else
            {
                line1 += "\u00A0   Current: " + RACE_TimeToString( this.finishTime ) + "   \u00A0";
                line2 += "\u00A0           " + "                    " + "           \u00A0";
            }

            if ( spec_player.hasTime )
            {
                line1 = "\u00A0  Personal:    " + "          " + line1;
                line2 = RACE_TimeDiffString(this.finishTime, spec_player.bestFinishTime, true) + "          " + line2;
            }
            else if ( levelRecords[0].finishTime != 0 )
            {
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

        Table@ report;
        if ( this.practicing )
            @report = @this.practiceReport;
        else
            @report = @this.report;

        report.addCell( "Finish:" );
        report.addCell( RACE_TimeToString( this.finishTime ) );
        report.addCell( "Personal:" );
        report.addCell( RACE_TimeDiffString( this.finishTime, this.bestFinishTime, false ) );
        report.addCell( "Server:" );
        report.addCell( RACE_TimeDiffString( this.finishTime, levelRecords[0].finishTime, false ) );
        report.addCell( "Speed:" );
        report.addCell( this.getSpeed() + "" );
        if ( this.practicing )
        {
            report.addCell( "" );
            report.addCell( "" );
        }
        else
        {
            report.addCell( ", max" );
            report.addCell( S_COLOR_WHITE + this.maxSpeed );
        }
        uint rows = report.numRows();
        for ( uint i = 0; i < rows; i++ )
            G_PrintMsg( ent, report.getRow( i ) + "\n" );

        if ( !this.practicing )
        {
            if ( !this.hasTime || this.finishTime < this.bestFinishTime )
            {
                this.client.addAward( S_COLOR_YELLOW + "Personal record!" );
                // copy all the sectors into the new personal record backup
                this.setBestTime( this.finishTime, this.maxSpeed );
                for ( int i = 0; i < numCheckpoints; i++ )
                    this.bestSectorTimes[i] = this.sectorTimes[i];

                this.bestRunPositionCount = this.runPositionCount;
                for ( int i = 0; i < this.runPositionCount; i++ )
                    this.bestRunPositions[i] = this.runPositions[i];
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
                        RACE_UpdatePosValues();
                    }

                    break;
                }
            }

            // set up for respawning the player with a delay
            Entity@ respawner = G_SpawnEntity( "race_respawner" );
            respawner.nextThink = levelTime + 5000;
            @respawner.think = race_respawner_think;
            respawner.count = this.client.playerNum;
        }
    }

    bool touchCheckPoint( int id )
    {
        uint delta;
        String str;

        if ( id < 0 || id >= numCheckpoints )
            return false;

        if ( !this.inRace && ( !this.practicing || !this.recalled ) )
            return false;

        if ( this.sectorTimes[id] != 0 ) // already past this checkPoint
            return false;

        if ( !this.validTime() ) // something is very wrong here
            return false;

        this.sectorTimes[id] = this.raceTime();

        // send this checkpoint to MM
        if ( !this.practicing )
            this.client.setRaceTime( id, this.sectorTimes[id] );

        // print some output and give awards if earned

        if ( this.practicing )
            str = S_COLOR_CYAN;
        else
            str = S_COLOR_WHITE;
        str += "Current: " + S_COLOR_WHITE + RACE_TimeToString( this.sectorTimes[id] );

        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            if ( this.sectorTimes[id] < levelRecords[i].sectorTimes[id] )
            {
                str += " (" + S_COLOR_GREEN + "#" + ( i + 1 ) + S_COLOR_WHITE + ")"; // extra id when on server record beating time
                break;
            }
        }

        Entity@ ent = this.client.getEnt();

        G_CenterPrintMsg( ent, str + "\n" + RACE_TimeDiffString( this.sectorTimes[id], this.bestSectorTimes[id], true ) );

        this.updateMaxSpeed();

        Client@[] specs = RACE_GetSpectators( this.client );
        for ( uint i = 0; i < specs.length; i++ )
        {
            Player@ spec_player = @RACE_GetPlayer( specs[i] );
            String line1 = "";
            String line2 = "";

            if ( this.hasTime && this.sectorTimes[id] != 0 )
            {
                line1 += "\u00A0   Current: " + RACE_TimeToString( this.sectorTimes[id] ) + "   \u00A0";
                line2 += "\u00A0           " + RACE_TimeDiffString(this.sectorTimes[id], this.bestSectorTimes[id], true) + "           \u00A0";
            }
            else
            {
                line1 += "\u00A0   Current: " + RACE_TimeToString( this.sectorTimes[id] ) + "   \u00A0";
                line2 += "\u00A0           " + "                    " + "           \u00A0";
            }

            if ( spec_player.hasTime && spec_player.bestSectorTimes[id] != 0 )
            {
                line1 = "\u00A0  Personal:    " + "          " + line1;
                line2 = RACE_TimeDiffString(this.sectorTimes[id], spec_player.bestSectorTimes[id], true) + "          " + line2;
            }
            else if ( levelRecords[0].finishTime != 0 )
            {
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

        Table@ report;
        if ( this.practicing )
            @report = @this.practiceReport;
        else
            @report = @this.report;

        report.addCell( "CP" + (this.currentSector + 1) + ":" );
        report.addCell( RACE_TimeToString( this.sectorTimes[id] ) );
        report.addCell( "Personal:" );
        report.addCell( RACE_TimeDiffString( this.sectorTimes[id], this.bestSectorTimes[id], false ) );
        report.addCell( "Server:" );
        report.addCell( RACE_TimeDiffString( this.sectorTimes[id], levelRecords[0].sectorTimes[id], false ) );
        report.addCell( "Speed:" );
        report.addCell( this.getSpeed() + "" );
        if ( this.practicing )
        {
            report.addCell( "" );
            report.addCell( "" );
        }
        else
        {
            report.addCell( ", max" );
            report.addCell( S_COLOR_WHITE + this.maxSpeed );
        }

        if ( !this.practicing )
        {
            // if beating the level record on this sector give an award
            if ( this.sectorTimes[id] < levelRecords[0].sectorTimes[id] )
            {
                this.client.addAward( "Server record on CP" + (this.currentSector + 1) + "!" );
            }
            // if beating his own record on this sector give an award
            else if ( this.sectorTimes[id] < this.bestSectorTimes[id] )
            {
                // ch : does racesow apply sector records only if race is completed?
                this.client.addAward( "Personal record on CP" + (this.currentSector + 1) + "!" );
            }
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
        this.recalled = false;
        G_CenterPrintMsg( this.client.getEnt(), S_COLOR_CYAN + "Entered practice mode" );

        this.cancelRace();
        this.setQuickMenu();

        // msc: practicemode message
        client.setHelpMessage( practiceModeMsg );

        Client@[] specs = RACE_GetSpectators( this.client );
        for ( uint i = 0; i < specs.length; i++ )
            specs[i].setHelpMessage( practiceModeMsg );
    }

    void leavePracticeMode()
    {
        if ( !this.practicing )
            return;

        // for accuracy, reset scores.
        target_score_init( this.client );

        this.cancelRace();
        this.practicing = false;
        this.release = 0;
        G_CenterPrintMsg( this.client.getEnt(), S_COLOR_CYAN + "Left practice mode" );
        if ( this.client.team != TEAM_SPECTATOR )
            this.client.respawn( false );
        this.setQuickMenu();

        // msc: practicemode message
        client.setHelpMessage(defaultMsg);

        Client@[] specs = RACE_GetSpectators( this.client );
        for ( uint i = 0; i < specs.length; i++ )
            specs[i].setHelpMessage(defaultMsg);
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

    bool recallExit()
    {
        if ( this.client.team == TEAM_SPECTATOR || !this.practicing )
        {
            G_PrintMsg( this.client.getEnt(), "Not available.\n" );
            return false;
        }

        if ( !this.noclipBackup.saved )
            return true;

        Entity@ ent = this.client.getEnt();
        ent.moveType = MOVETYPE_NOCLIP;
        this.applyPosition( this.noclipBackup );
        ent.set_velocity( Vec3() );
        this.noclipBackup.saved = false;
        this.recalled = false;
        G_CenterPrintMsg( ent, S_COLOR_CYAN + "Left recall mode" );
        return true;
    }

    bool recallSteal()
    {
        if ( this.client.team == TEAM_SPECTATOR && this.client.chaseActive && this.client.chaseTarget != 0 )
        {
            this.takeHistory( RACE_GetPlayer( G_GetEntity( this.client.chaseTarget ).client ) );
        }
        else
        {
            G_PrintMsg( this.client.getEnt(), "Not available.\n" );
            return false;
        }
        return true;
    }

    bool recallInterval( int number )
    {
        if ( number < 0 )
            G_PrintMsg( this.client.getEnt(), this.positionInterval + "\n" );
        else
            this.positionInterval = number;
        return true;
    }

    bool recallBest( String pattern )
    {
        if ( this.inRace )
        {
            G_PrintMsg( this.client.getEnt(), "Not possible during a race.\n" );
            return false;
        }

        Player@ target = this;

        if ( pattern != "" )
        {
            Player@[] matches = RACE_MatchPlayers( pattern );
            if ( matches.length() == 0 )
            {
                G_PrintMsg( this.client.getEnt(), "No players matched.\n" );
                return false;
            }
            else if ( matches.length() > 1 )
            {
                G_PrintMsg( this.client.getEnt(), "Multiple players matched:\n" );
                for ( uint i = 0; i < matches.length(); i++ )
                    G_PrintMsg( this.client.getEnt(), matches[i].client.name + S_COLOR_WHITE + "\n" );
                return false;
            }
            else
            {
                @target = matches[0];
            }
        }

        if ( target.bestRunPositionCount == 0 )
        {
            G_PrintMsg( this.client.getEnt(), "No best run recorded.\n" );
            return false;
        }

        this.runPositionCount = target.bestRunPositionCount;
        for ( int i = 0; i < this.runPositionCount; i++ )
            this.runPositions[i] = target.bestRunPositions[i];
        this.positionCycle = 0;

        if ( this.practicing && this.client.team != TEAM_SPECTATOR )
            return this.recallPosition( 0 );
        else
            return true;
    }

    bool recallStart()
    {
        return this.recallPosition( -this.positionCycle );
    }

    bool recallEnd()
    {
        return this.recallPosition( -this.positionCycle - 1 );
    }

    bool recallExtend()
    {
        Entity@ ent = this.client.getEnt();

        if ( !this.recalled || ent.moveType == MOVETYPE_NONE )
        {
            G_PrintMsg( ent, "Only possible during a practice run.\n" );
            return false;
        }

        if ( this.extRunPositionCount == 0 )
        {
            G_PrintMsg( ent, "No practice run positions set.\n" );
            return false;
        }

        if ( this.runPositionCount != 0 )
            this.runPositionCount = this.positionCycle + 1;

        for ( int i = 0; i < this.extRunPositionCount && this.runPositionCount < MAX_POSITIONS; i++ )
            this.runPositions[this.runPositionCount++] = this.extRunPositions[i];

        return true;
    }

    bool recallAuto()
    {
        this.autoRecall = !this.autoRecall;
        Entity@ ent = this.client.getEnt();
        if ( this.autoRecall )
            G_PrintMsg( ent, "Auto recall extend ON.\n" );
        else
            G_PrintMsg( ent, "Auto recall extend OFF.\n" );
        this.extRunPositionCount = 0;
        return true;
    }

    bool recallCheckpoint( int cp )
    {
        int index = -1;
        for ( int i = 0; i < this.runPositionCount; i++ )
        {
            if ( this.runPositions[i].currentSector == cp )
            {
                index = i;
                break;
            }
        }
        if ( index != -1 )
        {
            return this.recallPosition( index - this.positionCycle );
        }
        else
        {
            G_PrintMsg( this.client.getEnt(), "Not found.\n" );
            return false;
        }
    }

    bool recallWeapon( uint weapon )
    {
        int index = -1;
        for ( int i = 0; i < this.runPositionCount; i++ )
        {
            if ( this.runPositions[i].weapons[weapon] )
            {
                index = i;
                break;
            }
        }
        if ( index != -1 )
        {
            return this.recallPosition( index - this.positionCycle );
        }
        else
        {
            G_PrintMsg( this.client.getEnt(), "Not found.\n" );
            return false;
        }
    }

    bool joinPosition( String pattern )
    {
        Entity@ ent = this.client.getEnt();

        if ( !this.practicing && this.client.team != TEAM_SPECTATOR )
        {
            G_PrintMsg( ent, "Position loading is not available during a race.\n" );
            return false;
        }

        Player@[] matches = RACE_MatchPlayers( pattern );
        if ( matches.length() == 0 )
        {
            G_PrintMsg( ent, "No players matched.\n" );
            return false;
        }
        else if ( matches.length() > 1 )
        {
            G_PrintMsg( this.client.getEnt(), "Multiple players matched:\n" );
            for ( uint i = 0; i < matches.length(); i++ )
                G_PrintMsg( this.client.getEnt(), matches[i].client.name + S_COLOR_WHITE + "\n" );
            return false;
        }

        this.applyPosition( matches[0].currentPosition() );
        ent.set_velocity( Vec3() );

        return true;
    }

    bool positionSpeed( String speedStr )
    {
        Position@ position = this.savedPosition();
        float speed = 0;
        if ( speedStr.locate( "+", 0 ) == 0 )
            speed += speedStr.substr( 1 ).toFloat();
        else if ( speedStr.locate( "-", 0 ) == 0 )
            speed -= speedStr.substr( 1 ).toFloat();
        else
            speed = speedStr.toFloat();
        Vec3 a, b, c;
        position.angles.angleVectors( a, b, c );
        a = HorizontalVelocity( a );
        a.normalize();
        position.velocity = a * speed;
        position.recalled = false;
        return true;
    }
}

Player@ RACE_GetPlayer( Client@ client )
{
    if ( @client == null || client.playerNum < 0 )
        return null;

    Player@ player = players[client.playerNum];
    @player.client = client;

    return player;
}

Player@[] RACE_MatchPlayers( String pattern )
{
    pattern = pattern.removeColorTokens().tolower();

    Player@[] playerList;
    for ( int i = 0; i < maxClients; i++ )
    {
        Client@ client = @G_GetClient(i);
        String clean = client.name.removeColorTokens().tolower();

        if ( PatternMatch( clean, pattern ) )
            playerList.push_back( RACE_GetPlayer( client ) );
    }
    return playerList;
}

void RACE_UpdatePosValues()
{
    Team@ team = G_GetTeam( TEAM_PLAYERS );
    for ( int i = 0; @team.ent( i ) != null; i++ )
        RACE_GetPlayer( team.ent( i ).client ).updatePos();
}
