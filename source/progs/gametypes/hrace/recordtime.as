const int MAX_RECORDS = 50;
const int DISPLAY_RECORDS = 20;
const int HUD_RECORDS = 3;

RecordTime[] levelRecords( MAX_RECORDS );
RecordTime[] topRequestRecords( MAX_RECORDS );

RecordTime[] otherVersionRecords( MAX_RECORDS );

class RecordTime
{
    bool saved;
    uint[] cpTimes;
    int[] cpOrder;
    uint finishTime;
    String playerName;
    String login;
    String version;
    bool arraysSetUp;

    void setupArrays( int size )
    {
        this.cpTimes.resize( size );
        this.cpOrder.resize( size );

        for ( int i = 0; i < size; i++ )
            this.cpTimes[i] = 0;

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
        this.version = "";
        this.finishTime = 0;

        for ( uint i = 0; i < cpTimes.length(); i++ )
            this.cpTimes[i] = 0;
    }

    void deduceCPOrder()
    {
        uint num = 0;
        uint minTime = 0;
        for ( uint i = 0; i < this.cpOrder.length(); i++ )
        {
            int id = -1;
            uint maxTime = 0;
            for ( uint j = 0; j < this.cpTimes.length(); j++ )
            {
                if ( this.cpTimes[j] == 0 )
                    continue;
                uint cpTime = this.cpTimes[j];
                if ( cpTime > minTime && ( id < 0 || cpTime < maxTime ) )
                {
                    maxTime = cpTime;
                    id = j;
                }
            }
            if ( id < 0 )
            {
                for ( uint j = i; j < this.cpOrder.length(); j++ )
                    this.cpOrder[j] = -1;
                break;
            }
            minTime = this.cpTimes[id];
            this.cpOrder[i] = id;
        }
    }

    void Copy( RecordTime &other )
    {
        if ( !this.arraysSetUp )
            return;

        this.saved = other.saved;
        this.finishTime = other.finishTime;
        this.playerName = other.playerName;
        this.login = other.login;
        this.version = other.version;
        for ( uint i = 0; i < cpTimes.length(); i++ )
            this.cpTimes[i] = other.cpTimes[i];
    }

    void Store( Client@ client )
    {
        if ( !this.arraysSetUp )
            return;

        Player@ player = RACE_GetPlayer( client );

        this.saved = true;
        this.finishTime = player.run.finishTime;
        this.playerName = client.name;
        this.login = client.getMMLogin();
        this.version = "";
        for ( uint i = 0; i < cpTimes.length(); i++ )
            this.cpTimes[i] = player.run.cpTimes[i];
    }
}

void RACE_AddTopScore( RecordTime[]@ records, RecordTime@ additional )
{
    int i;
    for ( i = 0; i < MAX_RECORDS; i++ )
    {
        if ( !records[i].saved || additional.finishTime < records[i].finishTime )
            break;
    }
    if ( i == MAX_RECORDS )
        return;

    String cleanName = additional.playerName.removeColorTokens().tolower();
    for ( int j = 0; j < i; j++ )
    {
        if ( ( additional.login != "" && records[j].login == additional.login )
                || ( additional.login == "" && records[j].playerName.removeColorTokens().tolower() == cleanName ) )
            return;
    }

    for ( int j = MAX_RECORDS - 1; j > i; j-- )
        records[j] = records[j - 1];
    records[i] = additional;
}

void RACE_LoadTopScores( RecordTime[]@ records, String mapName, int checkpoints, String version )
{
    String topScores;
    bool reset = version == "";

    if ( reset )
    {
        for ( int i = 0; i < MAX_RECORDS; i++ )
        {
            records[i].setupArrays( checkpoints );
            records[i].saved = false;
        }
        topScores = G_LoadFile( "topscores/race/" + mapName + ".txt" );
    }
    else
    {
        topScores = G_LoadFile( "topscores/race-" + version + "/" + mapName + ".txt" );
    }

    if ( topScores.length() > 0 )
    {
        RecordTime current;
        String timeToken, loginToken, nameToken, cpToken;
        int count = 0;
        uint sep;

        current.setupArrays( checkpoints );

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

            cpToken = topScores.getToken( count++ );
            if ( cpToken.length() == 0 )
                break;

            int numCPs = cpToken.toInt();

            // store this one
            for ( int j = 0; j < numCPs; j++ )
            {
                cpToken = topScores.getToken( count++ );
                if ( cpToken.length() == 0 )
                    break;

                if ( j < checkpoints )
                    current.cpTimes[j] = uint( cpToken.toInt() );
            }

            current.saved = true;
            current.version = version;
            current.finishTime = uint( timeToken.toInt() );
            current.playerName = nameToken;
            current.login = loginToken;

            if ( reset )
            {
                // check if he already has a score
                String cleanName = nameToken.removeColorTokens().tolower();
                bool exists = false;
                for ( int j = 0; j < i; j++ )
                {
                    if ( ( loginToken != "" && records[j].login == loginToken )
                            || ( loginToken == "" && records[j].playerName.removeColorTokens().tolower() == cleanName ) )
                    {
                        exists = true;
                        break;
                    }
                }
                if ( exists )
                {
                    current.clear();
                    continue;
                }

                records[i] = current;
            }
            else
            {
                RACE_AddTopScore( records, current );
            }

            current.clear();

            i++;
        }
    }
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

            // add the CPs
            topScores += "\"" + numCheckpoints+ "\" ";

            for ( int j = 0; j < numCheckpoints; j++ )
                topScores += "\"" + int( levelRecords[i].cpTimes[j] ) + "\" ";

            topScores += "\n";
        }
    }

    G_WriteFile( "topscores/race/" + mapName + ".txt", topScores );
}
