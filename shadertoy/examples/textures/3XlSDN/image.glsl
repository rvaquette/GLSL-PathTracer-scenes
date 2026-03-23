vec3 eye 					= vec3(0.f,0.f,5.f);
vec4 sphere					= vec4(0.f,0.f,0.f, 0.7f);
// vec3 spotLightDir 			= normalize(vec3(0.0f,0.0f,-1.f)); // front
vec3 spotLightDir 			= normalize(vec3(-0.75f,-0.15f,-1.f));
vec3 spotLightColor			= vec3(0.7f);
vec3 ambientColor 			= vec3(0.3f);
float camerafov 			= 45.f;
float scatteringProbability = 1.f;

vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

bool anyHit_sphere(vec3 rayEye, vec3 rayDir, vec4 sphere) {
    vec3 a = sphere.xyz - rayEye;
    float a1 = dot(a, rayDir);
    vec3 a2 = a - a1 * rayDir;
    float distSq = dot(a2,a2);
    float rSq = sphere.w*sphere.w;
    if (distSq < rSq) {
        float cSq = rSq - distSq;
        float t = a1 - sqrt(cSq);
        return t >= -0.01f;
    } else
        return false;
}

bool closestHit_sphere(vec3 rayEye, vec3 rayDir, vec4 sphere, out vec3 hit, out vec3 normal) {
    vec3 a = sphere.xyz - rayEye;
    float a1 = dot(a, rayDir);
    vec3 a2 = a - a1 * rayDir;
    float distSq = dot(a2,a2);
    float rSq = sphere.w*sphere.w;
    if (distSq < rSq) {
        float cSq = rSq - distSq;
        float t = a1 - sqrt(cSq);
        hit = rayEye + rayDir * t;
        normal = normalize(vec3(hit-sphere.xyz));
        return true;
    } else
        return false;
}

bool closestHit_plane(vec3 rayEye, vec3 rayDir, vec4 plane, out vec3 hit, out vec3 normal) {
	vec3 p0 = plane.xyz * plane.w;
    vec3 n = -plane.xyz;
    float d = dot(p0-rayEye,n)/dot(rayDir, n);
    hit = rayEye + rayDir * d;
    normal = n;
    return true;
}

float saturate(float x) { return clamp(x, 0.f, 1.f); }

bool inLightFoV(vec3 Ln, vec3 spotLightDir, float cosHalfAngle) {
    // return true;
    return dot(Ln, -spotLightDir) > cosHalfAngle;
}

vec2 lightUV(vec3 Ln, float fov, vec3 lightLookVector, vec3 lightUpVector, vec3 lightRightVector) {
    float x = dot(Ln, lightRightVector);
    float y = dot(Ln, lightUpVector);
    float d = -1. / dot(Ln, lightLookVector); // 'un-normalize Ln'
    
    float q = 1. / (2. * tan(fov));
    
    float u = d * x * q + 0.5;
    float v = d * y * q + 0.5;

    return vec2(u, v);
}

void shading(vec3 Nn, vec3 Ln, vec3 lightColor, inout vec3 result) {
 	// Diffuse (lambertian) reflectance
	float dotNL = saturate(dot(Nn, Ln));
	vec3 diffuse = dotNL * lightColor;
    result += diffuse;
}

// Fast inverse for affine matrix:
mat4 affineInverse(mat4 m) {
	mat3 rot;
	rot[0] = m[0].xyz;
	rot[1] = m[1].xyz;
	rot[2] = m[2].xyz;

	mat3 invRot = transpose(rot);

	mat4 result;
	result[0] = vec4(invRot[0], 0);
	result[1] = vec4(invRot[1], 0);
	result[2] = vec4(invRot[2], 0);
	result[3] = vec4(-(invRot * m[3].xyz), 1);
	return result;
}

void SolveQuadratic(float a, float b, float c, out float minT, out float maxT)
{
	float discriminant = b*b - 4.0*a*c;

	if (discriminant < 0.0)
	{
		// no real solutions so return a degenerate result
		maxT = 0.0;
		minT = 0.0;
		return;
	}

	// numerical receipes 5.6 (this method ensures numerical accuracy is preserved)
	float t = -0.5 * (b + sign(b)*sqrt(discriminant));
	float closestT = t / a;
	float furthestT = c / t;

	if (closestT > furthestT)
	{
		minT = furthestT;
		maxT = closestT;
	}
	else
	{
		minT = closestT;
		maxT = furthestT;
	}
}

void IntersectCone(vec3 rayOrigin, vec3 rayDir, mat4 invConeTransform, float tanAperture, float height, out float minT, out float maxT)
{
	vec4 localOrigin = invConeTransform * vec4(rayOrigin, 1.0);
	vec4 localDir = invConeTransform * vec4(rayDir, 0.0);

	float tanTheta = tanAperture * tanAperture;

	float a = localDir.x*localDir.x + localDir.z*localDir.z - localDir.y*localDir.y*tanTheta;
	float b = 2.0*(localOrigin.x*localDir.x + localOrigin.z*localDir.z - localOrigin.y*localDir.y*tanTheta);
	float c = localOrigin.x*localOrigin.x + localOrigin.z*localOrigin.z - localOrigin.y*localOrigin.y*tanTheta;

	SolveQuadratic(a, b, c, minT, maxT);

	float y1 = localOrigin.y + localDir.y*minT;
	float y2 = localOrigin.y + localDir.y*maxT;

	if (y1 > 0.0 && y2 > 0.0)
	{
		// both intersections are in the reflected cone so return degenerate value
		minT = 0.0;
		maxT = -1.0;
	}
	else if (y1 > 0.0 && y2 < 0.0)
	{
		// closest t on the wrong side, furthest on the right side => ray enters volume but doesn't leave it (so set maxT arbitrarily large)
		minT = maxT;
		maxT = 10000.0;
	}
	else if (y1 < 0.0 && y2 > 0.0)
	{
		// closest t on the right side, largest on the wrong side => ray starts in volume and exits once
		maxT = minT;
		minT = 0.0;
	}
}

float InScatter(vec3 start, vec3 dir, vec3 lightPos, float d, vec3 attenuation)
{
	// calculate quadratic coefficients a,b,c
	vec3 q = start - lightPos;

	float b = dot(dir, q);
	float c = dot(q, q);

	// evaluate integral
	float s = 1.0f / sqrt(c - b*b);

	float l = s * (atan((d + b) * s) - atan(b*s));

    // attenuation:
	//float lightDist = length(q);
	//l = l * saturate(1.0 / dot(vec3(1, sqrt(lightDist), lightDist), attenuation));
	return l;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 rayDir = rayDirection(camerafov, iResolution.xy, fragCoord.xy);

    float spotLightHalfAngle = 25.0f + sin(iTime) * 10.0f;
    // float spotLightHalfAngle = 35.0f;
    if (iMouse.z > 0.5f)
     	// spotLightDir = normalize(vec3(-normalize(iMouse.xy - iResolution.xy / 2.f), -1.f));
        spotLightDir = normalize(vec3(sin(6.28*iMouse.x/iResolution.x), cos(3.14*iMouse.y/iResolution.y), cos(6.28*iMouse.x/iResolution.x)));
    vec3 spotLightOrigin 	= (sphere.xyz - spotLightDir) * 1.4;
    vec3 lightUp = normalize(cross(spotLightDir, vec3(1,0,0)));
    vec3 lightRight = cross(spotLightDir, lightUp);
    float spotfov = radians(spotLightHalfAngle);
    float cosSpotHalfAngle = cos(spotfov);

    vec3 result = vec3(0.f);

    // lit sphere:
    vec3 hitPos, hitNormal;
    float hitDist = 1e5;
    if (closestHit_sphere(eye, rayDir, sphere, hitPos, hitNormal)) {
    // if (closestHit_plane(eye, rayDir, vec4(0,0,-1, 0), hitPos, hitNormal)) {
        hitDist = length(hitPos-eye); // used for cone
        
        // for each spotlight:
        vec3 Ln = normalize(spotLightOrigin-hitPos);
        if (inLightFoV(Ln, spotLightDir, cosSpotHalfAngle)) {
            // gobo:
            vec2 goboUV = lightUV(Ln, spotfov, spotLightDir, lightUp, lightRight);
            vec4 goboColor = texture(iChannel0, goboUV);
            
        	shading(hitNormal, Ln, goboColor.xyz * goboColor.a * spotLightColor, result);
        }
        
        shading(hitNormal, normalize(vec3(0.f,0.f,1.f)), ambientColor, result); // directional light
    } else {
        // checkerboard background
        int ix = int(fragCoord.x);
        int iy = int(fragCoord.y);
        
        result = (ix / 16) % 2 == 0 ^^ (iy / 16) % 2 == 0 ? vec3(0.1f) : vec3(0.15f);
    }
    
    // volumetric fog:
	float height = 30.0;
	float minT = 0.0;
	float maxT = 0.0;

	mat4 LightToWorld;
	LightToWorld[0] = vec4(lightRight, 0.0);
	LightToWorld[1] = vec4(-spotLightDir, 0.0); // change of basis from XYZ to X-ZY to rotate forward facing cone downward
	LightToWorld[2] = vec4(lightUp, 0.0);
	LightToWorld[3] = vec4(spotLightOrigin, 1);
			
	mat4 invLightToWorld = affineInverse(LightToWorld);

	float tanSpotAngle = tan(radians(spotLightHalfAngle));

	IntersectCone(eye, rayDir, invLightToWorld, tanSpotAngle, height, minT, maxT);

	minT = max(minT, 0.f);
	maxT = min(maxT, hitDist);
	float dt = max(0.0, maxT - minT);

    // analytic fog integral:
	vec3 scatter = spotLightColor * /* vec3(0.2, 0.5, 0.8) * */
        max(0.f, InScatter(eye + rayDir*minT, rayDir,spotLightOrigin, dt, vec3(1,1,1))) 
        * scatteringProbability * 0.5;
    
    // ray marched gobo fog:
    vec3 coneGoboColor = vec3(0.f);
    for (int i = 0; i < 16; ++i) {
    	float t = mix(minT, maxT, float(i) / float(16-1));
        vec3 p = eye + rayDir*t; // point in volume
        vec3 Ln = normalize(spotLightOrigin-p);
        // shadow ray:
        if (!anyHit_sphere(p, Ln, sphere)) 
        {
        	vec2 goboUV = lightUV(Ln, spotfov, spotLightDir, lightUp, lightRight);
        	vec4 goboColor = texture(iChannel0, goboUV);
        	coneGoboColor += goboColor.xyz * goboColor.a * spotLightColor;
        }
    }
    coneGoboColor /= 16.f;

	result += scatter * coneGoboColor;
    
    fragColor = vec4(result, 1.f);
}
