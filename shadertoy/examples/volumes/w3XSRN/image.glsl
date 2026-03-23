// ========================
// Marching through volume
// ========================

#define DATA(lmn) texture(iChannel0, vcubeFromLMN(2, lmn)).st

vec2 getDataInterp(vec3 lmn) {
    vec3 flmn = floor(lmn);

    vec2 d000 = DATA( flmn );
    vec2 d001 = DATA( flmn + vec3(0.0, 0.0, 1.0) );
    vec2 d010 = DATA( flmn + vec3(0.0, 1.0, 0.0) );
    vec2 d011 = DATA( flmn + vec3(0.0, 1.0, 1.0) );
    vec2 d100 = DATA( flmn + vec3(1.0, 0.0, 0.0) );
    vec2 d101 = DATA( flmn + vec3(1.0, 0.0, 1.0) );
    vec2 d110 = DATA( flmn + vec3(1.0, 1.0, 0.0) );
    vec2 d111 = DATA( flmn + vec3(1.0, 1.0, 1.0) );

    vec3 t = lmn - flmn;
    return mix(
        mix(mix(d000, d100, t.x), mix(d010, d110, t.x), t.y),
        mix(mix(d001, d101, t.x), mix(d011, d111, t.x), t.y),
        t.z
    );
}

void readLMN(in vec3 lmn, out float density, out float lightAmount) {
    #ifdef SMOOTHING
    	vec2 data = getDataInterp(lmn);
    #else
    	vec2 data = DATA(lmn);
    #endif

    bool noLight = texelFetch(iChannel2, ivec2(KEY_S,0), 0).x > 0.5;
    lightAmount = noLight ? 1.0 : data.t;
    lightAmount = mix(lightAmount, 1.0, 0.025);

    // density = fDensity(iChannel1, lmn, iTime);
    density = data.s;
}

vec4 march(vec3 p, vec3 nv, vec2 fragCoord) {
    vec2 tRange;
    float didHitBox;
    boxClip(BOX_MIN, BOX_MAX, p, nv, tRange, didHitBox);
    tRange.s = max(0.0, tRange.s);

    vec4 color = vec4(0.0);
    if (didHitBox < 0.5) {
        return color;
    }
    
    bool noColor = texelFetch(iChannel2, ivec2(KEY_A,0), 0).x > 0.5;
	bool noDensity = texelFetch(iChannel2, ivec2(KEY_D,0), 0).x > 0.5;
    
    float t = tRange.s + min(tRange.t-tRange.s, RAY_STEP)*hash12(fragCoord);
    int i=0;
    for (; i<150; i++) { // Theoretical max steps: (BOX_MAX-BOX_MIN)*sqrt(3)/RAY_STEP
        if (t > tRange.t || color.a > QUIT_ALPHA) { break; }

        vec3 rayPos = p + t*nv;
        vec3 lmn = lmnFromWorldPos(rayPos);

        float density;
        float lightAmount;
        readLMN(lmn, density, lightAmount);

        vec3 cfrag = noColor ? vec3(1.0) : colormap(0.7*density+0.8);
        density = noDensity ? 0.1 : density;

        float calpha = density * MAX_ALPHA_PER_UNIT_DIST * RAY_STEP;
        vec4 ci = clamp( vec4(cfrag * lightAmount, 1.0)*calpha, 0.0, 1.0);
        color = blendOnto(color, ci);

        t += RAY_STEP;
    }

    float finalA = clamp(color.a/QUIT_ALPHA, 0.0, 1.0);
    color *= (finalA / (color.a + 1e-5));

    bool showSteps = texelFetch(iChannel2, ivec2(KEY_F,0), 0).x > 0.5;
    return showSteps ? vec4(vec3(float(i)/150.0), 1.0) : color;
}

// ================
// Final rendering
// ================

#define RES iResolution
#define TAN_HALF_FOVY 0.5773502691896257
#define VIGNETTE_INTENSITY 0.25

vec3 skybox(vec3 nvDir) {
    return ( mix(0.1, 0.2, smoothstep(-0.2,0.2, nvDir.y)) )*vec3(1.0);
}

vec3 nvCamDirFromClip(vec3 nvFw, vec2 clip) {
    vec3 nvRt = normalize(cross(nvFw, vec3(0.,1.,0.)));
    vec3 nvUp = cross(nvRt, nvFw);
    return normalize(TAN_HALF_FOVY*(clip.x*(RES.x/RES.y)*nvRt + clip.y*nvUp) + nvFw);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Camera
    float isMousePressed = clamp(iMouse.z, 0.0, 1.0);
    vec2 mouseAng = mix(
        vec2(CAM_THETA, CAM_PHI),
        PI * vec2(4.0*iMouse.x, iMouse.y) / iResolution.xy,
        isMousePressed
    );

    vec3 camPos = 2.5 * SPHERICAL(mouseAng.x, mouseAng.y);
    vec3 lookTarget = vec3(0.0);

	vec3 nvCamFw = normalize(lookTarget - camPos);
    vec3 nvCamDir = nvCamDirFromClip(nvCamFw, uv*2. - 1.);

    // Render
    vec3 bgColor = skybox(nvCamDir);
    vec4 fgColor = march(camPos, nvCamDir, fragCoord);
    vec3 finalColor = blendOnto(fgColor, vec4(bgColor, 1.0)).rgb;

    // Vignette
    vec2 radv = vec2(0.5, 0.5) - uv;
    float dCorner = length(radv) / INV_SQRT_2;
    float vignetteFactor = 1.0 - mix(0.0, VIGNETTE_INTENSITY, smoothstep(0.4, 0.9, dCorner));

    fragColor = vec4(vignetteFactor * finalColor, 1.0);
}

