#define PI 3.14159265359
#define EPSILON 1e-6
#define SDF_NORMAL_DELTA 1e-3
#define LARGE_NUMBER 1e20
#define MATERIAL_GROUND 0
#define MATERIAL_VOLUME 1
#define MATERIAL_LIGHT 2
#define MATERIAL_INVALID -1
#define MATERIAL_LIGHT_FLAG 1
#define NUMBER_LIGHTS 3
#define NUMBER_MATERIALS NUMBER_LIGHTS+2

// Play around with these
#define AMBIENT_LIGHT_STRENGTH 0.0
#define LIGHT_ATTENUATION_FACTOR 2.0f
#define LIGHT_INTENSITY_MULTIPLIER 20.0f
#define MAX_STEPS_SDF 40
#define SURFACE_DIST 0.2
#define MAX_STEPS_VOLUME 40
#define ABSORPTION_CUTOFF 0.04
#define ABSORPTION_COEFF 0.4
#define MAX_FOG_DENSITY 1.0
#define MAX_STEPS_VOLUME_LIGHT 6
#define MARCH_SIZE_MULTIPLIER 1.0
#define MARCH_STEP_SIZE 0.5 * MARCH_SIZE_MULTIPLIER
#define MARCH_STEP_SIZE_LIGHT 0.65 * MARCH_SIZE_MULTIPLIER

struct CameraDescription
{
    vec3 Position;
    vec3 LookAt;    

    float LensHeight;
    float FocalDistance;
};

mat3 GetViewMatrix(vec4 iMouse, vec3 iResolution)
{
    float camRotX = iMouse.x / iResolution.x;
    float camRotY = iMouse.y / iResolution.y;
    float xRotation = (( - camRotX * 2.0 + 1.0)) * PI;
    float yRotation = ((camRotY * 0.29 - 0.2)) * PI;
    mat3 cameraRotX = mat3(
                cos(xRotation), 0.0, sin(xRotation),
                0.0,           1.0, 0.0,    
                -sin(xRotation),0.0, cos(xRotation));
    mat3 cameraRotY = mat3( 1.0,           0.0, 0.0,
                 0.0, cos(yRotation), -sin(yRotation),
                 0.0, sin(yRotation), cos(yRotation));
    mat3 viewMatrix = cameraRotY * cameraRotX;
    return viewMatrix;
}

struct Material
{
    vec3 color;
    int flags;
};

struct Ray
{
    vec3 origin;
    vec3 direction;
};

struct LightSource
{  
    vec3 position;
    float radius;
    vec3 color;
};

// some random matrix for fbm
const mat3 m3  = mat3( 0.00,  0.80,  0.60,
                      -0.80,  0.36, -0.48,
                      -0.60, -0.48,  0.64 );

// https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-plane-and-ray-disk-intersection
float PlaneIntersection(Ray ray, vec3 planeOrigin, vec3 planeNormal, out vec3 normal) 
{ 
    float t = -1.0f;
    normal = planeNormal;
    float denom = dot(-planeNormal, ray.direction);
    if (denom > EPSILON) { 
        vec3 rayToPlane = planeOrigin - ray.origin; 
        return dot(rayToPlane, -planeNormal) / denom; 
    } 
 
    return t; 
} 

// http://kylehalladay.com/blog/tutorial/math/2013/12/24/Ray-Sphere-Intersection.html
float SphereIntersection(Ray ray, in vec3 sphereCenter, in float sphereRadius, out vec3 normal)
{
      vec3 L = sphereCenter - ray.origin;
      float tc = dot(L, ray.direction);
      
      if (tc < 0.0f)
          return -1.0f;
          
      float d2 = dot(L,L) - (tc*tc);
      float radius2 = sphereRadius * sphereRadius;
      
      if ( d2 > radius2)
          return -1.0f;
          
      float t1c = sqrt( radius2 - d2 );
      float t1 = tc - t1c;
          
      normal = normalize(ray.origin + ray.direction * t1 - sphereCenter);
      return t1;
}

LightSource GetLight(int index, float iTime)
{
    LightSource orbLight;
    
    switch(index % NUMBER_LIGHTS)
    {
        case 0:
            orbLight.color = vec3(0, 1.0, 1.0);
            orbLight.position = vec3(6.0 + sin(1.0 * iTime) * 10.0, 20.0 + sin(iTime * 1.5) * 5.0, 4.0 + cos(iTime) * 5.0);
            break;
        case 1:
            orbLight.color = vec3(1.0, 1.0, 0.0);
            orbLight.position = vec3(-19, 20.0 + sin(2.0 * iTime) * 10.0,-1.0 + cos(2.0 * iTime) * 10.0);
            break;
        case 2:
            orbLight.color = vec3(1.0, 0.0, 1.0);
            orbLight.position = vec3(15.0 + sin(2.0 * iTime) * 5.0, 12.0, cos(2.0 * iTime) * 5.0);
            break;
    } 

    orbLight.radius = 0.8f;
    orbLight.color *= LIGHT_INTENSITY_MULTIPLIER;
    return orbLight;
}


Material materials[NUMBER_MATERIALS];


float AttenuateLight(float d)
{
    return 1.0 / pow(d, LIGHT_ATTENUATION_FACTOR);
}

vec3 Diffuse(in vec3 normal, in vec3 lightVec, in vec3 diffuse)
{
    float nDotL = dot(normal, lightVec);
    return clamp(nDotL * diffuse, 0.0, 1.0);
}

vec3 GetAmbientLight()
{
	return AMBIENT_LIGHT_STRENGTH * vec3(0.03, 0.018, 0.018);
}

void CalculateLighting(vec3 position, vec3 normal, vec3 reflectionDirection, Material material, float iTime, inout vec3 color)
{
    for(int i = 0; i < NUMBER_LIGHTS; ++i)
    {
        vec3 lightDirection = (GetLight(i, iTime).position - position);
        float lightDistance = length(lightDirection);
        lightDirection /= lightDistance;

        vec3 lightColor = GetLight(i, iTime).color * AttenuateLight(lightDistance); 
        
        color += lightColor * pow(max(dot(reflectionDirection, lightDirection), 0.0), 4.0);
        color += lightColor * Diffuse(normal, lightDirection, material.color);
    
    }
    color += GetAmbientLight() * material.color;
}

float sdSphere(vec3 p, vec3 origin, float s)
{
  p = p - origin;
  return length(p)-s;
}

float sdPlane( vec3 p )
{
	return p.y;
}

// Taken from https://iquilezles.org/articles/distfunctions
float sdSmoothUnion( float d1, float d2, float k ) 
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}


float BeerLambert(float absorption, float dist)
{
    return exp(-absorption * dist);
}

float GetFogDensity(vec3 position, float sdfDistance)
{
    bool insideSDF = sdfDistance < 0.0;
    return insideSDF ? min(abs(sdfDistance), MAX_FOG_DENSITY) : 0.0;
}

float Luminance(vec3 color)
{
    return (color.r * 0.3) + (color.g * 0.59) + (color.b * 0.11);
}

bool IsColorInsignificant(vec3 color)
{
    const float minValue = 0.005;
    return Luminance(color) < minValue;
}

