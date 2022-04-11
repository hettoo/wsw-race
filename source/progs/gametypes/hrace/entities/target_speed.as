/*QUAKED target_speed (1 1 0) (-8 -8 -8) (8 8 8) PERCENTAGE ADD +X -X +Y -Y +Z -Z LAUNCHER
Sets the speed of the player.
If ADD is specified, negative values will reduce the speed.
-------- KEYS --------
targetname: Activating trigger points to this.
speed: Speed value to set (default: 100).
-------- SPAWNFLAGS --------
PERCENTAGE: value is treated as percentage of current speed
ADD: adds the speed instead of setting it
+X: takes positive X-direction into account
-X: takes negative X-direction into account
+Y: takes positive Y-direction into account
-Y: takes negative Y-direction into account
+Z: takes positive Z-direction (up) into account
-Z: takes negative Z-direction (down) into account
LAUNCHER: will accelerate the player into the given direction (spawnflags)
-------- NOTES --------
If LAUNCHER isn't specified the player will only be accelerated if he is moving
while the target_speed is triggered, as the player needs a moving direction and this is
only given when he moves. LAUNCHER will split the given speed value to the given
directions. Note that only one of the spawnflags for each coordinate must be set. For
example if +X and -X is active the x-direction will be ignored. The same is the case
if whether +X nor -X is active. So if you want to accelerate the player up with 900u
you have to set the speed value to 900 and activate the spawnflags +Z and LAUNCHER.*/

uint[] ent_targetspeed_times( maxClients );
Entity@[] ent_targetspeed_lastent( maxClients );
const uint ENT_TARGET_SPEED_TIMEOUT = 0;

const int TARGET_SPEED_PERCENTAGE = 1;
const int TARGET_SPEED_ADD = 2;
const int TARGET_SPEED_POS_X = 4;
const int TARGET_SPEED_NEG_X = 8;
const int TARGET_SPEED_POS_Y = 16;
const int TARGET_SPEED_NEG_Y = 32;
const int TARGET_SPEED_POS_Z = 64;
const int TARGET_SPEED_NEG_Z = 128;
const int TARGET_SPEED_LAUNCHER = 256;

void target_speed( Entity @ent )
{
    @ent.use = target_speed_use;

    float speed_value = float(G_SpawnTempValue("speed"));
    if ( speed_value == 0 )
        speed_value = 100;

    ent.moveType = MOVETYPE_NONE;
    ent.svflags |= SVF_TRANSMITORIGIN2;

    Vec3 speed = Vec3(0);

    if ( (ent.spawnFlags & TARGET_SPEED_POS_X) != 0 )
        speed.x += speed_value;
    if ( (ent.spawnFlags & TARGET_SPEED_NEG_X) != 0 )
        speed.x -= speed_value;

    if ( (ent.spawnFlags & TARGET_SPEED_POS_Y) != 0 )
        speed.y += speed_value;
    if ( (ent.spawnFlags & TARGET_SPEED_NEG_Y) != 0 )
        speed.y -= speed_value;

    if ( (ent.spawnFlags & TARGET_SPEED_POS_Z) != 0 )
        speed.z += speed_value;
    if ( (ent.spawnFlags & TARGET_SPEED_NEG_Z) != 0 )
        speed.z -= speed_value;

    ent.origin2 = speed;

    ent.linkEntity();
}

void target_speed_use(Entity @ent, Entity @other, Entity @activator)
{
    if ( @activator.client == null || activator.moveType != MOVETYPE_PLAYER ||
        ( @ent_targetspeed_lastent[activator.playerNum] == @ent && ent_targetspeed_times[activator.playerNum] > levelTime) )
        return;
        
    ent_targetspeed_times[activator.playerNum] = levelTime + ENT_TARGET_SPEED_TIMEOUT;
    @ent_targetspeed_lastent[activator.playerNum] = @ent;

    bool is_percentage = (ent.spawnFlags & TARGET_SPEED_PERCENTAGE) != 0;
    bool is_add = (ent.spawnFlags & TARGET_SPEED_ADD) != 0;
    bool is_launcher = (ent.spawnFlags & TARGET_SPEED_LAUNCHER) != 0;

    Vec3 velocity = activator.velocity;

    if ( is_launcher || velocity.length() > 0 )
    {
        if ( is_percentage )
        {
            velocity.x *= 0.01 * ent.origin2.x;
            velocity.y *= 0.01 * ent.origin2.y;
            velocity.z *= 0.01 * ent.origin2.z;
        }

        if ( is_add )
            velocity += ent.origin2;
        else
        {
            if ( (ent.spawnFlags & (TARGET_SPEED_POS_X|TARGET_SPEED_NEG_X)) != 0 )
                velocity.x = ent.origin2.x;
            if ( (ent.spawnFlags & (TARGET_SPEED_POS_Y|TARGET_SPEED_NEG_Y)) != 0 )
                velocity.y = ent.origin2.y;
            if ( (ent.spawnFlags & (TARGET_SPEED_POS_Z|TARGET_SPEED_NEG_Z)) != 0 )
                velocity.z = ent.origin2.z;
        }

        activator.velocity = velocity;
    }
}
