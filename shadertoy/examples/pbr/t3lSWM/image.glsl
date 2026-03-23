
struct Camera 
{
    vec3 position;
    vec3 direction;
    float zoom; 
} camera;

struct Sphere
{
    vec3 color;
    vec3 position;
    float radius;     
} sphere;

struct Light
{
	vec3 direction;    
} light;

struct Material 
{
    float diffuse;
    float specular;
    float shininess;
    float ambience;
} material;

void setupScene()
{
    camera.position = vec3(0., 0., 3.5);
    camera.direction = vec3(0., 0., -1.);
    camera.zoom = 1.0;
    
    sphere.position = vec3(0., 0., 0.);
    sphere.radius = 0.3;
    sphere.color = vec3(0.9, 0.2, 0.3);
    
    light.direction = normalize(vec3(0., -1., -0.78));
    
    material.ambience = 0.2;
    material.diffuse = 0.7;
    material.specular = 1.9;
    material.shininess = 10.0;    
}

bool solveQuadratic(float a, float b, float c, out float t0, out float t1)
{
    float disc = b * b - 4. * a * c;
    
    if (disc < 0.)
    {
        return false;
    } 
    
    if (disc == 0.)
    {
        t0 = t1 = -b / (2. * a);
        return true;
    }
    
    t0 = (-b + sqrt(disc)) / (2. * a);
    t1 = (-b - sqrt(disc)) / (2. * a);
    return true;    
}

bool intersect(vec3 direction, out vec3 surfaceNormal, out vec3 hitPoint)
{
    vec3 L = camera.position - sphere.position;
    
    float a = dot(direction, direction);
    float b = 2. * dot(direction, L);
    float c = dot(L, L) - pow(sphere.radius, 2.);
    
    float t0;
    float t1;
    
    if (solveQuadratic(a, b, c, t0, t1))
    {
        float t = t0;
        if (t1 < t0)
        {
            t = t1;
        }
        
        hitPoint = camera.position + t * direction;
        surfaceNormal = normalize(hitPoint - sphere.position);
        
        return true;
    }  
     
    return false;
}

vec3 rayTrace(vec3 direction)
{
    vec3 surfaceNormal;
    vec3 hitPoint;
     const float PI = 3.14159265359;
    if (intersect(direction, surfaceNormal, hitPoint))
    {
        float coeff = -dot(light.direction, surfaceNormal);    
        
        vec3 localPhit = hitPoint - sphere.position;
        vec2 uv = vec2(atan(localPhit.z, localPhit.x) / (2.0 * PI) + 0.5, asin(localPhit.y) / PI + 0.5);
        vec3 color = texture(iChannel0, uv).rgb;
        
        vec3 ambient = material.ambience * color;
        vec3 diffuse = material.diffuse * max(coeff, 0.) * color;
        
        float shininess = pow(max(-dot(direction, reflect(light.direction, surfaceNormal)), 0.), material.shininess);
        vec3 specular = material.specular * shininess * color;
        
        return ambient + diffuse + specular;
    }
    
    return vec3(0., 0., 0.);
}



void mainImage(out vec4 fragColor, in vec2 fragCoord)
{        
    setupScene();
    
    // Normalized pixel coordinates (from -0.5 to 0.5)
    vec2 uv = fragCoord/iResolution.xy - 0.5;
    uv.x *= (iResolution.x / iResolution.y); 
    
    vec3 direction = normalize(vec3(uv, camera.zoom) - camera.position);
    

        sphere.position.y = sin(iTime * 6.) / 3.;

    
    light.direction.x = -(iMouse.x / iResolution.x - 0.5);
    light.direction.y = -(iMouse.y / iResolution.y - 0.5);
    light.direction = normalize(light.direction);
    
    
    
    vec3 col = rayTrace(direction);

    // Output to screen
    fragColor = vec4(col, 1.0);
}
