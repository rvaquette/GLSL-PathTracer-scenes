// Fork from https://www.shadertoy.com/view/Xdf3zB
// Experiment on light scattering by Ulysse Vimont (aka Ultraviolet)

#define PI				3.1415926535
#define SIGMA			2.0
#define STEP_COUNT		64
#define DIST_MAX		10.0
#define LIGHT_POWER		10.0
#define SURFACE_ALBEDO	0.1
#define EPS				0.01

#define LIGHT_COLOR		vec3(0.9, 0.77, 0.27)
#define LIGHT_POS		vec3(0.0)
#define SPHERE_POS		vec3(0.0)
#define SPHERE_RAD		0.25

// shamelessly stolen from iq!
float hash(float n)
{
    return fract(sin(n)*43758.5453123);
}

// also stolen from iq
float noise( in vec3 x )
{
    vec3 p = floor(x);
    vec3 f = fract(x);
	f = f*f*(3.0-2.0*f);
    
	vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
    vec2 rg = textureLod( iChannel0, (uv+ 0.5)/256.0, 0. ).yx;
	return mix( rg.x, rg.y, f.z );
}

bool mask(vec3 p)
{
    //return noise(p*100.0+vec3(iTime))> 0.5;
    return noise(p*75.0+vec3(0.0, iTime, 0.0))> 0.5;
    
    float period = 0.1;
    //float period = 0.1 + 0.05*cos(iTime);
    vec3 disp = vec3(iTime)*0.01*vec3(3.0, 5.0, 7.0);
    p += disp;
    
    bool res;
    res =  mod(p.x, period)>0.5*period ;
    res = (mod(p.y, period)>0.5*period)?res:!res;
    res = (mod(p.z, period)>0.5*period)?res:!res;
    return res;
}

void intersectSphere(vec3 ro, vec3 rd, vec3 spherePosition, float sphereRadius, inout float t, out vec3 n)
{    
    float delta = pow(dot(rd, ro) - dot(spherePosition,rd), 2.0) - (dot(spherePosition, spherePosition)+dot(ro,ro)-20.*dot(spherePosition, ro)-sphereRadius*sphereRadius);
    
    if(delta < 0.0)
    	return;
    delta = sqrt(delta);
    float t1 = dot(spherePosition, rd) - dot(rd, ro) - delta;
    float t2 = t1 + 2.0*delta;
    
    float t_ = (t1 > 0.0 && mask(ro+t1*rd)) ? t1 : mask(ro+t2*rd) ? t2 : t;
    t = min(t, t_);
    n = normalize(ro+t*rd - spherePosition);
}

void intersectScene(
	vec3 rayOrigin,
	vec3 rayDir,
	inout float rayT,
	inout vec3 geomNormal)
{
	intersectSphere(rayOrigin, rayDir, SPHERE_POS, SPHERE_RAD, rayT, geomNormal);
}

void sampleEquiAngular(
	float u,
	float maxDistance,
	vec3 rayOrigin,
	vec3 rayDir,
	vec3 lightPos,
	out float dist,
	out float pdf)
{
	// get coord of closest point to light along (infinite) ray
	float delta = dot(lightPos - rayOrigin, rayDir);
	
	// get distance this point is from light
	float D = length(rayOrigin + delta*rayDir - lightPos);

	// get angle of endpoints
	float thetaA = atan(0.0 - delta, D);
	float thetaB = atan(maxDistance - delta, D);
	
	// take sample
	float t = D*tan(mix(thetaA, thetaB, u));
	dist = delta + t;
	pdf = D/((thetaB - thetaA)*(D*D + t*t));
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
	vec3 cw = normalize(ta-ro);
	vec3 cp = vec3(sin(cr), cos(cr),0.0);
	vec3 cu = normalize( cross(cw,cp) );
	vec3 cv = normalize( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (-iResolution.xy + 2.0*fragCoord.xy)/ iResolution.y;
    
	vec3 lightPos = vec3(0.0);
	vec3 lightIntensity = vec3(LIGHT_POWER);
	vec3 surfIntensity = vec3(SURFACE_ALBEDO/PI);
	vec3 particleIntensity = vec3(1.0/(4.0*PI));
    
    float phi = (iMouse.x-0.5)/iResolution.x * PI * 2.0;
    float psi = -((iMouse.y-0.5)/iResolution.y-0.5) * PI;
    
    if(iMouse.x<1.0 && iMouse.y < 1.0)
    {
        phi = iTime * PI * 2.0*0.1;
        psi = cos(iTime*PI*2.0*0.1)*PI*0.25;
    }
    
    vec3 cameraPosition = 2.0*vec3(cos(phi)*cos(psi), sin(psi), sin(phi)*cos(psi));
    vec3 cameraTarget = vec3(0.0);
    mat3 m = setCamera(cameraPosition, cameraTarget, 0.0);
	
	vec3 rayOrigin, rayDir;
    rayOrigin = cameraPosition;
    rayDir = m*normalize(vec3(p, 3.5));
	
	vec3 col = vec3(0.0);
	float t = DIST_MAX;
	{
		vec3 n;
		intersectScene(rayOrigin, rayDir, t, n);
		
		if (t < DIST_MAX) {
			// connect surface to light
			vec3 surfPos = rayOrigin + t*rayDir;
			vec3 lightVec = lightPos - surfPos;
			vec3 lightDir = normalize(lightVec);
			vec3 cameraDir = -rayDir;
			float nDotL = dot(n, lightDir);
			float nDotC = dot(n, cameraDir);
			
			// only handle BRDF if entry and exit are same hemisphere
			if (nDotL*nDotC > 0.0) 
            {
				float d = length(lightVec);
                float t2 = d;
                vec3 n2;
                vec3 rayDir = normalize(lightVec);
				intersectScene(surfPos + EPS*rayDir, rayDir, t2, n2);
                
                // accumulate surface response if not occluded
                if (t2 == d) {
					float trans = exp(-SIGMA*(d + t));
					float geomTerm = abs(nDotL)/dot(lightVec, lightVec);
					col = surfIntensity*lightIntensity*geomTerm*trans;
                }
			}
            else
            {
                col = vec3(0.02, 0.01, 0.0);
            }
		}
	}
	
	float offset = hash(fragCoord.y*iResolution.x + fragCoord.x + iTime);
	for (int stepIndex = 0; stepIndex < STEP_COUNT; ++stepIndex) {
		float u = (float(stepIndex)+offset)/float(STEP_COUNT);
		
		// sample along ray from camera to surface
		float x;
		float pdf;
		sampleEquiAngular(u, t, rayOrigin, rayDir, lightPos, x, pdf);
		
		// adjust for number of ray samples
		pdf *= float(STEP_COUNT);
		
		// connect to light and check shadow ray
		vec3 particlePos = rayOrigin + x*rayDir;
		vec3 lightVec = lightPos - particlePos;
		float d = length(lightVec);
		float t2 = d;
		vec3 n2;
		intersectScene(particlePos, normalize(lightVec), t2, n2);
		
		// accumulate particle response if not occluded
		if (t2 == d) {
			float trans = exp(-SIGMA*(d+x)*1.0);
			float geomTerm = 1.0/dot(lightVec, lightVec);
			col += SIGMA*particleIntensity*lightIntensity*geomTerm*trans/pdf*LIGHT_COLOR;
		}
	}
	
	col = pow(col, vec3(1.0/2.2));
	
	fragColor = vec4(col, 1.0);
}

