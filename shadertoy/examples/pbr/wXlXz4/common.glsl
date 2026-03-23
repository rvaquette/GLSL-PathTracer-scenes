const float PI = 3.14159265358;

// Units are in megameters.
const float groundRadiusMM = 6371.;
const float atmosphereRadiusMM = 6471.;

const vec2 tLUTRes = vec2(256.0, 64.0)*1.;
const vec2 msLUTRes = vec2(32.0, 32.0)*1.;
const vec2 skyLUTRes = vec2(640.0, 360.0)*1.;

const vec3 groundAlbedo = vec3(0.1);

// These are per megameter.
// - Rayleigh and ozone parameters corrected from original values
//   using [ARPC](https://github.com/FarukEroglu2048/ARPC)
//const vec3 rayleighScatteringBase = vec3(5.802, 13.558, 33.1)*1e-3;
const vec3 rayleighScatteringBase = vec3(6.605, 12.344, 29.412)*1e-3;
const float rayleighAbsorptionBase = 0.0;

const float mieScatteringBase = 3.996*1e-3;
const float mieAbsorptionBase = 4.4*1e-3;

//const vec3 ozoneAbsorptionBase = vec3(0.650, 1.881, .085)*1e-3;
const vec3 ozoneAbsorptionBase = vec3(2.29, 1.540, .00)*1e-3;

// Quality
const float sunTransmittanceSteps = 40.0;
const float mulScattSteps = 20.0;
const int sqrtSamples = 8;

const int numScatteringSteps = 16;

/*
 * Animates the sun movement.
 */
float getSunAltitude(float time)
{
    const float periodSec = 60.0;
    return (PI)*time/periodSec - PI/24.;
}
vec3 getSunDir(float time)
{
    float altitude = getSunAltitude(time);
    return normalize(vec3(0.0, sin(altitude), -cos(altitude)));
}

/* Animate camera */
vec3 getViewPos(float time){

    vec3 viewPos = vec3(0.0, groundRadiusMM + 0.0002*1000., 0.0);

    // anything beyond about 7 falls apart because the skyview lut doesn't have enough resolution
    float alt_range = 50.0;
    
    viewPos.y += (sin(time/20.0 - PI/2.)*.5+.5) * (atmosphereRadiusMM - groundRadiusMM) * alt_range;

    return viewPos;
}


float getMiePhase(float cosTheta) {
    const float g = 0.8;
    const float scale = 3.0/(8.0*PI);

    float num = (1.0-g*g)*(1.0+cosTheta*cosTheta);
    float denom = (2.0+g*g)*pow((1.0 + g*g - 2.0*g*cosTheta), 1.5);

    return scale*num/denom;
}

float getRayleighPhase(float cosTheta) {
    const float k = 3.0/(16.0*PI);
    return k*(1.0+cosTheta*cosTheta);
}

void getScatteringValues(vec3 pos,
                         out vec3 rayleighScattering,
                         out float mieScattering,
                         out vec3 extinction) {
    float altitudeKM = (length(pos)-groundRadiusMM);//*1000.0;
    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM/8.0);
    float mieDensity = exp(-altitudeKM/1.2);

    rayleighScattering = rayleighScatteringBase*rayleighDensity;
    float rayleighAbsorption = rayleighAbsorptionBase*rayleighDensity;

    mieScattering = mieScatteringBase*mieDensity;
    float mieAbsorption = mieAbsorptionBase*mieDensity;

    vec3 ozoneAbsorption = ozoneAbsorptionBase*max(0.0, 1.0 - abs(altitudeKM-40.179)/17.83);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}

float safeacos(const float x) {
    return acos(clamp(x, -1.0, 1.0));
}

// From https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code.
float rayIntersectSphere(vec3 ro, vec3 rd, float rad) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - rad*rad;
    if (c > 0.0f && b > 0.0) return -1.0;
    float discr = b*b - c;
    if (discr < 0.0) return -1.0;
    // Special case: inside sphere, use far discriminant
    if (discr > b*b) return (-b + sqrt(discr));
    return -b - sqrt(discr);
}

// From https://www.shadertoy.com/view/wlBXWK
vec2 rayIntersectSphere2D(
    vec3 start, // starting position of the ray
    vec3 dir, // the direction of the ray
    float radius // and the sphere radius
) {
    // ray-sphere intersection that assumes
    // the sphere is centered at the origin.
    // No intersection when result.x > result.y
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, start);
    float c = dot(start, start) - (radius * radius);
    float d = (b*b) - 4.0*a*c;
    if (d < 0.0) return vec2(1e5,-1e5);
    return vec2(
        (-b - sqrt(d))/(2.0*a),
        (-b + sqrt(d))/(2.0*a)
    );
}


/*
 * Same parameterization here.
 */
vec3 getValFromTLUT(sampler2D tex, vec2 bufferRes, vec3 pos, vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;
	float sunCosZenithAngle = dot(sunDir, up);
    vec2 uv = vec2(tLUTRes.x*clamp(0.5 + 0.5*sunCosZenithAngle, 0.0, 1.0),
                   tLUTRes.y*clamp((height - groundRadiusMM)/(atmosphereRadiusMM - groundRadiusMM),0.,1.));
    uv /= bufferRes;
    return texture(tex, uv).rgb;
}
vec3 getValFromMultiScattLUT(sampler2D tex, vec2 bufferRes, vec3 pos, vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;
	float sunCosZenithAngle = dot(sunDir, up);
    vec2 uv = vec2(msLUTRes.x*clamp(0.5 + 0.5*sunCosZenithAngle, 0.0, 1.0),
                   msLUTRes.y*max(0.0, min(1.0, (height - groundRadiusMM)/(atmosphereRadiusMM - groundRadiusMM))));
    uv /= bufferRes;
    return texture(tex, uv).rgb;
}

/* 
 * Do raymarching : builds skyview lut inside atmoshpere, raymarches directly outside atmosphere
*/


vec3 raymarchScattering(sampler2D TLUT, vec2 TLUT_size, sampler2D MSLUT, vec2 MSLUT_size,
                              vec3 viewPos,
                              vec3 rayDir,
                              vec3 sunDir,
                              float numSteps) {
                              
                              
    vec2 atmos_intercept = rayIntersectSphere2D(viewPos, rayDir, atmosphereRadiusMM);
    float terra_intercept = rayIntersectSphere(viewPos, rayDir, groundRadiusMM);

    float mindist, maxdist;

    if (atmos_intercept.x < atmos_intercept.y){
        // there is an atmosphere intercept!
        // start at the closest atmosphere intercept
        // trace the distance between the closest and farthest intercept
        mindist = atmos_intercept.x > 0.0 ? atmos_intercept.x : 0.0;
		maxdist = atmos_intercept.y > 0.0 ? atmos_intercept.y : 0.0;
    } else {
        // no atmosphere intercept means no atmosphere!
        return vec3(0.0);
    }

    // if in the atmosphere start at the camera
    if (length(viewPos) < atmosphereRadiusMM) mindist=0.0;


    // if there's a terra intercept that's closer than the atmosphere one,
    // use that instead!
    if (terra_intercept > 0.0){ // confirm valid intercepts			
        maxdist = terra_intercept;
    }

    // start marching at the min dist
    vec3 pos = viewPos + mindist * rayDir;
                              
    float cosTheta = dot(rayDir, sunDir);

	float miePhaseValue = getMiePhase(cosTheta);
	float rayleighPhaseValue = getRayleighPhase(-cosTheta);

    vec3 lum = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    float t = 0.0;
    for (float i = 0.0; i < numSteps; i += 1.0) {
        float newT = ((i + 0.3)/numSteps)*(maxdist-mindist);
        float dt = newT - t;
        t = newT;

        vec3 newPos = pos + t*rayDir;

        vec3 rayleighScattering, extinction;
        float mieScattering;
        
        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

        vec3 sampleTransmittance = exp(-dt*extinction);

        vec3 sunTransmittance = getValFromTLUT(TLUT, TLUT_size, newPos, sunDir);
        vec3 psiMS = 0.0*getValFromMultiScattLUT(MSLUT, MSLUT_size, newPos, sunDir);

        vec3 rayleighInScattering = rayleighScattering*(rayleighPhaseValue*sunTransmittance + psiMS);
        vec3 mieInScattering = mieScattering*(miePhaseValue*sunTransmittance + psiMS);
        vec3 inScattering = (rayleighInScattering + mieInScattering);

        // Integrated scattering within path segment.
        vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        lum += scatteringIntegral*transmittance;

        transmittance *= sampleTransmittance;
    }
    return lum;
}

