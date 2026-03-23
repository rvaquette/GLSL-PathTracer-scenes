#define NUMSPHERES 40


#define ZERO min(0,iFrame)


float hash1( uint n ) 
{
	n = (n << 13U) ^ n;
    n = n * (n * n * 15731U + 789221U) + 1376312589U;
    return 1.0 - float(n&0x7fffffffU)/float(0x7fffffff);
}

vec3 hash3( uint n ) 
{
    uvec3 k = n + uvec3(0,517U,8191U);
	k = (k << 13U) ^ n;
    k = k * (k * k * 15731U + 789221U) + 1376312589U;
    return 1.0 - vec3(k&0x7fffffffU)/float(0x7fffffff);
}

