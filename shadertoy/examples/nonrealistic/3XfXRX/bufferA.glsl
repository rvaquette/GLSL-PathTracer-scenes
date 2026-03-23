#define BufferB iChannel0
#define TEAPOT_TEXTURE iChannel1
#define FLOOR_TEXTURE iChannel2
#define BUBBLE_TEXTURE iChannel3
// Note: choose wrap=clamp for all textures

// ======================================================================
// Camera Movement
// reference: CPSC591 PA-1 
mat3 rot3xy( vec2 angle ) {
    vec2 c = cos( angle );
    vec2 s = sin( angle );

    return mat3(
        c.y, 0.0, -s.y,
        s.y * s.x, c.x, c.y * s.x,
        s.y * c.x, -s.x, c.y * c.x
    );
}
// reference: CPSC591 PA-3
vec3 rotateWithMouse(vec3 v)
// Rotate a 3D vector 'v' around the y and z axes based on mouse coordinates
{
    // Convert mouse coordinates to normalized screen coordinates and scale by 2.0
    vec2 m = (2.0 * iMouse.xy - iResolution.xy) / iResolution.y;
    m *= 2.0;
    // Create a 4D vector 't' with sine values based on 'r' and a constant value (half pi)
    vec4 t = sin( vec4( m, m + HALF_PI ) );
    // Calculate the dot product between the 'v.yz' components and 't.yw'
    float g = dot( v.yz, t.yw );
    // Return a new 3D vector after applying rotation transformations
    return vec3( v.x * t.z - g   * t.x,
                 v.y * t.w - v.z * t.y,
                 v.x * t.x + g   * t.z );
}

// Camera offset due to keyboard input
vec3 getCamOffset() {
    return vec3(0.0, 0.0, -texelFetch(BufferB, ivec2(1, 0), 0).r);
}


// ======================================================================
// Nomal Visualization (for testing normal)
vec3 getNormalColor(vec3 n){
    return vec3((n+1.0)*0.5);
}


// Returns depth of p wrt camera
float getDepth(float d, vec3 p, vec3 focal_axis, vec3 cam_p){
    #ifdef DEPTH_FROM_CAMERA
        return d;
    #endif
    #ifdef DEPTH_ALONG_FOCAL_AXIS
        // project p onto focal_axis
        p = dot(p,focal_axis) * focal_axis;
        d = distance(p, cam_p);
        return d;
    #endif
    return d;
}

// Depth Visualization
vec3 getDepthColor(float d, vec3 p, vec3 focal_axis, vec3 cam_position){
    d = getDepth(d,p,focal_axis,cam_position);
    return vec3((d-MIN_DIST) / (MAX_DIST-MIN_DIST));
}


// ======================================================================
// X-toon: attribute based texture coordinate calculation
vec2 getTextureCoord(float NdotL, float NdotV, float VdotR, float z) {
    float D = 1.0;
    #ifdef DEPTH_BASED_D
        // depth-based mapping
        D = 1.0-log(z/z_min)/log(z_r);
    #endif
    #ifdef ORIENT_BASED_D_R
        D = pow(abs(NdotV), z_r);
    #endif
    #ifdef ORIENT_BASED_D_S
        D = pow(abs(VdotR), z_s);
    #endif
    return vec2(NdotL, D);
}

// ======================================================================
// Shadow
/* raymarch from p into the direction of the light and if the dist we get out 
of it is smaller than the distance to the light than we know we hit something
in between the light and that point. (i.e. the point is shadowed) 
*/
bool isShadowed(vec3 p, Ray light, vec3 n){
    Ray backwardRay = Ray(p, normalize(light.direction)); // note this direction points from p to light source
    backwardRay.origin = p + n*0.003;
    float d_light = ray_marching(backwardRay, 0.0, MAX_DIST);
    if (d_light < distance(p, light.origin)) return true;
    return false;
}



// ======================================================================
// Highlight
/* Implementation of squared highlight proposed in the paper:
    "Stylized highlights for cartoon rendering and animation" by Ken-ichi Anjyo and Katsuaki Hiramitsu
*/
vec3 squareHighlight(vec3 H, vec3 du, vec3 dv)
{
    float Hdu = dot(H,du);
    float Hdv = dot(H,dv);
    
    vec3 V = Hdu * du + Hdv * dv;
    V = normalize(V);
    
    float Vdu = dot(V,du);
    float Vdv = dot(V,dv);

    float theta = min(acos(Vdu), acos(Vdv));
    float sqrnorm = pow(sin(2.0 * theta), highlight_sharpness);
    vec3 H_sqr = H - highlight_square_magnitude * sqrnorm * V;
    return normalize(H_sqr);
}

vec3 scaleHighlight(vec3 H, vec3 d)
{
    float Hd = min(dot(H, d), EPSILON);
    vec3 H_scl = H - highlight_scale * Hd * d;
    return normalize(H_scl);
}


vec3 splitHighlight(vec3 H, vec3 d)
{

    float sgnHd = sgn(dot(H,d));
    vec3 H_spl = H - highlight_split * sgnHd * d;
    return normalize(H_spl);
}


// ======================================================================
float getLuminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// -------------------------------------------------------------

// returns the color at point p
vec3 getColor(vec3 p, vec3 N, Ray cam, Ray light, float z)
{
    vec3 V = normalize(  cam.origin - p  ); ///pointing from the position to the eye 
    vec3 L = light.direction;

    vec3 color = hitObjColor(p);
    float NdotL = dot(N,L);
    float NdotV = dot(N,V);

    vec3 R = L - 2.0*NdotL*N;
    float VdotR = dot(V,R);

    #ifdef XTOON_ON
        vec3 tex_col; // color get from the texture
        #ifdef SHADOW_ON
            if (isShadowed(p, light, N)) NdotL =0.0;
        #endif
        // apply corresponding texture
        if (color == teapot_col) tex_col = texture(TEAPOT_TEXTURE, getTextureCoord(NdotL, NdotV, VdotR, z)).rgb;
        else if (color == floor_col) tex_col = texture(FLOOR_TEXTURE, getTextureCoord(NdotL, NdotV, VdotR, z)).rgb;
        else tex_col = texture(BUBBLE_TEXTURE, getTextureCoord(NdotL, NdotV, VdotR, z)).rgb;
        
        #ifdef MULTIPLY_XTOON
            color += vec3(0.25); // make the color lighter (visually looks better)
            color *= vec3(getLuminance(tex_col));
        #else
            color = tex_col;
        #endif
        
    #else
        // apply traditional toon shading
        if (NdotL >= 0.8) {
            color += vec3 (0.3, 0.1, 0.0);
        } else if (NdotL <= 0.2) {
            color -= vec3 (0.2, 0.3, 0.1);
        }
        // apple shadow
        #ifdef SHADOW_ON
            if (isShadowed(p, light, N)) color -= vec3(0.2, 0.2, 0.2);
        #endif
    #endif
    

    #ifdef HIGHLIGHT_ON
        vec3 H = normalize(V + L); // inspected vector H
        
        #ifdef STYLIZE_HIGHLIGHT
        // stylize highligh
        vec3 du, dv;
        createLocalFrame(N, du, dv);
        
        
        H = scaleHighlight(H, dv); // scale in the dv direction
        H = splitHighlight(H, dv); // also split in the dv direction
        H = squareHighlight(H, du, dv);
        
        #endif
        
        if (dot(H, N) > 1.0-highlight_size) {
            // then p is highlighted 
            color = highlight_col;
        }
        
    #endif
    
    return color;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 color = vec3( 0.0 );
    
    // =======================================================================================
    // Camera Setup
    float fov = 40.0;
    vec3 camPosition = vec3(0.0, 0.0, 10.0);
    vec3 camDirection = ray_dir(fov, iResolution.xy, fragCoord.xy);

    // rotate camera
    mat3 rot = rot3xy(vec2(-DEG_TO_RAD * 10.0, iTime * 0.5));
    camPosition = rot * (camPosition + getCamOffset()); // camera offset due to keyboard input
    camDirection = rot * camDirection;
    
    // rotate if mouse is clicked
    if (iMouse.z > 0.0) {
        camPosition = rotateWithMouse(camPosition);
        camDirection = rotateWithMouse(camDirection);
    }
    
    vec3 focal_point = vec3(0.0);
    vec3 focal_axis = normalize(focal_point - camPosition); 
    // Initialize a ray for the camera
    Ray cam = Ray(camPosition, camDirection);

    // =======================================================================================
    // Ray March
    float edgeLength = MAX_DIST;
    float depth = ray_marching(cam, 0.0, MAX_DIST, edgeLength);
    
    
    // depth test
    if (false) {
        vec3 p = cam.origin + cam.direction * depth;
        color = getDepthColor(depth, p, focal_axis, camPosition);
        fragColor = vec4( color, 1.0 );
        return;
    }
    
    
    if (depth >= MAX_DIST) {// no hit
        fragColor = vec4(background_col, 1.0);
        return;
    }
    
    #ifdef LINEART_ON
        if (depth < EPSILON) { // edeg hit
            fragColor = vec4(edge_col, 1.0);
            return;
        }
    #endif
    
    // hit some object in the scene
    vec3 pos = cam.origin + cam.direction * depth;
    vec3 n = getNormal(pos);
    
    // =======================================================================================
    // Light Setup
    vec3 lightPosition = vec3(8.0, 12.0, 2.0);
    vec3 lightDirection = normalize(lightPosition - pos);
    
    // rotate light 
    rot = rot3xy(vec2(0.0, iTime * 0.5));
    lightPosition = rot * lightPosition;
    lightDirection = rot * lightDirection;
    
    Ray light = Ray(lightPosition, lightDirection);
    
    // =======================================================================================
    // apply toon shading
    color = getColor(pos, n, cam, light, getDepth(depth, pos, focal_axis, camPosition));
    

    fragColor = vec4( color, 1.0 );

}
