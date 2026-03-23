// distance function for a sphere centered at (0, 0, -2)
float sphereSDF(vec3 p, float radius) {
    return length(p) - radius;
}

// raymarching function
float raymarch(vec3 ro, vec3 rd) {
    float dist = 0.0;
    float maxDist = 20.0;
    int maxSteps = 100;
    float hitThreshold = 0.001;

    for (int i = 0; i < maxSteps; i++) {
        vec3 p = ro + dist * rd;
        float d = sphereSDF(p, 1.0); // our sphere radius 1.0
        if (d < hitThreshold) {
            return dist;
        }
        dist += d;
        if (dist > maxDist) break;
    }
    return -1.0;
}

// normal calculation using SDF
vec3 calcNormal(vec3 p) {
    float h = 0.001;
    vec2 k = vec2(1.0, -1.0);
    return normalize(
        k.xyy * sphereSDF(p + k.xyy * h, 1.0) +
        k.yyx * sphereSDF(p + k.yyx * h, 1.0) +
        k.yxy * sphereSDF(p + k.yxy * h, 1.0) +
        k.xxx * sphereSDF(p + k.xxx * h, 1.0)
    );
}

// main shader function
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;

    // set up camera position and direction
    vec3 ro = vec3(0.0, 0.0, 3.0); // camera position
    vec3 rd = normalize(vec3(uv, -1.5)); // ray direction

    // raymarching to find distance to the sphere
    float dist = raymarch(ro, rd);
    if (dist > 0.0) {
        vec3 p = ro + dist * rd;
        vec3 normal = calcNormal(p);

        // rresnel Rim Effect
        vec3 viewDir = normalize(ro - p);
        float fresnel = pow(1.0 - dot(normal, viewDir), 2.0); // fresnel factor for rim light
        vec3 rimColor = vec3(0.2, 0.6, 1.0); // rim color
        float rimIntensity = 3.0; // rim glow intensity

        // final color calculation with rim lighting
        vec3 color = mix(vec3(0.1, 0.1, 0.1), rimColor * fresnel * rimIntensity, fresnel);
        fragColor = vec4(color, 1.0);
    } else {
        // background color
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}

