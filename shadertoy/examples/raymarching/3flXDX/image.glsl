/*	
    Normal mapping arbitrary shapes with synthesized pattern texture. 

	Long compilation times on some platforms.

	Edit: 	Spherical harmonics for diffuse IBL
		 	To change the environment, swap the cubemap in Buffer C.
            
    Based on:
	https://learnopengl.com/PBR/Theory
	https://tinyurl.com/y5ebd7w7
	https://google.github.io/filament/Filament.md.html
	https://graphics.pixar.com/library/OrthonormalB/paper.pdf

	
	We raymarch the union of simple shapes and apply a heightfield texture from Buffer B to 
	adjust the surface normals using triplanar mapping. We create an orthonormal coordinate 
	system based on the surface normal of the unrotated shape. This basis has a discontinuity
	at the z-plane where one of the coordinate axes is flipped. As we sample the neighbourhood
	symmetrically across the origin, this should  not cause visual artefacts, however, we need
	to clamp the z value as very small values break the basis construction.
	
	Colour is calculated using PBR with diffuse IBL using spherical harmonics. There is no 
	specular IBL.
	
	Normal mapping will lead to an impossible surface where the view ray and normal dot 
	product is negative. Using PBR, this leads to negative radiance and black artefacts at 
	detail fringes. See "Microfacet-based Normal Mapping for Robust Monte Carlo Path Tracing"
	by Schüssler et al. for a discussion of a physically correct solution. We just clamp the
	dot product with a normal to some small	value.

*/

#define HEAD 0
#define EARS 1
#define SNOUT 2
#define BODY 3
#define ARMS 4
#define LEGS 5
#define NOSE 6
#define EYES 7
#define TAIL 8

//#define ANIMATE_LIGHT

// Variable iterator initializer to stop loop unrolling
#define ZERO (min(iFrame,0))

// azimuth
float sunLocation = 2.05;

// 0: horizon, 1: zenith
float sunHeight = 0.5;

const int MAX_STEPS = 64;
const float MIN_DIST = 0.01;
const float MAX_DIST = 10.0;
const float EPSILON = 1e-4;
const float DETAIL_EPSILON = 1e-2;
const float SHADOW_SHARPNESS = 2.0;
const float DETAIL_HEIGHT = 0.02;
const vec3 DETAIL_SCALE = vec3(1.0);
const vec3 BLENDING_SHARPNESS = vec3(16.0);

const float AMBIENT_STRENGTH = 2.8;
const float EXPOSURE = 0.65;

// Minimum dot product value
const float minDot = 1e-5;

// Clamped dot product
float dot_c(vec3 a, vec3 b){
	return max(dot(a, b), minDot);
}

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

//---------------------------- Rotations ----------------------------

vec3 rotate(vec3 p, vec4 q){
  return 2.0 * cross(q.xyz, p * q.w + cross(q.xyz, p)) + p;
}

vec3 rotateX(vec3 p, float angle){
    return rotate(p, vec4(sin(angle/2.0), 0.0, 0.0, cos(angle/2.0)));
}

vec3 rotateY(vec3 p, float angle){
	return rotate(p, vec4(0.0, sin(angle/2.0), 0.0, cos(angle/2.0)));
}

vec3 rotateZ(vec3 p, float angle){
	return rotate(p, vec4(0.0, 0.0, sin(angle), cos(angle)));
}


//---------------------------- Positioning ----------------------------

// Rotate and translate part for SDF depending on the id.
void setPosition(inout vec3 p, inout vec3 n, int id){
    float angleX;
    float angleZ;
    
    vec3 globalOffset = vec3(0, -1 , 0);
    
    vec3 offset = globalOffset;

    // GPUs love branching!
    if(id == HEAD){
		p = p + offset;
        return;
        
    }else if(id == EARS){
        angleZ = -2.35;
        offset += vec3(0.0, -0.5, -0.5);
        if(p.z > 0.0){
            p = rotateZ(p+offset, angleZ);
            n = rotateZ(n, angleZ);
            return;
        }else{
            p = rotateZ(p+offset*vec3(1,1,-1), angleZ);
            n = rotateZ(n, angleZ);
            return;
        }
        
    }else if(id == SNOUT){
        angleZ = -0.25;
        p = rotateZ(p+offset, angleZ)+vec3(0.55, 0.0, 0.0);
        n = rotateZ(n, angleZ);
        return;
        
    }else if(id == BODY){
        offset += vec3(0.0, 1.4, -0.0);
    	p = p + offset;
        return;
        
    }else if(id == ARMS){
        angleX = -1.0;
        angleZ = -1.0;
        offset += vec3(0.0, 0.95, -0.38);
        if(p.z > 0.0){
            p = rotateX(rotateZ(p+offset, angleZ), angleX);
            n = rotateX(rotateZ(n, angleZ), angleX);
            return;
        }else{
            p = rotateX(rotateZ(p+offset * vec3(1,1,-1), angleZ), -angleX);
            n = rotateX(rotateZ(n, angleZ), -angleX);
            return;
        }

    }else if(id == LEGS){
        angleX = -0.5;
        angleZ = -1.2;
        offset += vec3(0.05, 2.05, -0.3);
        if(p.z > 0.0){
            p = rotateX(rotateZ(p+offset, angleZ), angleX);
            n = rotateX(rotateZ(n, angleZ), angleX);
            return;
        }else{
            p = rotateX(rotateZ(p+offset * vec3(1,1,-1), angleZ), -angleX);
            n = rotateX(rotateZ(n, angleZ), -angleX);
            return;
        }
    
    }else if(id == NOSE){
        offset += vec3(0.7, 0.18, 0.0);
        p = p + offset;
        return;
        
    }else if(id == EYES){
        offset += vec3(0.55, 0.0, -0.25);
    	p = p + offset;
        return;

    }else if(id == TAIL){
        offset += vec3(-0.5, 1.9, 0.0);
    	p = rotateZ(p + offset, -0.2);
        n = rotateZ(n, -0.2);
        return;
    }
}

//---------------------------- Distance functions ----------------------------

vec4 opElongate( in vec3 p, in vec3 h ){ 
    vec3 q = abs(p)-h;
    return vec4( max(q,0.0), min(max(q.x,max(q.y,q.z)),0.0) );
}

float sphereSDF(vec3 p, float radius) {
    return length(p) - radius;
}

float torusSDF(vec3 p, float smallRadius, float largeRadius) {
	return length(vec2(length(p.xz) - largeRadius, p.y)) - smallRadius;
}

float sdRoundCone( vec3 p, float r1, float r2, float h ){
  vec2 q = vec2( length(p.xz), p.y );
    
  float b = (r1-r2)/h;
  float a = sqrt(1.0-b*b);
  float k = dot(q,vec2(-b,a));
    
  if( k < 0.0 ) return length(q) - r1;
  if( k > a*h ) return length(q-vec2(0.0,h)) - r2;
        
  return dot(q, vec2(a,b) ) - r1;
}

// Update part id when smallest distance has changed.
void trackMaterial(inout float oldDist, float dist, inout int oldId, int id){
    if(dist != oldDist){
    	oldDist = dist;
        oldId = id;
    }
}

// Get the combined SDF of the body. Arms, legs, ears and eyes are evaluated once by using
// the absolute value of Z to mirror them across the plane, reducing overall work. Keep track
// of which body part is the closest to determine texture rotation later.
float getSDF(vec3 position, inout int id) {
    float dist = 1e10;
    float oldDist = dist;

    // Two variables for temporary position manipulation
    vec3 q;
    vec4 w;

    // Unused here
    vec3 n;
    
    // Head
    q = position;
   	setPosition(q, n, HEAD);
    w = opElongate(q, vec3(-0.08, 0, 0));
    dist = min(dist, sphereSDF(w.xyz, 0.7));
    trackMaterial(oldDist, dist, id, HEAD);
    
    // Ears, mirrored
    q = position;
    q.z = abs(q.z);
    setPosition(q, n, EARS);
    dist = min(dist, torusSDF(q, 0.12, 0.12));
    trackMaterial(oldDist, dist, id, EARS);
   
    // Snout
    q = position;
    setPosition(q, n, SNOUT);
    w = opElongate(q, vec3(-0.08, 0, 0));
    dist = min(dist, sphereSDF(w.xyz, 0.3));
    trackMaterial(oldDist, dist, id, SNOUT);
    
    // Body
    q = position;
    setPosition(q, n, BODY);
    w = opElongate(q, vec3(-0.2, 0.2, -0.08));
    dist = min(dist, sphereSDF(w.xyz, 0.75));
    trackMaterial(oldDist, dist, id, BODY);
    
    // Arms, mirrored
    q = position;
    q.z = abs(q.z);
    setPosition(q, n, ARMS);
    dist = min(dist, sdRoundCone(q, 0.3, 0.28, 0.7));
    trackMaterial(oldDist, dist, id, ARMS);
	
    // Legs, mirrored
    q = position;
    q.z = abs(q.z);
    setPosition(q, n, LEGS);
    dist = min(dist, sdRoundCone(q, 0.3, 0.3, 0.7));
    trackMaterial(oldDist, dist, id, LEGS);
    
    // Nose
    q = position;
    setPosition(q, n, NOSE);
	w = opElongate(q, vec3(-0.04,0.0, 0.02) );
    dist = min(dist, sphereSDF(w.xyz, 0.08));
    trackMaterial(oldDist, dist, id, NOSE);
    
    // Eyes, mirrored
    q = position;
    q.z = abs(q.z);
    setPosition(q, n, EYES);
    dist = min(dist, sphereSDF(q, 0.05));
    trackMaterial(oldDist, dist, id, EYES);
    
    // Tail
    q = position;
    setPosition(q, n, TAIL);
    dist = min(dist, sphereSDF(q, 0.15));
    trackMaterial(oldDist, dist, id, TAIL);

    return dist;
}

float distanceToScene(vec3 cameraPos, vec3 rayDir, float start, float end, out int id) {
	
    // Start at a predefined distance from the camera in the ray direction
    float depth = start;
    
    // Variable that tracks the distance to the scene 
    // at the current ray endpoint
    float dist;
    
    // For a set number of steps
    for (int i = ZERO; i < MAX_STEPS; i++) {
        
        // Get the sdf value at the ray endpoint, giving the maximum 
        // safe distance we can travel in any direction without hitting a surface
        dist = getSDF(cameraPos + depth * rayDir, id);
        
        // If it is small enough, we have hit a surface
        // Return the depth that the ray travelled through the scene
        if (dist < EPSILON){
            return depth;
        }
        
        // Else, march the ray by the sdf value
        depth += dist;
        
        // Test if we have left the scene
        if (depth >= end){
            id = -1;
            return end;
        }
    }

    return depth;
}

//---------------------------- Normal mapping ----------------------------

// https://tinyurl.com/y5ebd7w7
vec3 getTriplanar(vec3 position, vec3 normal, int id){

    setPosition(position, normal, id);

    vec3 xaxis;
    vec3 yaxis;
    vec3 zaxis;

    xaxis = texture(iChannel1, DETAIL_SCALE.x*(position.zy)).rgb;
    yaxis = texture(iChannel1, DETAIL_SCALE.y*(position.zx)).rgb;
    zaxis = texture(iChannel1, DETAIL_SCALE.z*(position.xy)).rgb;


    if(id == EYES || id == NOSE){
    	xaxis = xaxis.ggg;
    	yaxis = yaxis.ggg;
    	zaxis = zaxis.ggg;
    }else{
    	xaxis = xaxis.rrr;
    	yaxis = yaxis.rrr;
    	zaxis = zaxis.rrr;
    }

    vec3 blending = abs(normal);
	blending = normalize(max(blending, 0.00001));
    blending = pow(blending, BLENDING_SHARPNESS);
	float b = (blending.x + blending.y + blending.z);
	blending /= b;

    return	xaxis * blending.x + 
       		yaxis * blending.y + 
        	zaxis * blending.z;
}

//Return the position of p extruded in the normal direction by normal map
vec3 getDetailExtrusion(vec3 p, vec3 normal, int id){
    float detail = DETAIL_HEIGHT*length(getTriplanar(p, normal, id));
    return p + detail * normal;
}

// Get surface normal from the gradient of the surrounding sdf field
// by sampling the values in the neighbouring area
/*
vec3 getNormal(vec3 p) {
    int id;
    return normalize(vec3(
        getSDF(vec3(p.x + EPSILON, p.y, p.z), id) - 
        getSDF(vec3(p.x - EPSILON, p.y, p.z), id),
        getSDF(vec3(p.x, p.y + EPSILON, p.z), id) - 
        getSDF(vec3(p.x, p.y - EPSILON, p.z), id),
        getSDF(vec3(p.x, p.y, p.z + EPSILON), id) - 
        getSDF(vec3(p.x, p.y, p.z - EPSILON), id)
    ));
}*/

// Tetrahedral normal technique with a loop to avoid inlining getSDF()
// This should improve compilation times
// https://iquilezles.org/articles/normalsSDF
vec3 getNormal(vec3 p){
    vec3 n = vec3(0.0);
    int id;
    for(int i = ZERO; i < 4; i++){
        vec3 e = 0.5773*(2.0*vec3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e*getSDF(p+e*EPSILON, id);
    }
    return normalize(n);
}

// Get orthonormal basis from surface normal
// https://graphics.pixar.com/library/OrthonormalB/paper.pdf
void pixarONB(vec3 n, out vec3 b1, out vec3 b2){
	float sign_ = n.z >= 0.0 ? 1.0 : -1.0;
	float a = -1.0 / (sign_ + n.z);
	float b = n.x * n.y * a;
	b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
	b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

// Return the the normal after applying a normal map
vec3 getDetailNormal(vec3 p, vec3 normal, float t, int id){
    vec3 tangent;
    vec3 bitangent;
    // Construct orthogonal directions tangent and bitangent to sample detail gradient in
    pixarONB(normal, tangent, bitangent);
    
    tangent = normalize(tangent);
    bitangent = normalize(bitangent);
    
    float EPS = DETAIL_EPSILON * 0.2;
    
    vec3 delTangent = vec3(0);
    vec3 delBitangent = vec3(0);
    
    for(int i = ZERO; i < 2; i++){
        
        // i ->  s
        // 0 ->  1
        // 1 -> -1
        float s = 1.0 - 2.0 * float(i&1);
    
        delTangent += s * getDetailExtrusion(p + s * tangent * EPS, normal, id);

        delBitangent += s * getDetailExtrusion(p + s * bitangent * EPS, normal, id);

    }
    
    return normalize(cross(delTangent, delBitangent));
}

//---------------------------- Shadows ----------------------------

// https://iquilezles.org/articles/rmshadows
float softShadow(vec3 pos, vec3 rayDir, float start, float end, float k ){
    float res = 1.0;
    float depth = start;
    int id;
    for(int counter = ZERO; counter < MAX_STEPS; counter++){
        float dist = getSDF(pos + rayDir * depth, id);
        if( abs(dist) < EPSILON){ return 0.0; }       
        if( depth > end){ break; }
        res = min(res, k*dist/depth);
        depth += dist;
    }
    return res;
}

// Ambient occlusion reduces the ambient light strength in areas which are closely shielded 
// by other objects
// https://www.youtube.com/watch?v=22PZF7fWLqI
float ambientOcclusion(vec3 position, vec3 normal){

	float ao = 0.0;
    // step size
    float del = 0.08;
    float weight = 0.1;
    
    // Travel out from point with fixed step size and accumulate proximity to other surfaces
    // iq slides include 1.0/pow(2.0, i) factor to reduce the effect of farther objects
    // but Peer Play uses just 1.0/dist
    int id;
    for(int i = ZERO; i < 5; i++){
        float dist = float(i+1) * del;
    	// Ignore measurements from inside objects
    	ao += max(0.0, (dist - getSDF(position + normal * dist, id))/dist);
    }
    // Return a weighted occlusion amount
    return 1.0 - weight * ao;
}


//---------------------------- PBR ----------------------------

// Trowbridge-Reitz
float distribution(vec3 n, vec3 h, float roughness){
    float a_2 = roughness * roughness;
	return a_2/(PI * pow(pow(dot_c(n, h), 2.0) * (a_2 - 1.0) + 1.0, 2.0));
}

// GGX and Schlick-Beckmann
float geometry(float cosTheta, float k){
	return (cosTheta) / (cosTheta * (1.0 - k) + k);
}

float smiths(float NdotV, float NdotL, float roughness){
    float k = pow(roughness + 1.0, 2.0) / 8.0; 
	return geometry(NdotV, k) * geometry(NdotL, k);
}

// Fresnel-Schlick
vec3 fresnel(float cosTheta, vec3 F0){
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
} 

// Cook-Torrance BRDF
vec3 BRDF(vec3 p, vec3 n, vec3 viewDir, vec3 lightDir,
          vec3 albedo, vec3 F0, float roughness, float metalness){
          
    vec3 h = normalize(viewDir + lightDir);
    float NdotL = dot_c(lightDir, n);
    float NdotV = dot_c(viewDir, n);

    float cosTheta = dot_c(h, viewDir);
    vec3 lambertian = albedo / PI;

    float D = distribution(n, h, roughness);
    vec3 F = fresnel(cosTheta, F0);

    float G = smiths(NdotV, NdotL, roughness);
    
    vec3 specular =  D * F * G / max(0.0001, (4.0 * NdotV * NdotL));
   
    vec3 kD = (1.0 - F) * (1.0 - metalness);
    return kD * lambertian + specular;
}

vec3 getSPHIrradiance(vec3 normal){

    vec4 n = vec4(normal, 1.0);
    
    mat4 redMatrix = mat4(
        texelFetch(iChannel2, ivec2(0,0), 0),
        texelFetch(iChannel2, ivec2(0,1), 0),
        texelFetch(iChannel2, ivec2(0,2), 0),
        texelFetch(iChannel2, ivec2(0,3), 0));
    
    
    mat4 grnMatrix = mat4(
        texelFetch(iChannel2, ivec2(1,0), 0),
        texelFetch(iChannel2, ivec2(1,1), 0),
        texelFetch(iChannel2, ivec2(1,2), 0),
        texelFetch(iChannel2, ivec2(1,3), 0));
    
    
    mat4 bluMatrix = mat4(
        texelFetch(iChannel2, ivec2(2,0), 0),
        texelFetch(iChannel2, ivec2(2,1), 0),
        texelFetch(iChannel2, ivec2(2,2), 0),
        texelFetch(iChannel2, ivec2(2,3), 0));
    
    float r = dot(n, redMatrix * n);
    float g = dot(n, grnMatrix * n);
    float b = dot(n, bluMatrix * n);
    
    return  vec3(r, g, b);
}

vec3 getEnvironment(vec3 rayDir){
    vec2 texCoord = vec2((atan(rayDir.z, rayDir.x) / TWO_PI) + 0.5, acos(rayDir.y) / PI);
    return texture(iChannel2, texCoord).rgb;
}

vec3 getIrradiance(vec3 p, vec3 n, vec3 rayDir, vec3 geoNormal, int id){
    vec3 I = vec3(0);
    
#ifdef ANIMATE_LIGHT
    sunLocation = mod(iTime, 6.28);
#endif

    vec3 albedo = 0.25 * vec3(0.75,0.4,0.2);
    vec3 F0 = vec3(0.01);
    float roughness = 1.0;
    float metalness = 0.0;

    if(id == NOSE || id == EYES){
        albedo = vec3(0.02);
    }

    vec3 lightPosition = 10.0*normalize(vec3(cos(sunLocation), sunHeight, sin(sunLocation)));
    vec3 lightColour = vec3(5);

    vec3 vectorToLight = lightPosition - p;
   	vec3 lightDir = normalize(vectorToLight);
    vec3 radiance = lightColour;
    float shadow = softShadow(p + n * EPSILON * 2.0, lightDir, MIN_DIST,
                              length(vectorToLight), SHADOW_SHARPNESS);
    I += shadow 
        * BRDF(p, n, -rayDir, lightDir, albedo, F0, roughness, metalness) 
        * radiance 
        * dot_c(n, lightDir);


    // Ambient occlusion from geometry. Use texture heightmap for detail ao.
    float ao = ambientOcclusion(p, geoNormal)
        	 * length(getTriplanar(p, normalize(geoNormal), id));

    // Ignore kS until specular irradiance is implemented
	vec3 kD = vec3(1.0 - metalness);
	vec3 irradiance = AMBIENT_STRENGTH * getSPHIrradiance(n);
	vec3 diffuse    = irradiance * albedo / PI;
	vec3 ambient    = kD * diffuse * ao; 
    
    return ambient + I;
}

//---------------------------- Render ----------------------------

// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x){
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

vec3 getColour(vec3 cameraPos, vec3 rayDir, float dist, int id){
    
    // If the ray endpoint is not at a surface
    if (dist > MAX_DIST - EPSILON) {
        return getEnvironment(rayDir);
    }

    // Else, determine the surface colour
    vec3 position = cameraPos + rayDir * dist;
    vec3 normal = getNormal(position);
    
    // Avoid artefacts when trying to sample detail normals across Z-plane. Shape deformation
    // increases the region where visible errors occur.
    if(abs(normal.z) < 1e-5){
    	normal.z = 1e-5;
    }
    
    normal = normalize(normal);
    vec3 detailNormal = normalize(getDetailNormal(position, normal, dist, id));
    return getIrradiance(position, detailNormal, rayDir, normal, id);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    
	//----------------- Define a camera -----------------
    
    vec3 rayDir = rayDirection(60.0, fragCoord);

    vec3 cameraPos = texelFetch(iChannel0, ivec2(0.5, 1.5), 0).xyz;

    vec3 targetDir = -cameraPos;

    vec3 up = vec3(0.0, 1.0, 0.0);

    // Get the view matrix from the camera orientation
    mat3 viewMatrix = lookAt(cameraPos, targetDir, up);

    // Transform the ray to point in the correct direction
    rayDir = normalize(viewMatrix * rayDir);

    //---------------------------------------------------
	
    // Track which part was hit.
    int id = -1;
    
    // Find the distance to where the ray stops
    float dist = distanceToScene(cameraPos, rayDir, MIN_DIST, MAX_DIST, id);
    vec3 col = vec3(0);
    
    if (dist < MAX_DIST) {
        vec3 position = cameraPos + rayDir * dist;
        vec3 normal = getNormal(position);

        // Avoid artefacts when trying to sample detail normals across Z-plane. Shape 
        // deformation increases the region where visible errors occur.
        if(abs(normal.z) < 1e-5){
            normal.z = 1e-5;
        }

        normal = normalize(normal);
        vec3 detailNormal = normalize(getDetailNormal(position, normal, dist, id));
        col = getIrradiance(position, detailNormal, rayDir, normal, id);

        // Tonemapping
        col = ACESFilm(EXPOSURE * col);

    }else{
        col = getEnvironment(rayDir);
    }

    // Gamma
    col = pow(col, vec3(0.4545));
    
    
    //col = texture(iChannel2, fragCoord.xy/iChannelResolution[1].xy).rrr;


    fragColor = vec4(col, 1.0);
}