const int TARGET_FRAGSFILTER_PRINTDELAY = 1000;

int[] target_score_scores(maxClients);
uint[] target_fragsFilter_printdelay(maxClients);

/*QUAKED target_score (0 .5 0) (-8 -8 -8) (8 8 8)
This is used to automatically give frag points to the player who activates this. A spawn location entity like info_player_* or CTF respawn points can target this entity to give points to the player when he spawns in the game. Or a trigger can also be used to activate this. The activator of the trigger will get the points.
--------  Q3  --------
-------- KEYS --------
targetname : ativating entity points to this.
count: number of frag points to give to player (default 1).
notfree : when set to 1, entity will not spawn in "Free for all" and "Tournament" modes.
notteam : when set to 1, entity will not spawn in "Teamplay" and "CTF" modes.
notsingle : when set to 1, entity will not spawn in Single Player mode (bot play mode).
*/

TargetScore@[] target_score_ents;

class TargetScore
{
  Entity@ ent;
  int score = 1;
  bool[] touched(maxClients);
  bool print = true;

  TargetScore( Entity@ ent )
  {
    @this.ent = @ent;
    this.score = ent.count;
    if ( ent.count <= 0 )
    {
      this.score = 1;
    }

    @ent.use = target_score_use;

    // Gotta wait until all entities are loaded.
    @ent.think = target_score_setup;
    ent.nextThink = levelTime + 1;
  }

  void Use( Entity@ activator )
  {
    if ( @activator == null || (activator.svflags & SVF_NOCLIENT) == 1 || @activator.client == null )
    {
      return;
    }

    Client@ client = @activator.client;

    if ( this.touched[client.playerNum] )
    {
      return;
    }

    target_score_scores[client.playerNum] += score;
    this.touched[client.playerNum] = true;
    
    if ( this.print && score != 0 )
    {
      client.addAward( "Your score is: " + target_score_scores[client.playerNum] );
    }
  }

  void Setup( Entity@ ent )
  {
    // Don't print if this is triggered by a spawnpoint.
    this.print = !this.findTargetingSpawnpoint( ent );
  }

  bool findTargetingSpawnpoint(Entity@ ent)
  {
    Entity@[] targeting = ent.findTargeting();
    for ( uint i = 0; i < targeting.length; i++ )
    {
      if ( targeting[i].classname.tolower().substr(0,12) == "info_player_" )
      {
        return true;
      }
      if ( this.findTargetingSpawnpoint( targeting[i] ) )
      {
        return true;
      }
    }
    return false;
  }
}

void target_score( Entity @ent )
{
  TargetScore@ target_score_ent = TargetScore(ent);
  target_score_ents.push_back(target_score_ent);
}

void target_score_use( Entity @ent, Entity @other, Entity @activator )
{
  for ( uint i = 0; i < target_score_ents.length; i++ )
  {
    if ( @target_score_ents[i].ent == @ent )
    {
      target_score_ents[i].Use(activator);
    }
  }
}

void target_score_setup( Entity @ent )
{
  for ( uint i = 0; i < target_score_ents.length; i++ )
  {
    if ( @target_score_ents[i].ent == @ent )
    {
      target_score_ents[i].Setup(ent);
    }
  };
}

void target_score_init( Client@ client )
{
  target_score_scores[client.playerNum] = 0;
  for ( uint i = 0; i < target_score_ents.length; i++ )
  {
    target_score_ents[i].touched[client.playerNum] = false;
  }
}

/*QUAKED target_fragsFilter (1 0 0) (-8 -8 -8) (8 8 8) REMOVER RUNONCE SILENT RESET MATCH
Frags Filter
-------- KEYS --------
frags: (default is 1) number of frags required to trigger the targeted entity.
target: targeted entity.
-------- SPAWNFLAGS --------
REMOVER: removes from player's score the number of frags that was required to trigger the targeted entity.
RUNONCE: no longer used, kept for compatibility.
SILENT: disables player warnings. ("x more frags needed" messages)
RESET: resets player's score to 0 after the targeted entity is triggered.
MATCH: the player's score must be exactly equal to the frags value.
-------- NOTES --------
If the Frags Filter is not bound from a trigger, it becomes independant and is so always active.
Defrag is limited to 10 independant target_fragsFilter.
*/

const int TARGET_FRAGSFILTER_REMOVER = 1;
const int TARGET_FRAGSFILTER_RUNONCE = 2;
const int TARGET_FRAGSFILTER_SILENT  = 4;
const int TARGET_FRAGSFILTER_RESET   = 8;
const int TARGET_FRAGSFILTER_MATCH   = 16;

TargetFragsFilter@[] target_fragsFilter_ents;

class TargetFragsFilter
{
  Entity@ ent;
  int frags = 1;

  bool remover = false;
  bool runonce = false;
  bool silent  = false;
  bool reset   = false;
  bool match   = false;

  TargetFragsFilter( Entity@ ent )
  {
    @this.ent = @ent;
    String fragsStr = G_SpawnTempValue("frags");
    this.frags = fragsStr.toInt();
    if ( this.frags <= 0 )
    {
      this.frags = 1;
    }

    this.remover = ( ent.spawnFlags & TARGET_FRAGSFILTER_REMOVER ) != 0;
    this.runonce = ( ent.spawnFlags & TARGET_FRAGSFILTER_RUNONCE ) != 0;
    this.silent  = ( ent.spawnFlags & TARGET_FRAGSFILTER_SILENT  ) != 0;
    this.reset   = ( ent.spawnFlags & TARGET_FRAGSFILTER_RESET   ) != 0;
    this.match   = ( ent.spawnFlags & TARGET_FRAGSFILTER_MATCH   ) != 0;

    @ent.use = target_fragsFilter_use;

    // Gotta wait until all entities are loaded.
    @ent.think = target_fragsFilter_setup;
    ent.nextThink = levelTime + 1;
  }

  void Setup( Entity@ ent )
  {
    // If the Frags Filter is not bound from a trigger, it becomes independant and is so always active.
    if ( !this.findTargetingTrigger( ent ) )
    {
      @ent.think = target_fragsFilter_think;
      ent.nextThink = levelTime + 1;
    }
    else
    {
      @ent.think = null;
    }
  }

  bool findTargetingTrigger(Entity@ ent)
  {
    Entity@[] targeting = ent.findTargeting();
    for ( uint i = 0; i < targeting.length; i++ )
    {
      if ( targeting[i].solid == SOLID_TRIGGER )
      {
        return true;
      }
      if ( this.findTargetingTrigger( targeting[i] ) )
      {
        return true;
      }
    }
    return false;
  }

  void Use(Entity@ activator)
  {
    if ( @activator == null || (activator.svflags & SVF_NOCLIENT) == 1 || @activator.client == null )
    {
      return;
    }

    Client@ client = @activator.client;
    int score = target_score_scores[client.playerNum];
    bool valid = score >= this.frags;

    if ( this.match )
    {
      // the player's score must be exactly equal to the frags value.
      valid = score == this.frags;
    }
    if ( this.runonce )
    {
      // no longer used, kept for compatibility.

    }
    if ( !this.silent )
    {
      // disables player warnings. ("x more frags needed" messages)

      // only print once every x seconds
      if ( target_fragsFilter_printdelay[client.playerNum] >= levelTime )
      {
        client.addAward( "" + (this.frags - score) + " more points needed" );
        target_fragsFilter_printdelay[client.playerNum] = levelTime + TARGET_FRAGSFILTER_PRINTDELAY;
      }
    }

    if ( valid )
    {
      this.ent.useTargets(activator);
    
      if ( this.remover )
      {
        // removes from player's score the number of frags that was required to trigger the targeted entity.
        score -= this.frags;
      }
      if ( this.reset )
      {
        // resets player's score to 0 after the targeted entity is triggered.
        score = 0;
      }
    }

    target_score_scores[client.playerNum] = score;
  }

  void Think()
  {
    for ( int i = 0; i < maxClients; i++ )
    {
      Client@ client = @G_GetClient(i);
      if ( @client != null && client.team != TEAM_SPECTATOR )
      {
        this.Use( client.getEnt() );
      }
    }
    ent.nextThink = levelTime + 1;
  }
}

void target_fragsFilter( Entity @ent )
{
  TargetFragsFilter@ target_fragsFilter_ent = TargetFragsFilter(ent);
  target_fragsFilter_ents.push_back(target_fragsFilter_ent);
}

void target_fragsFilter_use( Entity @ent, Entity @other, Entity @activator )
{
  for ( uint i = 0; i < target_fragsFilter_ents.length; i++ )
  {
    if ( @target_fragsFilter_ents[i].ent == @ent )
    {
      target_fragsFilter_ents[i].Use(activator);
    }
  };
}

void target_fragsFilter_setup( Entity @ent )
{
  for ( uint i = 0; i < target_fragsFilter_ents.length; i++ )
  {
    if ( @target_fragsFilter_ents[i].ent == @ent )
    {
      target_fragsFilter_ents[i].Setup(ent);
    }
  };
}

void target_fragsFilter_think( Entity @ent )
{
  for ( uint i = 0; i < target_fragsFilter_ents.length; i++ )
  {
    if ( @target_fragsFilter_ents[i].ent == @ent )
    {
      target_fragsFilter_ents[i].Think();
    }
  };
}
