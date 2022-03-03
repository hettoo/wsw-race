const int NOTOUCH       = 1;
const int STRICTTRIGGER = 2;
const int CRUSH         = 4;
const int FINISH        = 8;

void trigger_race_checkpoint( Entity@ self )
{
  int cnt = int( G_SpawnTempValue( "cnt" ) );

  self.count = numCheckpoints;
  self.solid = SOLID_TRIGGER;
  self.moveType = MOVETYPE_NONE;
  self.setupModel( self.model );
  self.svflags &= ~SVF_NOCLIENT;
  self.wait = 0;
  self.linkEntity();

  @self.touch = trigger_race_checkpoint_touch;

  if( ( self.spawnFlags & FINISH ) != 0 ) {
    @self.use = target_stoptimer_use;
    return;
  }
  if( cnt == 0 ) {
    @self.use = target_starttimer_use;
    return;
  }

  @self.use = target_checkpoint_use;
  numCheckpoints++;
  entityFinder.add( "cp", self, self.origin );
}

void trigger_race_checkpoint_touch( Entity@ ent, Entity@ other, const Vec3 planeNormal, int surfFlags )
{
  ent.use( ent, other, other );
}
