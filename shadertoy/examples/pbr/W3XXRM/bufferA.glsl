// Modified by HK-SHAO - 2022

// Upgraded from genis sole - 2016
// License Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International.

#define store(P, V) if (all(equal(ivec2(fragCoord), P))) fragColor = V
#define key(K)  texelFetch(iChannel0, ivec2(K, 0), 0).x
#define load(P) texelFetch(iChannel1, ivec2(P), 0)

// Keyboard constants definition
const int KEY_W     = 87;
const int KEY_A     = 65;
const int KEY_S     = 83;
const int KEY_D     = 68;
const int KEY_E     = 69;
const int KEY_Q     = 81;
const int KEY_SHIFT = 16;
const int KEY_SP    = 32;

vec3 KeyboardInput() {
	vec3 i = vec3(key(KEY_D) - key(KEY_A), 
                  key(KEY_E) - key(KEY_Q),
                  key(KEY_S) - key(KEY_W));
    
    float n = abs(abs(i.x) - abs(i.y));
    return i * (n + (1.0 - n)*inversesqrt(2.0));
}

vec3 CameraDirInput(vec2 m) {
    return CameraRotation(m) * KeyboardInput();
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {   
    if (any(greaterThan(ivec2(fragCoord), MEMORY_BOUNDARY))) discard;
    
    fragColor = load(fragCoord);
    
    if (iFrame == 0) {
        store(POSITION, vec4(0.0, 0.2, 4.0, 0.0));
        store(ROTATION, vec4(0.0));
        
        store(TARGET,   vec4(0.0, -0.2, 4.0, 0.0));
        store(TMOUSE,   vec4(0.0));
        store(PMOUSE,   vec4(0.0));
        
        return;
    }

    vec2 resolution  = load(RESOLUTION).xy;
    
    vec3 position    = load(POSITION).xyz;
    vec2 rotation    = load(ROTATION).xy;

    vec3 target      = load(TARGET).xyz;
    vec3 tm          = load(TMOUSE).xyz;
    vec2 pm          = load(PMOUSE).xy;
    
    float dt = clamp(iTimeDelta, 0.0, 0.1);
    
    const float rt_acc = 16.0;
    const float mv_acc = 5.0;
    float velocity =  5.0 + 15.0 * key(KEY_SHIFT);
    
    rotation += (tm.xy - rotation) * dt * rt_acc;
    target   += CameraDirInput(rotation) * dt * velocity;
    position += (target - position) * dt * mv_acc;
    
    bvec4 moving = bvec4(
        length(tm.xy - rotation) * iResolution.x > 1.0,
        length(target - position) * iResolution.x > 1.0,
        any(notEqual(resolution, iResolution.xy)),
        key(KEY_SP) > 0.0
    );
    
    store(TARGET,     vec4(target, 0.0));
    store(POSITION,   vec4(position, 0.0));
    store(ROTATION,   vec4(rotation, 0.0, 0.0));
    store(RESOLUTION, vec4(iResolution.xy, 0.0, 0.0));
    store(MOVING,     vec4(any(moving), 0.0, 0.0, 0.0));
    
	if (iMouse.z > 0.0) {
        vec2 new_tm  = pm + (abs(iMouse.zw) - iMouse.xy) / iResolution.x;
        
        float clamp_y = float(new_tm.y > -PI*0.5+0.01 && new_tm.y < PI*0.5-0.01);
        new_tm.y = mix(tm.y, new_tm.y, clamp_y);
        
        store(TMOUSE, vec4(new_tm, 1.0, 0.0));
	} else if (tm.z != 0.0) {
        store(PMOUSE, vec4(tm.xy, 0.0, 0.0));
    }

}
