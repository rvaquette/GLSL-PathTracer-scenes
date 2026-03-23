#define MAX_STEPS 1000
#define MIN_DIST 0.001
#define MAX_DIST 100.
#define PI 3.14159265359

const Material nullMat = Material(-1., -1., vec3(-1));
const Object nullObj = Object(nullMat, -1);
const Hit nullHit = Hit(-1., nullObj);

// Cook-Torrance BRDF functions
// Starting with Fresnel-Schlick approximation

vec3 FresnelSchlick(float cosTheta, vec3 F0){
    float clamped = clamp(1. - cosTheta, 0., 1.);
    return F0 + (1. - F0) * pow(clamped, 5.);
}

// Using GGX model for normal distribution

float GGXDistribution(vec3 N, vec3 H, float roughness){
    float alpha = roughness * roughness;
    float alphaSquared = alpha * alpha;
    float alignment = max(dot(N, H), 0.);
    float alignmentSquared = alignment * alignment;
    float divisor = (alignmentSquared  * (alphaSquared - 1.) + 1.);
    divisor = divisor * divisor * PI;
    return alphaSquared / divisor;
}


// Using Schlick-GGX for geometry obstruction and shadowing
// Then using Smith to combine the two
float SchlickGGXGeometry(float NdotV, float roughness){
    float k = ((roughness + 1.) * (roughness + 1.)) / 8.;
    return NdotV / (k + NdotV * (1. - k));
}

float SmithGeometry(vec3 N, vec3 V, vec3 L, float roughness){
    float NdotV = max(dot(N, V), 0.);
    float NdotL = max(dot(N, L), 0.);
    return SchlickGGXGeometry(NdotV, roughness) * SchlickGGXGeometry(NdotL, roughness);
}

Hit map(vec3 p){
    // Basic sphere
    float radius = 1.;
    // 4x4 grid of spheres
    vec3 spherePos;
    float sphereDist;
    float minSphereDist = MAX_DIST;
    int id = -1;
    for (int i = 0; i < 4; ++i){
        for (int j = 0; j < 4; ++j){
            spherePos = vec3(i * 3, j * 3, 0) - vec3(4., 4., 0.);
            sphereDist = length(p - spherePos) - radius;
            if (sphereDist < minSphereDist){
                minSphereDist = sphereDist;
                id = i * 4 + j;
            }
        }
    }
    
    Object obj = getObjects()[id];
    
    return Hit(minSphereDist, obj);
}

vec3 getNormal(vec3 p){
    float ep = 0.001;
    vec3 xOffset = vec3(ep, 0, 0);
    vec3 yOffset = vec3(0, ep, 0);
    vec3 zOffset = vec3(0, 0, ep);
    float xDist = map(p + xOffset).dist - map(p - xOffset).dist;
    float yDist = map(p + yOffset).dist - map(p - yOffset).dist;
    float zDist = map(p + zOffset).dist - map(p - zOffset).dist;
    return normalize(vec3(xDist, yDist, zDist));
}

Hit raymarch(vec3 origin, vec3 direction){
    Hit hit = map(origin);
    float d = 0.;
    vec3 p = origin + direction * d;
    
    for (int i = 0; i < MAX_STEPS; ++i){
        p = origin + direction * d;
        hit = map(p);
        if (hit.dist <= MIN_DIST) return Hit(d, hit.obj);

        d += hit.dist;
        if (d >= MAX_DIST) return nullHit;
    }
    return nullHit;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{   
    // Normalized pixel coordinates (from -1 to 1)
    vec2 uv = (fragCoord * 2. - iResolution.xy) / iResolution.y;
    vec2 mouse = (iMouse.xy * 2. - iResolution.xy) / iResolution.y;
    
    vec3 cam = vec3(0., 0., -8.);
    vec3 dir = normalize(vec3(uv, 1.));
    
    cam.xz *= rot2d(mouse.x * -5.);
    dir.xz *= rot2d(mouse.x * -5.);
    
    //vec3 skyColor = vec3(0.33, 0.79, 1);
    vec3 skyColor = vec3(0.);
    
    Hit ray = raymarch(cam, dir);
    if (ray.obj == nullObj) {
        fragColor = vec4(skyColor, 1.0);
        return;
    }
    float d = ray.dist;
    vec3 p = cam + dir * d;
    vec3 normal = getNormal(p);
    vec3 view = normalize(cam - p);
    
    Object obj = ray.obj;
    Material mat = obj.material;
    
    vec3 outColor = vec3(0.);
    
    // Surface reflection at zero incidence
    // Assuming 0.04 for nonmetals
    // If metal, instead use the albedo for tint.
    vec3 F0 = vec3(0.04);
    F0 = mix(F0, mat.albedo, mat.metallic);
    
    int numLights = getLights().length();
    
    for (int i = 0; i < numLights; ++i){
        vec3 lightDir = getLights()[i].p - p;
        
        
        float lightDist = length(lightDir);
        lightDir = normalize(lightDir);
        vec3 halfway = normalize(lightDir + view);
        
        float attenuation = 1. / (lightDist * lightDist);
        vec3 radiance = getLights()[i].color * attenuation;
        
        // I'm unsure about this line; I've seen some sources argue that
        // This should be the dot product of the halfway vector and the view
        // vector, and some that say it should be this.
        float cosTheta = max(dot(normal, view), 0.);
        vec3 F = FresnelSchlick(cosTheta, F0);
        float G = SmithGeometry(normal, view, lightDir, mat.roughness);
        float D = GGXDistribution(normal, halfway, mat.roughness);
        
        
        // Cook-Torrance
        vec3 numerator = F * G * D;
        float denominator = 4. * max(dot(normal, view), 0.0001) * max(dot(normal, lightDir), 0.0001);
        vec3 specular = numerator / denominator; 
        
        vec3 kS = F;
        vec3 kD = (1. - F) * (1. - mat.metallic);	 
        
        float NdotL = max(dot(normal, lightDir), 0.);
        outColor += (kD * mat.albedo / PI + specular) * radiance * NdotL;
    }
    
    // Potentially add ambient occlusion and multiply this term by it
    vec3 ambient = vec3(0.03) * mat.albedo;
    vec3 color = ambient + outColor;
    
    // Map HDR to LDR
    color = color / (1. + color);
    // Gamma correction
    color = pow(color, vec3(0.45454));

    // Output to screen
    fragColor = vec4(color, 1.0);
}
