class EntityFinder
{
    PositionList@ starts;
    PositionList@ finishes;
    PositionList@ rls;
    PositionList@ gls;
    PositionList@ pgs;
    PositionList@ pushes;
    PositionList@ doors;
    PositionList@ cps;
    PositionList@ teles;
    PositionList@ slicks;

    EntityFinder()
    {
        this.clear();
    }

    void clear()
    {
        @this.starts = Nil();
        @this.finishes = Nil();
        @this.rls = Nil();
        @this.gls = Nil();
        @this.pgs = Nil();
        @this.pushes = Nil();
        @this.doors = Nil();
        @this.cps = Nil();
        @this.teles = Nil();
        @this.slicks = Nil();
    }

    bool add( String type, Vec3 position )
    {
        if ( type == "start" )
            @this.starts = Cons( position, this.starts );
        else if ( type == "finish" )
            @this.finishes = Cons( position, this.finishes );
        else if ( type == "rl" )
            @this.rls = Cons( position, this.rls );
        else if ( type == "gl" )
            @this.gls = Cons( position, this.gls );
        else if ( type == "pg" )
            @this.pgs = Cons( position, this.pgs );
        else if ( type == "push" )
            @this.pushes = Cons( position, this.pushes );
        else if ( type == "door" )
            @this.doors = Cons( position, this.doors );
        else if ( type == "cp" )
            @this.cps = Cons( position, this.cps );
        else if ( type == "tele" )
            @this.teles = Cons( position, this.teles );
        else if ( type == "slick" )
            @this.slicks = Cons( position, this.slicks );
        else
            return false;
        return true;
    }

    Vec3 find( String type, uint index )
    {
        PositionList@ target;
        if ( type == "start" )
            @target = this.starts;
        else if ( type == "finish" )
            @target = this.finishes;
        else if ( type == "rl" )
            @target = this.rls;
        else if ( type == "gl" )
            @target = this.gls;
        else if ( type == "pg" )
            @target = this.pgs;
        else if ( type == "push" )
            @target = this.pushes;
        else if ( type == "door" )
            @target = this.doors;
        else if ( type == "cp" )
            @target = this.cps;
        else if ( type == "tele" )
            @target = this.teles;
        else if ( type == "slick" )
            @target = this.slicks;
        else
            return Vec3();

        return target.get( index );
    }

    ~EntityFinder() {}
}

interface PositionList
{
    uint length();
    PositionList@ drop( uint n );
    Vec3 get( uint index );
}

class Nil : PositionList
{
    Nil()
    {
    }

    uint length()
    {
        return 0;
    }

    PositionList@ drop( uint n )
    {
        return this;
    }

    Vec3 get( uint index )
    {
        return Vec3();
    }

    ~Nil() {}
}

class Cons : PositionList
{
    Vec3 head;
    PositionList@ tail;

    Cons( Vec3 head, PositionList@ tail )
    {
        this.head = head;
        @this.tail = tail;
    }

    uint length()
    {
        return 1 + this.tail.length();
    }

    PositionList@ drop( uint n )
    {
        if ( n == 0 )
            return this;
        return this.tail.drop( n - 1 );
    }

    Vec3 get( uint index )
    {
        if ( index == 0 )
            return this.head;
        return this.drop( index % this.length() ).get( 0 );
    }

    ~Cons() {}
}
