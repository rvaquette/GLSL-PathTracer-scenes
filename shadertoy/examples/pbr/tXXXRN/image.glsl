/*

    Physically based rendering with direct and image based lighting.

    Always nice to see it be useful.
    Leave a comment if this was linked to from somewhere.

    Changing the cubemap in BufferB will propagate the new data to other tabs and trigger
    a re-render. Changing the resolution will use the existing data textures scaled to the
    new viewport. Because we use a texture atlas in BufferC, seam artifacts can appear.

    Edit 1: Added anisotropic BRDF and trick for IBL

    Edit 2: Added environment map filtering option ENV_FILTERING. Disabled by default.

    Edit 3: Fix missing /PI scaling for diffuse irradiance

    Edit 4: Some notes on spherical harmonics and changes to environment filtering
    
    Edit 5: Added a source discussing the details of spherical harmonics calculation
    
    Edit 6: Cleaned up specular sampling, corrected IBL calculation, added multiple scattering

    Based on:
    https://learnopengl.com/PBR/Theory
    https://google.github.io/filament/Filament.html
    https://cseweb.ucsd.edu/~ravir/papers/envmap/envmap.pdf

    https://www.shadertoy.com/view/ld3SRr
    https://www.shadertoy.com/view/ls3Szr
    https://www.shadertoy.com/view/lscBW4

    BufferA: Input and resolution change
    BufferB: Diffuse IBL with spherical harmonics
    BufferC: Specular IBL with prefiltered and BRDF integration maps

    BufferB also stores an equirectangular projection of the cubemap it loads. This is used
    as input for BufferC and also as the environment map for Image. This allows us to rerender
    the scene by changing just one iChannel input in BufferB.

    BufferC creates 5 prefiltered environment maps of decreasing resolution for various 
    roughness values. These are interpolated between to get the correct specular reflection
    on the spheres. BufferC also creates a two channel BRDF integration map needed for the 
    split-sum IBL.

*/

//  ----------------------- Uncomment to view buffer outputs -----------------------


// Use the matrices from BufferB to replace the environment map
//#define DISPLAY_DIFFUSE_SH


// The equirectangular projection of the cubemap from BufferB
//#define DISPLAY_ENVIRONMENT_MAP


// Prefiltered maps and BRDF integration map from BufferC
//#define DISPLAY_SPECULAR_MAPS


//  --------------------------------------------------------------------------------


// ----- Toggle two point lights
#define LIGHTS

// ----- Move lights
//#define ANIMATE_LIGHTS

// ----- Tone map spheres
#define TONEMAPPING

// Multiplied by strength later
const vec3 lightColour = vec3(1.0);

// Normal mapping using triplanar texture mapping of iChannel3
const vec3 DETAIL_SCALE = vec3(0.05);
const vec3 BLENDING_SHARPNESS = vec3(2.0);
const float DETAIL_HEIGHT = 0.05;

// ----- TODO: Physically based camera and light sources
// Shadertoy cubemaps are not HDR and diffuse irradiance can seem quite dull.
// We can artificially increase the strength of the image radiance in BufferB
const float AMBIENT_STRENGTH = 1.0;
const float EXPOSURE = 1.0;

const float SHADOW_SHARPNESS = 8.0;

// Raymaching of scene geometry
const float EPSILON = 1e-3;
const float MIN_DIST = 0.01;
const int MAX_STEPS = 128;
const float MAX_DIST = 100.0;

// Sphere size
float radius = 3.0;

// Sphere positioning in capped domain repetition
const float CELL = 10.0;
const float HALF_CELL = 0.5 * CELL;

//-------------------------- Camera ---------------------------

vec3 rayDirection(float fieldOfView, vec2 fragCoord) {
    vec2 xy = fragCoord - iResolution.xy / 2.0;
    float z = (0.5 * iResolution.y) / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

// https://www.geertarien.com/blog/2017/07/30/breakdown-of-the-lookAt-function-in-OpenGL/
mat3 lookAt(vec3 camera, vec3 at, vec3 up){
  vec3 zaxis = normalize(at-camera);    
  vec3 xaxis = normalize(cross(zaxis, up));
  vec3 yaxis = cross(xaxis, zaxis);

  return mat3(xaxis, yaxis, -zaxis);
}


//-------------------------- Geometry -------------------------

float sphereSDF(vec3 p, float radius) {
    return length(p) - radius;
}

vec3 getLightPosition(int i){

    #ifdef ANIMATE_LIGHTS
        float offset = 2.8+0.45*iTime;
    #else
        float offset = 2.8;
    #endif

    if(i == 0){
        return vec3(30.0*cos(offset), 4.0, 30.0*sin(offset)); 
    }
    return vec3(-2.0*cos(2.0*offset), 12.0,  -2.0*sin(2.0*offset));
}

float getLightSDF(vec3 p){
    float d = MAX_DIST;
    d = min(MAX_DIST, sphereSDF(p-getLightPosition(0), 0.2));
    d = min(d, sphereSDF(p-getLightPosition(1), 0.2));
    return d;
}

float getSDF(vec3 p){

    vec3 l = vec3(1,0,1);
    return sphereSDF(p-CELL*clamp(round(p/CELL),-l,l), radius);
}

float distanceToScene(vec3 cameraPos, vec3 rayDir, float start, float end, bool scene) {
	
    float depth = start;
    
    float dist;
    
    for (int i = 0; i < MAX_STEPS; i++){
    
        if(scene){
            dist = getSDF(cameraPos + depth * rayDir);
        }else{
            dist = getLightSDF(cameraPos + depth * rayDir);
        }
        
        if (dist < EPSILON){ return depth; }
        
        depth += dist;
        
        if (depth >= end){ return end; }
    }
    
    return depth;
}

// Tetrahedral normal technique with a loop to avoid inlining getSDF()
// This should improve compilation times
// https://iquilezles.org/articles/normalsSDF
vec3 getNormal(vec3 p){
    vec3 n = vec3(0.0);
    int id;
    for(int i = ZERO; i < 4; i++){
        vec3 e = 0.5773*(2.0*vec3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e*getSDF(p+e*EPSILON);
    }
    return normalize(n);
}

vec3 getTriplanar(vec3 position, vec3 normal){
    vec3 xaxis = texture(iChannel3, DETAIL_SCALE.x*(position.zy)).rgb;
    vec3 yaxis = texture(iChannel3, DETAIL_SCALE.y*(position.zx)).rgb;
    vec3 zaxis = texture(iChannel3, DETAIL_SCALE.z*(position.xy)).rgb;

    vec3 blending = abs(normal);
	blending = normalize(max(blending, 0.00001));
    blending = pow(blending, BLENDING_SHARPNESS);
	float b = (blending.x + blending.y + blending.z);
	blending /= b;

    return	xaxis * blending.x + 
       		yaxis * blending.y + 
        	zaxis * blending.z;
}


// Return the position of p extruded in the normal direction by normal map
vec3 getDetailExtrusion(vec3 p, vec3 normal, vec3 idx){
    float m = 0.0;
    if(idx.x == 0.0){
        m = 1.0;
    }
    if(idx.x == 1.0){
        m = 0.2;
    }
    float detail = m * DETAIL_HEIGHT*length(getTriplanar(12.0*p, normal));
    return p + detail * normal;
}

// Return the normal direction after applying a normal map
vec3 getDetailNormal(vec3 p, vec3 normal, vec3 idx){
    vec3 tangent;
    vec3 bitangent;
    // Construct orthogonal directions tangent and bitangent to sample detail gradient in
    pixarONB(normal, tangent, bitangent);
    
    tangent = normalize(tangent);
    bitangent = normalize(bitangent);
    
    float EPS = 1e-3;
    vec3 delTangent = 	getDetailExtrusion(p + tangent * EPS, normal, idx) - 
        				getDetailExtrusion(p - tangent * EPS, normal, idx);
    
    vec3 delBitangent = getDetailExtrusion(p + bitangent * EPS, normal, idx) - 
        				getDetailExtrusion(p - bitangent * EPS, normal, idx);
    
    return normalize(cross(delTangent, delBitangent));
}

//---------------------------- Material ----------------------------

// The domain is repeated and clamped. Store the cell a point is in to vary sphere materials
vec3 getIndex(vec3 p){
    return 1.0 + floor((p+HALF_CELL) / CELL);
}

// Base colour for dielectrics. This is overwritten for metals.
vec3 getAlbedo(vec3 p, vec3 normal, vec3 idx){

    // Have a smooth white dielectric sphere to demonstrate diffuse IBL
    if(idx.x == 2.0 && idx.z == 2.0){
        return vec3(1);
    }
    
    // Green corner sphere
    if(idx.x == 0.0 && idx.z == 0.0){
        return vec3(0.0625, 0.375, 0.0625);
    }
    
    // Diffuse colour for mixed sphere
    if(idx.x == 0.0 && idx.z == 1.0){
        return vec3(0.0125, 0.2625, 0.3125);
    }
    
    // Sky blue
    if(idx.x == 0.0 && idx.z == 2.0){
        return vec3(0.1125, 0.4125, 1.0);
    }
    
    // Striped
    if(idx.x == 2.0 && idx.z == 1.0){
        return mix(vec3(0.0625), vec3(1.0, 0.8125, 0.125), 
            smoothstep(0.0, 0.2, sin(5.8*p.y + 5.8*p.z)));
    }
    
    // Orange.
    return vec3(0.875, 0.125, 0.0);
}

// Metalness is binary
float getMetalness(vec3 p, vec3 normal, vec3 idx){
    if(idx.x == 0.0 && idx.z == 1.0){
        // Have one sphere mixing metal and dielectric based on texture
        return length(getTriplanar(12.0*p, normal)) > 0.4 ? 1.0 : 0.0;
    }else{
        // Middle row is metal
        return mod(idx.x, 2.0);
    }
}

float getRoughness(vec3 p, vec3 normal, float metalness, vec3 idx){
    float roughness = 0.0;
    if(idx.x == 0.0 && idx.z == 1.0){
        // Mixed sphere roughness depends on material
        roughness = metalness == 1.0 ?
            0.25*saturate(length(getTriplanar(1.0*p, normal)))
          : 0.5*length(getTriplanar(12.0*p, normal));
    }else if(idx.x == 1.0 && idx.z == 2.0){
        // Copper sphere roughness
        roughness = 0.3;
    }else{
        // Rougness gradient in z direction
        roughness = idx.z / 3.0;
    }

    // Stop roughness being 0 or 1
    return clamp(roughness, 0.05, 0.999);
}


//---------------------------- PBR ----------------------------

// Trowbridge-Reitz AKA GGX
float distribution(vec3 n, vec3 h, float roughness){
    float a_2 = roughness * roughness;
	return a_2/(PI * pow(pow(dot_c(n, h), 2.0) * (a_2 - 1.0) + 1.0, 2.0));
}

// Schlick-Beckmann
float geometry(float cosTheta, float k){
	return (cosTheta) / (cosTheta * (1.0 - k) + k);
}

float smiths(float NdotV, float NdotL, float roughness){
    float k = pow(roughness + 1.0, 2.0) / 8.0; 
	return geometry(NdotV, k) * geometry(NdotL, k);
}

// Anisotropic distribution and visibility functions from Filament
// GGX
float distributionAnisotropic(float NoH, vec3 h, vec3 t, vec3 b, float at, float ab) {
    float ToH = dot(t, h);
    float BoH = dot(b, h);
    float a2 = at * ab;
    vec3 v = vec3(ab * ToH, at * BoH, a2 * NoH);
    float v2 = dot(v, v);
    float w2 = a2 / v2;
    return a2 * w2 * w2 * (1.0 / PI);
}

// Smiths GGX correlated anisotropic
float smithsAnisotropic(float at, float ab, float ToV, float BoV,
                                       float ToL, float BoL, float NoV, float NoL) {
    float lambdaV = NoL * length(vec3(at * ToV, ab * BoV, NoV));
    float lambdaL = NoV * length(vec3(at * ToL, ab * BoL, NoL));
    float v = 0.5 / (lambdaV + lambdaL);
    return saturate(v);
}

// Fresnel-Schlick
vec3 fresnel(float cosTheta, vec3 F0){
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
} 

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness){
    return F0 + (max(vec3(1.0-roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

// Cook-Torrance BRDF
vec3 BRDF(vec3 p, vec3 n, vec3 viewDir, vec3 lightDir, vec3 albedo, float metalness, 
            float roughness, vec3 F0,
            vec3 tangent, vec3 bitangent, float anisotropy,
            vec3 energyCompensation){
            
    vec3 h = normalize(viewDir + lightDir);
    float cosTheta = dot_c(h, viewDir);
    
    // Lambertian diffuse reflectance
    vec3 diffuse = albedo / PI;
    
    // Normal distribution
    // What fraction of microfacets are aligned in the correct direction
    float D;

    // Fresnel term
    // How reflective are the microfacets viewed from the current angle
    vec3 F = fresnelSchlickRoughness(cosTheta, F0, roughness);

    // Geometry term
    // What fraction of the microfacets are lit and visible
    float G;
    
    // Visibility term. 
    // In Filament it combines the geometry term and the denominator
    float V;
    
    float NdotL = dot_c(lightDir, n);
    float NdotV = dot_c(viewDir, n);
    
    if(anisotropy == 0.0){
    
        D = distribution(n, h, roughness);
        G = smiths(NdotV, NdotL, roughness);
        V = G / max(0.0001, (4.0 * NdotV * NdotL));
        
    }else{
    
        float at = max(roughness * (1.0 + anisotropy), 0.001);
        float ab = max(roughness * (1.0 - anisotropy), 0.001);
        
        D = distributionAnisotropic(dot_c(n, h), h, tangent, bitangent, at, ab);
        
        V = smithsAnisotropic(at, ab, dot_c(tangent, viewDir), 
                                                     dot_c(bitangent, viewDir),
                                                     dot_c(tangent, lightDir), 
                                                     dot_c(bitangent, lightDir),
                                                     dot_c(n, viewDir), 
                                                     dot_c(n, lightDir));
    
    }
    
    // Specular reflectance
    vec3 specular = D * F * V;
    
    specular *= energyCompensation;
    
    // Combine diffuse and specular
    vec3 kD = (1.0 - F) * (1.0 - metalness);
    return kD * diffuse + specular;
}


//---------------------------- Shadows ----------------------------

// https://iquilezles.org/articles/rmshadows
float softShadow(vec3 pos, vec3 rayDir, float start, float end, float k ){
    float res = 1.0;
    float depth = start;
    for(int counter = ZERO; counter < MAX_STEPS; counter++){
        float dist = getSDF(pos + rayDir * depth);
        if( abs(dist) < EPSILON){ return 0.0; }       
        if( depth > end){ break; }
        res = min(res, k*dist/depth);
        depth += dist;
    }
    return res;
}


//------------------------------ IBL ------------------------------

// BufferB writes matrices of the spherical harmonics coefficients for red, green and blue.
// These can be used to get the channel value in a given direction
vec3 getSHIrradiance(vec3 normal){

    vec4 n = vec4(normal, 1.0);
    
    mat4 redMatrix = mat4(
        texelFetch(iChannel1, ivec2(0,0), 0),
        texelFetch(iChannel1, ivec2(0,1), 0),
        texelFetch(iChannel1, ivec2(0,2), 0),
        texelFetch(iChannel1, ivec2(0,3), 0));
    
    
    mat4 grnMatrix = mat4(
        texelFetch(iChannel1, ivec2(1,0), 0),
        texelFetch(iChannel1, ivec2(1,1), 0),
        texelFetch(iChannel1, ivec2(1,2), 0),
        texelFetch(iChannel1, ivec2(1,3), 0));
    
    
    mat4 bluMatrix = mat4(
        texelFetch(iChannel1, ivec2(2,0), 0),
        texelFetch(iChannel1, ivec2(2,1), 0),
        texelFetch(iChannel1, ivec2(2,2), 0),
        texelFetch(iChannel1, ivec2(2,3), 0));
    
    float r = dot(n, redMatrix * n);
    float g = dot(n, grnMatrix * n);
    float b = dot(n, bluMatrix * n);
    
    return vec3(r, g, b);
}

// Get the environment colour from the equirectangular projection of the cubemap from bufferB
// Clamp texture coordinates to reduce the seam artifact
vec3 getEnvironment(vec3 rayDir, vec2 scaleSize){
    vec2 texCoord = vec2((atan(rayDir.z, rayDir.x) / TWO_PI) + 0.5, acos(rayDir.y) / PI);
    texCoord.x = clamp(texCoord.x, 1.e-3, 0.999);
    texCoord *= scaleSize;
    return texture(iChannel1, texCoord).rgb;
}

// https://google.github.io/filament/Filament.md.html#lighting/imagebasedlights/anisotropy
vec3 getReflectedVector(vec3 v, vec3 n, vec3 t, vec3 b, float roughness, float anisotropy) {
    vec3  anisotropyDirection = anisotropy >= 0.0 ? b : t;
    vec3  anisotropicTangent  = cross(anisotropyDirection, -v);
    vec3  anisotropicNormal   = cross(anisotropicTangent, anisotropyDirection);
    vec3  bentNormal          = normalize(mix(n, anisotropicNormal, abs(anisotropy)));

    return reflect(v, bentNormal);
}

// Get two prefiltered roughness environment maps and linearly interpolate
// between them to get the roughness data needed.
vec3 getEnvironment(vec3 rayDir, float roughness, vec2 scaleSize){

    // There are 5 levels of roughness (0.0, 0.25, 0.5, 0.75, 1.0)
    float level1 = floor(1.0+(roughness) * 5.0);
    
    // Level 0 would give us the entire atlas
    level1 = max(1.0, level1);
    
    float level2 = level1 + 1.0;
    level2 = min(level2, 5.0);
    
    // The dimensions of the projection tile as a fraction of the viewport.
    float size1 = 1.0/pow(2.0, level1);
    float size2 = 1.0/pow(2.0, level2);
    
    // The offset in the x direction. y offset is always 0
    float offset1 = 0.0;
    float i;
    // The offset of the tile in the atlas is the sum of tiles before it (1/2 + 1/4 + ...)
    for(i = 1.0; i < level1; i++){
    	offset1 += 1.0/pow(2.0, i);
    }
    
    float offset2 = offset1 + 1.0/pow(2.0, i);
    
    vec2 texCoord1 = vec2((atan(rayDir.z, rayDir.x) / TWO_PI) + 0.5, acos(rayDir.y) / PI);
                    
    vec2 texCoord2 = vec2((atan(rayDir.z, rayDir.x) / TWO_PI) + 0.5, acos(rayDir.y) / PI);

    float f = fract(roughness * 5.0);
    
    
    // Clamp texture coordinates to reduce the seam artifact. Depends on level.
    texCoord1.x = clamp(texCoord1.x, 0.0 + level1 * 0.005, 1.0 - level1 * 0.005);
    texCoord2.x = clamp(texCoord2.x, 0.0 + level2 * 0.005, 1.0 - level2 * 0.005);
    
    
    // Scale and offset to correct atlas tile
    texCoord1 = vec2(offset1, 0.0) + size1 * texCoord1;
    texCoord2 = vec2(offset2, 0.0) + size2 * texCoord2;
    
    // When changing to fullscreen, the atlas is not rerendered. 
    // Find the scaled relative coordinates
    texCoord1 *= scaleSize;
    texCoord2 *= scaleSize;
    
    return mix(texture(iChannel2, texCoord1).rgb, texture(iChannel2, texCoord2).rgb, f);
}

vec2 getBRDFIntegrationMap(vec2 coord, vec2 scaleSize){
    // Avoid reading outside the tile in the atlas
    coord = clamp(coord, 1e-5, 0.99);
    vec2 texCoord = vec2(coord.x/2.0, coord.y / 2.0 + 0.5);
    texCoord *= scaleSize;
    return texture(iChannel2, texCoord).rg;
}


//---------------------------- Lighting ----------------------------

vec3 getIrradiance(vec3 p, vec3 rayDir, vec3 geoNormal, vec3 idx, vec2 scaleSize){
    vec3 I = vec3(0);
    vec3 radiance = vec3(0);
    vec3 lightDir = vec3(0);
    vec3 vectorToLight = vec3(0);
    
    vec3 n = getDetailNormal(p, geoNormal, idx);
    vec3 albedo = getAlbedo(p, n, idx);
    float metalness = getMetalness(p, n, idx);
    float roughness = getRoughness(p, n, metalness, idx);
    
    // Index of refraction for common dielectrics. Corresponds to f0 4%
    float IOR = 1.5;

    // Reflectance of the surface when looking straight at it along the negative normal
    vec3 F0 = vec3(pow(IOR - 1.0, 2.0) / pow(IOR + 1.0, 2.0));
    
    float anisotropy = 0.0;
    
    // Metals tint specular reflections.
    // https://docs.unrealengine.com/en-US/RenderingAndGraphics/Materials/PhysicallyBased/index.html
    vec3 tintColour;
    if(idx.x == 1.0 && idx.z == 1.0){
        // Silver
        tintColour = vec3(0.972, 0.960, 0.915);
    }else if(idx.x == 1.0 && idx.z == 2.0){
        // Copper
        // Add darker circles
        float weight = length(getTriplanar(8.0*(p.xxx+p.yyy+p.zzz), geoNormal));
        tintColour = saturate(0.6 + max(0.2, weight)) * vec3(0.955, 0.637, 0.538);
        anisotropy = -0.5;
        // Remove normal mapping
        n = geoNormal;
    }else{
        // Gold
        // https://www.youtube.com/watch?v=j-A0mwsJRmk&ab_channel=ACMSIGGRAPH
        tintColour = vec3(1.022, 0.782, 0.344);
    }

    F0 = mix(F0, tintColour, metalness);
    
    vec2 envBRDF = getBRDFIntegrationMap(vec2(dot_c(n, -rayDir), roughness), scaleSize);
    // https://google.github.io/filament/Filament.html#materialsystem/improvingthebrdfs/energylossinspecularreflectance
    vec3 energyCompensation = 1.0 + F0 * (1.0 / envBRDF.y - 1.0);
    
    // Anisotropy directions
    vec3 tangent;
    vec3 bitangent;
    
    if(anisotropy != 0.0){
    
        //Normalise position
        vec3 pos = p - idx * vec3(CELL); 

        //Tangent and bitangent on a sphere have a nice solution given an orientation direction
        //https://computergraphics.stackexchange.com/questions/5498/compute-sphere-tangent-for-normal-mapping
        tangent = normalize(cross(vec3(1), pos));
        bitangent = normalize(cross(geoNormal, tangent));
    }
    
    // Find direct lighting for all sources
    
    #ifdef LIGHTS
    for(int i = ZERO; i < 2; i++){
        
        vec3 position = getLightPosition(i);
        vectorToLight = position-p;
        lightDir = normalize(vectorToLight);
        radiance = i == 0 ? 1.5 * lightColour : 1.0 * lightColour;
        
        float shadow = softShadow(p + n * EPSILON * 2.0, lightDir, MIN_DIST, length(vectorToLight), SHADOW_SHARPNESS);
                                  
        I +=  shadow 
            * BRDF(p, n, -rayDir, lightDir, albedo, metalness, roughness, F0, tangent, bitangent, anisotropy, energyCompensation) 
            * radiance 
            * dot_c(n, lightDir);
    }

    #endif
    
    // Find ambient diffuse IBL component
    
    vec3 F = fresnelSchlickRoughness(dot_c(n, -rayDir), F0, roughness);
	vec3 kD = (1.0 - F) * (1.0 - metalness);
	vec3 irradiance = AMBIENT_STRENGTH * getSHIrradiance(n);
	vec3 diffuse    = irradiance * albedo / PI;
    
    // Find ambient specular IBL component
    
    vec3 R;
    
    if(anisotropy == 0.0){
        R = reflect(rayDir, n);
    }else{      
        R = getReflectedVector(rayDir, n, tangent, bitangent, roughness, anisotropy);
    }
    
    vec3 prefilteredColor = getEnvironment(R, roughness, scaleSize);   
    vec3 specular = prefilteredColor * mix(envBRDF.xxx, envBRDF.yyy, F0);
    
    specular *= energyCompensation;
    
	vec3 ambient = kD * diffuse + specular;
    
    // Combine direct and IBL lighting
    return ambient + I;
}

// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x){
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}
void mainImage( out vec4 fragColor, in vec2 fragCoord ){

    // Read the size of the texture atlas and environment map
    vec2 atlasSize = texelFetch(iChannel2, ivec2(5.5), 0).rg;
    vec2 scaleSize = 1.0/(iResolution.xy/atlasSize);
    
    vec3 rayDir = rayDirection(60.0, fragCoord);

    //----------------- Define a camera -----------------

    vec3 cameraPos = texelFetch(iChannel0, ivec2(0.5, 1.5), 0).xyz;
    vec3 targetDir = -cameraPos;
    vec3 up = vec3(0.0, 1.0, 0.0);

    // Get the view matrix from the camera orientation
    mat3 viewMatrix = lookAt(cameraPos, targetDir, up);

    // Transform the ray to point in the correct direction
    rayDir = normalize(viewMatrix * rayDir);
    
    //---------------------------------------------------

    vec3 p;
    vec3 col;
    
    float distToLight = MAX_DIST;
    
    #ifdef LIGHTS
        distToLight = distanceToScene(cameraPos, rayDir, MIN_DIST, MAX_DIST, false);
    #endif
    float t = distanceToScene(cameraPos, rayDir, MIN_DIST, distToLight, true);
    
    if(t < MAX_DIST){
        p = cameraPos + rayDir * t;
        vec3 normal = getNormal(p);
        vec3 idx = getIndex(p);
        if(t == distToLight){
            col = lightColour;
        }else{
            col = EXPOSURE * getIrradiance(p, rayDir, normal, idx, scaleSize);
            #ifdef TONEMAPPING
                col = ACESFilm(col);
            #endif
        }
    } else {
        col = getEnvironment(rayDir, scaleSize);
        #ifdef DISPLAY_DIFFUSE_SH
            col = getSHIrradiance(rayDir);
        #endif
    }
      
    vec2 uv = fragCoord.xy/iResolution.xy;

    #ifdef DISPLAY_ENVIRONMENT_MAP
        col = texture(iChannel1, uv*scaleSize).rgb;
    #endif
    
    #ifdef DISPLAY_SPECULAR_MAPS
        col = texture(iChannel2, uv*scaleSize).rgb;
    #endif
    
    col = gamma(col);
    
    fragColor = vec4(col,1.0);
}
