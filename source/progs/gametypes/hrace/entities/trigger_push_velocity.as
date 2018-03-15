Dictionary ent_pushvelocity_values;
uint[] ent_pushvelocity_times( maxClients );
const uint ENT_PUSHVELOCITY_TIMEOUT = 1000;

/**
 * trigger_push_velocity
 * @param Entity @ent
 * @return void
 */
void trigger_push_velocity( Entity @ent )
{
	@ent.think = trigger_push_velocity_think;
	ent.nextThink = levelTime + 1;
	@ent.touch = trigger_push_velocity_touch;

	ent_pushvelocity_values.set( String( ent.entNum ) + "_speed", G_SpawnTempValue("speed") );
	ent_pushvelocity_values.set( String( ent.entNum ) + "_count", G_SpawnTempValue("count") );
	ent.solid = SOLID_TRIGGER;
	ent.moveType = MOVETYPE_NONE;
	ent.setupModel( ent.model );
	ent.svflags &= ~SVF_NOCLIENT;
	ent.svflags |= SVF_TRANSMITORIGIN2; // |SVF_NOCULLATORIGIN2 Removed in Warsow 0.7
	ent.wait = 1;

	ent.linkEntity();

}

void trigger_push_velocity_think( Entity @ent )
{
	Entity@[] targets = ent.findTargets();
	String @speedString;
	ent_pushvelocity_values.get( String( ent.entNum ) + "_speed", @speedString );
	int speed = speedString.getToken( 0 ).toInt();
	int vert_speed = speedString.getToken( 1 ).toInt();
	if ( speed == 0 && vert_speed == 0 && targets.length() > 0 )
	{
		Entity@ target = targets[0]; // assume always first target

		Vec3 mins, maxs;
		ent.getSize(mins, maxs);
		Vec3 origin = mins + maxs;

		Cvar g_gravity("g_gravity", "850", 0);
		float height = target.origin.z - origin.z;
		float time = sqrt( height / (0.5 * g_gravity.value) );

		Vec3 origin2 = Vec3(0);
		origin2.z = time * g_gravity.value;

		ent.origin2 = origin2;
		ent.count = 1; // use this to know if it's based on target or not
	} else {
		ent.count = 0; // use this to know if it's based on target or not
	}
}

int PLAYERDIR_XY = 1;//apply the horizontal speed in the player's horizontal direction of travel, otherwise it uses the target XY component.
int ADD_XY = 2;//add to the player's horizontal velocity, otherwise it set's the player's horizontal velociy.
int PLAYERDIR_Z = 3;//apply the vertical speed in the player's vertical direction of travel, otherwise it uses the target Z component.
int ADD_Z = 4;//add to the player's vertical velocity, otherwise it set's the player's vectical velociy.
int BIDIRECTIONAL_XY = 5;//non-playerdir velocity pads will function in 2 directions based on the target specified.  The chosen direction is based on the current direction of travel.  Applies to horizontal direction.
int BIDIRECTIONAL_Z = 6;//non-playerdir velocity pads will function in 2 directions based on the target specified.  The chosen direction is based on the current direction of travel.  Applies to vertical direction.
int CLAMP_NEGATIVE_ADDS = 7;//adds negative velocity will be clamped to 0, if the resultant velocity would bounce the player in the opposite direction.

void trigger_push_velocity_touch( Entity @ent, Entity @other, const Vec3 planeNormal, int surfFlags )
{
/*
	-------- KEYS --------
	target: this points to the target_position to which the player will jump.
	speed:
	count:
	-------- SPAWNFLAGS --------
	PLAYERDIR_XY: if set, trigger will apply the horizontal speed in the player's horizontal direction of travel, otherwise it uses the target XY component.
	ADD_XY: if set, trigger will add to the player's horizontal velocity, otherwise it set's the player's horizontal velociy.
	PLAYERDIR_Z: if set, trigger will apply the vertical speed in the player's vertical direction of travel, otherwise it uses the target Z component.
	ADD_Z: if set, trigger will add to the player's vertical velocity, otherwise it set's the player's vectical velociy.
	BIDIRECTIONAL_XY: if set, non-playerdir velocity pads will function in 2 directions based on the target specified.  The chosen direction is based on the current direction of travel.  Applies to horizontal direction.
	BIDIRECTIONAL_Z: if set, non-playerdir velocity pads will function in 2 directions based on the target specified.  The chosen direction is based on the current direction of travel.  Applies to vertical direction.
	CLAMP_NEGATIVE_ADDS: if set, then a velocity pad that adds negative velocity will be clamped to 0, if the resultant velocity would bounce the player in the opposite direction.
*/


	Vec3 dir, velocity;
	// if(( ent.spawnFlags & 1 ) == 0 )
	velocity = other.velocity;

	if ( (ent.count == 0 && velocity.length() == 0 ) ||
		other.type != ET_PLAYER ||
		other.moveType != MOVETYPE_PLAYER ||
		ent_pushvelocity_times[other.get_playerNum()] > realTime )
	{
		return;
	} else {
		ent_pushvelocity_times[other.get_playerNum()] = realTime + ENT_PUSHVELOCITY_TIMEOUT + uint( ent.wait );

		if ( ent.count == 0 ) // based on normal stuff
		{
			String @speedString;
			ent_pushvelocity_values.get( String( ent.entNum ) + "_speed", @speedString );
			int speed = speedString.getToken( 0 ).toInt();

			if( velocity.x == 0 && velocity.y == 0 )
				return;
			velocity.x += (speed * velocity.x)/sqrt(pow(velocity.x, 2) + pow(velocity.y, 2));
			velocity.y += (speed * velocity.y)/sqrt(pow(velocity.x, 2) + pow(velocity.y, 2));
			velocity.z += speedString.getToken( 1 ).toInt();
			other.velocity = velocity;
		} else { // based on target
			velocity.z = ent.origin2.z;
			other.velocity = velocity;
		}
	}
}
