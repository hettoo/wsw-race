/*QUAKED trigger_push_velocity (.5 .5 .5) ? PLAYERDIR_XY ADD_XY PLAYERDIR_Z ADD_Z BIDIRECTIONAL_XY BIDIRECTIONAL_Z CLAMP_NEGATIVE_ADDS
This is used to create jump pads and launch ramps. It MUST point to a target_position or info_notnull entity to work. Unlike target_push,
this is client side predicted.  This is similar to a jumppad, however, it may be configured to add to the player's velocity, as opposed to just setting it.
-------- KEYS --------
target : this points to the target_position to which the player will jump.
notfree : when set to 1, entity will not spawn in "Free for all" and "Tournament" modes.
notteam : when set to 1, entity will not spawn in "Teamplay" and "CTF" modes.
notsingle : when set to 1, entity will not spawn in Single Player mode (bot play mode).
speed: XY speed for player-directional velocity pads - either sets or adds to the player's horizontal velocity.
count: Z speed for player-directional velocity pads - either sets or adds to the player's vectical velocity.
-------- SPAWNFLAGS --------
PLAYERDIR_XY: if set, trigger will apply the horizontal speed in the player's horizontal direction of travel, otherwise it uses the target XY component.
ADD_XY: if set, trigger will add to the player's horizontal velocity, otherwise it set's the player's horizontal velocity.
PLAYERDIR_Z: if set, trigger will apply the vertical speed in the player's vertical direction of travel, otherwise it uses the target Z component.
ADD_Z: if set, trigger will add to the player's vertical velocity, otherwise it set's the player's vectical velocity.
BIDIRECTIONAL_XY: if set, non-playerdir velocity pads will function in 2 directions based on the target specified. The chosen direction is based on the current direction of travel. Applies to horizontal direction.
BIDIRECTIONAL_Z: if set, non-playerdir velocity pads will function in 2 directions based on the target specified. The chosen direction is based on the current direction of travel. Applies to vertical direction.
CLAMP_NEGATIVE_ADDS: if set, then a velocity pad that adds negative velocity will be clamped to 0, if the resultant velocity would bounce the player in the opposite direction.
-------- NOTES --------
To make a jump pad or launch ramp, place the target_position/info_notnull entity at the highest point of the jump and target it with this entity.*/

Dictionary ent_pushvelocity_values;
uint[] ent_pushvelocity_times( maxClients );
Entity@[] ent_pushvelocity_lastent( maxClients );

const uint ENT_PUSHVELOCITY_TIMEOUT = 1000;
const int ENT_PUSHVELOCITY_SOUND = G_SoundIndex("sounds/world/launchpad");

const int PLAYERDIR_XY = 1;
const int ADD_XY = 2;
const int PLAYERDIR_Z = 4;
const int ADD_Z = 8;
const int BIDIRECTIONAL_XY = 16;
const int BIDIRECTIONAL_Z = 32;
const int CLAMP_NEGATIVE_ADDS = 64;

void trigger_push_velocity( Entity @ent )
{
    @ent.think = trigger_push_velocity_think;
    ent.nextThink = levelTime + 1;
    @ent.touch = trigger_push_velocity_touch;

    ent_pushvelocity_values.set( String( ent.entNum ) + "_speed", float(G_SpawnTempValue("speed")) );
    ent_pushvelocity_values.set( String( ent.entNum ) + "_count", float(G_SpawnTempValue("count")) );
    ent.solid = SOLID_TRIGGER;
    ent.moveType = MOVETYPE_NONE;
    ent.setupModel( ent.model );
    ent.svflags &= ~SVF_NOCLIENT;
    ent.svflags |= SVF_TRANSMITORIGIN2;
    ent.wait = 1;

    Cvar cm_mapHeader("cm_mapHeader", "", 0);
    if ( cm_mapHeader.string == "FBSP" && ent.spawnFlags == 0 ) // defaults for compatibility
        ent.spawnFlags = PLAYERDIR_XY | ADD_XY | PLAYERDIR_Z | ADD_Z;

    ent.linkEntity();
}

void trigger_push_velocity_think( Entity @ent )
{
    Entity@[] targets = ent.findTargets();
    if ( targets.length() > 0 )
    {
        Entity@ target = targets[0]; // assume always first target

        Vec3 mins, maxs, velocity, origin;
        Cvar g_gravity("g_gravity", "850", 0);

        ent.getSize(mins, maxs);
        origin = mins + maxs;
        origin *= 0.5;

        float height = target.origin.z - origin.z;
        float time = sqrt( height / (0.5 * g_gravity.value) );

        velocity = target.origin - origin;
        velocity.z = 0;

        float dist = velocity.normalize();
        if ( time != 0 )
            velocity *= dist/time;
        else
            velocity *= 0;

        velocity.z = time * g_gravity.value;
        ent.origin2 = velocity;
    }
}

void trigger_push_velocity_touch( Entity @ent, Entity @other, const Vec3 planeNormal, int surfFlags )
{
    if ( @other.client == null || other.moveType != MOVETYPE_PLAYER ||
        ( @ent_pushvelocity_lastent[other.playerNum] == @ent && ent_pushvelocity_times[other.playerNum] > levelTime) )
        return;

    ent_pushvelocity_times[other.playerNum] = levelTime + ENT_PUSHVELOCITY_TIMEOUT + uint( ent.wait );
    @ent_pushvelocity_lastent[other.playerNum] = @ent;

    bool is_playerdir_xy =        (ent.spawnFlags & PLAYERDIR_XY) != 0;
    bool is_add_xy =              (ent.spawnFlags & ADD_XY) != 0;
    bool is_playerdir_z =         (ent.spawnFlags & PLAYERDIR_Z) != 0;
    bool is_add_z =               (ent.spawnFlags & ADD_Z) != 0;
    bool is_bidirectional_xy =    (ent.spawnFlags & BIDIRECTIONAL_XY) != 0;
    bool is_bidirectional_z =     (ent.spawnFlags & BIDIRECTIONAL_Z) != 0;
    bool is_clamp_negative_adds = (ent.spawnFlags & CLAMP_NEGATIVE_ADDS) != 0;

    float hor_speed, vert_speed;
    ent_pushvelocity_values.get( String( ent.entNum ) + "_speed", hor_speed );
    ent_pushvelocity_values.get( String( ent.entNum ) + "_count", vert_speed );

    Vec3 velocity = other.velocity;
    Vec3 hor_vel = Vec3(velocity.x, velocity.y, 0);
    float hor_vel_speed = hor_vel.normalize();

    Vec3 vert_vel = Vec3(0, 0, velocity.z);
    float vert_vel_speed = vert_vel.normalize();

    Vec3 hor_target = Vec3(ent.origin2.x, ent.origin2.y, 0);
    float hor_target_speed = hor_target.normalize();
    if ( hor_target_speed == 0 )
        hor_target = hor_vel;
    Vec3 vert_target = Vec3(0, 0, ent.origin2.z);
    float vert_target_speed = vert_target.normalize();
    if ( vert_target_speed == 0 )
        vert_target = vert_vel;

    Vec3 hor_add = Vec3(0);
    float hor_add_speed = 0;
    Vec3 vert_add = Vec3(0);
    float vert_add_speed = 0;

    Vec3 hor_base_vel;
    float hor_base_speed;
    if ( is_playerdir_xy )
    {
        hor_base_vel = hor_vel;
        hor_base_speed = hor_speed;
    }
    else
    {
        hor_base_vel = hor_target;
        hor_base_speed = hor_target_speed;
    }

    if ( is_add_xy )
        hor_base_speed += hor_vel_speed;

    float hor_dot = (hor_base_vel) * (hor_vel*hor_vel_speed);
    if ( !is_playerdir_xy )
    {
        if ( is_bidirectional_xy )
        {
            if ( hor_dot < 0 )
            {
                hor_base_vel = hor_target*-1;
            }
        }
    }

    if ( is_add_xy && is_clamp_negative_adds )
    {
        if ( !is_playerdir_xy && hor_dot < 0 )
        {
            hor_base_speed = - hor_dot - hor_target_speed;
            hor_base_vel *= -1;
        }
        if ( hor_base_speed < 0 )
            hor_base_speed = 0;
    }

    Vec3 vert_base_vel;
    float vert_base_speed;
    if ( is_playerdir_z )
    {
        vert_base_vel = vert_vel;
        vert_base_speed = vert_speed;
    }
    else
    {
        vert_base_vel = vert_target;
        vert_base_speed = vert_target_speed;
    }

    if ( is_add_z )
        vert_base_speed += vert_vel_speed;

    float vert_dot = (vert_base_vel) * (vert_vel*vert_vel_speed);
    if ( !is_playerdir_z )
    {
        if ( is_bidirectional_z )
        {
            if ( vert_dot < 0 )
            {
                vert_base_vel = vert_target*-1;
            }
        }
    }

    if ( is_add_z && is_clamp_negative_adds )
    {
        if ( !is_playerdir_z && vert_dot < 0 )
        {
            vert_base_speed = - vert_dot - vert_target_speed;
            vert_base_vel *= -1;
        }
        if ( vert_base_speed < 0 )
            vert_base_speed = 0;
    }

    velocity = hor_base_vel*hor_base_speed + vert_base_vel*vert_base_speed;

    other.velocity = velocity;
    G_Sound( other, CHAN_AUTO, ENT_PUSHVELOCITY_SOUND, ATTN_NORM );
}
