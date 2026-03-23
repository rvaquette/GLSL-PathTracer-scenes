// Depth and normal Pass
#define PRECIS 0.001
#define DMAX 20.0
mat3 camMat;
vec3 lightDir = normalize(vec3(5.0, 5.0, -4.0));

// Distance functions by iquilezles.org
float fSubtraction(float a, float b) {return max(-a,b);}
float fIntersection(float d1, float d2) {return max(d1,d2);}
void fUnion(inout float d1, float d2) {d1 = min(d1,d2);}
float pSphere(vec3 p, float s) {return length(p)-s;}
float pRoundBox(vec3 p, vec3 b, float r) {return length(max(abs(p)-b,0.0))-r;}
float pTorus(vec3 p, vec2 t) {vec2 q = vec2(length(p.xz)-t.x,p.y); return length(q)-t.y;}
float pTorus2(vec3 p, vec2 t) {vec2 q = vec2(length(p.xy)-t.x,p.z); return length(q)-t.y;}
float pCapsule(vec3 p, vec3 a, vec3 b, float r) {vec3 pa = p - a, ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 ); return length( pa - ba*h ) - r;}

float map(vec3 p)
{
	float d = 100000.0;

    fUnion(d, pRoundBox(p - vec3(0,-2.0,0), vec3(4,0.1,4), 0.2));
	fUnion(d, pSphere(p - vec3(2,0,2), 1.5));
    fUnion(d, pSphere(p - vec3(3.5,-1.0,0.0), 0.8));
    fUnion(d, pTorus(p - vec3(-2,0,2), vec2(1,0.3)));
	fUnion(d, pTorus2(p - vec3(-3,0,2), vec2(1,0.3)));
    fUnion(d, pRoundBox(p - vec3(2,0.6,-2), vec3(0.1,0.1,1), 0.3));
	fUnion(d, pRoundBox(p - vec3(2,0,-2), vec3(0.1,1.5,0.1), 0.3));
	fUnion(d, pRoundBox(p - vec3(2,-0.4,-2), vec3(1.2,0.1,0.1), 0.3));
    fUnion(d, pCapsule(p, vec3(-2,1.5,-2), vec3(-2,-1,-1.0), 0.3));
	fUnion(d, pCapsule(p, vec3(-2,1.5,-2), vec3(-1.0,-1,-2.5), 0.3));
	fUnion(d, pCapsule(p, vec3(-2,1.5,-2), vec3(-3.0,-1,-2.5), 0.3));
	
	return d;
}

vec3 normal(vec3 pos) {
    vec2 eps = vec2(0.001, 0.0);
    return normalize(vec3(	map(pos + eps.xyy) - map(pos - eps.xyy),
                    		map(pos + eps.yxy) - map(pos - eps.yxy),
                         	map(pos + eps.yyx) - map(pos - eps.yyx)));
}

float shadow(vec3 ro, vec3 rd)
{
    float res = 1.0;
    float t = PRECIS * 30.0;
    for( int i=0; i < 30; i++ )
    {
		float distToSurf = map( ro + rd*t );
        res = min(res, 8.0 * distToSurf / t);
        t += distToSurf;
        if(distToSurf < PRECIS || t > DMAX) break;
    }
    
    return clamp(res, 0.0, 1.0);
}

vec4 raymarching(vec3 ro, vec3 rd)
{
    float t = 0.0;
    for (int i = 0; i < 50; i++) {
       	float distToSurf = map(ro + t * rd);
        t += distToSurf;
        if (distToSurf < PRECIS || t > DMAX) break; 
    }
    
    vec4 col = vec4(0.0);
    if (t <= DMAX) {
        vec3 nor = normal(ro + t * rd);
        col.z = 1.0 - abs((t * rd) * camMat).z / DMAX; // Depth
        col.xy = (nor * camMat * 0.5 + 0.5).xy;	// Normal
        col.w = dot(lightDir, nor) * 0.5 + 0.5; // Diff
        col.w *= shadow(ro + t * rd, lightDir);
    }
    
    return col;
}

mat3 setCamera(vec3 ro, vec3 ta, float cr)
{
	vec3 cw = normalize(ta-ro);
	vec3 cp = vec3(sin(cr), cos(cr),0.0);
	vec3 cu = normalize( cross(cw,cp) );
	vec3 cv = normalize( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (2.0 * fragCoord.xy - iResolution.xy) / iResolution.yy;
    
    // Mouse
    vec2 mo = vec2(0.0);
    if (iMouse.z > 0.0) {
        mo += (2.0 * iMouse.xy - iResolution.xy) / iResolution.yy;
    }
    
    // Camera position
    float dist = 6.5;
    vec3 ro = vec3(dist * cos(iTime * 0.1 + 6.0 * mo.x), 2.0 + mo.y * 4.0, dist * sin(iTime * 0.1 + 6.0 * mo.x));
    
    // Rotate the camera
    vec3 target = vec3(0.0, 0.0, 0.0);
    
    // Compute the ray
    camMat = setCamera(ro, target, 0.0);
    vec3 rd = camMat * normalize(vec3(p.xy, 1.5));
    
    // calculate color
	fragColor = raymarching(ro, rd);
}
