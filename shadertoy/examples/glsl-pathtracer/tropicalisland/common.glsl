#define OPT_SHADERTOY_LIGHT // Use to enable the "light" version of the shader, which prints some info text instead of rendering the pathtracer.
                            // Comment out to disable and render the pathtracer as normal.

#define OPT_SHADERTOY

// START_COMMON_CODE
#define OPT_USE_MESHDATA_BLOB
        
#define OPT_ENVMAP
#define OPT_RR
#define OPT_RR_DEPTH 2
#define OPT_OPENGL_NORMALMAP
#define OPT_ALPHA_TEST
#define OPT_MEDIUM
#define OPT_VOL_MIS
// END_COMMON_CODE

#define CAMERA_DATA_POS 0
#define CAMERA_DATA_VEC4_COUNT 9
#ifdef OPT_USE_MESHDATA_BLOB
#define MESH_DATA_OFFSET 0
#else
#define MESH_DATA_OFFSET (CAMERA_DATA_POS+CAMERA_DATA_VEC4_COUNT)
#endif

#define isMouseDown (iMouse.z > 0.)

struct Camera3D
{
    vec3 position;
    vec3 pivot;
    vec3 worldUp;
    float pitch; float yaw; float radius;
    float fov; float focalDist; float aperture;
    vec3 forward;
    vec3 right;
    vec3 up; bool initialized; 
    vec2 mouseXY;
};

vec4[CAMERA_DATA_VEC4_COUNT] getCameraData(Camera3D camera3d) {
    vec4 data[CAMERA_DATA_VEC4_COUNT] = vec4[](
        vec4(camera3d.position, 0.),
        vec4(camera3d.pivot, 0.),
        vec4(camera3d.worldUp, 0.),
        vec4(camera3d.pitch, camera3d.yaw, camera3d.radius, 0.),
        vec4(camera3d.fov, camera3d.focalDist, camera3d.aperture, 0.),
        vec4(camera3d.forward, 0.),
        vec4(camera3d.right, 0.),
        vec4(camera3d.up, camera3d.initialized ? 1. : 0.),
        vec4(camera3d.mouseXY, 0., 0.)
    );
    return data;
}

Camera3D getCamera(sampler2D sampler) {
    vec4 data[CAMERA_DATA_VEC4_COUNT] = vec4[](
        texelFetch(sampler, ivec2(CAMERA_DATA_POS + 0, 0), 0),
        texelFetch(sampler, ivec2(CAMERA_DATA_POS + 1, 0), 0),
        texelFetch(sampler, ivec2(CAMERA_DATA_POS + 2, 0), 0),
        texelFetch(sampler, ivec2(CAMERA_DATA_POS + 3, 0), 0),
        texelFetch(sampler, ivec2(CAMERA_DATA_POS + 4, 0), 0),
        texelFetch(sampler, ivec2(CAMERA_DATA_POS + 5, 0), 0),
        texelFetch(sampler, ivec2(CAMERA_DATA_POS + 6, 0), 0),
        texelFetch(sampler, ivec2(CAMERA_DATA_POS + 7, 0), 0),
        texelFetch(sampler, ivec2(CAMERA_DATA_POS + 8, 0), 0)
    );
    
    Camera3D camera3d;
    
    camera3d.position = data[0].xyz;
    camera3d.pivot = data[1].xyz;
    camera3d.worldUp = data[2].xyz;
    camera3d.pitch = data[3].x;
    camera3d.yaw = data[3].y;
    camera3d.radius = data[3].z;
    camera3d.fov = data[4].x;
    camera3d.focalDist = data[4].y;
    camera3d.aperture = data[4].z;
    camera3d.forward = data[5].xyz;
    camera3d.right = data[6].xyz;
    camera3d.up = data[7].xyz;
    camera3d.initialized = data[7].w > 0.;
    camera3d.mouseXY = data[8].xy;
    
    return camera3d;
}

