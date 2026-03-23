#define PI 3.14159265359
#define DEG_TO_RAD PI / 180.0

// configure
#define AA 4
#define TEXTURE 1
#define NORMAL_BUMP 1

// math
mat2 rot2( float angle ) {
	float c = cos( angle );
	float s = sin( angle );
	
	return mat2(
		 c, s,
		-s, c
	);
}

// rotate over the xy plane
mat3 rot3xy( vec2 angle ) {
	vec2 c = cos( angle );
	vec2 s = sin( angle );
	
	return mat3(
		c.y      ,  0.0, -s.y,
		s.y * s.x,  c.x,  c.y * s.x,
		s.y * c.x, -s.x,  c.y * c.x
	);
}

float sqr(float x) {
    return x * x;
}

// distance functions
float sdPlane(vec3 v) {
    return v.y;
}

float sdBox( vec3 v, vec3 size, float r ) {
	return length( max( abs( v ) - size, 0.0 ) ) - r;
}

float sdSphere(vec3 v, float r) {
    return length(v) - r;
}

vec2 scene(vec3 v) {
	// sphere
	float sphere = sdSphere( v - vec3(0.0, 0.4, 0.0), 2.7 );
	
	// box
	v.xz = rot2( v.y ) * v.xz;
	float box = sdBox( v - vec3(0.0, 0.4, 0.0), vec3( 2.0, 2.0, 2.0 ), 0.05 );

    // blend sphere and the box
	return vec2(min( sphere, box ),1.0);
}

// gets the direction of the camera through the pixel coordinates
vec3 rayDir(float fov, vec2 size, vec2 pos) {
    // get the xy between -1 and 1;
    vec2 xy = pos - size * 0.5;
    
    float halfFov = tan( (90.0 - fov * 0.5) * DEG_TO_RAD);
    float z = size.y * 0.5 * halfFov;
    
    return normalize( vec3(xy, -z));
}

// basic raymarching
vec2 rayMarching(vec3 origin, vec3 direction) {
    const float NEAR_CLIPPING_PLANE = 0.1;
	const float FAR_CLIPPING_PLANE = 100.0;
	const int MAX_MARCH_STEPS = 64;
    const float DISTANCE_BIAS = 0.4;
	const float EPSILON = 0.01;

    float t = NEAR_CLIPPING_PLANE;
    float material = -1.0;
    
    for( int i=0; i < MAX_MARCH_STEPS; i++ )
    {
	    vec2 hit = scene( origin + direction * t );
        if( hit.x < EPSILON || t > FAR_CLIPPING_PLANE) break;
        t += hit.x * DISTANCE_BIAS;
	    material= hit.y;
    }

    if( t > FAR_CLIPPING_PLANE ) material = -1.0;
    return vec2(t, material);
}

// takes the absolutes of the dot product (since we are between -1 and 1)
float minMax(float d) {
    return max(abs(d),0.0001);
}

// calculate micro normal of p on the scene
vec3 normal(vec3 p, float smoothness)
{	
    // From https://www.shadertoy.com/view/MdSGDW
	vec3 n;
	vec2 dn = vec2(smoothness, 0.0);
	n.x	= scene(p + dn.xyy).x - scene(p - dn.xyy).x;
	n.y	= scene(p + dn.yxy).x - scene(p - dn.yxy).x;
	n.z	= scene(p + dn.yyx).x - scene(p - dn.yyx).x;
	return normalize(n);
}


// Ashikmin-Shirely BRDF function
vec3 brdf(vec3 p, vec3 n, vec3 eye, vec3 lightPos, vec3 lightCol, vec3 mat) {
    vec3 k1 = normalize(lightPos - p);
    vec3 k2 = normalize(eye - p);
    vec3 h = normalize(k1 + k2);
    vec3 u = cross(n, vec3(1.0,0.0,0.0));
    vec3 v = cross(n, u);
    u = normalize(u);
    v = normalize(v);
    
    // You can tweak n_u,n_v,Rs and the normal bump map 
    // to get different material metal look.
    float n_u = 10.0;
    float n_v = 100.0;
    
    float nDoth = minMax(dot(n,h));
    float nDotk1 = minMax(dot(n,k1));
    float nDotk2 = minMax(dot(n,k2));
    float hDotu = minMax(dot(h,u));
    float hDotv = minMax(dot(h,v));
    float hDotn = minMax(dot(h,n));
    float hDotk = minMax(dot(h,k1));
    
    vec3 Rs = vec3(0.1);
    vec3 Rd =  mat * lightCol;
    
    // fresnal
    vec3 F = Rs + (vec3(1.0) - Rs) * pow(1.0 - hDotk, 5.0);
    
    // specular
    float specExp = (n_u * sqr(hDotu) + n_v * sqr(hDotv)) / (1.0 - sqr(hDotn));
    vec3 spec = (sqrt((n_u + 1.0) * (n_v + 1.0)) / 8.0 * PI) *
        (pow(nDoth, specExp) / (hDotk * max(nDotk1, nDotk2))) * F;
            
    // diffuse
    vec3 diff = ((28.0 * Rd) / (23.0 * PI)) *
        (vec3(1.0) - Rs) *
        (1.0 - pow(1.0 - 0.5 * nDotk1, 5.0)) *
        (1.0 - pow(1.0 - 0.5 * nDotk2, 5.0));
    
    diff *= 2.0;
    
    return diff + spec;
}

// Calculates the color at the given position with the normal, eye position and material color
// for every light there is.
vec3 shading(vec3 p, vec3 n, vec3 eye, vec3 mat) {
	vec3 final = vec3( 0.0 );	
	mat3 rot = rot3xy( vec2( -DEG_TO_RAD*30.0, iTime * 0.5 ) );

	// light 0
	{
		vec3 light = vec3( 2.0, 5.0, 2.0 );
		vec3 lightColor = vec3( 0.4, 0.6, 0.8 );
		
		final += brdf(p,n,eye,light,lightColor,mat);
	}
	
	// light 1
	{
		vec3 light = vec3( -3.0, 7.0, -3.0 );
		vec3 lightColor = vec3( 0.8, 0.5, 0.3 );
		
		final += brdf(p,n,eye,light,lightColor,mat);
	}

	return final;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 totalColor = vec3(0.0);
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        vec2 offset = vec2(float(m),float(n)) / float(AA) - 0.5;
        
        vec3 dir = rayDir(45.0, iResolution.xy + offset, fragCoord.xy);

        vec3 color = vec3(0.7) + dir.y * 0.72;

        vec3 eye = vec3(0.0,0.0,10.0);

        // rotate camera
        mat3 rot = rot3xy( vec2( -DEG_TO_RAD*30.0, iTime * 0.5 ) );
        dir = rot * dir;
        eye = rot * eye;

        vec2 hit = rayMarching(eye, dir);
        float depth = hit.x;

        // if hit
        if (hit.y == 1.0) {
            vec3 p = eye + dir * depth;
            vec3 n = normal(p, 0.1);

            #if TEXTURE
            // material color from texture
            float u = atan(n.z, n.x) / PI*2.0;
            float v = asin(n.y) / PI*2.0 + 0.5;
            vec3 mat = texture( iChannel0, vec2(u,v)).xyz;
            #else
            vec3 mat = vec3(0.6);
            #endif

            #if TEXTURE&&NORMAL_BUMP
            // bumbmapping
            float maxVariance = 2.0; 
            float minVariance = maxVariance / 6.0;
            n += normalize(mat * maxVariance - minVariance);
			#endif 
            
            color = shading(p,n,eye,mat); 
        }
        totalColor += color;
    }
    
    totalColor /= float(AA*AA);
    
    fragColor = vec4(totalColor, 1.0);        
}
