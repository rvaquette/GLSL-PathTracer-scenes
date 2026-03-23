 /*
    Raymarching with rounded cubes to illustrate
    - infinite number of objects because it's not necessary to model the 
      scene with all objects per loops but use distance to nearest object instead. 
    - roundness of cubes edges comes with almost zero cost.
    - reflection
    
    For nicer visuals:
    - cube rotation!
    - shift of the object coordinates (with y-shift dependent on x)
    - object density on y axis decreased by factor
    - 3d checker pattern (needs to take into account the shift)
    - color cycling
    - camera angle and camera zoom cycling
    - simple and unrealistic diffuse lighting with squaring for more contrast
    Due to shifting and rotation, its not straight forward to get the nearest object,
    instead of caculating correctly, the effect of potential error is mitigated
    by a factor on the ray marching step distance, unless close enough
*/

#define maxSteps 50.   // max raymarching steps
#define maxRayLen 50.  // max raymarching ray lenght 
#define reflections 2  // max number of reflections
#define eps 0.001      // 'very' small number, 'almost' zero
#define PI 3.1416128
#define yStep 1.4      // factor for y-axis steps
#define yLevel0 -2.    // max y level with objects (pre shift), nothing above, but camera above
#define waves 0.4      // factor on sinus for y-shift
#define v3null vec3(0., 0., 0.)
#define cubeSize      0.12 * vec3(1., 1., 1.) 
#define cubeRoundness 0.07
#define lightPos vec3(-3.,5.,-1.) // diffuse light

/* return 'integer' index for y with 0 at yLevel0, 
   called roundY because round gives the index for x / z */
float roundY(float y)
{
    return round((y - yLevel0) / yStep);
}

/* y value of closest y level (with integer index) */
float roundedY(float y)
{
    return yLevel0 + (roundY(y) * yStep );
}

vec3 rotX(vec3 coord, vec3 center, float phi)
{
    return vec3(
        coord.x,
        center.y +(coord.y - center.y)*cos(phi)
                 -(coord.z - center.z)*sin(phi),
        
        center.z +(coord.y - center.y)*sin(phi)
                 +(coord.z - center.z)*cos(phi));
}

vec3 rotZ(vec3 coord, vec3 center, float phi)
{   // = rotX(coord.zxy , center, phi).yzx;
    return vec3(
        center.x +(coord.x - center.x)*cos(phi)
                 -(coord.y - center.y)*sin(phi),
        center.y +(coord.x - center.x)*sin(phi)
                 +(coord.y - center.y)*cos(phi),
        coord.z);
}

vec3 rotY(vec3 coord, vec3 center, float phi)
{
    return vec3(
        center.x +(coord.x - center.x)*cos(phi)
                 -(coord.z - center.z)*sin(phi),
        coord.y,
        center.z +(coord.x - center.x)*sin(phi)
                 +(coord.z - center.z)*cos(phi));
}

/* time and location dependent shift */
vec3 getShift (vec3 p) 
{
    float xIndex = round(p.x);
    return vec3(
            sin(iTime * .4) * 3., 
            sin(xIndex + iTime) * waves, // y-shift depends on xIndex
            -iTime * 2.);
}

/* get original point from shifted (inverse of getShift) */
vec3 getPFromShifted (vec3 p) 
{
    float xShift   = sin(iTime * .4) * 3.;
    float oriX = p.x - xShift;
    float xIndex = round(oriX);
    return vec3(
            oriX, 
            p.y - sin(xIndex + iTime) * waves,
            p.z + iTime * 2.);
}

/* distance from box at <0,0,0> with border size b per axis */
float distBox(vec3 p, vec3 b )
{
    return length(max(abs(p) - b, 0.0));
}

/* distance from rotating rounded cube, center 0,0,0 
    obj center is only for pos/index dependent rotation */
float distObject(vec3 p, vec3 objCenter) {
    vec3 pRot = rotX(
            rotY(p, v3null, iTime + 0.2 * objCenter.z), 
            v3null, iTime * .5);
    return distBox (pRot, cubeSize) - cubeRoundness; 
}

/* distance from close object in relevant layer
   it is based on rounding position to index, close is not closest, but not too bad */
float distObjLayers(vec3 p) {
    vec3 o = getPFromShifted(p); // calculating distance to shifted object, o is the corresponding unshifted position
    vec3 c = vec3(round(o.x), roundedY(o.y), round(o.z)); // original unshifted center (xyz-index)
    if (c.y  > yLevel0 + eps) c.y = yLevel0; // nothing above us
    return distObject(o - c, c);
}


float distBigObject(vec3 p) {
    vec3 pos = vec3(2.,1.5,1.5);
    float d1 = distBox(rotY(rotX(p, pos, 0.3+sin(iTime*0.5)*0.4), pos, iTime) - pos, vec3(1.,1.,1.)*1.1) ;
    return d1 -0.02;
}

vec2 normCoord(vec2 coord) {
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv  = coord/iResolution.xy;
    //Shift to center
    uv.xy -= vec2(.5, .5);
	//Rescale axis
    uv.x *= iResolution.x/iResolution.y;
    return uv * 2.; // y: [-1 : +1]
}



/* ~ distance of point to scene */
float dist(vec3 p) {
    return min(distObjLayers(p), distBigObject(p));
}

/* normal vector to scene */
vec3 distNorm (vec3 p)
{
    float d = dist(p);
    
    vec3 n  = vec3(d - dist(p-vec3(eps, 0.,  0. )),
                   d - dist(p-vec3(0.,  eps, 0. )),
                   d - dist(p-vec3(0.,  0.,  eps)));
    return normalize(n);
}

struct Hit 
{
    vec3 p; // point on surface
    vec3 n; // normal vector (normalized)
    float l; // ray length
    int nSteps;
};


/* dot product of normalized light vector and scene normal vector */
float diffuseLight (Hit h)
{
    return dot(h.n, normalize(lightPos - h.p));
}

/* raymarching, return hit position, normal and ray lenght */
Hit rayMarch(vec3 p0, vec3 normRayDir)
{
    vec3  p      = p0;
    float d      = dist(p);
    float rayLen = 0.;
    int n = 0;
    for (float i = 0.; i < maxSteps; i++)
    {
        d = dist(p);
        d = (d > 0.1) ? d *.8 : d; // above dist 0.1, scale step down because dist can give a distance to the not closest bust quite close object
        p += normRayDir * d;
        rayLen += d;
        if ( rayLen > maxRayLen || d < 0.005)
            break;
        n++;
    }
    return Hit(p, distNorm(p), rayLen, n);
}

/* return color for a hit on object */ 
vec3 getColor(Hit h) 
{    
    float b = diffuseLight(h) * smoothstep(11., 0.5, h.l + 0.2);
    b +=.25; // brightness
    b *= b;  // drama
    if (h.p.y > yLevel0 +1.+waves)
        return vec3(1., 1., 1.) *.9*b;
    
    vec3 pOri = getPFromShifted(h.p); // object colors based on xyz-index, need original position 

    float fCont =  mod(pOri.x + pOri.z + (yLevel0 + pOri.y) / yStep, 2.);
    float fDisc =  mod(round(pOri.x) + round(pOri.z) + roundY(pOri.y), 2.);
    float checker = 0.; //fCont;//fDisc;
    
    return vec3(b * fDisc , b*(0.5+0.5*abs(sin(iTime+checker*PI *0.5))), b*(0.5+0.5*abs(cos(iTime+checker*PI*0.5))));
}

/* return normalized reflection vector of r, n is normal of reflecting surface*/
vec3 getReflectionRay(vec3 n, vec3 r) {
    return r - 2. * dot(r, n) * n;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2  uv   = normCoord(fragCoord);

    // Camera setup
    float angX = .7 + sin(iTime) * 0.2;  // camera rotation X - time dependent
    float angZ = sin(iTime * 0.3) * 0.4; // camera rotation Z - time dependent
    vec3  cam  = rotZ(rotX(vec3 (0., 1., -5.), v3null, angX), v3null, angZ);
    float cs   = 2.5 + sin(iTime * 0.3) * 1.3; // camera zoom (time dependent)
    vec3  rayDir     = rotZ(rotX(cs * vec3(uv.x, uv.y, 0.),v3null, angX), v3null, angZ) - cam;
    vec3  p    = cam + rayDir * 0.5; // image plane can intersect with objects, goingonly 0.5 times ray dir helps
    
    // Ray marching
    rayDir = normalize(rayDir);
    Hit  h   = rayMarch(p, rayDir);
    vec3 col = getColor(h);
    
    // Reflections
    float b = length(col); 
    for (int i = 0; i < reflections && h.l < maxRayLen; i++)
    {
        vec3 rayDir = getReflectionRay(h.n, rayDir);
        h = rayMarch(h.p+ 0.1*rayDir, rayDir);
        col += b * (1./(1.+h.l)) *min(getColor(h), vec3(1.,1.,1.));
        col = min(col, vec3(1., 1., 1.));
        b*=length(col);
    }
    
    fragColor = vec4(col, 1.0);
}


