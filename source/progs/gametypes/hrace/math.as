float Lerp( float a, float t, float b )
{
    return a * ( 1.0 - t ) + b * t;
}

uint Lerp( uint a, float t, uint b )
{
    return uint( Lerp( float( a ), t, float( b ) ) );
}

Vec3 Lerp( Vec3 a, float t, Vec3 b )
{
    return a * ( 1.0 - t ) + b * t;
}

float LerpAngle( float a, float t, float b )
{
    if ( b - a > 180 )
        b -= 360;
    if ( b - a < -180 )
        b += 360;
    return Lerp( a, t, b );
}

Vec3 LerpAngles( Vec3 a, float t, Vec3 b )
{
    return Vec3(
        LerpAngle( a.x, t, b.x ),
        LerpAngle( a.y, t, b.y ),
        LerpAngle( a.z, t, b.z )
    );
}

Position Lerp( Position a, float t, Position b )
{
    Position p;
    p.copy( t < 0.5 ? a : b );
    p.location = Lerp( a.location, t, b.location );
    p.angles = LerpAngles( a.angles, t, b.angles );
    p.velocity = Lerp( a.velocity, t, b.velocity );
    p.currentTime = Lerp( a.currentTime, t, b.currentTime );
    return p;
}

Vec3 HorizontalVelocity( Vec3 vel )
{
    vel.z = 0;
    return vel;
}

float HorizontalSpeed( Vec3 vel )
{
    return HorizontalVelocity( vel ).length();
}

uint randrange(uint n)
{
    uint64 r = 0;
    for ( int i = 0; i < 32; i++ )
        r = ( r << 1 ) | ( ( rand() ^ ( realTime >> i ) ) & 1 );
    return uint( ( r * uint64( n ) ) >> 32 );
}
