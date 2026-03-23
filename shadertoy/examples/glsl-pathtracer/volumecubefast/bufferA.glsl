// START_BUFFERA_CODE
vec3 eye = vec3(6.000000, 6.000000, 6.000000);
vec3 lookat = vec3(0.000000, 1.000000, 0.000000);
float fov = 45.000000;

#define VEC4_COUNT 37

vec4[VEC4_COUNT] getData() {
    vec4 data[VEC4_COUNT] = vec4[](
        // Materials
        vec4(1.000000,1.000000,1.000000,0.000000),vec4(0.000000,0.000000,0.000000,0.000000),vec4(0.000000,0.500000,0.000000,0.000000),vec4(0.000000,0.000000,0.000000,0.000000),vec4(0.000000,1.500000,0.000000,0.000000),vec4(1.000000,1.000000,1.000000,0.000000),vec4(-1.000000,-1.000000,-1.000000,-1.000000),vec4(1.000000,0.000000,0.000000,0.000000),
        vec4(1.000000,1.000000,1.000000,0.000000),vec4(0.000000,0.000000,0.000000,0.000000),vec4(0.000000,0.000000,0.000000,0.000000),vec4(0.000000,0.000000,0.000000,0.000000),vec4(1.000000,1.500000,2.000000,2.000000),vec4(0.800000,1.000000,1.200000,0.000000),vec4(-1.000000,-1.000000,-1.000000,-1.000000),vec4(0.000000,1.000000,0.000000,0.000000),
        vec4(0.100000,0.100000,0.100000,0.000000),vec4(0.000000,0.000000,0.000000,0.000000),vec4(0.000000,0.500000,0.000000,0.000000),vec4(0.000000,0.000000,0.000000,0.000000),vec4(0.000000,1.500000,0.000000,0.000000),vec4(1.000000,1.000000,1.000000,0.000000),vec4(-1.000000,-1.000000,-1.000000,-1.000000),vec4(1.000000,0.000000,0.000000,0.000000),
        // Transforms
        vec4(1.000000,0.000000,0.000000,0.000000),vec4(0.000000,1.000000,0.000000,0.000000),vec4(0.000000,0.000000,1.000000,0.000000),vec4(0.000000,0.000000,0.000000,1.000000),
        vec4(10.000000,0.000000,0.000000,0.000000),vec4(0.000000,10.000000,0.000000,0.000000),vec4(0.000000,0.000000,10.000000,0.000000),vec4(0.000000,-0.001000,0.000000,1.000000),
        // Lights
        vec4(-1.000000,3.000000,1.000000,0.000000),vec4(25.000000,25.000000,25.000000,0.000000),vec4(0.000000,0.000000,-2.000000,0.000000),vec4(2.000000,0.000000,0.000000,0.000000),vec4(0.000000,4.000000,0.000000,0.000000),
    );
    return data;
}
// END_BUFFERA_CODE

#define altPressed     (texelFetch(iChannel1, ivec2(18,0),0).x > 0.)

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
        
    if (index == INFO_FRAME_POS) {  
    
        if (isMouseDown) {
            fragColor = vec4(float(iFrame), 0., 0., 0.);
        }
            
    } else if (index == INFO_RESOLUTION_POS) {
    
        float resolutionChangeFlag = 0.0;
        vec2 oldResolution = texelFetch(iChannel0, ivec2(INFO_RESOLUTION_POS, 0), 0).yz;

        if (iResolution.xy != oldResolution) {
            resolutionChangeFlag = 1.0;
        }

        fragColor = vec4(resolutionChangeFlag, iResolution.xy, 1.0);
        
    } else if (index < CAMERA_DATA_POS + CAMERA_DATA_VEC4_COUNT) {
        
        index -= CAMERA_DATA_POS;
        
        setCamera(fragColor, index);

    } else if (iFrame < 2) {

        index -= MESH_DATA_OFFSET;

        if(index < VEC4_COUNT) {
            vec4[] data = getData();
            fragColor = data[index]; 
        } else {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        }

    }   

}

