// START_BUFFERA_CODE
vec3 eye = vec3(-0.031890, 1.005752, 6.110609);
vec3 lookat = vec3(-0.031890, 1.005752, -0.722523);
float fov = 45.000000;
// END_BUFFERA_CODE

//-------------------------- Camera ---------------------------

#define PI         3.14159265358979323

#define altPressed     (texelFetch(iChannel1, ivec2(18,0),0).x > 0.)

void updateCamera(inout Camera3D camera3d) {
    float radYaw = camera3d.yaw * PI / 180.;
    float radPitch = camera3d.pitch * PI / 180.;
    vec3 forwardTemp = vec3(
        cos(radYaw) * cos(radPitch),
        sin(radPitch),
        sin(radYaw) * cos(radPitch)
    );
    camera3d.forward = normalize(forwardTemp);
    camera3d.position = camera3d.pivot + (camera3d.forward * (-camera3d.radius));
    camera3d.right = normalize(cross(camera3d.forward, camera3d.worldUp));
    camera3d.up = normalize(cross(camera3d.right, camera3d.forward));
}
    
Camera3D createCamera() {
    Camera3D camera3d;
    
    camera3d.position = eye;
    camera3d.pivot = lookat;
    camera3d.worldUp = vec3(0., 1., 0.);

    vec3 dir = normalize(camera3d.pivot - camera3d.position);
    camera3d.pitch = asin(dir.y) * 180. / PI;
    camera3d.yaw = atan(dir.z, dir.x) * 180. / PI;

    camera3d.radius = distance(eye, lookat);

    camera3d.fov = fov * PI / 180.;
    camera3d.focalDist = 0.1;
    camera3d.aperture = 0.0;
    updateCamera(camera3d);
    
    camera3d.initialized = true;
    
    return camera3d;
}
  
void offsetOrientation(inout Camera3D camera3d, float dx, float dy) {
    camera3d.pitch -= dy;
    camera3d.yaw += dx;
    updateCamera(camera3d);
}

void setRadius(inout Camera3D camera3d, float dr) {
    camera3d.radius += dr;
    updateCamera(camera3d);
}

void setCamera(inout vec4 fragColor, int index) {
    Camera3D camera3d = getCamera(iChannel0);

    bool dataChanged = false;
    
    if (!camera3d.initialized) {
        camera3d = createCamera();
        dataChanged = true;
    } else if (isMouseDown) {
        if (!altPressed) {
            vec2 delta = (iMouse.xy - camera3d.mouseXY) / iResolution.xy * 360.;
            offsetOrientation(camera3d, delta.x, delta.y);
        } else {
            vec2 delta = (iMouse.xy - camera3d.mouseXY) / iResolution.xy * 10.;
            setRadius(camera3d, delta.y);
        }
        camera3d.mouseXY = iMouse.xy;
        dataChanged = true;
    }

    if (dataChanged) {
        vec4[] data = getCameraData(camera3d);
        fragColor = data[index]; 
    }
}

//-------------------------- Main ---------------------------

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {

    ivec2 v = ivec2(fragCoord.xy);
    
    int width = int(iResolution.x);
    int index = v.x + v.y * width;
     
    fragColor = texelFetch(iChannel0, v, 0); 

    if (index < CAMERA_DATA_POS + CAMERA_DATA_VEC4_COUNT) {
        
        index -= CAMERA_DATA_POS;
        
        setCamera(fragColor, index);

#if !defined(OPT_USE_MESHDATA_BLOB)

    } else if (iFrame < 2) {

        index -= MESH_DATA_OFFSET;

        if(index < VEC4_COUNT) {
            vec4[] data = getData();
            fragColor = data[index]; 
        } else {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        }

#endif   

    }

}

