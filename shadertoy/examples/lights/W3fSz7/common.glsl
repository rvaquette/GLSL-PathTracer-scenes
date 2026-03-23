/**
* Creative Commons CC0 1.0 Universal (CC-0)
*
* Contains all the helper functions used by Buffer A for the area lights.
*
*/

#define saturate(x) clamp(x, 0., 1.)
#define dot2(x) dot(x, x)

#define EPS .0002
#define SMOL_EPS .0000002

#define PI 3.1415926535
#define TWO_PI 6.283185307
#define PI_INV .3183098861

#define DRAW_LIGHTS

// enable/disable these for floor normal map and roughness
#define FLOOR_DISPLACEMENT
#define FLOOR_ROUGHNESS

#define T (iTime * .25)

#define SPHERE_LIGHT_POS vec3(9. * cos(T), 6. * abs(sin(T)) \
		- .75 + SPHERE_LIGHT_RADIUS, 1.)
#define SPHERE_LIGHT_RADIUS (sin(T) * .5 + .7)
#define SPHERE_LIGHT_VOLUME_RADIUS 20.
#define SPHERE_LIGHT_INTENSITY 256.
            
#define LINE_LIGHT_RADIUS (sin(T) * .075 + .125)
#define LINE_LIGHT_VOLUME_RADIUS 20.
#define LINE_LIGHT_INTENSITY 512.
            
#define RECT_LIGHT_RADIUS 4.
#define RECT_LIGHT_INTENSITY 64.
            
#define LIGHT_COLOR vec3(1., .6, .3)
            
#define SPHERE_ALBEDO vec3(.2, .01, .6)
#define REFLECTION_STEPS 8
            
#define SILVER_F0 vec3(.95, .93, .88)
#define PLASTIC_F0 vec3(.05)

#define CAMERA_POS vec3(0., 9., 21.)
#define CAMERA_FAR 100.

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

mat3 rotZ(float a)
{
	return mat3(cos(a), -sin(a), 0.,
                sin(a),  cos(a), 0.,
                	0., 	 0., 1.);
}

vec3 rotateAround(vec3 v, vec3 k, float theta)
{
  return v * cos(theta) + cross(k, v) * sin(theta) + k * dot(k, v) * (1. - cos(theta));
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
    vec3 origin = CAMERA_POS;
    vec3 target = vec3(0., 1., 0.);
    mat3 camera = getCameraMatrix(origin, target);
    vec3 direction = normalize(camera * vec3(uv, 2.5));
    return Ray(origin, direction);
}

void initRect(out Rect rect, float t)
{
    rect.up = vec3(0., 0., 1.);
    rect.right = vec3(1., 0., 0.);
    rect.front = normalize(cross(rect.right, rect.up));
    vec2 widthScale = vec2(cos(t), sin(t)) * .25 + .75;
    rect.halfSize = vec2(2.5, 1.5) * widthScale;
    
    rect.center = vec3(0., 6., sin(t) * 4. - 1.5);
    
    rect.a = rect.center + rect.halfSize.x * rect.right + rect.halfSize.y * rect.up;
    rect.b = rect.center - rect.halfSize.x * rect.right + rect.halfSize.y * rect.up;
    rect.c = rect.center - rect.halfSize.x * rect.right - rect.halfSize.y * rect.up;
    rect.d = rect.center + rect.halfSize.x * rect.right - rect.halfSize.y * rect.up;
}


// Based on the technique in EA's frostbite engine
float rectSolidAngle(vec3 p, vec3 v0, vec3 v1, vec3 v2, vec3 v3)
{
    vec3 n0 = normalize(cross(v0, v1));
    vec3 n1 = normalize(cross(v1, v2));
    vec3 n2 = normalize(cross(v2, v3));
    vec3 n3 = normalize(cross(v3, v0));
    
    float g0 = acos(dot(-n0, n1));
	float g1 = acos(dot(-n1, n2));
	float g2 = acos(dot(-n2, n3));
	float g3 = acos(dot(-n3, n0));
    
    return g0 + g1 + g2 + g3 - 2. * PI;
}

