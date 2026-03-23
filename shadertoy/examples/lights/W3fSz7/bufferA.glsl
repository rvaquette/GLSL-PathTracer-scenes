/**
* Creative Commons CC0 1.0 Universal (CC-0)
*
* My implementation of 3 types of area light sources (sphere, line, and rectangle). Based on most 
* representative point techniques by Brian Karis (Epic) and Sébastien Lagarde (Unity). The general
* idea is to calculate the location of a point light on the surface of the light source and use that
* point as the light direction to calculate the diffuse and specular components of the area light. 
*
* https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
* https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
*
*/

vec3 lineStart, lineEnd;
Rect rect;

vec2 sdUnion(vec2 a, vec2 b)
{
 	return a.x < b.x ? a : b;  
}

float sdPlane(vec3 pos, float height)
{
	float plane = pos.y - height;
#ifdef FLOOR_DISPLACEMENT
    return plane - textureLod(iChannel0, pos.xz * .04, 0.).r * .01;   
#else
    return plane;
#endif
}

float sdPlaneNoDisplacement(vec3 pos, float height)
{
	return pos.y - height;
}

float sdSphere(vec3 position, vec3 center, float radius)
{
	return length(position - center) - radius;   
}

float sdCapsule(vec3 position, vec3 start, vec3 end, float radius)
{
    vec3 pa = position - start, ba = end - start;
    float h = saturate(dot(pa, ba) / dot(ba, ba));
    return length(pa - ba * h) - radius;
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
	vec2 result = sdUnion(vec2(sdPlaneNoDisplacement(pos, -.75), 3.), 
						vec2(sdSphere(pos, vec3(-4.5, .75, 0.), 1.5), 1.05));
    
    result = sdUnion(result, vec2(sdSphere(pos, vec3(-1.5, .75,0.), 1.5), 1.25));
    
	result = sdUnion(result, vec2(sdSphere(pos, vec3(1.5, .75, 0.), 1.5), 1.45));
    
    result = sdUnion(result, vec2(sdSphere(pos, vec3(4.5, .75, 0.), 1.5), 1.65));

#ifdef DRAW_LIGHTS
	result = sdUnion(result, vec2(sdSphere(pos, SPHERE_LIGHT_POS, SPHERE_LIGHT_RADIUS),
                                  0.));
    
    result = sdUnion(result, vec2(sdCapsule(pos, lineStart, lineEnd, 
                                          LINE_LIGHT_RADIUS), 0.));
    
    result = sdUnion(result, vec2(sdRect(pos, rect.a, rect.b, rect.c, rect.d), 0.));
#endif
    
    return result;
}

vec2 sdSceneNormal(vec3 pos)
{
	vec2 result = sdUnion(vec2(sdPlane(pos, -.75), 3.), 
						vec2(sdSphere(pos, vec3(-4.5, .75, 0.), 1.5), 1.05));
    
    result = sdUnion(result, vec2(sdSphere(pos, vec3(-1.5, .75, 0.), 1.5), 1.25));
    
    result = sdUnion(result, vec2(sdSphere(pos, vec3(1.5, .75, 0.), 1.5), 1.45));
    
    result = sdUnion(result, vec2(sdSphere(pos, vec3(4.5, .75, 0.), 1.5), 1.65));
    
    return result;
}

vec2 sdSceneNoLights(vec3 pos)
{
	vec2 result = sdUnion(vec2(sdPlaneNoDisplacement(pos, -.75), 3.), 
						vec2(sdSphere(pos, vec3(-4.5, .75, 0.), 1.5), 1.05));
    
    result = sdUnion(result, vec2(sdSphere(pos, vec3(-1.5, .75, 0.), 1.5), 1.25));
    
    result = sdUnion(result, vec2(sdSphere(pos, vec3(1.5, .75, 0.), 1.5), 1.45));
    
    result = sdUnion(result, vec2(sdSphere(pos, vec3(4.5, .75, 0.), 1.5), 1.65));
    
    return result;
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
        if (result.x < EPS * dist || dist >= CAMERA_FAR) break;
        dist += result.x;
    }

    if (dist >= CAMERA_FAR) result.y = -1.;
    return vec2(dist, result.y);
}

vec2 rayMarchNoLights(Ray ray)
{
	float dist = 0.;
    vec2 result = vec2(-1.);
    for(int i = 0; i < 64; ++i)
    {  
        result = sdSceneNoLights(ray.origin + ray.direction * dist);
        if (result.x < EPS * dist || dist >= CAMERA_FAR) break;
        dist += result.x;
    }

    if (dist >= CAMERA_FAR) result.y = -1.;
    return vec2(dist, result.y);
}
#if 1
float softShadow(Ray ray)
{
 	float shadow = 1., dist = 0.;
    for (int i = 0; i < 64; ++i)
    {
        vec2 result = sdSceneNoLights(ray.origin + ray.direction * dist);
        if (result.y > 0.)
        {
            // iq's soft shadow hack
            shadow = min(shadow, .5 + .5 * result.x / (.125 * dist));
            if (shadow < 0.) break;
            dist += clamp(result.x, .005, .5);
        }
    }
    return smoothstep(0., 1., max(shadow, 0.));
}
#else
float softShadow(Ray ray)
{
    float t = 0.;
	for(int i = 0; i < 64; ++i)
    {
        float h = sdSceneNoLights(ray.origin + ray.direction * t).x;
        if (h < EPS)
            return 0.0;
        t += h;
    }
    return 1.0;   
}
#endif

float normalDistributionGGXSphere(float NdotH, float alpha, float alphaPrime)
{
    float alpha2 = alpha * alpha;
    float alphaPrime2 = alphaPrime * alphaPrime;
    float NdotH2 = NdotH * NdotH;
    
    return 
        			 (alpha2 * alphaPrime2)
    	/ /*----------------------------------------*/
        	  pow(NdotH2 * (alpha2 - 1.) + 1., 2.);      
}

float normalDistributionGGXLine(float NdotH, float alpha, float alphaPrime)
{
    float alpha2 = alpha * alpha;
    float alphaPrime2 = alphaPrime * alphaPrime;
    float NdotH2 = NdotH * NdotH;
    
    return 
        			 (alpha2 * alphaPrime)
    	/ /*----------------------------------------*/
        	  pow(NdotH2 * (alpha2 - 1.) + 1., 2.);      
}

float normalDistributionGGXRect(float NdotH, float alpha, float alphaPrime)
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

vec3 Irradiance_SphericalHarmonics(const vec3 n) {
    // Irradiance from "Ditch River" IBL (http://www.hdrlabs.com/sibl/archive.html)
    // Generated using google filament cmgen tool
    return max(
          vec3( .754554516862612,  .748542953903366,  .790921515418539)
        + vec3(-.083856548007422,  .092533500963210,  .322764661032516) * (n.y)
        + vec3( .308152705331738,  .366796330467391,  .466698181299906) * (n.z)
        + vec3(-.188884931542396, -.277402551592231, -.377844212327557) * (n.x)
        , 0.0);
}

vec2 PrefilteredDFG_Karis(float roughness, float NoV) {
    // Karis 2014, "Physically Based Material on Mobile"
    // https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
    const vec4 c0 = vec4(-1., -.0275,  -.572,  .022);
    const vec4 c1 = vec4( 1.,  .0425,  1.040, -.040);

    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;

    return vec2(-1.04, 1.04) * a004 + r.zw;
}

vec4 sphereLight(vec3 p, vec3 n, vec3 v, vec3 r, vec3 f0, float NdotV, float roughness,
                 float metalness, out vec3 fresnel, out float attenuation)
{
    vec3 L = (SPHERE_LIGHT_POS - p);
    vec3 centerToRay = dot(L, r) * r - L;
    vec3 closestPoint = L + centerToRay * saturate(SPHERE_LIGHT_RADIUS
								/ length(centerToRay));
    vec3 l = normalize(closestPoint);
    vec3 h = normalize(v + l);
    float lightDist = length(closestPoint);
    
    float NdotL = max(dot(n, l), 0.);
    float NdotH = max(dot(n, h), 0.);
    float VdotH = max(dot(h, v), 0.);
    
    attenuation = pow(saturate(1. - pow(lightDist / SPHERE_LIGHT_VOLUME_RADIUS, 4.)), 2.)  
            					/ (lightDist * lightDist + 1.);
        
	attenuation *= softShadow(Ray(p + n * EPS, l));
    
    float alpha = roughness * roughness;
    float alphaPrime = saturate(alpha + (SPHERE_LIGHT_RADIUS / (2. * lightDist)));
    
    fresnel = fresnelSchlick(f0, VdotH);
    vec3 specular = normalDistributionGGXSphere(NdotH, alpha, alphaPrime)
        * geometrySmith(NdotV, NdotL, roughness)
        * fresnel;
    
 	return vec4(specular, NdotL);   
}

vec4 lineLight(vec3 p, vec3 n, vec3 v, vec3 r, vec3 f0, float NdotV, float roughness,
                 float metalness, out vec3 fresnel, out float attenuation)
{
    vec4 result = vec4(0.);
    vec3 l0 = lineStart - p, l1 = lineEnd - p;
    float lengthL0 = length(l0), lengthL1 = length(l1);
    float NdotL0 = dot(n, l0) / (2. * lengthL0);
    float NdotL1 = dot(n, l1) / (2. * lengthL1);
    result.w = (2. * saturate(NdotL0 + NdotL1)) / 
        	 (lengthL0 * lengthL1 + dot(l0, l1) + 2.); // NdotL
    
    vec3 ld = l1 - l0;
    float RdotL0 = dot(r, l0);
    float RdotLd = dot(r, ld);
    float L0dotLd = dot(l0, ld);
    float distLd = length(ld);
    
    float t = (RdotL0 * RdotLd - L0dotLd ) / (distLd * distLd - RdotLd * RdotLd);
    
    // point on the line
    vec3 closestPoint = l0 + ld * saturate(t);
    // point on the tube based on its radius
    vec3 centerToRay = dot(closestPoint, r) * r - closestPoint;
    closestPoint = closestPoint + centerToRay * saturate(LINE_LIGHT_RADIUS 
						/ length(centerToRay));
    vec3 l = normalize(closestPoint);
    vec3 h = normalize(v + l);
    float lightDist = length(closestPoint);
    
    float NdotH = max(dot(n, h), 0.);
    float VdotH = dot(h, v);
    
    float denom = lightDist / LINE_LIGHT_VOLUME_RADIUS;
    attenuation = 1. / (denom * denom + 1.);
        
	attenuation *= softShadow(Ray(p + n * EPS, normalize(l0 + ld * .5)));
    
    float alpha = roughness * roughness;
    float alphaPrime = saturate(alpha + (LINE_LIGHT_RADIUS / (2. * lightDist)));
    
    fresnel = fresnelSchlick(f0, VdotH);
    result.xyz = normalDistributionGGXLine(NdotH, alpha, alphaPrime)
        * geometrySmith(NdotV, result.w, roughness)
        * fresnel;
    
    return result;
}

vec3 rayPlaneIntersect(Ray ray)
{
   return ray.origin + ray.direction * (dot(rect.front, rect.center - ray.origin)
										/ dot(rect.front, ray.direction));
}

vec4 rectLight(vec3 p, vec3 n, vec3 v, vec3 r, vec3 f0, float NdotV, float roughness,
                 float metalness, out vec3 fresnel, out float attenuation)
{
 	vec4 result = vec4(0.);
    
    // facing side check
    float windingCheck = dot(cross(rect.right, rect.up), rect.center - p);
    if (windingCheck > 0.)
        return result;
    
    vec3 v0 = rect.a - p;
    vec3 v1 = rect.b - p;
    vec3 v2 = rect.c - p;
    vec3 v3 = rect.d - p;
    
    float solidAngle = rectSolidAngle(p, v0, v1, v2, v3);
    
    // diffuse
    result.w = solidAngle * .2 * (
        saturate(dot(normalize(v0), n)) +
        saturate(dot(normalize(v1), n)) +
        saturate(dot(normalize(v2), n)) +
        saturate(dot(normalize(v3), n)) +
        saturate(dot(normalize(rect.center - p), n)));    
    
    attenuation = softShadow(Ray(p + n * EPS, normalize(rect.center)));
    
    // specular
	Ray rectRay = Ray(p, r);
    vec3 planePointCenter = rayPlaneIntersect(rectRay) - rect.center;
    // project point on the plane on which the rectangle lies
    vec2 planePointProj = vec2(dot(planePointCenter, rect.right), 
                               dot(planePointCenter, rect.up));
    // translate the point to the top-right quadrant of the rectangle, project it on
    // the rectangle or its edge and translate back using sign of the original point.
    vec2 c = min(abs(planePointProj), rect.halfSize) * sign(planePointProj);
    vec3 L = rect.center + rect.right * c.x + rect.up * c.y - p;
    
    vec3 l = normalize(L);
    vec3 h = normalize(v + l);
    float lightDist = length(L);
    
    float NdotH = max(dot(n, h), 0.);
    float VdotH = dot(h, v);

    float alpha = roughness * roughness;
    float alphaPrime = saturate(alpha + (RECT_LIGHT_RADIUS / (2. * lightDist)));
    
    fresnel = fresnelSchlick(f0, VdotH);
    result.xyz = normalDistributionGGXRect(NdotH, alpha, alphaPrime)
        * geometrySmith(NdotV, result.w, roughness)
        * fresnel;
    
    return result;
}

vec3 renderScene(Ray ray)
{
    // update line light position & rotation
    //float t = iTime * .25;
    vec3 lineRotation = vec3(2., 0., 0.) * rotZ(T);
    vec3 linePosition = vec3(6. * sin(T), 3., 5.);
    lineStart = linePosition - lineRotation;
    lineEnd = linePosition + lineRotation;
    
	initRect(rect, T);
    
    vec3 col = vec3(0.);
    vec2 marchResult = rayMarch(ray);
    vec3 position = ray.origin + ray.direction * marchResult.x;
    vec3 normal = calculateNormal(position);
    vec3 viewDirection = -ray.direction;
    vec3 reflectDirection = reflect(ray.direction, normal);
    
    float NdotV = max(dot(normal, viewDirection), 0.);
    
    vec3 albedo = SPHERE_ALBEDO;
    
    float roughness = fract(marchResult.y), metalness = .88;
    vec3 reflectance = SILVER_F0;  

    if (marchResult.y > -1.)
    {
        if (marchResult.y > 2.)
        {
            albedo = pow(textureLod(iChannel0, position.xz * .18, 0.).rgb, vec3(2.2));
#ifdef FLOOR_ROUGHNESS
            roughness = albedo.r * .5;
#else
            roughness = .05;
#endif
            metalness = .05;
            reflectance = PLASTIC_F0;
        }
        else if (marchResult.y < .5)
            return LIGHT_COLOR * RECT_LIGHT_INTENSITY;
        
        vec3 F0 = mix(reflectance, albedo, metalness);
        
        vec3 sphereLightFresnel = vec3(0.);
        float sphereLightAttenuation = 1.;
        vec4 sphereLightDiffSpec = sphereLight(position, normal, viewDirection, 
				reflectDirection, F0, NdotV, roughness, metalness, sphereLightFresnel, 
				sphereLightAttenuation);
        vec3 sphereLightKd = 1. - sphereLightFresnel;
    	sphereLightKd *= 1. - metalness;

        vec3 lineLightFresnel = vec3(0.);
        float lineLightAttenuation = 1.;
        vec4 lineLightDiffSpec = lineLight(position, normal, viewDirection, 
				reflectDirection, F0, NdotV, roughness, metalness, lineLightFresnel, 
				lineLightAttenuation);
        vec3 lineLightKd = 1. - lineLightFresnel;
        lineLightKd *= 1. - metalness;
        
        vec3 rectLightFresnel = vec3(0.);
        float rectLightAttenuation = 1.;
        vec4 rectLightDiffSpec = rectLight(position, normal, viewDirection, 
				reflectDirection, F0, NdotV, roughness, metalness, rectLightFresnel, 
				rectLightAttenuation);
		vec3 rectLightKd = 1. - rectLightFresnel;
        rectLightKd *= 1. - metalness;
        
        col += (sphereLightKd * PI_INV * albedo + sphereLightDiffSpec.xyz)
            * SPHERE_LIGHT_INTENSITY * sphereLightDiffSpec.w * sphereLightAttenuation;
        
        col += (lineLightKd * PI_INV * albedo + lineLightDiffSpec.xyz)
            * LINE_LIGHT_INTENSITY * lineLightDiffSpec.w * lineLightAttenuation;

        col += (rectLightKd * PI_INV * albedo + rectLightDiffSpec.xyz)
            * RECT_LIGHT_INTENSITY * rectLightDiffSpec.w * rectLightAttenuation;
        
        col += albedo * .025; // global ambient
        
        // calculate glossy reflection + ibl
        float glossiness = roughness * roughness;
        vec3 indirectSpecular = vec3(.1125, .1875, .25) + reflectDirection.y * .35;
        Ray reflectRay = Ray(position, vec3(0.));
        for (int i = 0; i < REFLECTION_STEPS; ++i)
        {
			float percentage = float(i) / float(REFLECTION_STEPS);
            vec3 delta = rotateAround(vec3(0., 1., 0.), reflectDirection, 
                                      TWO_PI * percentage);
			reflectRay.direction = normalize(delta * glossiness + reflectDirection);
        	vec2 indirectMarchResult = rayMarchNoLights(reflectRay);
            
            if (floor(indirectMarchResult.y) == 3.)
            {
                vec3 indirectPosition = position + indirectMarchResult.x
                    	* reflectRay.direction;
                indirectSpecular += textureLod(iChannel0, indirectPosition.xz * .18, 0.).rgb;
            }  
            else if(floor(indirectMarchResult.y) == 1.)
                indirectSpecular += SPHERE_ALBEDO;
			
        }
        
        indirectSpecular /= float(REFLECTION_STEPS);
        
        vec2 dfg = PrefilteredDFG_Karis(roughness, NdotV);
        vec3 specularColor = F0 * dfg.x + dfg.y;
        vec3 ibl = indirectSpecular * specularColor
            + Irradiance_SphericalHarmonics(normal) * PI_INV * albedo;
        
        col += ibl * .84;
        col *= LIGHT_COLOR;
    }   

    // fog
    return mix(col, vec3(.01, .006, .004), // brown-ish fog color
               		clamp(1. - exp(-marchResult.x * .08), 0., 1.));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 blueNoise = texelFetch(iChannel1,
						(iFrame * ivec2(113, 127)) & 63, 0).rg;
    vec2 uv = (2. * (fragCoord + blueNoise) - iResolution.xy) / iResolution.y;
    vec2 st = fragCoord / iResolution.xy;
    
    Ray ray = getCameraRay(uv);
    
    vec3 col = renderScene(ray);

    fragColor = vec4(col, 1.);
}
