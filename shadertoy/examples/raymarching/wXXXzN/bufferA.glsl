#define NUMPASES 3


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    ivec2 p = ivec2(fragCoord-0.5);
    
    if( p.y>1 || p.x>NUMSPHERES ) return;

    // compute current and previous frame    
    float time = (iTime - 0.5*float(p.y)/24.0);

    vec4 sphere[NUMSPHERES];

    // animate
    for( int i=0; i<NUMSPHERES; i++ )
    {
        float rad = pow(float(i)/float(NUMSPHERES-1),5.0);
        vec3  pos = 1.0*cos( 6.2831*hash3(uint(i)*147U) + (1.0-0.7*rad)*time*0.7 );
        rad = 0.25 + 0.4*rad;
        sphere[i] = vec4( pos, rad );
    }

    // repell
    for( int k=ZERO; k<NUMPASES; k++ )
    for( int i=ZERO; i<NUMSPHERES; i++ )
    for( int j=ZERO; j<NUMSPHERES; j++ )
    {
        if( i!=j )
        {
            vec3  di = sphere[i].xyz - sphere[j].xyz;
            float rr = sphere[i].w   + sphere[j].w;
            float di2 = dot(di,di);
            if( di2 < rr*rr )
            {
                float l = sqrt(di2);
                di = 0.5*di*(1.0-rr/l);
                sphere[i].xyz -= di;
                sphere[j].xyz += di;
            }
        }
    }
    fragColor = sphere[p.x];
}


