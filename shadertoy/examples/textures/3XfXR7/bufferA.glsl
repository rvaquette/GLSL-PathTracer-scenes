/**
* Creative Commons CC0 1.0 Universal (CC-0)
*
* A small experimental follow up to my area lights shader (https://www.shadertoy.com/view/3dsBD4)
* with a textured rectangular area light. The diffuse component of the light is based on the 5 sample
* solid angle technique from the frostbite engine[1], and the specular technique is based on the most
* representative point method from unreal engine[2]. For specular, a point on the rectangular light source
* is calculated using the reflection vector originating from the shaded point. That point on the rectangle
* is the new light vector using which normal pbr shading calculations are done. 
*
* [1] Real Shading in Unreal Engine 4 -
* (https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf)
* [2] Moving Frostbite to Physically Based Rendering 3.0 -
* (https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf)
*
*/

Rect rect;

vec2 sdUnion(vec2 a, vec2 b)
{
 	return a.x < b.x ? a : b;  
}

void initRect(vec2 rot)
{
    rect.up = rotateYX(vec3(0., 1., 0.), rot);
    rect.right = rotateYX(vec3(1., 0., 0.), rot);;
    rect.front = normalize(cross(rect.right, rect.up));
    rect.halfSize = vec2(5., 3.);
    
    rect.center = vec3(0., 5., 0.);
    
    rect.a = rect.center + rect.halfSize.x * rect.right + rect.halfSize.y * rect.up;
    rect.b = rect.center - rect.halfSize.x * rect.right + rect.halfSize.y * rect.up;
    rect.c = rect.center - rect.halfSize.x * rect.right - rect.halfSize.y * rect.up;
    rect.d = rect.center + rect.halfSize.x * rect.right - rect.halfSize.y * rect.up;
}

float sdPlane(vec3 pos, float height)
{
	float plane = pos.y - height;
#ifdef FLOOR_DISPLACEMENT
    return plane - textureLod(iChannel0, pos.xz * .02, 0.).r * .01;   
#else
    return plane;
#endif
}

float sdPlaneNoDisplacement(vec3 pos, float height)
{
	return pos.y - height;
}

float sdRect(vec3 p, vec3 a, vec3 b, vec3 c, vec3 d)
{
    vec3 ba = b - a; vec3 pa = p - a;
    vec3 cb = c - b; vec3 pb = p - b;
    vec3 dc = d - c; vec3 pc = p - c;
    vec3 ad = a - d; vec3 pd = p - d;
    vec3 nor = cross(ba, ad);

    return sqrt(
        (sign(dot(cross(ba, nor), pa)) +
         sign(dot(cross(cb, nor), pb)) +
         sign(dot(cross(dc, nor), pc)) +
         sign(dot(cross(ad, nor), pd)) < 3.)

        ?

        min(min(min(
		dot2(ba * clamp(dot(ba, pa) / dot2(ba), 0., 1.) - pa),
		dot2(cb * clamp(dot(cb, pb) / dot2(cb), 0., 1.) - pb)),
		dot2(dc * clamp(dot(dc, pc) / dot2(dc), 0., 1.) - pc)),
		dot2(ad * clamp(dot(ad, pd) / dot2(ad), 0., 1.) - pd))
        
        :
        
        dot(nor, pa) * dot(nor, pa) / dot2(nor) 
    );
}

vec2 sdScene(vec3 pos)
{
	vec2 result = vec2(sdPlaneNoDisplacement(pos, -.75), 2.);
    
    result = sdUnion(result, vec2(sdRect(pos, rect.a, rect.b, rect.c, rect.d), 0.));
    
    return result;
}

vec2 sdSceneNormal(vec3 pos)
{
	return vec2(sdPlane(pos, -.75), 1.);
}

vec3 calculateNormal(vec3 pos)
{
	vec2 eps = vec2(EPS, 0.);
    return normalize(vec3(sdSceneNormal(pos + eps.xyy).x, 
                          sdSceneNormal(pos + eps.yxy).x, 
                          sdSceneNormal(pos + eps.yyx).x) 
                     - sdSceneNormal(pos).x);
}

vec2 rayMarch(Ray ray)
{
	float dist = 0.;
    vec2 result = vec2(-1.);
    for(int i = 0; i < 128; ++i)
    {  
        result = sdScene(ray.origin + ray.direction * dist);
        if (result.x < EPS * dist || dist >= cameraFar) break;
        dist += result.x;
    }

    if (dist >= cameraFar) result.y = -1.;
    return vec2(dist, result.y);
}

float ndfTrowbridgeReitzRect(float NdotH, float alpha, float alphaPrime)
{
    float alpha2 = alpha * alpha;
    float alpha4 = alpha2 * alpha2;
    float alphaPrime3 = alphaPrime * alphaPrime * alphaPrime;
    float NdotH2 = NdotH * NdotH;
    
    return 
        			 	(alpha2 * alphaPrime3)
    	/ /*-------------------------------------------------*/
        	  	(pow(NdotH2 * (alpha2 - 1.) + 1., 2.));      
}

// Schlick-Beckmann GGX approximation used for smith's method
float geometrySchlickGGX(float NdotX, float k)
{
    return 
        					NdotX
    	/ /*----------------------------------------*/
    	  	  max(NdotX * (1. - k) + k, SMOL_EPS);
}

float geometrySmith(float NdotV, float NdotL, float roughness)
{
 	float roughnessplusone = roughness + 1.;
    float k = roughnessplusone * roughnessplusone / 8.;
    
    return geometrySchlickGGX(NdotV, k) * geometrySchlickGGX(NdotL, k);
}

// Schlick's approximation for Fresnel equation
vec3 fresnelSchlick(vec3 F0, float dotProd)
{
    return F0 + (1. - F0) * pow(1. - dotProd, 5.);
}

float rectSolidAngle(vec3 p, vec3 p0, vec3 p1, vec3 p2, vec3 p3)
{
    vec3 v0 = p0 - p;
    vec3 v1 = p1 - p;
    vec3 v2 = p2 - p;
    vec3 v3 = p3 - p;
    
    vec3 n0 = normalize(cross(v0, v1));
    vec3 n1 = normalize(cross(v1, v2));
    vec3 n2 = normalize(cross(v2, v3));
    vec3 n3 = normalize(cross(v3, v0));
    
    float g0 = acos(dot(-n0, n1));
	float g1 = acos(dot(-n1, n2));
	float g2 = acos(dot(-n2, n3));
	float g3 = acos(dot(-n3, n0));
    
    return g0 + g1 + g2 + g3 - TWO_PI;
}

vec3 rayPlaneIntersect(Ray ray)
{
   return ray.origin + ray.direction * (dot(rect.front, rect.center - ray.origin)
                                      / dot(rect.front, ray.direction));
}

vec4 rectLight(vec3 p, vec3 n, vec3 v, vec3 r, float NdotV, float roughness,
              vec3 f0, out vec3 fresnel, out vec3 diffCol, out vec3 specCol)
{
  
    vec4 result = vec4(0.);
    // ensure the points are wound counter-clockwise (only debug)
    float windingCheck = dot(cross(rect.right, rect.up), rect.center - p);
    if (windingCheck > 0.)
		return result;
    
    float solidAngle = rectSolidAngle(p, rect.a, rect.b, rect.c, rect.d);
    
    // diffuse
    result.w = solidAngle * .2 * (
        saturate(dot(normalize(rect.a - p), n)) +
        saturate(dot(normalize(rect.b - p), n)) +
        saturate(dot(normalize(rect.c - p), n)) +
        saturate(dot(normalize(rect.d - p), n)) +
        saturate(dot(normalize(rect.center - p), n)));   
    
    Ray rectRay = Ray(p, r);
    
    // calculate point on the rectangle surface/edge based on the ray originating from the shaded point
    vec3 planePointCenter = rayPlaneIntersect(rectRay) - rect.center;
    vec2 planePointProj = vec2(dot(planePointCenter, rect.right), 
                               dot(planePointCenter, rect.up));
    //vec2 c = min(abs(planePointProj), rect.halfSize) * sign(planePointProj);
    vec2 c = clamp(planePointProj, -rect.halfSize, rect.halfSize);
    vec3 L = rect.center + rect.right * c.x + rect.up * c.y;
#ifdef LIGHT_TEXTURE
    // calculate light uv
    vec3 L0 = L - rect.c;
    vec2 luv = vec2(dot(rect.right, L0), dot(rect.up, L0)) / (rect.halfSize * 2.);
#endif
    L -= p;
    
    vec3 l = normalize(L);
    vec3 h = normalize(l + v);
    float lightDist = length(L);
    
    float NdotH = max(0., dot(n, h));
    float VdotH = dot(v, h);
    
    float alpha = roughness * roughness;
    float alphaPrime = saturate(alpha + (RECT_LIGHT_RADIUS / (2. * lightDist)));
    
#ifdef LIGHT_TEXTURE
    // calculate approx light diffuse and specular colors (super experimental :p) 
    diffCol = pow(textureLod(iChannel1, luv, pow(exp(lightDist + .5), 2.)).rgb, vec3(2.2));
    specCol = pow(textureLod(iChannel1, luv, exp(lightDist * alpha + .5) + 1.).rgb, vec3(2.2));
#endif
    
    result.xyz += geometrySmith(NdotV, result.w, roughness) 
        * ndfTrowbridgeReitzRect(NdotH, alpha, alphaPrime)
        * fresnelSchlick(f0, VdotH);
    
    return result;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 blueNoise = texelFetch(iChannel1,
						(iFrame * ivec2(113, 127)) & 63, 0).rg;
    vec2 uv = (2. * (fragCoord + blueNoise) - iResolution.xy) / iResolution.y;
    vec2 m = iMouse.xy / iResolution.y;
    float t = iTime * .5;
    
    vec3 col = vec3(0.);
     
    vec2 rot = m * TWO_PI;    
    initRect(rot);
    
    Ray ray = getCameraRay(uv);
    vec2 marchResult = rayMarch(ray);
    vec3 position = ray.origin + ray.direction * marchResult.x;
    vec3 normal = calculateNormal(position);
    vec3 viewDirection = -ray.direction;
    vec3 reflectDirection = reflect(ray.direction, normal);
    
    float NdotV = max(dot(normal, viewDirection), 0.);
    
    vec3 rectFresnel = vec3(0.);
	vec3 rLightDiff = vec3(0.); // light diffuse color
    vec3 rLightSpec = vec3(0.); // light specular color
    float rectRoughness = .08;
    float rectMetalness = .25;
	if (marchResult.y > -1.)
    {
		if (marchResult.y > 1.)
        {
            vec3 albedo = pow(textureLod(iChannel0, position.xz * .04, 0.).rgb, vec3(2.2));
#ifdef FLOOR_ROUGHNESS
            rectRoughness += albedo.r * .64;
#endif
            vec3 F0 = mix(vec3(.05), vec3(1.), rectMetalness);
            vec4 rLight = rectLight(position, normal, viewDirection,
					reflectDirection, NdotV, rectRoughness, F0, rectFresnel, rLightDiff, rLightSpec);
            vec3 kD = 1. - rectFresnel;
            kD *= 1. - rectMetalness;
#ifdef LIGHT_TEXTURE
        	col += (albedo * kD * rLightDiff + rLight.xyz * rLightSpec) * rLight.w * 
                RECT_LIGHT_INTENSITY;
#else
            col += (albedo * kD * PI_INV + rLight.xyz) * rLight.w * 
                RECT_LIGHT_INTENSITY * RECT_LIGHT_COLOR;
#endif
        }
        else
        {
#ifdef LIGHT_TEXTURE
            vec3 rectOrigin = position - rect.c;
        	vec2 rectUv = vec2(dot(rect.right, rectOrigin), dot(rect.up, rectOrigin)) / (rect.halfSize * 2.);
            col += pow(textureLod(iChannel1, rectUv, 0.).rgb, vec3(2.2)) * RECT_LIGHT_INTENSITY;
#else
            col += RECT_LIGHT_COLOR * RECT_LIGHT_INTENSITY;
#endif
        }
    }
    
    col = mix(col, vec3(.005, .0003, .0002), // brown-ish fog color
               		clamp(1. - exp(-marchResult.x * .08), 0., 1.));
    

    fragColor = vec4(col, 1.);
}
