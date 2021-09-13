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
