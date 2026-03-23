// MIT Licensed

// ==================== Shape Stuff ==================== 

float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float smoothMin(float d1, float d2, float k) {
    float h = max(k - abs(d1 - d2), 0.0) / k;
    return min(d1, d2) - h * h * h * k / 6.0;
}

float sampleDensity(vec3 p) {
    p.y += 2.0;
    // Create base shape - a torus
    float torus = sdTorus(p, vec2(2.0, 0.5));
    
    // Add floating spheres around the torus
    float spheres = 999999.0;
    for(int i = 0; i < 6; i++) {
        float a = float(i) * 3.14159 * 2.0 / 6.0;
        vec3 offset = vec3(cos(a) * 2.0, sin(iTime + float(i)), sin(a) * 2.0);
        float sphere = sdSphere(p - offset, 0.3);
        spheres = min(spheres, sphere);
    }
    
    // Add a center piece
    vec3 boxP = p;
    boxP.y *= 1.0 + 0.3 * sin(iTime);  // Stretch/squish animation
    float box = sdBox(boxP, vec3(0.7));
    
    // Combine everything with smooth min
    float d = smoothMin(torus, spheres, 1.0);
    d = smoothMin(d, box, 1.0);
    
    // Convert distance to density (negative distance = inside shape)
    return -d;
}

// ==================== End Of Shape Stuff ==================== 

// ==================== Camera Stuff ==================== 

mat3 getCameraMatrix(vec3 ro, vec3 lookAt) {
    vec3 forward = normalize(lookAt - ro);
    vec3 right = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
    vec3 up = normalize(cross(right, forward));
    return mat3(right, up, forward);
}

void getRoRd(vec2 fragCoord, out vec3 ro, out vec3 rd)
{    
    vec2 uv = fragCoord/iResolution.xy;
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    
    // Orbit camera controls
    vec2 mouse = iMouse.xy/iResolution.xy;
    float camDist = 5.0;
    
    // If mouse isn't being used, auto-rotate
    if (iMouse.z <= 0.0) {
        mouse = vec2(0.5 + 0.5*cos(0.2*iTime), 0.5);
    }
    
    // Convert mouse position to spherical coordinates
    float azimuth = (mouse.x * 2.0 - 1.0) * 3.141592;
    float elevation = (mouse.y - 0.5) * 3.141592;
    
    // Calculate camera position
    ro = vec3(
        camDist * cos(elevation) * cos(azimuth),
        camDist * sin(elevation),
        camDist * cos(elevation) * sin(azimuth)
    );
    
    // Look at origin
    vec3 lookAt = vec3(0.0, -2.0, 0.0);
    mat3 camMat = getCameraMatrix(ro, lookAt);
    rd = camMat * normalize(vec3(p, 2.0));

}

// ==================== End Of Camera Stuff ==================== 

const float DensityMultiplier = 2.0;
const float ShadowMultiplier = 15.0;

float sampleLight(vec3 pos, vec3 lightDir, float jitter) {
    
    // Sample fewer steps for light than main ray for performance
    const int LIGHT_STEPS = 32;
    const float MAX_LIGHT_DIST = 2.0;
    float stepSize = MAX_LIGHT_DIST / float(LIGHT_STEPS);
    
    // March towards light
    vec3 p = pos + (lightDir * jitter * stepSize);
    float totalDensity = 0.0;
    for(int i = 0; i < LIGHT_STEPS; i++) {
        float density = sampleDensity(p);
        if(density > 0.0)
        {
            totalDensity += density * DensityMultiplier * ShadowMultiplier * stepSize;
            p += lightDir * stepSize;
        }
        else
        {
            // Density is also the distance we are to surface.... lets do a cheecky skip
            int stepsToSkip = max(1, int(floor(-density / stepSize)));
            p += lightDir * stepSize * float(stepsToSkip);
            i += stepsToSkip - 1;
        }
    }
    
    return totalDensity;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 ro;
    vec3 rd;
    getRoRd(fragCoord, ro, rd);
    
    // Sun direction
    vec3 sunDir = normalize(vec3(0.5, 0.2, -0.3));
    vec3 sunColor = vec3(1.0, 0.9, 0.7); // Warm, bright sun
    
    // Per-channel scattering coefficients
    vec3 scatteringCoeff = vec3(0.3, 1.64, 2.28);
    
    // Raymarch parameters
    const int MAX_STEPS = 32;
    const float MAX_DIST = 6.5;
    float stepSize = MAX_DIST/float(MAX_STEPS);
    
    vec3 acc = vec3(0.0);
    float totalDensity = 0.0;
    
    // Jitter the start position with blue noise
    float blueNoise = texture(iChannel0, fragCoord / 1024.0f).r;
    vec3 pos = ro + (rd * stepSize * blueNoise);
    // We can start the ray a little closer
    pos += (rd * 1.5);
    
    // Raymarch loop
    for(int i = 0; i < MAX_STEPS; i++) {
    
        float density = sampleDensity(pos);
        
        if(density > 0.0) 
        {
            density *= DensityMultiplier * stepSize;
            totalDensity += density;
            
            // Calculate inscattering with shadows
            float sunRayDensity = sampleLight(pos, sunDir, blueNoise);
            vec3 inscatter = exp(-sunRayDensity * scatteringCoeff) * density * scatteringCoeff;
            
            acc += inscatter * exp(-totalDensity * scatteringCoeff);
            
            pos += rd * stepSize;
        }
        else
        {
            // Density is also the distance we are to surface.... lets do a cheecky skip
            int stepsToSkip = max(1, int(floor(-density / stepSize)));
            pos += rd * stepSize * float(stepsToSkip);
            i += stepsToSkip - 1;
        }
    }
    
    vec3 col = acc * 4.0;
    col.rgb = (col.rgb * (2.51 * col.rgb + 0.03)) / (col.rgb * (2.43 * col.rgb + 0.59) + 0.14);
    col = pow(col, vec3(0.4545));
    
    fragColor = vec4(col, 1.0);
}
