const int MAX_START_HEIGHT_CHECK = 2048;

void target_checkpoint_use( Entity@ self, Entity@ other, Entity@ activator )
{
    if ( @activator.client == null )
        return;

    Player@ player = RACE_GetPlayer( activator.client );

    if ( player.touchCheckPoint( self.count ) )
        self.useTargets( activator );
}

void target_checkpoint( Entity@ self )
{
    self.count = numCheckpoints;
    @self.use = target_checkpoint_use;
    numCheckpoints++;
    entityFinder.add( "cp", self, self.origin );
}

void target_stoptimer_use( Entity@ self, Entity@ other, Entity@ activator )
{
    if ( @activator.client == null )
        return;

    Player@ player = RACE_GetPlayer( activator.client );

    if ( !player.inRace && !player.practicing )
        return;

    player.completeRace();

    self.useTargets( activator );
}

// This sucks: some defrag maps have the entity classname with pseudo camel notation
// and classname->function is case sensitive

void target_stoptimer( Entity@ self )
{
    @self.use = target_stoptimer_use;
}

void target_stopTimer( Entity@ self )
{
    target_stoptimer( self );
}

void target_starttimer_use( Entity@ self, Entity@ other, Entity@ activator )
{
    if ( @activator.client == null )
        return;

    Player@ player = RACE_GetPlayer( activator.client );

    if ( player.inRace )
        return;

    if ( player.startRace() )
    {
        self.useTargets( activator );

        if ( @activator.client == null )
          return;

        int speed = int( HorizontalSpeed( activator.velocity ) );
        activator.client.setHUDStat( STAT_PROGRESS_OTHER, speed );
        String msg = S_COLOR_ORANGE + "Starting speed: " + S_COLOR_WHITE + speed;

        Vec3 mins, maxs;
        activator.getSize( mins, maxs );
        Vec3 down = activator.origin;
        down.z -= MAX_START_HEIGHT_CHECK;
        Trace tr;
        if ( tr.doTrace( activator.origin, mins, maxs, down, activator.entNum, MASK_DEADSOLID ) )
            msg += S_COLOR_ORANGE + ", height: " + S_COLOR_WHITE + int( tr.fraction * MAX_START_HEIGHT_CHECK );
        activator.client.printMessage( msg + "\n" );
    }
}

// doesn't need to do anything at all, just sit there, waiting
void target_starttimer( Entity@ ent )
{
    @ent.use = target_starttimer_use;
    ent.wait = 0;
}

void target_startTimer( Entity@ ent )
{
    target_starttimer( ent );
}
