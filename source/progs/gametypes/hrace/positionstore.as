const uint POSITION_STORE_SIZE = 8;

class PositionStore
{
    Position[] positions;
    String[] names;
    uint count;

    PositionStore()
    {
        this.positions.resize( POSITION_STORE_SIZE );
        this.names.resize( POSITION_STORE_SIZE );
        this.names[0] = "";
        this.clear();
    }

    void clear()
    {
        this.positions[0].clear();
        this.count = 1;
    }

    Position@ get( String name )
    {
        for ( uint i = 0; i < this.count; i++ )
        {
            if ( this.names[i] == name )
                return positions[i];
        }
        return null;
    }

    bool set( String name, Position@ position )
    {
        int free = -1;
        for ( uint i = 0; i < this.count; i++ )
        {
            if ( this.names[i] == name )
            {
                this.positions[i] = position;
                return true;
            }
            else if ( i > 0 && !this.positions[i].saved )
                free = i;
        }
        if ( this.count < this.positions.length() )
        {
            this.names[this.count] = name;
            this.positions[this.count++] = position;
            return true;
        }
        if ( free >= 0 )
        {
            this.names[free] = name;
            this.positions[free] = position;
            return true;
        }
        return false;
    }

    void remove( String name )
    {
        for ( uint i = 0; i < this.count; i++ )
        {
            if ( this.names[i] == name )
            {
                this.positions[i].clear();
                return;
            }
        }
    }

    ~PositionStore() {}
}
