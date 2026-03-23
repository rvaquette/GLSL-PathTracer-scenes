/*
 * Modified version of Andrew Helmer's https://www.shadertoy.com/view/slSXRW 
 * implementation of Sebastian Hillare's Unreal engine sky-atmosphere
 * ... still doesn't implement aerial perspective lut, just makes space views possible
* TODO: replace sunflare with something new that works
        allow density profiles, and thicker atmospheres (fails beyond 7.1 right now)
 */

/*
 * Final output basically looks up the value from the skyLUT, and then adds a sun on top,
 * does some tonemapping.
 */
vec3 getValFromSkyLUT(vec3 rayDir, vec3 sunDir) {

    vec3 viewPos = getViewPos(iTime);
    float height = length(viewPos);
    vec3 up = viewPos / height;

    float horizonAngle = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height);
    float altitudeAngle = horizonAngle - acos(dot(rayDir, up)); // Between -PI/2 and PI/2
    float azimuthAngle; // Between 0 and 2*PI

    vec3 right = cross(sunDir, up);
    vec3 forward = cross(up, right);

    vec3 projectedDir = normalize(rayDir - up*(dot(rayDir, up)));
    float sinTheta = dot(projectedDir, right);
    float cosTheta = dot(projectedDir, forward);
    azimuthAngle = atan(sinTheta, cosTheta) + PI;

    // Non-linear mapping of altitude angle. See Section 5.3 of the paper.
    float v = 0.5 + 0.5*sign(altitudeAngle)*sqrt(abs(altitudeAngle)*2.0/PI);
    vec2 uv = vec2(azimuthAngle / (2.0*PI), v);
    uv *= skyLUTRes;
    uv /= iChannelResolution[1].xy;

    return texture(iChannel1, uv).rgb;
}

vec3 jodieReinhardTonemap(vec3 c){
    // From: https://www.shadertoy.com/view/tdSXzD
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (c + 1.0);
    return mix(c / (l + 1.0), tc, tc);
}

vec3 sunWithBloom(vec3 rayDir, vec3 sunDir) {
    const float sunSolidAngle = 0.53*PI/180.0;
    const float minSunCosTheta = cos(sunSolidAngle);

    float cosTheta = dot(rayDir, sunDir);
    if (cosTheta >= minSunCosTheta) return vec3(1.0);

    float offset = minSunCosTheta - cosTheta;
    float gaussianBloom = exp(-offset*50000.0)*0.5;
    float invBloom = 1.0/(0.02 + offset*300.0)*0.01;
    return vec3(gaussianBloom+invBloom);
}

vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

mat4 viewMatrix(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat4(
        vec4(s, 0.0),
        vec4(u, 0.0),
        vec4(-f, 0.0),
        vec4(0.0, 0.0, 0.0, 1)
    );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 sunDir = getSunDir(iTime);
   
    vec3 viewPos = getViewPos(iTime);
    
    float fov = 35.0;
    vec2 ang = (iMouse.xy / iResolution.xy) * 3.1415;
    ang.x *= 2.0;

	vec3 viewDir = rayDirection(fov, iResolution.xy, fragCoord);
    vec3 eye = vec3(6.0 * cos(ang.x), 6.0 * cos(ang.y), 6.0 * sin(ang.x));
    mat4 viewToWorld = viewMatrix(eye, vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0));
    
    vec3 camDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;

    float camFOVWidth = fov * PI/180.0;

    float camWidthScale = 2.0*tan(camFOVWidth/2.0);
    float camHeightScale = camWidthScale*iResolution.y/iResolution.x;

    vec3 camRight = normalize(cross(camDir, vec3(0.0, 1.0, 0.0)));
    vec3 camUp = normalize(cross(camRight, camDir));

    vec2 xy = 2.0 * (fragCoord.xy / iResolution.xy) - 1.0;
    vec3 rayDir = normalize(camDir + camRight*xy.x*camWidthScale + camUp*xy.y*camHeightScale);

    vec3 lum;

    if (length(viewPos) < atmosphereRadiusMM * 1.0){
        lum = getValFromSkyLUT(rayDir, sunDir);
    } else {
    
        // As mentioned in section 7 of the paper, switch to direct raymarching outside atmosphere
        lum = raymarchScattering(iChannel0, iChannelResolution[0].xy,
                                 iChannel2, iChannelResolution[2].xy,
                                 viewPos, rayDir, sunDir, float(numScatteringSteps));
        
        // This little bit of red helps to debug when the rendering switches to pure raymarching
        //lum += vec3(1e-3,0.0,0.0);
    }

    // Tonemapping and gamma. Super ad-hoc, probably a better way to do this.
    lum *= 100.0;
    lum = jodieReinhardTonemap(lum);
    lum = pow(lum, vec3(1.0/2.2));

    fragColor = vec4(lum,1.0);

    // Peek at the Transmittance LUT
    //fragColor = vec4(100.*texture(iChannel0, fragCoord.xy/iResolution.xy).rgb,1.0);

    // Peek at the Sky View LUT
    //fragColor = vec4(80.*texture(iChannel1, fragCoord.xy/iResolution.xy).rgb,1.0);

    // Peek at the Multiscattering LUT
    //fragColor = vec4(100.*texture(iChannel2, fragCoord.xy/iResolution.xy).rgb,1.0);
}

