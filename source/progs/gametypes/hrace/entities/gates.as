//=================
//Logic gates
//===============
Entity@[] gate_targeters;
bool[] gate_targeters_state;
uint[] gate_targeters_time;
void gate_init( Entity @gate )
{
    for( uint i = 0; i < gate_targeters.size(); i++ )
    {
        gate_targeters_state[i] = false;
        gate_targeters_time[i] = 0;
    }
}
void gate_setup( Entity @gate )
{
    gate.count = gate_targeters.size();
    array<Entity @> @targeters = gate.findTargeting();
    for( uint i = 0; i < targeters.size(); i++ )
    {
        Entity @targeter = targeters[i];
        if ( @targeter != null && targeter.classname != "gate_reset" )
        {
            gate_targeters.push_back( @targeter );
            gate_targeters_state.push_back( false );
            gate_targeters_time.push_back( 0 );
        }
    }
    @gate.think = null;
    gate.nextThink = levelTime + 1;
}
void gate_think( Entity @gate )
{
    if ( gate.delay > 0 )
    {
        for( uint i = gate.count; i < gate_targeters.size() && gate_targeters[i].target == gate.targetname; i++ )
        {
            if ( levelTime > gate_targeters_time[i] )
                gate_targeters_state[i] = false;
        }
    }
    if ( gate.spawnFlags & 1 > 0 && gate.timeStamp != 0 && levelTime >= gate.timeStamp )
        gate_init( gate );
    if ( levelTime >= gate.timeStamp )
        gate.timeStamp = 0;
    gate.nextThink = levelTime + 1;
}
void gate_input( Entity @gate, Entity @ent )
{
    if ( gate.spawnFlags & 1 == 0 && gate.timeStamp != 0 && levelTime < gate.timeStamp )
        return;
    for( uint i = gate.count; i < gate_targeters.size() && gate_targeters[i].target == gate.targetname; i++ )
    {
        if ( gate_targeters[i].entNum == ent.entNum )
        {
            gate_targeters_state[i] = true;
            if ( gate.delay > 0 )
                gate_targeters_time[i] = levelTime + uint( gate.delay * 1000 );
        }
    }
}
void gate_activate( Entity @gate, Entity @other, Entity @activator, bool negated )
{
    if ( ( negated && gate.spawnFlags & 2 == 0 ) || ( !negated && gate.spawnFlags & 2 > 0 ) )
        return;
    if ( gate.spawnFlags & 1 == 0 && gate.timeStamp != 0 && levelTime < gate.timeStamp )
        return;
    String backup = gate.map;
    if ( @other != null && other.map != "" )
        gate.map = other.map;
    array<Entity @> @targets = gate.findTargets();
    for( uint i = 0; i < targets.size(); i++ )
    {
        Entity @target = targets[i];
        if ( @target != null )
        {
            bool use = target.map == "" || target.map == gate.map;
            if ( negated && target.map != "" )
            {
                use = true;
                for( uint j = gate.count; use && j < gate_targeters.size() && gate_targeters[j].target == gate.targetname; j++ )
                {
                    if ( gate_targeters[j].map == target.map && gate_targeters_state[j] )
                        use = false;
                }
            }
            if ( use )
                __G_CallUse( target, gate, activator );
        }
    }
    gate.map = backup;
    gate.timeStamp = levelTime + uint(gate.wait * 1000);
}
bool gate_resetter( Entity @gate, Entity @reset, Entity @activator )
{
    if ( reset.classname != "gate_reset" )
        return false;
    gate_init( gate );
    if ( reset.spawnFlags & 1 > 0 )
    {
        array<Entity @> @targets = gate.findTargets();
        for( uint i = 0; i < targets.size(); i++ )
        {
            Entity @target = targets[i];
            if ( @target != null )
            {
                if ( target.classname == "gate_reset" )
                    target.useTargets( @activator );
                else if ( target.classname == "gate_and" || target.classname == "gate_or" )
                    gate_resetter( target, reset, activator );
            }
        }
    }
    return true;
}
bool gate_and_check( Entity @gate )
{
    bool done = true;
    for( uint i = gate.count; i < gate_targeters.size() && gate_targeters[i].target == gate.targetname; i++ )
    {
        if ( !gate_targeters_state[i] )
            done = false;
    }
    return done;
}
void gate_and_use( Entity @self, Entity @other, Entity @activator )
{
    if ( gate_resetter( self, other, activator ) )
        return;
    gate_input( self, other );
    if ( gate_and_check( self ) )
        gate_activate( self, other, activator, false );
}
void gate_and_think( Entity @self )
{
    gate_think( self );
    if ( !gate_and_check( self ) )
        gate_activate( self, null, null, true );
}
void gate_and_setup( Entity @self )
{
    gate_setup( self );
    @self.think = gate_and_think;
}
void gate_and( Entity @ent )
{
    @ent.use = gate_and_use;
    @ent.think = gate_and_setup;
    ent.nextThink = levelTime + 1;
}
bool gate_or_check( Entity @gate )
{
    bool done = false;
    for( uint i = gate.count; i < gate_targeters.size() && gate_targeters[i].target == gate.targetname; i++ )
    {
        if ( gate_targeters_state[i] )
            done = true;
    }
    return done;
}
void gate_or_use( Entity @self, Entity @other, Entity @activator )
{
    if ( gate_resetter( self, other, activator ) )
        return;
    gate_input( self, other );
    if ( gate_or_check( self ) )
        gate_activate( self, other, activator, false );
}
void gate_or_think( Entity @self )
{
    gate_think( self );
    if ( !gate_or_check( self ) )
        gate_activate( self, null, null, true );
}
void gate_or_setup( Entity @self )
{
    gate_setup( self );
    @self.think = gate_or_think;
}
void gate_or( Entity @ent )
{
    @ent.use = gate_or_use;
    @ent.think = gate_or_setup;
    ent.nextThink = levelTime + 1;
}
void gate_reset_use( Entity @self, Entity @other, Entity @activator )
{
    self.useTargets( @activator );
}
void gate_reset( Entity @ent )
{
    @ent.use = gate_reset_use;
}

