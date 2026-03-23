//TODO:
// * WASD to move the crosshairs by 1 pixel? If timedelta < 10fps, only move if 
//   iTime - iTimeDelta crosses a 100ms line so we have good control.
// * Add zoom. A single pixel is too small to get a good look at. I'd like to
//   have a way to zoom pixels to 4x4, 8x8, etc.

//It just mysteriously fails if you use "iTime" or "iResolution" for these names. Sucks.
float uniformTime;
vec3 uniformResolution;
int debug_trace_index;
bool debug_trace_occurred;
vec4 debug_trace_value;

const float reserved_float = -867.5309;

#define DEBUG 1
#if DEBUG

//DEBUG_TRACE will not overwrite a previously-traced value in the current frame.
#define DEBUG_TRACE(index, val) \
    do{\
        if(!debug_trace_occurred && index == debug_trace_index) {\
            debug_trace_value = val;\
            debug_trace_occurred = true;\
        }}while(false)
//DEBUG_RETRACE will overwrite any value already recorded for this property.
#define DEBUG_RETRACE(index, val) \
    do{\
        if(index == debug_trace_index) {\
            debug_trace_value = val;\
            debug_trace_occurred = true;\
        }}while(false)
#define DEBUG_INCREMENT(index, val) \
    do{\
        if(index == debug_trace_index) {\
            if(debug_trace_val.x == reserved_float) \
                debug_trace_val = val;\
            else\
                debug_trace_val += val;\
        }}while(false)
#else
#define DEBUG_TRACE(index, val) do{}while(false)
#define DEBUG_RETRACE(index, val) do{}while(false)
#endif

float sdRoundedBox( in vec3 p, in vec3 r) {
    return length(max(abs(p) - r, 0.0)) - 0.20;
}

float map( in vec3 p) {
	return sdRoundedBox(p, vec3(0.2, 0.2, 0.2));
}

vec3 calcNormal( in vec3 p ) // for function f(p)
{
    const float eps = 0.0001; // or some other value
    const vec2 h = vec2(eps,0);
    vec3 normal = normalize( 
        vec3(map(p+h.xyy) - map(p-h.xyy),
             map(p+h.yxy) - map(p-h.yxy),
             map(p+h.yyx) - map(p-h.yyx) ) );
    return normal;
}

void render(out vec4 fragColor, in vec2 fragCoord, in vec3 resolutionIn, in float timeIn)
{
    uniformResolution = resolutionIn;
    uniformTime = timeIn;

    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = (fragCoord/uniformResolution.xy - 0.5) * 1.0;

    uv.y /= uniformResolution.x/uniformResolution.y;

	vec3 view_plane = vec3(vec2(0.0) + (uv * 3.0), 0.0);
    float view_plane_scale = 2.0;
    vec3 cam_position = vec3(4.0 * sin(uniformTime), 3.0 + sin(uniformTime), 4.0*cos(uniformTime));
    vec3 cam_lookat = vec3(0.0);
    vec3 cam_direction = cam_lookat - cam_position;
    vec3 cam_up = vec3(0.0, 1.0, 0.0); // This is only approximate. We'll fix it in a second.
    vec3 cam_right = normalize(cross(cam_up, cam_direction));
    cam_up = normalize(cross(cam_direction, cam_right));
    
    vec3 ray_direction = normalize(
        cam_direction + view_plane_scale * cam_up * uv.y + view_plane_scale * cam_right * uv.x);
    vec3 ray_pos = cam_position;
    float dist;
    float i;
    float total_dist = 0.0;
    for(i=0.0; i<100.0; i+=1.0) {
        dist = map(ray_pos);
        if(dist < 0.0001 || dist > 1000.0) {
            break;
        }
        total_dist += dist;
        ray_pos += ray_direction * (dist * 0.999);
    }
    DEBUG_TRACE(2, vec4(total_dist));
    DEBUG_TRACE(3, vec4(i));
    vec3 col;
    if(dist < 1000.0) {
        vec3 normal = calcNormal(ray_pos);
        DEBUG_TRACE(0, vec4(normal, 1.0));
        col = normal;
    } else {
        col = vec3(0.0);
    }
    col = max(col, 0.0);
    // Output to screen
    fragColor = vec4(col,1.0);
    DEBUG_TRACE(1, fragColor);
}
