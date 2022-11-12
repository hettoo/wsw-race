class Run
{
    uint[] cpTimes;
    int[] cpOrder;
    uint finishTime;
    int maxSpeed;

    Position[] positions;
    int positionCount;

    Run() {
        this.positions.resize( MAX_POSITIONS );
        this.resizeCPs( 0 );
        this.clear();
    }

    ~Run() {
    }

    void clear()
    {
        this.clearPositions();
        this.clearTimes();
    }

    void clearTimes()
    {
        this.finishTime = 0;
        this.maxSpeed = 0;
        this.clearCPs();
    }

    void clearPositions()
    {
        this.positionCount = 0;
    }

    void clearCPs()
    {
        for ( uint i = 0; i < this.cpTimes.length; i++ )
        {
            this.cpTimes[i] = 0;
            this.cpOrder[i] = -1;
        }
    }

    void resizeCPs( uint size )
    {
        if ( this.cpTimes.length != size )
        {
            this.cpTimes.resize( size );
            this.cpOrder.resize( size );
        }

        this.clearCPs();
    }

    void copy( Run@ other )
    {
        for ( uint i = 0; i < this.cpTimes.length; i++ )
        {
            this.cpTimes[i] = other.cpTimes[i];
            this.cpOrder[i] = other.cpOrder[i];
        }

        this.finishTime = other.finishTime;
        this.maxSpeed = other.maxSpeed;

        this.copyPositions( other );
    }

    void copyPositions( Run@ other )
    {
        this.positionCount = other.positionCount;
        for ( int i = 0; i < this.positionCount; i++ )
            this.positions[i] = other.positions[i];
    }

    void savePosition( Position@ position )
    {
        this.positions[this.positionCount++] = position;
    }

    void setCP( int id, uint time )
    {
        this.cpTimes[id] = time;
    }

    void setCP( int id, uint time, int order )
    {
        this.setCP( id, time );
        this.cpOrder[order] = id;
    }

    bool hasCP( int id )
    {
        if ( this.cpTimes[id] != 0 )
            return true;
        for ( uint i = 0; i < this.cpOrder.length; i++ )
        {
            if ( this.cpOrder[i] == id )
                return true;
            else if ( this.cpOrder[i] == -1 )
                break;
        }
        return false;
    }

    uint getCP( int id )
    {
        return this.cpTimes[id];
    }

    void observeSpeed( int speed )
    {
        if ( speed > this.maxSpeed )
            this.maxSpeed = speed;
    }

    void finish( uint time )
    {
        this.finishTime = time;
    }
}
