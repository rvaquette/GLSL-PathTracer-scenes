/**
* Creative Commons CC0 1.0 Universal (CC-0)
*
* Helper functions and macros used for the rectangular area light in the mainImage buffer.
*
*/

#define saturate(x) clamp(x, 0., 1.)
#define dot2(x) dot(x, x)

// Comment/uncomment these for different material settings
#define FLOOR_DISPLACEMENT
#define FLOOR_ROUGHNESS
#define LIGHT_TEXTURE

#define EPS .0002
#define SMOL_EPS .0000002

#define PI 3.1415926535
#define TWO_PI 6.283185307
#define PI_INV .3183098861

#define RECT_LIGHT_RADIUS 1.25
#define RECT_LIGHT_COLOR vec3(.6, .3, .15)
#define RECT_LIGHT_INTENSITY 32.

const vec3 cameraPosition = vec3(0., 10., 25.);
const float cameraFar = 100.;

struct Ray
{
    vec3 origin, direction;
};
    
struct Rect
{
	vec3 center, a, b, c, d; 
	vec3 up, right, front;
    vec2 halfSize;
};
    
float hash12(vec2 p)
{
	uvec2 q = uvec2(ivec2(p)) * uvec2(1597334673U, 3812015801U);
	uint n = (q.x ^ q.y) * 1597334673U;
	return float(n) * (1. / float(0xffffffffU));
}

mat3 rotY(float a)
{
	return mat3(cos(a), 0., sin(a),
                	0., 1., 	0.,
               -sin(a), 0., cos(a));
}

mat3 rotX(float a)
{
	return mat3(1., 	0., 	 0.,
                0., cos(a), -sin(a),
                0., sin(a),  cos(a));
}

vec3 rotateYX(vec3 a, vec2 rot)
{
	return rotX(rot.y) * rotY(rot.x) * a;
}

mat3 getCameraMatrix(vec3 origin, vec3 target)
{
    vec3 lookAt = normalize(target - origin);
    vec3 right = normalize(cross(lookAt, vec3(0., 1., 0.)));
    vec3 up = normalize(cross(right, lookAt));
    return mat3(right, up, lookAt);
}

Ray getCameraRay(vec2 uv)
{
    vec3 origin = cameraPosition;
    vec3 target = vec3(0., 1., 0.);
    mat3 camera = getCameraMatrix(origin, target);
    vec3 direction = normalize(camera * vec3(uv, 2.5));
    return Ray(origin, direction);
}
