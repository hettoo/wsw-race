class Position
{
    bool saved;
    bool recalled;
    Vec3 location;
    Vec3 angles;
    Vec3 velocity;
    float health;
    float armor;
    int currentSector;
    uint currentTime;
    bool skipWeapons;
    int weapon;
    bool[] weapons;
    int[] ammos;
    int[] powerups;

    Position()
    {
        this.weapons.resize( WEAP_TOTAL );
        this.ammos.resize( WEAP_TOTAL );
        this.powerups.resize( POWERUP_TOTAL - POWERUP_QUAD );
        this.clear();
    }

    ~Position() {}

    void copy( Position@ other )
    {
        this.saved = other.saved;
        this.recalled = other.recalled;
        this.location = other.location;
        this.angles = other.angles;
        this.velocity = other.velocity;
        this.health = other.health;
        this.armor = other.armor;
        this.currentSector = other.currentSector;
        this.currentTime = other.currentTime;
        this.skipWeapons = other.skipWeapons;
        this.weapon = other.weapon;
        for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
        {
            this.weapons[i] = other.weapons[i];
            this.ammos[i] = other.ammos[i];
        }
        for ( int i = 0; i < POWERUP_TOTAL - POWERUP_QUAD; i++ )
            this.powerups[i] = other.powerups[i];
    }

    void clear()
    {
        this.saved = false;
        this.recalled = false;
        this.velocity = Vec3();
    }
}
