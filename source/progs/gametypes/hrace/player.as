const int MAX_POSITIONS = 400;
const int POSITION_INTERVAL = 500;
const float POSITION_HEIGHT = 32;

const int RECALL_ACTION_TIME = 200;
const int RECALL_ACTION_JUMP = 5;
const int RECALL_HOLD = 20;

const float POINT_DISTANCE = 65536.0f;
const float POINT_PULL = 0.004f;
const float PULL_MARGIN = 16.0f;

const uint BIG_LIST = 15;

Player[] players( maxClients );

class Player
{
    Client@ client;

    bool inRace;
    uint startTime;
    int currentSector;
    Table report( S_COLOR_ORANGE + "l " + S_COLOR_WHITE + "r " + S_COLOR_ORANGE + "/ l r " + S_COLOR_ORANGE + "/ l r " + S_COLOR_ORANGE + "/ l " + S_COLOR_WHITE + "r" + S_COLOR_ORANGE + "l r" );
    Table practiceReport( S_COLOR_CYAN + "l " + S_COLOR_WHITE + "r " + S_COLOR_CYAN + "/ l r " + S_COLOR_CYAN + "/ l r " + S_COLOR_CYAN + "/ l " + S_COLOR_WHITE + "r" + S_COLOR_CYAN + "l r" );

    bool postRace;
    Run run;
    uint forceRespawn;

    uint nextRunPositionTime;
    int positionCycle;

    bool hasTime;
    Run bestRun;
    int pos;

    bool practicing;

    PositionStore preRacePositionStore;
    PositionStore practicePositionStore;

    bool noclipSpawn;
    int noclipWeapon;

    bool recalled;
    Position noclipBackup;
    uint practiceFinish;

    uint release;
    uint lastNoclipAction;
    Position lerpFrom;
    Position lerpTo;

    bool autoRecall;
    int autoRecallStart;

    uint[] messageTimes;
    uint messageLock;
    bool firstMessage;

    int positionInterval;
    int recallHold;

    String lastFind;
    uint findIndex;

    String randmap;
    String randmapPattern;
    uint randmapMatches;

    Entity@ marker;

    void resizeCPs( int size )
    {
        this.run.resizeCPs( size );
        this.bestRun.resizeCPs( size );
    }

    void clear()
    {
        @this.client = null;

        this.positionInterval = POSITION_INTERVAL;
        this.recallHold = RECALL_HOLD;

        this.currentSector = 0;
        this.inRace = false;
        this.postRace = false;
        this.forceRespawn = 0;
        this.practicing = false;
        this.recalled = false;
        this.autoRecall = false;
        this.autoRecallStart = -1;
        this.release = 0;
        this.practiceFinish = 0;
        this.startTime = 0;
        this.nextRunPositionTime = 0;
        this.positionCycle = 0;
        this.hasTime = false;
        this.pos = -1;
        this.noclipSpawn = false;

        this.practicePositionStore.clear();
        this.preRacePositionStore.clear();
        this.noclipBackup.clear();
        this.lastNoclipAction = 0;
        this.lerpFrom.saved = false;
        this.lerpTo.saved = false;

        this.run.clear();
        this.bestRun.clear();

        this.messageTimes.resize( MAX_FLOOD_MESSAGES );
        this.firstMessage = true;
        this.messageLock = 0;
        for ( int i = 0; i < MAX_FLOOD_MESSAGES; i++ )
            this.messageTimes[i] = 0;

        this.lastFind = "";
        this.findIndex = 0;

        this.randmap = "";
        this.randmapPattern = "";
        this.randmapMatches = 0;

        @this.marker = null;
    }

    Player()
    {
        this.clear();
    }

    ~Player() {}

    void updatePos()
    {
        this.pos = -1;
        if ( this.bestRun.finishTime == 0 )
            return;

        String cleanName = this.client.name.removeColorTokens().tolower();
        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            if ( !levelRecords[i].saved )
                break;

            if ( this.bestRun.finishTime == levelRecords[i].finishTime && cleanName == levelRecords[i].playerName.removeColorTokens().tolower() )
            {
                this.pos = i + 1;
                break;
            }
        }
    }

    void updateScore()
    {
        this.client.stats.setScore( this.bestRun.finishTime / 10 );
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
        if ( this.hasTime && levelRecords[0].saved && this.bestRun.finishTime >= levelRecords[0].finishTime )
        {
            uint change = this.bestRun.finishTime - levelRecords[0].finishTime;
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
            speed = this.bestRun.maxSpeed + "";
        else
            speed = "\u00A0";

        return "&p " + playerID + " " + ent.client.clanName + " " + pos + " " + this.bestRun.finishTime + " " + diff + " " + speed + " " + ent.client.ping + " " + racing + " ";
    }

    bool preRace()
    {
        return !this.inRace && !this.practicing && !this.postRace && this.client.team != TEAM_SPECTATOR && this.client.getEnt().health > 0;
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
        if ( pending_endmatch || match.getState() >= MATCH_STATE_POSTMATCH )
        {
            G_PrintMsg( ent, "Can't use noclip in overtime.\n" );
            return false;
        }
        if ( this.client.team == TEAM_SPECTATOR || ent.health <= 0 )
        {
            Vec3 origin = ent.origin;
            Vec3 angles = ent.angles;
            if ( this.client.team == TEAM_SPECTATOR )
            {
                this.client.team = TEAM_PLAYERS;
                G_PrintMsg( null, this.client.name + S_COLOR_WHITE + " joined the " + G_GetTeam( this.client.team ).name + S_COLOR_WHITE + " team.\n" );
            }
            this.noclipSpawn = true;
            this.respawn();
            ent.origin = origin;
            ent.angles = angles;
            return true;
        }
        if ( !this.practicing )
            this.enterPracticeMode();

        if ( ent.moveType == MOVETYPE_PLAYER )
        {
            this.cancelRace();
            ent.moveType = MOVETYPE_NOCLIP;
            this.noclipWeapon = ent.weapon;
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
                    this.applyPosition( this.savedPosition() );
                this.autoRecallStart = this.positionCycle;
            }
            this.noclipBackup.saved = false;
        }

        this.setQuickMenu();
        this.updateHelpMessage();

        return true;
    }

    PositionStore@ positionStore()
    {
        if ( this.preRace() )
            return preRacePositionStore;
        else
            return practicePositionStore;
    }

    Position@ savedPosition()
    {
        return this.positionStore().positions[0];
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

    bool loadPosition( String name, Verbosity verbosity )
    {
        Entity@ ent = this.client.getEnt();
        if ( !this.practicing && this.client.team != TEAM_SPECTATOR && !this.preRace() )
        {
            if ( verbosity == Verbosity_Verbose )
                G_PrintMsg( ent, "Position loading is not available during a race.\n" );
            return false;
        }

        this.noclipBackup.saved = false;

        PositionStore@ store = this.positionStore();
        Position@ position = store.get( name );

        if ( @position == null || !position.saved )
        {
            if ( verbosity == Verbosity_Verbose )
                G_PrintMsg( ent, "No position has been saved yet.\n" );
            return false;
        }

        this.applyPosition( position );

        if ( this.preRace() )
            ent.set_velocity( Vec3() );
        else if ( this.practicing && position.recalled )
        {
            this.cancelRace();
            this.startTime = this.timeStamp() - position.currentTime;
            this.recalled = true;
            this.nextRunPositionTime = this.timeStamp() + this.positionInterval;
            this.autoRecallStart = this.positionCycle;
        }
        else if ( this.practicing )
            this.recalled = false;

        if ( name != "" )
            store.set( "", position );

        this.updateHelpMessage();

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

        if ( this.run.positionCount == 0 )
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
            this.positionCycle = ( this.run.positionCount - ( -this.positionCycle % this.run.positionCount ) ) % this.run.positionCount;
        else
            this.positionCycle %= this.run.positionCount;
        Position@ position = this.run.positions[this.positionCycle];

        this.applyPosition( position );
        Position@ saved = this.savedPosition();
        saved.copy( position );
        saved.saved = true;
        saved.recalled = true;
        this.recalled = true;
        saved.skipWeapons = false;

        this.startTime = this.timeStamp() - position.currentTime;

        this.setQuickMenu();
        this.updateHelpMessage();

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

    bool savePosition( String name )
    {
        Client@ ref = this.client;
        if ( this.client.team == TEAM_SPECTATOR && this.client.chaseActive && this.client.chaseTarget != 0 )
            @ref = G_GetEntity( this.client.chaseTarget ).client;
        Entity@ ent = ref.getEnt();

        if ( ent.health <= 0 )
        {
            G_PrintMsg( ent, "You can only save your position while alive.\n" );
            return false;
        }

        if ( this.preRace() )
        {
            Vec3 mins, maxs;
            ent.getSize( mins, maxs );
            Vec3 down = ent.origin;
            down.z -= 1;
            Trace tr;
            if ( !tr.doTrace( ent.origin, mins, maxs, down, ent.entNum, MASK_DEADSOLID ) )
            {
                G_PrintMsg( this.client.getEnt(), "You can only save your prerace position on solid ground.\n" );
                return false;
            }

            if ( tr.doTrace( ent.origin, playerMins, playerMaxs, ent.origin, ent.entNum, MASK_DEADSOLID ) )
            {
                G_PrintMsg( this.client.getEnt(), "You can't save your prerace position where you cannot stand up.\n" );
                return false;
            }
        }

        PositionStore@ store = this.positionStore();
        Position@ position = store.get( name );
        if( @position == null )
            @position = Position();

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

        if ( !store.set( name, position ) )
        {
            G_PrintMsg( this.client.getEnt(), "No free position slot available.\n" );
            return false;
        }

        this.setQuickMenu();

        return true;
    }

    void listPositions()
    {
        Entity@ ent = this.client.getEnt();
        PositionStore@ store = this.positionStore();
        for ( uint i = 0; i < store.positions.length; i++ )
        {
            if( store.positions[i].saved )
            {
                if ( store.names[i] == "" )
                    G_PrintMsg( ent, "Main position saved\n" );
                else
                    G_PrintMsg( ent, "Additional position: '" + store.names[i] + "'\n" );
            }
        }
    }

    bool clearPosition( String name )
    {
        if ( !this.practicing && this.client.team != TEAM_SPECTATOR && !this.preRace() )
        {
            G_PrintMsg( this.client.getEnt(), "Position clearing is not available during a race.\n" );
            return false;
        }

        this.positionStore().remove( name );
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
            this.loadPosition( "", Verbosity_Silent );
            this.release = 0;
        }
    }

    bool startRace()
    {
        if ( this.practicing && this.autoRecall && !this.recalled )
        {
            this.run.clear();
            this.startTime = this.timeStamp();
            this.recalled = true;
            this.positionCycle = 0;
            this.nextRunPositionTime = this.timeStamp() + this.positionInterval;
            this.autoRecallStart = -1;
            this.updateHelpMessage();
            return true;
        }

        if ( !this.preRace() )
            return false;

        if ( RS_QueryPjState( this.client.playerNum )  )
        {
            this.client.addAward( S_COLOR_RED + "Prejumped!" );
            this.respawn();
            RS_ResetPjState( this.client.playerNum );
            return false;
        }

        this.currentSector = 0;
        this.inRace = true;
        this.startTime = this.timeStamp();
        this.positionCycle = 0;
        this.nextRunPositionTime = this.timeStamp() + this.positionInterval;

        this.run.clear();
        this.report.reset();
        this.client.newRaceRun( numCheckpoints );
        this.setQuickMenu();

        return true;
    }

    void saveRunPosition()
    {
        if ( this.run.positionCount == MAX_POSITIONS || this.timeStamp() < this.nextRunPositionTime )
            return;

        Entity@ ent = this.client.getEnt();

        if ( !this.inRace && ( this.client.team == TEAM_SPECTATOR || !this.practicing || !this.recalled || !this.autoRecall || ent.moveType != MOVETYPE_PLAYER ) )
            return;

        if ( ent.velocity.length() == 0 )
            return;

        uint keys = this.client.pressedKeys;
        if ( ent.velocity.z <= 0 && keys & ( Key_Jump | Key_Crouch | Key_Special ) != 0 )
        {
            Vec3 mins, maxs;
            ent.getSize( mins, maxs );
            Vec3 down = ent.origin;
            down.z -= POSITION_HEIGHT;
            Trace tr;
            if ( tr.doTrace( ent.origin, mins, maxs, down, ent.entNum, MASK_DEADSOLID ) )
                return;
        }

        if ( !this.inRace && this.autoRecall && this.autoRecallStart >= 0 )
        {
            if ( this.autoRecallStart < this.run.positionCount )
                this.run.positionCount = this.autoRecallStart + 1;
            this.autoRecallStart = -1;
        }

        this.run.savePosition( this.currentPosition() );
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

        if ( keys & Key_Attack != 0 && keys & Key_Special != 0 && ent.moveType == MOVETYPE_NOCLIP )
        {
            Vec3 mins( 0 );
            Vec3 maxs( 0 );
            Vec3 offset( 0, 0, ent.viewHeight );
            Vec3 origin = ent.origin + offset;
            Vec3 a, b, c;
            ent.angles.angleVectors( a, b, c );
            a.normalize();
            Trace tr;
            float pull = 1.0f - pow( 1.0f - POINT_PULL, frameTime );
            if ( tr.doTrace( origin, mins, maxs, origin + a * POINT_DISTANCE, ent.entNum, MASK_PLAYERSOLID | MASK_WATER ) && tr.fraction * POINT_DISTANCE > PULL_MARGIN )
                ent.origin = origin * ( 1.0 - pull ) + tr.endPos * pull - offset;
            return;
        }

        if ( this.run.positionCount == 0 )
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
                this.updateHelpMessage();
            }
            else
                this.recallPosition( 0 );
        }
        else if ( keys & Key_Backward != 0 && this.noclipBackup.saved )
        {
            if ( this.positionCycle == 0 )
                this.recallPosition( -1 );
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

    bool validTime()
    {
        return this.timeStamp() >= this.startTime;
    }

    uint raceTime()
    {
        return this.timeStamp() - this.startTime;
    }

    void spawn( int oldTeam, int newTeam )
    {
        this.forceRespawn = 0;

        this.cancelRace();

        this.setQuickMenu();
        this.updateHelpMessage();
        this.updateScore();
        if ( oldTeam != TEAM_PLAYERS && newTeam == TEAM_PLAYERS )
            this.updatePos();

        Entity@ ent = this.client.getEnt();

        if ( ent.isGhosting() )
            return;

        // set player movement to pass through other players
        this.client.pmoveFeatures = this.client.pmoveFeatures | PMFEAT_GHOSTMOVE;

        if ( gametype.isInstagib )
            this.client.inventoryGiveItem( WEAP_INSTAGUN );
        else
            this.client.inventorySetCount( WEAP_GUNBLADE, 1 );

        // select rocket launcher if available
        if ( this.client.canSelectWeapon( WEAP_ROCKETLAUNCHER ) )
            this.client.selectWeapon( WEAP_ROCKETLAUNCHER );
        else
            this.client.selectWeapon( -1 ); // auto-select best weapon in the inventory

        G_RemoveProjectiles( ent );
        RS_ResetPjState( this.client.playerNum );

        this.loadPosition( "", Verbosity_Silent );

        if ( this.noclipSpawn )
        {
            this.enterPracticeMode();
            this.recalled = false;
            ent.moveType = MOVETYPE_NOCLIP;
            ent.velocity = Vec3();
            this.noclipWeapon = this.client.pendingWeapon;
            this.noclipSpawn = false;
        }

        if ( this.recalled )
        {
            ent.moveType = MOVETYPE_NONE;
            this.updateHelpMessage();
            this.release = this.recallHold;
        }

        this.updateHelpMessage();
    }

    void updateHelpMessage()
    {
        // msc: permanent practicemode message
        Client@ ref = this.client;
        if ( ref.team == TEAM_SPECTATOR && ref.chaseActive && ref.chaseTarget != 0 )
            @ref = G_GetEntity( ref.chaseTarget ).client;
        Player@ refPlayer = RACE_GetPlayer( ref );
        if ( refPlayer.practicing && ref.team != TEAM_SPECTATOR )
        {
            if ( refPlayer.recalled )
                this.client.setHelpMessage( recallModeMsg );
            else
            {
                if ( ref.getEnt().moveType == MOVETYPE_NOCLIP )
                    this.client.setHelpMessage( noclipModeMsg );
                else
                    this.client.setHelpMessage( practiceModeMsg );
            }
        }
        else
        {
            if ( this.client.team == TEAM_SPECTATOR && this.client.getEnt().isGhosting() )
                this.client.setHelpMessage( 0 );
            else if ( refPlayer.preRace() && RS_QueryPjState( refPlayer.client.playerNum ) )
                this.client.setHelpMessage( prejumpMsg );
            else
                this.client.setHelpMessage( defaultMsg );
        }
    }

    void think()
    {
        Client@ client = this.client;
        Entity@ ent = client.getEnt();

        // all stats are set to 0 each frame, so it's only needed to set a stat if it's going to get a value
        if ( this.inRace || ( this.practicing && this.recalled && ent.health > 0 ) )
        {
            if ( ent.moveType == MOVETYPE_NONE )
                client.setHUDStat( STAT_TIME_SELF, this.savedPosition().currentTime / 100 );
            else
                client.setHUDStat( STAT_TIME_SELF, this.raceTime() / 100 );
        }

        client.setHUDStat( STAT_TIME_BEST, this.bestRun.finishTime / 100 );
        client.setHUDStat( STAT_TIME_RECORD, levelRecords[0].finishTime / 100 );

        client.setHUDStat( STAT_TIME_ALPHA, -9999 );
        client.setHUDStat( STAT_TIME_BETA, -9999 );

        if ( levelRecords[0].playerName.length() > 0 )
            client.setHUDStat( STAT_MESSAGE_OTHER, CS_GENERAL );
        if ( levelRecords[1].playerName.length() > 0 )
            client.setHUDStat( STAT_MESSAGE_ALPHA, CS_GENERAL + 1 );
        if ( levelRecords[2].playerName.length() > 0 )
            client.setHUDStat( STAT_MESSAGE_BETA, CS_GENERAL + 2 );

        this.saveRunPosition();
        this.checkNoclipAction();
        this.updateMaxSpeed();
        this.checkRelease();

        this.updateHelpMessage();

        // msc: temporary MAX_ACCEL replacement
        if ( frameTime > 0 )
        {
            float cgframeTime = float( frameTime ) / 1000;
            float base_speed = client.pmoveMaxSpeed;
            float base_accel = base_speed * cgframeTime;
            float speed = HorizontalSpeed( ent.velocity );
            int max_accel = int( ( sqrt( speed * speed + base_accel * ( 2 * base_speed - base_accel ) ) - speed ) / cgframeTime );
            client.setHUDStat( STAT_PROGRESS_SELF, max_accel );
        }

        if ( client.state() >= CS_SPAWNED && ent.team != TEAM_SPECTATOR )
        {
            if ( ent.health > ent.maxHealth )
            {
                ent.health -= ( frameTime * 0.001f );
                // fix possible rounding errors
                if ( ent.health < ent.maxHealth )
                    ent.health = ent.maxHealth;
            }
        }

        if ( this.postRace && this.forceRespawn > 0 && this.forceRespawn < levelTime )
            this.respawn();
    }

    void cancelRace()
    {
        Entity@ ent = this.client.getEnt();

        if ( this.inRace && this.currentSector > 0 )
        {
            uint rows = this.report.numRows();
            for ( uint i = 0; i < rows; i++ )
                G_PrintMsg( ent, this.report.getRow( i ) + "\n" );
            G_PrintMsg( ent, S_COLOR_ORANGE + "Race cancelled, max speed " + S_COLOR_WHITE + this.run.maxSpeed + "\n" );
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
        this.run.clearTimes();

        this.inRace = false;
        this.postRace = false;
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

        this.run.finish( this.raceTime() );
        this.updateMaxSpeed();
        this.inRace = false;
        if ( !this.practicing )
            this.postRace = true;

        // send the final time to MM
        if ( !this.practicing && this.client.getMMLogin() != "" )
            this.client.setRaceTime( -1, this.run.finishTime );

        if ( this.practicing )
            str = S_COLOR_CYAN;
        else
            str = S_COLOR_WHITE;
        str += "Current: " + S_COLOR_WHITE + RACE_TimeToString( this.run.finishTime );
        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            if ( !levelRecords[i].saved || this.run.finishTime < levelRecords[i].finishTime )
            {
                str += " (" + S_COLOR_GREEN + "#" + ( i + 1 ) + S_COLOR_WHITE + ")"; // extra id when on server record beating time
                break;
            }
        }
        G_CenterPrintMsg( this.client.getEnt(), str + "\n" + RACE_TimeDiffString( this.run.finishTime, this.bestRun.finishTime, true ) );

        this.reportTime( "End", this.run.finishTime, this.bestRun.finishTime, levelRecords[0].finishTime );
        this.showReport();

        Client@[] specs = RACE_GetSpectators( this.client );
        for ( uint i = 0; i < specs.length; i++ )
        {
            Player@ specPlayer = @RACE_GetPlayer( specs[i] );
            specPlayer.showChaseeTime( this.run.finishTime, this.bestRun.finishTime, specPlayer.bestRun.finishTime, levelRecords[0].finishTime );
        }

        if ( !this.practicing && ( !this.hasTime || this.run.finishTime < this.bestRun.finishTime ) )
        {
            this.client.addAward( S_COLOR_YELLOW + "Personal record!" );
            this.hasTime = true;
            this.bestRun.copy( this.run );
            this.client.stats.setScore( this.bestRun.finishTime / 10 );
        }

        if ( !this.practicing )
        {
            // see if the player improved one of the top scores
            this.updateTop();

            // set up for respawning the player with a delay
            this.scheduleRespawn();
        }
    }

    void updateTop()
    {
        for ( int top = 0; top < MAX_RECORDS; top++ )
        {
            if ( !levelRecords[top].saved || this.run.finishTime < levelRecords[top].finishTime )
            {
                String cleanName = this.client.name.removeColorTokens().tolower();
                String login = this.client.getMMLogin();

                if ( top == 0 )
                {
                    this.client.addAward( S_COLOR_GREEN + race_servername.string + " record!" );

                    uint prevTime = 0;

                    if ( levelRecords[0].finishTime != 0 )
                        prevTime = levelRecords[0].finishTime;

                    if ( levelRecords[0].finishTime == 0 )
                    {
                        G_PrintMsg( null, this.client.name + S_COLOR_YELLOW + " set a new " + S_COLOR_GREEN + race_servername.string + " " + S_COLOR_YELLOW + "record: "
                            + S_COLOR_GREEN + RACE_TimeToString( this.run.finishTime ) + "\n" );
                    }
                    else
                    {
                        G_PrintMsg( null, this.client.name + S_COLOR_YELLOW + " set a new " + S_COLOR_GREEN + race_servername.string + " " + S_COLOR_YELLOW + "record: "
                            + S_COLOR_GREEN + RACE_TimeToString( this.run.finishTime ) + " " + S_COLOR_YELLOW + "[-" + RACE_TimeToString( levelRecords[0].finishTime - this.run.finishTime ) + "]\n" );
                    }
                    if ( otherVersionRecords[0].saved && otherVersionRecords[0].finishTime <= this.run.finishTime )
                    {
                        G_PrintMsg( null, S_COLOR_YELLOW + "Note overall top is " + RACE_TimeToString( otherVersionRecords[0].finishTime ) + " [" + RACE_TimeDiffString( otherVersionRecords[0].finishTime, this.run.finishTime, false ).removeColorTokens() + "]" + S_COLOR_YELLOW + " by " + S_COLOR_WHITE + otherVersionRecords[0].playerName + S_COLOR_YELLOW + " in " + otherVersionRecords[0].version + "\n" );
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
                        // there may be authed and unauthed records for a player;
                        // remove the unauthed if it is worse than the authed one
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

                    if ( top == 0 )
                        lastRecords.toFile();
                }

                break;
            }
        }
    }

    void scheduleRespawn()
    {
        this.forceRespawn = levelTime + 5000;
    }

    void updateMaxSpeed()
    {
        if ( this.inRace )
            this.run.observeSpeed( this.getSpeed() );
    }

    bool touchCheckPoint( int id )
    {
        uint delta;
        String str;

        if ( id < 0 || id >= numCheckpoints )
            return false;

        if ( !this.inRace && ( !this.practicing || !this.recalled ) )
            return false;

        if ( this.run.hasCP( id ) ) // already past this checkPoint
            return false;

        if ( !this.validTime() ) // something is very wrong here
            return false;

        if ( this.client.getEnt().moveType == MOVETYPE_NONE )
            return false;

        uint time = this.raceTime();
        if ( this.practicing )
            this.run.setCP( id, time );
        else
            this.run.setCP( id, time, this.currentSector );
        this.currentSector++;

        // send this checkpoint to MM
        if ( !this.practicing && this.client.getMMLogin() != "" )
            this.client.setRaceTime( id, time );

        this.updateMaxSpeed();

        // print some output and give awards if earned

        if ( this.practicing )
            str = S_COLOR_CYAN;
        else
            str = S_COLOR_WHITE;
        str += "Current: " + S_COLOR_WHITE + RACE_TimeToString( time );
        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            if ( !levelRecords[i].saved || time < levelRecords[i].cpTimes[id] )
            {
                str += " (" + S_COLOR_GREEN + "#" + ( i + 1 ) + S_COLOR_WHITE + ")"; // extra id when on server record beating time
                break;
            }
        }
        G_CenterPrintMsg( this.client.getEnt(), str + "\n" + RACE_TimeDiffString( time, this.bestRun.cpTimes[id], true ) );

        this.reportTime( "CP" + this.currentSector, time, this.bestRun.cpTimes[id], levelRecords[0].cpTimes[id] );

        if ( !this.practicing )
        {
            if ( time < levelRecords[0].cpTimes[id] )
                this.client.addAward( "Server record on CP" + this.currentSector + "!" );
            else if ( time < this.bestRun.cpTimes[id] )
                this.client.addAward( "Personal record on CP" + this.currentSector + "!" );
        }

        G_AnnouncerSound( this.client, G_SoundIndex( "sounds/misc/timer_bip_bip" ), GS_MAX_TEAMS, false, null );

        Client@[] specs = RACE_GetSpectators( this.client );
        for ( uint i = 0; i < specs.length; i++ )
        {
            Player@ specPlayer = @RACE_GetPlayer( specs[i] );
            specPlayer.showChaseeTime( time, this.bestRun.cpTimes[id], specPlayer.bestRun.cpTimes[id], levelRecords[0].cpTimes[id] );
        }

        return true;
    }

    void showChaseeTime( uint time, uint best, uint personal, uint server )
    {
        String line1 = "";
        String line2 = "";

        line1 += "\u00A0   Current: " + RACE_TimeToString( time ) + "   \u00A0";
        if ( best != 0 )
            line2 += "\u00A0           " + RACE_TimeDiffString( time, best, true ) + "           \u00A0";
        else
            line2 += "\u00A0                                          \u00A0";

        if ( personal != 0 )
        {
            line1 = "\u00A0  Personal:              " + line1;
            line2 = RACE_TimeDiffString( time, personal, true ) + "          " + line2;
        }
        else if ( server != 0 )
        {
            line1 = "\u00A0                                " + line1;
            line2 = "\u00A0                                " + line2;
        }

        if ( server != 0 )
        {
            line1 += "\u00A0          " + "Server:     \u00A0";
            line2 += "\u00A0      " + RACE_TimeDiffString( time, server, true ) + "\u00A0";
        }

        G_CenterPrintMsg( this.client.getEnt(), line1 + "\n" + line2 );
    }

    Table@ activeReport()
    {
        if ( this.practicing )
            return this.practiceReport;
        else
            return this.report;
    }

    void reportTime( String name, uint time, uint bestTime, uint serverTime )
    {
        Table@ report = this.activeReport();
        report.addCell( name + ":" );
        report.addCell( RACE_TimeToString( time ) );
        report.addCell( "Personal:" );
        report.addCell( RACE_TimeDiffString( time, bestTime, false ) );
        report.addCell( "Server:" );
        report.addCell( RACE_TimeDiffString( time, serverTime, false ) );
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
            report.addCell( S_COLOR_WHITE + this.run.maxSpeed );
        }
    }

    void showReport()
    {
        Table@ report = this.activeReport();
        Entity@ ent = this.client.getEnt();
        uint rows = report.numRows();
        for ( uint i = 0; i < rows; i++ )
            G_PrintMsg( ent, report.getRow( i ) + "\n" );
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
        this.updateHelpMessage();
    }

    void respawn()
    {
        // for accuracy, reset scores.
        target_score_init( client );

        this.forceRespawn = 0;
        this.client.respawn( false );
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
            this.respawn();
        this.setQuickMenu();
        this.updateHelpMessage();
    }

    void togglePracticeMode()
    {
        if ( pending_endmatch )
            this.client.printMessage( "Can't join practicemode in overtime.\n" );
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
        this.updateHelpMessage();
        return true;
    }

    bool recallInterval( String value )
    {
        Entity@ ent = this.client.getEnt();
        if ( value == "auto" )
        {
            if ( this.bestRun.finishTime == 0 )
            {
                G_PrintMsg( ent, "You haven't finished yet.\n" );
                return false;
            }
            this.positionInterval = this.bestRun.finishTime / MAX_POSITIONS;
            G_PrintMsg( ent, "Setting the interval to " + this.positionInterval + "\n" );
        }
        else
        {
            int number = -1;
            if ( value != "" )
                number = value.toInt();
            if ( number < 0 )
                G_PrintMsg( ent, this.positionInterval + "\n" );
            else
                this.positionInterval = number;
        }
        return true;
    }

    bool recallDelay( String value )
    {
        Entity@ ent = this.client.getEnt();
        int number = -1;
        if ( value != "" )
            number = value.toInt();
        if ( number < 0 )
            G_PrintMsg( ent, this.recallHold + "\n" );
        else
        {
            if ( number < 2 )
                number = 2;
            this.recallHold = number;
        }
        return true;
    }

    Player@ oneMatchingPlayer( String pattern )
    {
        Player@[] matches = RACE_MatchPlayers( pattern );
        Entity@ ent = this.client.getEnt();

        if ( matches.length() == 0 )
        {
            G_PrintMsg( ent, "No players matched.\n" );
            return null;
        }
        else if ( matches.length() > 1 )
        {
            G_PrintMsg( ent, "Multiple players matched:\n" );
            for ( uint i = 0; i < matches.length(); i++ )
                G_PrintMsg( ent, matches[i].client.name + S_COLOR_WHITE + "\n" );
            return null;
        }
        else
            return matches[0];
    }

    bool recallCurrent( String pattern )
    {
        if ( this.inRace )
        {
            G_PrintMsg( this.client.getEnt(), "Not possible during a race.\n" );
            return false;
        }

        Player@ target = this;

        Player@ match = this.oneMatchingPlayer( pattern );
        if ( @match == null )
        {
            G_PrintMsg( this.client.getEnt(), "Failed to identify a single player.\n" );
            return false;
        }
        @target = match;

        if ( target.run.positionCount == 0 )
        {
            G_PrintMsg( this.client.getEnt(), "No run recorded.\n" );
            return false;
        }

        this.run.copyPositions( target.run );
        this.positionCycle = 0;

        if ( this.practicing && this.client.team != TEAM_SPECTATOR )
            return this.recallPosition( 0 );
        else
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
            Player@ match = this.oneMatchingPlayer( pattern );
            if ( @match == null )
                return false;
            @target = match;
        }

        if ( target.bestRun.positionCount == 0 )
        {
            G_PrintMsg( this.client.getEnt(), "No best run recorded.\n" );
            return false;
        }

        this.run.copyPositions( target.bestRun );
        this.positionCycle = 0;

        if ( this.practicing && this.client.team != TEAM_SPECTATOR )
            return this.recallPosition( 0 );
        else
            return true;
    }

    bool recallFake( uint time )
    {
        if ( !this.practicing )
        {
            G_PrintMsg( this.client.getEnt(), "Only available in practicemode.\n" );
            return false;
        }

        Position@ position = this.savedPosition();

        if ( !position.saved )
        {
            G_PrintMsg( this.client.getEnt(), "No position saved.\n" );
            return false;
        }
        position.recalled = true;
        position.currentTime = time;

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

    bool recallExtend( String option )
    {
        if ( option == "on" )
            this.autoRecall = true;
        else if ( option == "off" )
            this.autoRecall = false;
        else
            this.autoRecall = !this.autoRecall;
        Entity@ ent = this.client.getEnt();
        if ( this.autoRecall )
            G_PrintMsg( ent, "Auto recall extend ON.\n" );
        else
            G_PrintMsg( ent, "Auto recall extend OFF.\n" );
        return true;
    }

    bool recallCheckpoint( int cp )
    {
        int index = -1;
        for ( int i = 0; i < this.run.positionCount; i++ )
        {
            if ( this.run.positions[i].currentSector == cp )
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
        for ( int i = 0; i < this.run.positionCount; i++ )
        {
            if ( this.run.positions[i].weapons[weapon] )
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

    bool findPosition( String entity, String parameter )
    {
        Entity@ ent = this.client.getEnt();

        if ( entity == "" )
        {
            this.showMapStats();
            G_PrintMsg( ent, "Usage: /position find <start|finish|rl|gl|pg|push|door|button|tele|slick> [info]\n" );
            return false;
        }

        if ( parameter == "info" )
        {
            EntityList@ list = entityFinder.allEntities( entity );
            if ( list.isEmpty() )
            {
                G_PrintMsg( ent, "No matching entity found.\n" );
                return false;
            }
            uint len = list.length();
            bool small = len < BIG_LIST;
            bool single = len == 1;
            if ( !small )
                G_PrintMsg( ent, "Omitting target info as this is a big list\n" );
            while ( !list.isEmpty() )
            {
                Entity@ current = list.getEnt( 0 );
                G_PrintMsg( ent, "entity " + current.entNum + ": " + current.classname + " @ " + ent.origin.x + " " + ent.origin.y + " " + ent.origin.z + "\n" );
                if ( small )
                {
                    if ( single )
                    {
                        Vec3 mins, maxs;
                        current.getSize( mins, maxs );
                        G_PrintMsg( ent, "    mins: " + mins.x + " " + mins.y + " " + mins.z + "\n" );
                        G_PrintMsg( ent, "    maxs: " + maxs.x + " " + maxs.y + " " + maxs.z + "\n" );
                        G_PrintMsg( ent, "    type: " + current.type + "\n" );
                        G_PrintMsg( ent, "    solid: " + current.solid + "\n" );
                        G_PrintMsg( ent, "    svflags: " + current.svflags + "\n" );
                        G_PrintMsg( ent, "    clipMask: " + current.clipMask + "\n" );
                        G_PrintMsg( ent, "    spawnFlags: " + current.spawnFlags + "\n" );
                        G_PrintMsg( ent, "    frame: " + current.frame + "\n" );
                        G_PrintMsg( ent, "    count: " + current.count + "\n" );
                        G_PrintMsg( ent, "    wait: " + current.wait + "\n" );
                        G_PrintMsg( ent, "    delay: " + current.delay + "\n" );
                        G_PrintMsg( ent, "    health: " + current.health + "\n" );
                        G_PrintMsg( ent, "    maxHealth: " + current.maxHealth + "\n" );
                    }
                    array<Entity@>@ targeting = current.findTargeting();
                    for ( uint i = 0; i < targeting.length; i++ )
                        G_PrintMsg( ent, "    targetted by " + targeting[i].entNum + ": " + targeting[i].classname + "\n" );
                    array<Entity@>@ targets = current.findTargets();
                    for ( uint i = 0; i < targets.length; i++ )
                        G_PrintMsg( ent, "    target " + targets[i].entNum + ": " + targets[i].classname + "\n" );
                }
                @list = list.drop( 1 );
            }
        }
        else
        {
            if ( !this.practicing && this.client.team != TEAM_SPECTATOR )
            {
                G_PrintMsg( ent, "Position loading is not available during a race.\n" );
                return false;
            }

            if ( entity == this.lastFind )
                this.findIndex++;
            else
                this.findIndex = 0;
            Vec3 origin = entityFinder.find( entity, this.findIndex );
            if ( origin == NO_POSITION )
            {
                G_PrintMsg( ent, "No matching entity found.\n" );
                return false;
            }
            this.lastFind = entity;

            ent.origin = origin;
        }

        return true;
    }

    bool joinPosition( String pattern )
    {
        Entity@ ent = this.client.getEnt();

        if ( !this.practicing && this.client.team != TEAM_SPECTATOR )
        {
            G_PrintMsg( ent, "Position loading is not available during a race.\n" );
            return false;
        }

        Player@ match = this.oneMatchingPlayer( pattern );
        if ( @match == null )
            return false;

        this.applyPosition( match.currentPosition() );
        ent.set_velocity( Vec3() );

        return true;
    }

    bool positionSpeed( String speedStr, String name )
    {
        Position@ position = this.practicePositionStore.get( name );
        if ( @position == null )
        {
            G_PrintMsg( this.client.getEnt(), "No such position set.\n" );
            return false;
        }
        if ( !position.saved )
        {
            position.copy( this.currentPosition() );
            position.saved = true;
        }
        float speed = 0;
        bool doAdd = speedStr.locate( "+", 0 ) == 0;
        bool doSubtract = speedStr.locate( "-", 0 ) == 0;
        if ( position.saved && ( doAdd || doSubtract ) )
        {
            speed = HorizontalSpeed( position.velocity );
            float diff = speedStr.substr( 1 ).toFloat();
            if ( doAdd )
                speed += diff;
            else
                speed -= diff;
        }
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

    bool showCPs( String targetPattern, String refPattern, bool full )
    {
        RecordTime[]@ records;
        if ( full )
        {
            topRequestRecords = levelRecords;
            @records = topRequestRecords;

            for ( int i = 0; i < MAX_RECORDS && otherVersionRecords[i].saved; i++ )
                RACE_AddTopScore( records, otherVersionRecords[i] );
        }
        else
            @records = levelRecords;

        Entity@ ent = this.client.getEnt();
        int ref = -1;
        if ( refPattern == "" )
        {
            if ( this.bestRun.finishTime == 0 )
            {
                G_PrintMsg( ent, "You haven't finished yet.\n" );
                return false;
            }
        }
        else
        {
            refPattern = refPattern.removeColorTokens().tolower();
            for ( int j = 0; j < DISPLAY_RECORDS && records[j].saved && ref < 0; j++ )
            {
                if( PatternMatch( records[j].playerName.removeColorTokens().tolower(), refPattern ) )
                    ref = j;
            }
            if ( ref < 0 )
            {
                G_PrintMsg( ent, "Reference player not found in top list.\n" );
                return false;
            }
            G_PrintMsg( ent, S_COLOR_ORANGE + "Comparing relative to " + S_COLOR_WHITE + records[ref].playerName + S_COLOR_ORANGE + " (#" + ( ref + 1 ) + ")\n" );

            records[ref].deduceCPOrder();
        }

        targetPattern = targetPattern.removeColorTokens().tolower();

        int worst = -1;
        uint worstDiff = 0;
        uint potential = 0;

        Table table( S_COLOR_ORANGE + "l " + S_COLOR_WHITE + "r" + S_COLOR_ORANGE + " / l rr " + S_COLOR_ORANGE + "l " + S_COLOR_WHITE + "l" );
        int i;
        for ( i = 0; i < numCheckpoints && ( ( ref < 0 && this.bestRun.cpOrder[i] >= 0 ) || ( ref >= 0 && records[ref].cpOrder[i] >= 0 ) ); i++ )
        {
            uint time;
            int id;
            int previousId;
            if ( ref < 0 )
            {
                id = this.bestRun.cpOrder[i];
                time = this.bestRun.cpTimes[id];
                if ( i > 0 )
                {
                    previousId = this.bestRun.cpOrder[i - 1];
                    time -= this.bestRun.cpTimes[previousId];
                }
            }
            else
            {
                id = records[ref].cpOrder[i];
                time = records[ref].cpTimes[id];
                if ( i > 0 )
                {
                    previousId = records[ref].cpOrder[i - 1];
                    time -= records[ref].cpTimes[previousId];
                }
            }

            bool bestSet = false;
            uint best = 0;
            String bestName;
            bool missing = false;
            for ( int j = 0; j < DISPLAY_RECORDS && records[j].saved; j++ )
            {
                if( targetPattern == "" || PatternMatch( records[j].playerName.removeColorTokens().tolower(), targetPattern ) )
                {
                    uint other = records[j].cpTimes[id];
                    if ( !missing && other == 0 )
                    {
                        G_PrintMsg( ent, S_COLOR_ORANGE + "CP" + ( i + 1 ) + " is missing for " + S_COLOR_WHITE + records[j].playerName + "\n" );
                        missing = true;
                    }
                    if ( other != 0 )
                    {
                        uint previous = 0;
                        if ( i > 0 )
                        {
                            previous = records[j].cpTimes[previousId];
                            other -= previous;
                        }
                        if ( ( i == 0 || previous != 0 ) && ( !bestSet || other < best ) )
                        {
                            bestSet = true;
                            best = other;
                            bestName = records[j].playerName;
                        }
                    }
                }
            }

            if ( bestSet )
            {
                uint diff = time - best;
                if ( best < time )
                {
                    if ( worst < 0 || diff > worstDiff )
                    {
                        worst = i;
                        worstDiff = diff;
                    }
                    potential += diff;
                }
                this.reportDiff( table, "CP" + ( i + 1 ), time, best, bestName, targetPattern == "" );
            }
        }

        uint time;
        int previousId;
        uint finishTime;
        if ( ref < 0 )
        {
            finishTime = this.bestRun.finishTime;
            time = finishTime;
            if ( i > 0 )
            {
                previousId = this.bestRun.cpOrder[i - 1];
                time -= this.bestRun.cpTimes[previousId];
            }
        }
        else
        {
            finishTime = records[ref].finishTime;
            time = finishTime;
            if ( i > 0 )
            {
                previousId = records[ref].cpOrder[i - 1];
                time -= records[ref].cpTimes[previousId];
            }
        }
        bool bestSet = false;
        uint best = 0;
        String bestName;
        for ( int j = 0; j < DISPLAY_RECORDS && records[j].saved; j++ )
        {
            if( targetPattern == "" || PatternMatch( records[j].playerName.removeColorTokens().tolower(), targetPattern ) )
            {
                uint other = records[j].finishTime;
                uint previous = 0;
                if ( i > 0 )
                {
                    previous = records[j].cpTimes[previousId];
                    other -= previous;
                }
                if ( i == 0 || previous != 0 )
                {
                    if ( !bestSet || other < best )
                    {
                        bestSet = true;
                        best = other;
                        bestName = records[j].playerName;
                    }
                }
            }
        }

        if ( bestSet )
        {
            uint diff = time - best;
            if ( best < time )
            {
                if ( best < time && ( worst < 0 || diff > worstDiff ) )
                {
                    worst = i;
                    worstDiff = diff;
                }
                potential += diff;
            }
            this.reportDiff( table, "End", time, best, bestName, targetPattern == "" );
        }

        uint rows = table.numRows();
        for ( uint j = 0; j < rows; j++ )
            G_PrintMsg( ent, table.getRow( j ) + "\n" );
        if ( worst >= 0 )
        {
            String improve = S_COLOR_ORANGE + "Potential " + RACE_TimeToString( finishTime - potential ) + ", worst loss between ";
            if ( worst == 0 )
                improve += "START";
            else
                improve += "CP" + worst;
            improve += " and ";
            if ( worst == i )
                improve += "END";
            else
                improve += "CP" + ( worst + 1 );
            G_PrintMsg( ent, improve + "\n" );
        }

        return true;
    }

    void reportDiff( Table@ table, String name, uint time, uint best, String bestName, bool global )
    {
        table.addCell( name + ":" );
        table.addCell( RACE_TimeToString( time ) );
        if ( global )
            table.addCell( "Server:" );
        else
            table.addCell( "Reference:" );
        table.addCell( RACE_TimeDiffString( time, best, false ) );
        int percent = 0;
        if ( best != 0 && time != 0 )
        {
            if ( best > time )
                percent = ( int( best - time ) * 100 ) / time;
            else
                percent = ( int( time - best ) * 100 ) / best;
            table.addCell( " (" + percent + "%)" );
        }
        else
            table.addCell( "" );
        table.addCell( "from" );
        table.addCell( bestName );
    }

    bool setMarker( String copy )
    {
        Entity@ ent = this.client.getEnt();
        Entity@ ref = ent;

        if ( copy != "" )
        {
            Player@ match = this.oneMatchingPlayer( copy );
            if ( @match == null )
            {
                this.marker.unlinkEntity();
                this.marker.freeEntity();
                @this.marker = null;
                return false;
            }
            @ref = match.marker;
            if ( @ref == null )
            {
                this.client.printMessage( "Player does not have a marker set.\n" );
                return false;
            }
        }

        Entity@ dummy = G_SpawnEntity( "dummy" );
        dummy.modelindex = G_ModelIndex( "models/players/bigvic/tris.iqm" );
        dummy.svflags |= SVF_ONLYOWNER;
        dummy.svflags &= ~SVF_NOCLIENT;
        dummy.ownerNum = ent.entNum;
        dummy.origin = ref.origin;
        dummy.angles = Vec3( 0, ref.angles.y, 0 );

        if ( @this.marker != null )
        {
            this.marker.unlinkEntity();
            this.marker.freeEntity();
        }

        dummy.linkEntity();

        @this.marker = dummy;

        return true;
    }

    void loadStoredTime()
    {
        String login = client.getMMLogin();
        if ( login == "" )
            return;

        // find out if he holds a record better than his current time
        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            if ( !levelRecords[i].saved )
                break;
            if ( levelRecords[i].login == login
                    && ( !this.hasTime || levelRecords[i].finishTime < this.bestRun.finishTime ) )
            {
                this.bestRun.finishTime = levelRecords[i].finishTime;
                this.bestRun.maxSpeed = 0;
                for ( int j = 0; j < numCheckpoints; j++ )
                    this.bestRun.cpTimes[j] = levelRecords[i].cpTimes[j];
                this.updatePos();
                break;
            }
        }
    }

    void showMapStats()
    {
        String msg = "";
        uint numRLs = entityFinder.rls.length();
        uint numGLs = entityFinder.gls.length();
        uint numPGs = entityFinder.pgs.length();
        if ( numRLs + numGLs + numPGs == 0 )
            msg = "strafe";
        else
        {
            if ( numRLs > 0 )
            {
                msg += "rl(" + numRLs + ")";
                if ( numGLs + numPGs > 0 )
                    msg += ", ";
            }
            if ( numGLs > 0 )
            {
                msg += "gl(" + numGLs + ")";
                if ( numPGs > 0 )
                    msg += ", ";
            }
            if ( numPGs > 0 )
                msg += "pg(" + numPGs + ")";
        }
        if ( entityFinder.slicks.length() > 0 )
            msg += ", slick";
        if ( numCheckpoints > 0 )
            msg += ", cps(" + numCheckpoints + ")";
        uint numPushes = entityFinder.pushes.length();
        uint numDoors = entityFinder.doors.length();
        uint numButtons = entityFinder.buttons.length();
        uint numTeles = entityFinder.teles.length();
        if ( numPushes > 0 )
            msg += ", push(" + numPushes + ")";
        if ( numDoors > 0 )
            msg += ", doors(" + numDoors + ")";
        if ( numButtons > 0 )
            msg += ", buttons(" + numButtons + ")";
        if ( numTeles > 0 )
            msg += ", teles(" + numTeles + ")";
        if ( entityFinder.starts.length() == 0 )
            msg += ", " + S_COLOR_RED + "no start" + S_COLOR_WHITE;
        if ( entityFinder.finishes.length() == 0 )
            msg += ", " + S_COLOR_RED + "no finish" + S_COLOR_WHITE;
        G_PrintMsg( this.client.getEnt(), S_COLOR_GREEN + "Map stats: " + S_COLOR_WHITE + msg + "\n" );
    }

    String randomMap( String pattern, bool pre )
    {
        pattern = pattern.removeColorTokens().tolower();
        if ( pattern == "*" )
            pattern = "";

        if ( !pre && this.randmap != "" && this.randmapPattern == pattern )
            return this.randmap;

        Cvar mapname( "mapname", "", 0 );
        String current = mapname.string;

        String[] maps = GetMapsByPattern( pattern, current );

        if ( maps.length() == 0 )
        {
            this.client.printMessage( "No matching maps\n" );
            return "";
        }

        uint matches = maps.length();
        String result = maps[randrange(matches)];
        if ( pre )
        {
            this.randmap = result;
            this.randmapPattern = pattern;
        }
        else
        {
            this.randmap = "";
        }
        this.randmapMatches = matches;
        return result;
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
