/*
CPSC 591 Final Project
Daky Wang (30131194)

// KEY_UP = move camera forward
// KET_DOWN = move camera backward

references: 
Teapot SDF Model: https://www.shadertoy.com/view/3lG3Dc
Cylinder SDF Model: https://iquilezles.org/articles/distfunctions/
Ray Marching & Camera Rotation: CPSC591 PA-1, PA-3
Edge Detection: https://www.shadertoy.com/view/ll33Wn
Shadow Mapping: https://www.shadertoy.com/view/flX3Ds
Keyboard Input: https://www.shadertoy.com/view/ltsyRS
Pascal Barla, Jo¨elle Thollot ARTIS GRAVIR/IMAG INRIA* Grenoble France Lee Markosian University of Michigan 2006 X-Toon: An Extended Toon Shader
"Stylized highlights for cartoon rendering and animation" by Ken-ichi Anjyo and Katsuaki Hiramitsu
*/

// ======================================================================
// Ray Marching Constants
const int MAX_STEP = 255;
const float MIN_DIST = 0.001;
const float MAX_DIST = 1000.0;
const float scale_factor = 0.75;

// USER DEFINED ATTRIBUTES
// ======================================================================
// MODEL CONFIG
// sphere position and radius (to show different depth)
#define SPHERE_OFFSET_VALUE 8.0
const vec3 sphere_pos_1 = SPHERE_OFFSET_VALUE * vec3(0.866, -0.15, -0.5);
const vec3 sphere_pos_2 = SPHERE_OFFSET_VALUE * vec3(0.0, -0.15, 1.0);
const vec3 sphere_pos_3 = SPHERE_OFFSET_VALUE * vec3(-0.866, -0.15, -0.5);
const float sphere_r = 1.0;
// radius of floor (cylinder)
const float floor_radius = 5.0;

// OUTPUT CONFIG
// SWITCHES (COMMENT = TURN OFF)
#define LINEART_ON
#define SHADOW_ON
#define HIGHLIGHT_ON
#define STYLIZE_HIGHLIGHT

// EDGE (LINEART)
const vec3 edge_col = vec3(0.1, 0.1, 0.3);
const float edge_thickness = 0.03;
// DEFAULT COLORS
const vec3 background_col = vec3(0.5, 0.8, 1.0);
const vec3 teapot_col = vec3(0.7, 0.7, 0.75);
const vec3 floor_col = vec3(0.35, 1.0, 0.5);
const vec3 bubble_col = vec3(1.0, 0.7, 0.8);
// HIGHLIGHT
const vec3 highlight_col = vec3(1.0, 1.0, 1.0);
const float highlight_size = 0.005; // adjust size of the highligh
const float highlight_sharpness = 2.0; // the larger the highlighted area becomes more sharpened (an integer)
const float highlight_square_magnitude = 0.02; // prescribes the magnitude of the squared area. (between 0 to 1)
const float highlight_scale = 0.4; // used for scaling highlight (0<delta<=1.0)
const float highlight_split = 0.15; // how far the splitted highlight should be

// DEPTH (Z-VALUE) CALCULATION
//#define DEPTH_FROM_CAMERA
#define DEPTH_ALONG_FOCAL_AXIS

// X-TOON ATTRIBUTES
// ---------------------------------------------------------------------
//#define XTOON_ON

#define MULTIPLY_XTOON

// how is D calculated (determines texture coordinate)
//#define DEPTH_BASED_D
//#define ORIENT_BASED_D_R
#define ORIENT_BASED_D_S

const float z_min = 2.0;            //most vague
//should be adjust when using different texture to achieve idea result
#ifdef DEPTH_BASED_D
    const float z_r = 100.0;         //>=1.0
#else
    const float z_r = 0.9;           //power of the orientation based effect
#endif
const float z_s = 1.0;              // shininess
const float z_max = z_r * z_min;    //most detailed (the smaller, the more close you need to get to get most detailed)


// ======================================================================
// Math
const float PI = 3.14159265358979323846;
const float HALF_PI = 1.5707963268;
const float INV_PI = 0.31830988618379067154; 
const float DEG_TO_RAD = PI / 180.0;
const float EPSILON = 0.00001; 

// ======================================================================
// Structures
struct Ray {
    vec3 origin;     // The starting point of the ray
    vec3 direction;  // The direction in which the ray points
};


// ======================================================================
// SDFs
// Teapot SDF Model 
// reference: “Isosurface Teapot” by klk. https://www.shadertoy.com/view/3lG3Dc
// Many thanks to TA Katherine
// ----------------------------------------------------------------------
float smin(float a, float b, float k)
{
	float h=clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
	return mix(b, a, h)-k*h*(1.0-h);
}

float smax( float a, float b, float k)
{
	return -smin(-a,-b,k);
}

float smin( float a, float b)
{
	return smin(a,b,0.1);
}

float smax( float a, float b)
{
	return smax(a,b,0.1);
}

float sq(float x){return x*x;}

float Torus(float x, float y, float z, float R, float r)
{
	return sqrt(sq(sqrt(sq(x)+sq(z))-R)+sq(y))-r;
}

float Torus(vec3 p, float R, float r)
{
	return sqrt(sq(sqrt(sq(p.x)+sq(p.z))-R)+sq(p.y))-r;
}


float Lid(float x, float y, float z)
{
	float v=sqrt(sq(x)+sq(y-0.55)+sq(z))-1.4;
	v=smin(v,Torus(y-2.,x,z,.2,.08),.1);
	v=smax(v,-sqrt(sq(x)+sq(y-0.55)+sq(z))+1.3);
	v=smax(v,sqrt(sq(x)+sq(y-2.5)+sq(z))-1.3);

	v=smax(v,-sqrt(sq(x-.25)+sq(z-.35))+0.05,.05);
	v=smin(v,Torus(x,(y-1.45)*.75,z,.72,.065),.2);
	return v;
}

float Nose(float x, float y, float z)
{
	z-=sin((y+0.8)*3.6)*.15;
	
	float v=sqrt(sq(x)+sq(z));
	
	v=abs(v-.3+sin(y*1.6+.5)*0.18)-.05;
	v=smax(v,-y-1.);
	v=smax(v,y-0.85,.075);
	
	return v;
}

float sdTeapot(vec3 p)
{
	float x=p.x;
	float y=p.y;
	float z=p.z;

	float v=0.0;
	v=sqrt(x*x+z*z)-1.2-sin(y*1.5+2.0)*.4;
	v=smax(v,abs(y)-1.,0.3);

	float v1=sqrt(x*x*4.+sq(y+z*.1)*1.6+sq(z+1.2))-1.0;
	v1=smax(v1,-sqrt(sq(z+1.2)+sq(y+z*.12+.015)*1.8)+.8,.3);
	
	v=smin(v,Torus(y*1.2+.2+z*.3,x*.75,z+1.25+y*.2,.8,.1),.25);
	v=smin(v,sqrt(sq(x)+sq(y-1.1)+sq(z+1.8))-.05,.32);

	float v3=Nose(x,(y+z)*sqrt(.5)-1.6,(z-y)*sqrt(.5)-1.1);

	v=smin(v,v3,0.2);
	
	v=smax(v,smin(sin(y*1.4+2.0)*0.5+.95-sqrt(x*x+z*z),y+.8, .2));
	v=smax(v,-sqrt(sq(x)+sq(y+.15)+sq(z-1.5))+.12);

	v=smin(v,Torus(x,y-0.95,z,0.9,.075));
	v=smin(v,Torus(x,y+1.05,z,1.15,.05),0.15);

	float v2=Lid(x,y+.5,z);
	v=min(v,v2);

	return v;
}
// ----------------------------------------------------------------------
float sdFloor(vec3 p) {
  //float v = p.y + 1.5;
  p = p + vec3(0.0, 1.4, 0.0); //offset
  vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(floor_radius, 0.25);
  float v = min(max(d.x,d.y),0.0) + length(max(d,0.0));
  return v;
}
// ----------------------------------------------------------------------
float sdSphere( vec3 p, float r )
{
  return length(p)-r;
}

// ======================================================================
// Ray marching
vec3 ray_dir( float fov, vec2 size, vec2 pos )
{
    vec2 xy = pos - size * 0.5;

    float cot_half_fov = tan( ( 90.0 - fov * 0.5 ) * DEG_TO_RAD );
    float z = size.y * 0.5 * cot_half_fov;
    
    return normalize( vec3( xy, -z ) );
}


vec3 hitObjColor(vec3 p) {
    float bubble1 = sdSphere((p + sphere_pos_1), sphere_r);
    float bubble2 = sdSphere((p + sphere_pos_2), sphere_r);
    float bubble3 = sdSphere((p + sphere_pos_3), sphere_r);
   
    float teapot = sdTeapot(p);
    float plate = sdFloor(p);
    
    float co = min(min(min(min(teapot, plate), bubble1), bubble2), bubble3); //closest object
    
    if (co == bubble1 || co == bubble2 || co == bubble3) {
        return bubble_col;
    } else if (co == teapot) {
        return teapot_col;
    } else {
        return floor_col;
    }

    if (sdTeapot(p) < sdFloor(p)) return teapot_col;
    return floor_col;
}

float sdScene(vec3 p) {
    float bubble1 = sdSphere((p + sphere_pos_1), sphere_r);
    float bubble2 = sdSphere((p + sphere_pos_2), sphere_r);
    float bubble3 = sdSphere((p + sphere_pos_3), sphere_r);
   
    float teapot = sdTeapot(p);
    float plate = sdFloor(p);
    
    return min(min(min(min(teapot, plate), bubble1), bubble2), bubble3);

    return min(sdTeapot(p), sdFloor(p));
}

// with edge detection
// view dependent
float ray_marching( Ray cam, float start, float end, float edgeLength ) 
{
    float depth = start;
    
    for (int i = 0; i < MAX_STEP; i++) 
    {
        vec3 p = cam.origin + cam.direction * depth; // take minimum step
        
        // march for a distance in the scene
        float dist = sdScene(p);
        
        edgeLength = min(dist, edgeLength);
        
        if ( dist < MIN_DIST ) 
            return depth; // hit
        
        
        #ifdef LINEART_ON
            if (dist > edgeLength && edgeLength <= edge_thickness ) // Edge hit
                return 0.0;
        #endif
        
        depth += dist * scale_factor;
        
        if ( depth >= end ) // no hit
            return end;
    }
    
    return depth;
}

// without edge detection
float ray_marching( Ray ray, float start, float end) 
{
    float depth = start;
    
    for (int i = 0; i < MAX_STEP; i++) 
    {
        vec3 p = ray.origin + ray.direction * depth; // take minimum step
        
        // march for a distance in the scene
        float dist = sdScene(p);
        

        
        if ( dist < MIN_DIST ) 
            return depth; // hit
        
        
        depth += dist * scale_factor;
        
        if ( depth >= end ) // no hit
            return end;
    }
    
    return depth;
}



// Gradient in the world
vec3 getNormal( vec3 v ) 
{
    const vec3 dx = vec3( 0.1, 0.0, 0.0 );
    const vec3 dy = vec3( 0.0, 0.1, 0.0 );
    const vec3 dz = vec3( 0.0, 0.0, 0.1 );
    
    return normalize(
        vec3(
            sdScene( v + dx ) - sdScene( v - dx ),
            sdScene( v + dy ) - sdScene( v - dy ),
            sdScene( v + dz ) - sdScene( v - dz )
        )
    );
}

// ======================================================================
// Camera
mat3 cameraMatrix(vec3 cx, vec3 cy, vec3 cam_dir){
    return mat3(cx, cy, cam_dir);
}

// ======================================================================
// Maths
void createLocalFrame(vec3 N, out vec3 T, out vec3 B) 
{
    // choose an arbitary vector v such that v is not parallel to N
    vec3 v = vec3(1.0, 0.0, 0.0);
    if (N == v) v = vec3(0.0, 0.0, 1.0);
    // project v onto the plane perpendicular to N
    T = v - dot(v, N) * N;
    T = normalize(T);
    // take the cross product of N and T to get B
    B = cross(N, T);
    B = normalize(B);
}

float sgn (float x) 
{
    if (x==0.0) return 1.0;
    else return x/abs(x);
}
