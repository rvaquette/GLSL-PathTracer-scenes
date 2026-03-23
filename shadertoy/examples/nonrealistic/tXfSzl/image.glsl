// Joseph Klinger - University of Pennsylvania
// https://github.com/klingerj
// https://www.linkedin.com/in/josephklinger/
// Inspired by: https://www.shadertoy.com/view/MsSGD1
// Idea also inspired from this course taught by Rachel Hwang at UPenn: https://cis700-procedural-graphics.github.io/

// Raymarching params
#define T_MAX 50.0

// Colors
#define GRAPHITE_COLOR vec3(0.3)
#define RED_LINE_COLOR vec3(1.0, 0.41, 0.73)
#define BLUE_LINE_COLOR vec3(0.58, 0.83, 0.95)
#define PAPER_COLOR vec3(0.8, 0.8, 0.73)

#define SHADOWS
#define LIGHT_VEC normalize(vec3(0.0, 0.8, -1.0))

// 3D Noise by IQ
float Noise3D( in vec3 pos )
{
    vec3 p = floor(pos);
    vec3 f = fract(pos);
    f = f * f * (3.0 - 2.0 * f);
    vec2 uv = (p.xy + vec2(37.0, 17.0) * p.z) + f.xy;
    vec2 rg = textureLod( iChannel0, (uv + 0.5) / 256.0, 0.0).yx;
    return -1.0 + 2.0 * mix( rg.x, rg.y, f.z );
}

float ComputeFBM( in vec3 pos )
{
    float amplitude = 0.25;
    float sum = 0.0;
    sum += Noise3D(pos) * amplitude;
    return clamp(sum, 0.0, 1.0);
}

// Credit to IQ: https://iquilezles.org/articles/distfunctions


float SDF_Box( in vec3 pos, in vec3 b )
{
     return length(max(abs(pos) - b, 0.0));
}


// tea pot and cup==================================


float sdCappedCylinder( vec3 p, vec2 h )
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdRoundedCylinder( vec3 p, float ra, float rb, float h )
{
    vec2 d = vec2( length(p.xz)-2.0*ra+rb, abs(p.y) - h );
    return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float opSmoothSubtraction( float d1, float d2, float k )
{
	float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
	return mix( d2, -d1, h ) + k*h*(1.0-h);
}

float cupSDF(vec3 p) {	
    float dst = 0.0;
	float d1 = sdRoundedCylinder(-p, 0.12, 0.1, 0.1);
   	float d2 = sdCappedCylinder(vec3(0.,0.2,0.)-p, vec2(.1,.35));
    dst = opSmoothSubtraction(d2, d1, 0.2);    
    return dst;   
}

//Bezier curve utility func=====================
float U(in vec2 a, in vec2 b){
  return (a.x*b.y-b.x*a.y);
}


vec2 B(vec2 m, vec2 n, vec2 o, vec3 p) {
	vec2 q = p.xy;
	m-= q; n-= q; o-= q;
	float x = U(m, o), y = 2. * U(n, m), z = 2. * U(o, n);
	vec2 i = o - m, j = o - n, k = n - m, 
		 s = 2. * (x * i + y * j + z * k), 
		 r = m + (y * z - x * x) * vec2(s.y, -s.x) / dot(s, s);
	float t = clamp((U(r, i) + 2. * U(k, r)) / (x + x + y + z), 0.,1.); // parametric position on curve
	r = m + t * (k + k + t * (j - k)); // distance on 2D xy space
	return vec2(sqrt(dot(r, r) + p.z * p.z), t); // distance on 3D space
}

float smin(float a, float b, float k){
    float h = clamp(.5+.5*(b-a)/k, 0., 1.);
    return mix(b,a,h)-k*h*(1.-h);
}
//Tea pot distance func=============================================
vec2 A[15];
vec2 T1[5];
vec2 T2[5];

void potAssgn(){
	 //pot=====
    // Teapot body profil (8 quadratic curves) 
    A[0]=vec2(0,0);A[1]=vec2(.64,0);A[2]=vec2(.64,.03);A[3]=vec2(.8,.12);A[4]=vec2(.8,.3);A[5]=vec2(.8,.48);A[6]=vec2(.64,.9);A[7]=vec2(.6,.93);
    A[8]=vec2(.56,.9);A[9]=vec2(.56,.96);A[10]=vec2(.12,1.02);A[11]=vec2(0,1.05);A[12]=vec2(.16,1.14);A[13]=vec2(.2,1.2);A[14]=vec2(0,1.2);
	// Teapot spout (2 quadratic curves)
	T1[0]=vec2(1.16, .96);T1[1]=vec2(1.04, .9);T1[2]=vec2(1,.72);T1[3]=vec2(.92, .48);T1[4]=vec2(.72, .42);
	// Teapot handle (2 quadratic curves)
	T2[0]=vec2(-.6, .78);T2[1]=vec2(-1.16, .84);T2[2]=vec2(-1.16,.63);T2[3]=vec2(-1.2, .42);;T2[4]=vec2(-.72, .24);
    //=========
}

float potSDF(vec3 p) {

// Distance to Teapot --------------------------------------------------- 
	// precalcul first part of teapot spout
	vec2 h = B(T1[2],T1[3],T1[4], p);
	float a = 99., 
    // distance to teapot handle (-.06 => make the thickness) 
		b = min(min(B(T2[0],T2[1],T2[2], p).x, B(T2[2],T2[3],T2[4], p).x) - .06, 
    // max p.y-.9 => cut the end of the spout 
                max(p.y - .9,
    // distance to second part of teapot spout (abs(dist,r1)-dr) => enable to make the spout hole 
                    min(abs(B(T1[0],T1[1],T1[2], p).x - .07) - .01, 
    // distance to first part of teapot spout (tickness incrase with pos on curve) 
                        h.x * (1. - .75 * h.y) - .08)));
    // distance to teapot body => use rotation symetry to simplify calculation to a distance to 2D bezier curve
    vec3 qq= vec3(sqrt(dot(p,p)-p.y*p.y), p.y, 0);
    // the substraction of .015 enable to generate a small thickness arround bezier to help convergance
    // the .8 factor help convergance  
	for(int i=0;i<13;i+=2) 
		a = min(a, (B(A[i], A[i + 1], A[i + 2], qq).x - .015) * .7); 
    // smooth minimum to improve quality at junction of handle and spout to the body
	float dTeapot = smin(a,b,.0);

    return dTeapot;
}


// Cheap, pseudorandom number generator taken from: https://www.shadertoy.com/view/MscSzf
/*
float rand(float x)
{
    return fract(sin(x) * 43758.5453);
}*/


float rand( float p )
{
    p = dot(p,1271311.7);// dot(p,vec2(269.5,183.3)) ;
	return fract(sin(p)*43758.5453);
}


float SceneMap( in vec3 pos )
{
   
	float sdf = potSDF(pos- vec3 (0.0, 0.0, 0.0));
    sdf = min(sdf, cupSDF(pos- vec3(0.8, 0.2, -1.0)));
   	sdf = min(sdf, SDF_Box(pos - vec3(0.0, 0.0, 0.0), vec3(4.0, 0.02, 4.0) * 0.5));
 
    return sdf;
}

vec3 ComputeNormal( in vec3 pos )
{
    vec2 epsilon = vec2(0.0, 0.001);
    return normalize( vec3( SceneMap(pos + epsilon.yxx) - SceneMap(pos - epsilon.yxx),
                            SceneMap(pos + epsilon.xyx) - SceneMap(pos - epsilon.xyx),
                            SceneMap(pos + epsilon.xxy) - SceneMap(pos - epsilon.xxy)));
}

vec3 RaymarchScene( in vec3 origin, in vec3 dir )
{
    float distance, lastDistance = 10000000.0;
    const float EDGE_THRESHOLD = 0.015;
    float dt = 0.01;
    float t = 0.01;
    float hitSomething, isOnEdge = 0.0;
    
    for(int i = 0; i < 200; i++)
    {
        distance = SceneMap(origin + t * dir);
        
        // If we get very close to an object and we also moved away since the last iteration
        if (distance < EDGE_THRESHOLD && distance > lastDistance + 0.00001)
        {//edge detection
            hitSomething = 1.0;
            isOnEdge = 1.0;
            break;
        }
        
        if(distance < 0.001)
        {
            hitSomething = 1.0;
            break;
        }
        else if (t > T_MAX)
        {
            break;
        }
        
        t += distance;
        lastDistance = distance;
    }
    return vec3(t, hitSomething, isOnEdge);
}

vec3 GetBackgroundColor( in vec2 coord )
{
    // Blue notebook paper lines
    vec3 col = PAPER_COLOR;
    
    
    //bool isOnRedLine = false;
    /*
    if (coord.x <= 86.5 && coord.x >= 85.0) // red notebook paper line
    {
        col *= RED_LINE_COLOR;
        isOnRedLine = true;
    }*/
   /* 
    if (mod(coord.y, 20.0) <= 1.0 && mod(coord.y, 20.0) >= -1.0)
    {
        col *= BLUE_LINE_COLOR;
        if (isOnRedLine) // mix the red and blue ink if the lines intersect
        {
            col *= RED_LINE_COLOR;
        }
        
    }*/
    
    
    // Accounting for the mottling in paper
    float mottling = ComputeFBM(vec3(coord, 1.0) * 1.0);
    //float mottling = 0.0;
    return mix(col, vec3(0.0, 0.0, 0.0), pow(mottling, 0.8));
}

vec3 GetHatchingColor( in vec2 coord, in float lightIntensity, in vec3 camRight, in vec3 camUp, in bool isGradientEnabled, in float doOffsetHatching )
{    
    vec3 hatchingColor = GetBackgroundColor(coord);
    
    // Make the hatching look more consistent at full resolution
    coord = coord / iResolution.xy * 1024.0;
    
    // Just catch a flag saying we want to jitter the hatching-
    // For example, make the outline or shadow hatching look
    // noncontinuous with any nearby dark hatching
    coord += vec2(75.0, 15.0) * doOffsetHatching;
    
    float lineWidth, lineFreq, hatching;
    
    float thresh1 = 0.5;
    float thresh0 = thresh1 + 0.075;
    float thresh2 = thresh1 - 0.1;
    float thresh3 = 0.2;
    float thresh4 = thresh3 - 0.1;
    
    // This code could probably be a lot less verbose but oh well
    
    // Threshold 1
    lineWidth = 0.015 * (0.5 * sin((coord.x - 0.25 * coord.y) * 0.04167 + 0.15 * (coord.x + coord.y)) + 0.5) + 1.0;
    lineFreq = 10.0;
    hatching = mod(coord.x + coord.y * 0.15 * (sin(abs(coord.y + coord.x) * 0.00390625 * 0.75)), lineFreq) + 2.0 * (rand(coord.x - 0.75 * coord.y) - 2.0);
    if (lightIntensity <= thresh1)
    {
        if ((hatching <= lineWidth) && (hatching >= -lineWidth))
    	{
    	    hatchingColor *= GRAPHITE_COLOR;
   	    }
    }
    else
    {
        if(isGradientEnabled && lightIntensity < thresh0)
        {
        	if ((hatching <= lineWidth) && (hatching >= -lineWidth))
    		{
        	   float weight = (thresh0 - lightIntensity) / (thresh0 - thresh1);
       	       weight = pow(weight, 1.0);
    		   hatchingColor = mix(hatchingColor * GRAPHITE_COLOR, hatchingColor, 1.0 - weight);
   	        }
        }
    }
    
    
    // Threshold 2
    lineWidth = 1.0 * (0.5 * sin((coord.x + 0.75 * coord.y) * 0.0625 + 0.15 * (coord.x - 0.5 * coord.y)) + 0.5) + 1.0;
    lineFreq = 14.0;
    hatching = mod(coord.x + coord.y, lineFreq) + 2.0 * (rand(coord.x - 0.75 * coord.y) - 2.0);
    if (lightIntensity <= thresh2)
    {
        if ((hatching <= lineWidth) && (hatching >= -lineWidth))
    	{
    	   hatchingColor *= GRAPHITE_COLOR;
   	    }
    }
    else
    {
        if(isGradientEnabled && lightIntensity < thresh1)
        {
        	if ((hatching <= lineWidth) && (hatching >= -lineWidth))
    		{
        	   float weight = (thresh1 - lightIntensity) / (thresh1 - thresh2);
       	       weight = pow(weight, 1.0);
    		   hatchingColor = mix(hatchingColor * GRAPHITE_COLOR, hatchingColor, 1.0 - weight);
   	        }
        }
    }
    
    // Threshold 3
    lineWidth = 1.0 * (0.5 * sin((coord.x + 1.0 * coord.y) * 0.03125 + 0.15 * (coord.x - 1.5 * coord.y)) + 0.5) + 1.5;
    lineFreq = 8.0;
    hatching = mod(coord.x - 0.75 * coord.y, lineFreq) + 2.0 * (rand(coord.x + 0.75 * coord.y) - 2.0);
    if (lightIntensity <= thresh3)
    {
        if ((hatching <= lineWidth) && (hatching >= -lineWidth))
    	{
    	    hatchingColor *= GRAPHITE_COLOR;
   	    }
    }
    else
    {
        if(isGradientEnabled && lightIntensity < thresh2)
        {
        	if ((hatching <= lineWidth) && (hatching >= -lineWidth))
    		{
        	   float weight = (thresh2 - lightIntensity) / (thresh2 - thresh3);
       	       weight = pow(weight, 1.0);
    		   hatchingColor = mix(hatchingColor * GRAPHITE_COLOR, hatchingColor, 1.0 - weight);
   	        }
        }        
    }
    
    
    // Threshold 4
    lineWidth = 1.25;
    lineFreq = 7.0;
    hatching = mod(coord.x + 0.15 * coord.y, lineFreq) + 2.0 * (rand(coord.x - 0.75 * coord.y) - 2.0);
    if (lightIntensity <= thresh4)
    {
        if ((hatching <= lineWidth) && (hatching >= -lineWidth))
    	{
    	    hatchingColor *= GRAPHITE_COLOR;
   	    }
    }
    else
    {
        if(isGradientEnabled && lightIntensity < thresh3)
        {
        	if ((hatching <= lineWidth) && (hatching >= -lineWidth))
    		{
        	   float weight = (thresh3 - lightIntensity) / (thresh3 - thresh4);
       	       weight = pow(weight, 2.0);
    		   hatchingColor = mix(hatchingColor * GRAPHITE_COLOR, hatchingColor, 1.0 - weight);
   	        }
        }  
    }
    return hatchingColor;
    
}

// Credit to IQ: https://iquilezles.org/articles/rmshadows
float SoftShadow( in vec3 ro, in vec3 rd, float k )
{
    float res = 1.0;
    float t = 0.05;
    while(t <= 10.0)
    {
        float h = SceneMap(ro + rd * t);
        if (h < 0.001)
        {
            return 0.0;
        }
        res = min(res, k * h / t);
        t += h;
    }
    return res;
}

// "Plasma": Compute ray jitter using "plasma": http://lodev.org/cgtutor/plasma.html
float Plasma( in vec2 sp, in float timeStutter )
{    
    float plasma = 0.5 * sin(sp.x * 8.0 + timeStutter) + 0.5;
    plasma *=  sin((sp.x + sp.y) * 8.0 + timeStutter) + 0.5;
    plasma *= 0.5 * sin(length(sp) * 15.0 + timeStutter) + 0.5;
    return plasma;
}

vec3 CastRay( in vec2 sp, in vec3 origin, out vec3 camRight, out vec3 camUp ) // need the camRight vector in the hatching color function
{
    // Compute local camera vectors
    vec3 refPoint = vec3(0.0, 0.4, 0.0);
    vec3 camLook = normalize(refPoint - origin);
    camRight = normalize(cross(camLook, vec3(0.0, 1.0, 0.0)));
    camUp = normalize(cross(camRight, camLook));
    
    vec3 rayPoint = refPoint + sp.x * camRight + sp.y * camUp;
    return normalize(rayPoint - origin);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{    
    potAssgn();
    
    vec2 screenPoint = (2.0 * fragCoord.xy - iResolution.xy) / iResolution.y;
    
    // Compute ray direction
    float radius = 4.0;
    float speed = 0.015625;
    
    // camera 
    vec3 rayOrigin = vec3(cos(iMouse.x * speed) * radius, -5.0 * ((iMouse.y / iResolution.y) - 0.8), sin(iMouse.x * speed) * radius);
    vec3 camRight, camUp;
    vec3 rayDirection = CastRay(screenPoint, rayOrigin, camRight, camUp);
    
    // Compute ray jitter using fake noise stuff using sin() - see the Plasma() function
    float timeStutter = floor(iTime * 12.0) * 16.0;
    timeStutter = mod(timeStutter, 2048.0); // the plasma function broke when iTime reached high values, mod every 2^24
    
    const bool isGradientEnabled = true;
    
    // Compute a direction to offset the .xy component of each ray via a gradient
    vec2 fragSize = 1.0 / iResolution.xy;
    vec2 offsetDir = normalize(vec2(cos(cos(iTime * 2.0)), sin(cos(iTime * 2.0)))) * 0.75;
    rayDirection.xy += max(Plasma(screenPoint, timeStutter), 0.05) * offsetDir * 0.00390625; // that's 1 / 256
    
    vec3 result = RaymarchScene(rayOrigin, rayDirection);
    
    if (result.y > 0.0)
    {
        vec3 isectPoint = rayOrigin + result.x * rayDirection;
        vec3 normal = ComputeNormal(isectPoint);
        float lightIntensity = clamp(dot(normal, LIGHT_VEC), 0.0, 1.0);
        
        vec3 col;
        
        // Compute shadows
        float shadowing = 1.0;
        #ifdef SHADOWS
            shadowing= SoftShadow(isectPoint, LIGHT_VEC, 7.0);
        #endif
        
        // Shade depending on whether or not we are on an outline
       
        col = mix(GetHatchingColor(fragCoord.xy, min(shadowing, lightIntensity), camRight, camUp, isGradientEnabled, 0.0),
                  GetHatchingColor(fragCoord.xy, 0.0, camRight, camUp, isGradientEnabled, 0.0),
                  result.z);
        
        
       // col = GetHatchingColor(fragCoord.xy, min(shadowing, lightIntensity), camRight, camUp, isGradientEnabled, 0.0);
        //col = GetHatchingColor(fragCoord.xy, 0.0, camRight, camUp, isGradientEnabled, 0.0);
                        
        fragColor = vec4(col, 1.0);
    }
    else // we miss geometry completely
    {
        fragColor = vec4(GetBackgroundColor(fragCoord.xy), 1.0);
    }
}
