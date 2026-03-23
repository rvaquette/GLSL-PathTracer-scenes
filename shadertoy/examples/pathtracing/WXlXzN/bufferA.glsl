//#define DEBUG_RAY_DIR
//#define DEBUG_MOUSE
//#define DEBUG_RAND

#define RAY_TMIN 0.1
#define RAY_TMAX 100000.0

#define CAMERA_FOV 90.0
#define CAMERA_SAMPLE_PER_PIXEL 10
#define BOUNCE_COUNT 100
#define RAY_NORMAL_NUDGE 0.01
#define TEMPORAL_ACCUM

#define PI 3.14159265359

// Random mess
uint wang_hash(inout uint seed)
{
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
}
 
float randomFloat01(inout uint state)
{
    return float(wang_hash(state)) / 4294967296.0;
}
 
vec3 randomUnitVector(inout uint state)
{
    float z = randomFloat01(state) * 2.0f - 1.0f;
    float a = randomFloat01(state) * PI * 2.;
    float r = sqrt(1.0f - z * z);
    float x = r * cos(a);
    float y = r * sin(a);
    return vec3(x, y, z);
}
// --------------


struct Camera {
    vec3 pos;
    float near;
    float aspectRatio;
    vec3 resolution;
    int samplePerPixel; // for anti-aliasing
};

struct Ray {
    vec3 origin;
    vec3 direction;
    float tMin;
    float tMax;
};

struct Material {
    vec3 albedo;
    vec3 emissive;
};

struct Intersection {
    float t;
    vec3 normal;
    Material material;
};

struct Sphere {
    vec3 center;
    float radius;
};

struct Triangle {
    vec3 p1;
    vec3 p2;
    vec3 p3;
};

Intersection intersectTriangle(Ray ray, Triangle triangle) {
    Intersection result;
    result.t = -1.0;
    result.normal = vec3(0.0);

    // Vectors
    vec3 v0 = triangle.p1;
    vec3 v1 = triangle.p2;
    vec3 v2 = triangle.p3;

    // Edges
    vec3 edge1 = v1 - v0;
    vec3 edge2 = v2 - v0;

    vec3 normal = normalize(cross(edge1, edge2));

    // Möller-Trumbore
    vec3 h = cross(ray.direction, edge2);
    float a = dot(edge1, h);

    // Check if ray is parallel to the triangle plane
    float epsilon = 1e-6;
    if (abs(a) < epsilon) {
        return result;   // parallel -> no intersection
    }

    float f = 1.0 / a;
    vec3 s = ray.origin - v0;
    float u = f * dot(s, h);

    if (u < 0.0 || u > 1.0) {
        return result; // no hit
    }

    vec3 q = cross(s, edge1);
    float v = f * dot(ray.direction, q);

    if (v < 0.0 || u + v > 1.0) {
        return result; // also, no hit
    }

    float t = f * dot(edge2, q);

    if (t < ray.tMin || t > ray.tMax) {
        // hit outside of valid range, consider as no hit
        return result;
    }

    // hit found
    result.t = t;

    // do side check
    // if hit at backface, reverse the normal
    if (dot(ray.direction, normal) > 0.0) {
        normal = -normal;
    }

    result.normal = normal;
    return result;
}

Intersection intersectSphere(
        Ray ray, Sphere sphere) {
    Intersection isect;
    
    float a = dot(ray.direction, ray.direction);
    float b = -2. * dot(ray.direction, (sphere.center - ray.origin));
    float c = dot((sphere.center - ray.origin), (sphere.center - ray.origin)) - 
                sphere.radius * sphere.radius;
    float discriminant = b * b - 4.f * a * c;
    
    if (discriminant < 0.f) {
        // no intersection
        isect.t = ray.tMax + 1.;
        return isect;
    }
    
    float root1 = (-b - sqrt(discriminant)) / (2.f * a);
    float root2 = (-b + sqrt(discriminant)) / (2.f * a);
    
    vec3 hitpoint1 = ray.origin + root1 * ray.direction;
    vec3 hitpoint2 = ray.origin + root2 * ray.direction;
    
    if (root1 < 0.f) {
        // ray origin is inside the sphere, have to 
        // take the positive direction no matter what
        isect.t = root2;
        isect.normal = normalize(sphere.center - hitpoint2);
    } else {
        // ray origin is outside the sphere,
        // then root1 must be a closer hitpoint.
        isect.t = root1;
        isect.normal = normalize(hitpoint1 - sphere.center);
    }
    
    return isect;
}

// Generate ray
Ray raygen(vec2 uv, Camera camera, inout uint seed) {
    Ray ray;
    ray.origin = camera.pos;
    // The point the ray should get
    // through on the near plane.
    float xNudge = randomFloat01(seed) * 2. - 1.;
    float yNudge = randomFloat01(seed) * 2. - 1.;
    
    xNudge /= camera.resolution.x;
    yNudge /= camera.resolution.y;
    
    vec3 rayTarget = vec3(uv.x + xNudge, uv.y + yNudge, camera.pos.z + camera.near);
    rayTarget.y /= camera.aspectRatio;
    ray.direction = normalize(rayTarget - ray.origin);
    ray.tMin = RAY_TMIN;
    ray.tMax = RAY_TMAX;
    return ray;
}

Intersection intersect(Ray ray) {
    Intersection isect;
    Intersection currentIsect;
    isect.t = ray.tMax + 1.;
    
    currentIsect = intersectSphere(
        ray,  
        Sphere(vec3(5.0f, -7.0f, 20.0f), 2.0f));
        
    if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
        isect = currentIsect;
        isect.material.albedo = vec3(1.);
        isect.material.emissive = vec3(0.);
    }
    
    currentIsect = intersectSphere(
        ray,  
        Sphere(vec3(-1.0f, -7.0f, 20.0f), 3.0f));
        
    if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
        isect = currentIsect;
        isect.material.albedo = vec3(1., 1., 0.);
        isect.material.emissive = vec3(0.);
    }
    
    // Back
    {
        vec3 v0 = vec3(-12.6f, -12.6f, 25.0f);
        vec3 v1 = vec3( 12.6f, -12.6f, 25.0f);
        vec3 v2 = vec3( 12.6f,  12.6f, 25.0f);
        vec3 v3 = vec3(-12.6f,  12.6f, 25.0f);
        currentIsect = intersectTriangle(ray, Triangle(v0, v1, v2));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(1., 1., 1.);
            isect.material.emissive = vec3(0.);
        }
        currentIsect = intersectTriangle(ray, Triangle(v3, v2, v0));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(1., 1., 1.);
            isect.material.emissive = vec3(0.);
        }
    }
    
    // Floor
    {
        vec3 v0 = vec3(-12.6f, -12.45f, 25.0f);
        vec3 v1 = vec3( 12.6f, -12.45f, 25.0f);
        vec3 v2 = vec3( 12.6f, -12.45f, 15.0f);
        vec3 v3 = vec3(-12.6f, -12.45f, 15.0f);
        currentIsect = intersectTriangle(ray, Triangle(v0, v1, v2));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(1., 1., 1.);
            isect.material.emissive = vec3(0.);
        }
        currentIsect = intersectTriangle(ray, Triangle(v3, v2, v0));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(1., 1., 1.);
            isect.material.emissive = vec3(0.);
        }
    }
    
    // Ceiling
    {
        vec3 v0 = vec3(-12.6f, 12.5f, 25.0f);
        vec3 v1 = vec3( 12.6f, 12.5f, 25.0f);
        vec3 v2 = vec3( 12.6f, 12.5f, 15.0f);
        vec3 v3 = vec3(-12.6f, 12.5f, 15.0f);
        currentIsect = intersectTriangle(ray, Triangle(v0, v1, v2));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(0.7f, 0.7f, 0.7f);
            isect.material.emissive = vec3(0.);
        }
        currentIsect = intersectTriangle(ray, Triangle(v3, v2, v0));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(0.7f, 0.7f, 0.7f);
            isect.material.emissive = vec3(0.);
        }
    }
    
    // Light
    {
        vec3 v0 = vec3(-5.0f, 12.4f,  22.5f);
        vec3 v1 = vec3( 5.0f, 12.4f,  22.5f);
        vec3 v2 = vec3( 5.0f, 12.4f,  17.5f);
        vec3 v3 = vec3(-5.0f, 12.4f,  17.5f);
        currentIsect = intersectTriangle(ray, Triangle(v0, v1, v2));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(0.0f, 0.0f, 0.0f);
            isect.material.emissive = vec3(1.0f, 0.9f, 0.7f) * 20.0f;
        }
        currentIsect = intersectTriangle(ray, Triangle(v3, v2, v0));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(0.0f, 0.0f, 0.0f);
            isect.material.emissive = vec3(1.0f, 0.9f, 0.7f) * 20.0f;
        }
    }
    
    // Left wall
    {
        vec3 v0 = vec3(-12.5f, -12.6f, 25.0f);
        vec3 v1 = vec3(-12.5f, -12.6f, 15.0f);
        vec3 v2 = vec3(-12.5f,  12.6f, 15.0f);
        vec3 v3 = vec3(-12.5f,  12.6f, 25.0f);
        currentIsect = intersectTriangle(ray, Triangle(v0, v1, v2));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(0.7f, 0.1f, 0.1f);
            isect.material.emissive = vec3(0.);
        }
        currentIsect = intersectTriangle(ray, Triangle(v3, v2, v0));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(0.7f, 0.1f, 0.1f);
            isect.material.emissive = vec3(0.);
        }
    }
    
    // right wall 
    {
        vec3 v0 = vec3( 12.5f, -12.6f, 25.0f);
        vec3 v1 = vec3( 12.5f, -12.6f, 15.0f);
        vec3 v2 = vec3( 12.5f,  12.6f, 15.0f);
        vec3 v3 = vec3( 12.5f,  12.6f, 25.0f);
        currentIsect = intersectTriangle(ray, Triangle(v0, v1, v2));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(0.1f, 0.7f, 0.1f);
            isect.material.emissive = vec3(0.);
        }
        currentIsect = intersectTriangle(ray, Triangle(v3, v2, v0));
        if (currentIsect.t > ray.tMin && currentIsect.t < isect.t) {
            isect = currentIsect;
            isect.material.albedo = vec3(0.1f, 0.7f, 0.1f);
            isect.material.emissive = vec3(0.);
        }
    }
    
        
    return isect;
        
}

float fovToNearValue(float fovInEuler) {
    return 1. / tan(fovInEuler * 0.5f * PI / 180.f);        
}

vec4 miss() {
    return vec4(0.5f, 0.5f, 0.5f, 1.0f);
}

vec4 traceRay(Ray primaryRay, inout uint seed) {
    vec4 color = vec4(0.f, 0.f, 0.f, 1.f);
    vec3 lightIntensity = vec3(1.0f, 1.0f, 1.0f);
    Ray ray = primaryRay;
    
    for (int bounce = 0; bounce < BOUNCE_COUNT; ++bounce) {
        Intersection isect = intersect(ray);
        if (isect.t < ray.tMin || isect.t > ray.tMax) {
            if (bounce == 0)
                color = miss();
            break;
        }
        
        // light too weak, stop reflection
        if (lightIntensity.x < 0.001 && lightIntensity.y < 0.001 && lightIntensity.z < 0.001)
            break;
        
        // Create a secondary ray, bounced off of primary ray.
        ray.origin = ray.origin + isect.t * ray.direction + RAY_NORMAL_NUDGE * isect.normal;
        ray.direction = normalize(isect.normal + randomUnitVector(seed));
        
        color.xyz += isect.material.emissive * lightIntensity;
        lightIntensity *= isect.material.albedo;
    }
    
    return color;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // uv, in -1 ~ +1 on both axis
    vec2 uv = (fragCoord/iResolution.xy) * 2.f - 1.f;
    
    vec2 mouseUV = vec2(iMouse.x / iResolution.x, iMouse.y / iResolution.y);
    bool mouseDown = iMouse.z > 0.f;
    
    Camera camera;
    camera.pos = vec3(0.f, 0.0f, -5.f);
    camera.near = fovToNearValue(CAMERA_FOV);
    camera.aspectRatio = iResolution.x / iResolution.y;
    camera.samplePerPixel = CAMERA_SAMPLE_PER_PIXEL;
    camera.resolution = iResolution;
    
    uint seed = uint(uint(fragCoord.x) * uint(1973) + uint(fragCoord.y) * uint(9277) + uint(iFrame) * uint(26699)) | uint(1);
    
    vec4 color = vec4(0.);
    

#ifdef DEBUG_RAY_DIR
    Ray ray = raygen(uv, camera, seed);
    fragColor = vec4(ray.direction, 1.f);
#elif defined DEBUG_MOUSE
    fragColor = vec4(mouseUV, 0.f, 1.);
    if (mouseDown && uv.x < -0.9 && uv.y < -0.9f)
        fragColor = vec4(0.f, 0.f, 0.f, 1.f);
#elif defined DEBUG_RAND
    fragColor = vec4(randomUnitVector(seed), 1.f);
#else
    // Multisample (anti-aliasing)
    for (int s = 0; s < camera.samplePerPixel; ++s) {
        Ray ray = raygen(uv, camera, seed);
        color += traceRay(ray, seed) / float(camera.samplePerPixel);
    }

#ifdef TEMPORAL_ACCUM
    vec4 prev = texture(iChannel0, fragCoord / iResolution.xy);
    color = mix(prev, color, 1.0f / (float(iFrame) + 1.0f));
#endif
    
    fragColor = color;
#endif
}
