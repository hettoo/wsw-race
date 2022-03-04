const Vec3 NO_POSITION( -99.99, -1337.99, -99.42 );

class EntityFinder
{
    EntityList@ starts;
    EntityList@ finishes;
    EntityList@ rls;
    EntityList@ gls;
    EntityList@ pgs;
    EntityList@ pushes;
    EntityList@ doors;
    EntityList@ buttons;
    EntityList@ cps;
    EntityList@ teles;
    EntityList@ slicks;

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
        @this.buttons = Nil();
        @this.cps = Nil();
        @this.teles = Nil();
        @this.slicks = Nil();
    }

    bool add( String type, Entity@ ent, Vec3 position )
    {
        if ( type == "start" )
            @this.starts = Cons( ent, position, this.starts );
        else if ( type == "finish" )
            @this.finishes = Cons( ent, position, this.finishes );
        else if ( type == "rl" )
            @this.rls = Cons( ent, position, this.rls );
        else if ( type == "gl" )
            @this.gls = Cons( ent, position, this.gls );
        else if ( type == "pg" )
            @this.pgs = Cons( ent, position, this.pgs );
        else if ( type == "push" )
            @this.pushes = Cons( ent, position, this.pushes );
        else if ( type == "door" )
            @this.doors = Cons( ent, position, this.doors );
        else if ( type == "button" )
            @this.buttons = Cons( ent, position, this.buttons );
        else if ( type == "cp" )
            @this.cps = Cons( ent, position, this.cps );
        else if ( type == "tele" )
            @this.teles = Cons( ent, position, this.teles );
        else if ( type == "slick" )
            @this.slicks = Cons( ent, position, this.slicks );
        else
            return false;
        return true;
    }

    bool addTriggering( String type, Entity@ ent, bool addUntargeted, bool resetWait, array<Entity@>@ ignore )
    {
        if( @ignore == null )
            @ignore = array<Entity@>();

        for( uint i = 0; i < ignore.length; i++ )
        {
            if( ignore[i].entNum == ent.entNum )
                return false;
        }

        bool result = false;
        array<Entity@>@ targeting = ent.findTargeting();
        if( ent.classname == "trigger_multiple" || ent.classname == "info_player_deathmatch" || ent.classname == "func_door" || ent.classname == "func_door_rotating" || ( addUntargeted && targeting.length == 0 ) )
        {
            if( resetWait )
                ent.wait = 0;
            this.add( type, ent, Centre( ent ) );
            result = true;
        }

        ignore.push_back( ent );
        for( uint i = 0; i < targeting.length; i++ )
            result = result || this.addTriggering( type, targeting[i], false, resetWait, ignore );
        ignore.pop_back();

        return result;
    }

    EntityList@ allEntities( String type )
    {
        if ( type == "start" )
            return this.starts;
        else if ( type == "finish" )
            return this.finishes;
        else if ( type == "rl" )
            return this.rls;
        else if ( type == "gl" )
            return this.gls;
        else if ( type == "pg" )
            return this.pgs;
        else if ( type == "push" )
            return this.pushes;
        else if ( type == "door" )
            return this.doors;
        else if ( type == "button" )
            return this.buttons;
        else if ( type == "cp" )
            return this.cps;
        else if ( type == "tele" )
            return this.teles;
        else if ( type == "slick" )
            return this.slicks;
        else if ( type == "" )
            return Nil();
        else
        {
            Entity@ ent = G_GetEntity( type.toInt() );
            if ( @ent == null )
                return Nil();
            return Cons( ent, Centre( ent ), Nil() );
        }
    }

    Vec3 find( String type, uint index )
    {
        return this.allEntities( type ).getPosition( index );
    }

    ~EntityFinder() {}
}

interface EntityList
{
    bool isEmpty();
    uint length();
    EntityList@ drop( uint n );
    Entity@ getEnt( uint index );
    Vec3 getPosition( uint index );
}

class Nil : EntityList
{
    Nil()
    {
    }

    bool isEmpty()
    {
        return true;
    }

    uint length()
    {
        return 0;
    }

    EntityList@ drop( uint n )
    {
        return this;
    }

    Entity@ getEnt( uint index )
    {
        return null;
    }

    Vec3 getPosition( uint index )
    {
        return NO_POSITION;
    }

    ~Nil() {}
}

class Cons : EntityList
{
    Entity@ ent;
    Vec3 position;
    EntityList@ tail;

    Cons( Entity@ ent, Vec3 position, EntityList@ tail )
    {
        @this.ent = ent;
        this.position = position;
        @this.tail = tail;
    }

    bool isEmpty()
    {
        return false;
    }

    uint length()
    {
        return 1 + this.tail.length();
    }

    EntityList@ drop( uint n )
    {
        if ( n == 0 )
            return this;
        return this.tail.drop( n - 1 );
    }

    Entity@ getEnt( uint index )
    {
        if ( index == 0 )
            return @this.ent;
        return this.drop( index % this.length() ).getEnt( 0 );
    }

    Vec3 getPosition( uint index )
    {
        if ( index == 0 )
            return this.position;
        return this.drop( index % this.length() ).getPosition( 0 );
    }

    ~Cons() {}
}
