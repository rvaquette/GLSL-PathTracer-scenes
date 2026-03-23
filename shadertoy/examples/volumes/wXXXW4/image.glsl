// Taken from Inigo Quilez's Rainforest ShaderToy:
// https://www.shadertoy.com/view/4ttSWf
float fbm_4( in vec3 x )
{
    float f = 2.0;
    float s = 0.5;
    float a = 0.0;
    float b = 0.5;
    for( int i=0; i<4; i++ )
    {
        float n = texture(iChannel0, x).r * 1.5;
        a += b*n;
        b *= s;
        x = f*m3*x;
    }
	return a;
}


float SDF(vec3 pos, float iTime)
{    
    vec3 fbmCoord = (pos + 2.0 * vec3(iTime * 6.0f, 0.0, iTime * 2.0)) / 150.0f;
    float sdfValue = sdSphere(pos, vec3(0.0, 5.0, 0), 5.0) + 10.0 * fbm_4(fbmCoord);
    sdfValue = sdSmoothUnion(sdfValue, sdPlane(pos), 35.0);
    return sdfValue;
}

vec3 SDFNormal(vec3 pos, float iTime) {
    vec2 e = vec2(SDF_NORMAL_DELTA, 0.0);
    return normalize(vec3(
        SDF(pos + e.xyy, iTime) - SDF(pos - e.xyy, iTime),
        SDF(pos + e.yxy, iTime) - SDF(pos - e.yxy, iTime),
        SDF(pos + e.yyx, iTime) - SDF(pos - e.yyx, iTime)
    ));
}

float FindVolumeBoundary(Ray ray, float maxT, float iTime, out vec3 normal)
{
    float t = 0.0f;
    float lastResult;
    for(int i = 0; i < MAX_STEPS_SDF; ++i)
    {
	    lastResult = SDF( ray.origin + ray.direction * t, iTime) * 1.5;
        if( lastResult < (SURFACE_DIST) || t > maxT ) break;
        t += lastResult;
    }
    
    if (t >= maxT || lastResult > SURFACE_DIST)
        return -1.0f;
    else
    {
        normal = SDFNormal(ray.origin + ray.direction * t, iTime);
        return t;
    }
}

float GetLightVisiblity(Ray ray, float maxT, float iTime)
{
    float t = 0.0f;
    float lightVisibility = 1.0f;
    float signedDistance = 0.0;
    for(int i = 0; i < MAX_STEPS_VOLUME_LIGHT; i++)
    {                       
        t += max(MARCH_STEP_SIZE_LIGHT, signedDistance);
        if(t > maxT || lightVisibility < ABSORPTION_CUTOFF) break;

        vec3 position = ray.origin + t * ray.direction;

        signedDistance = SDF(position, iTime);
        if(signedDistance < 0.0)
        {
            lightVisibility *= BeerLambert(ABSORPTION_COEFF * GetFogDensity(position, signedDistance), MARCH_STEP_SIZE_LIGHT);
        }
    }
    return lightVisibility;
}

Material GetMaterial(int materialID, vec3 position)
{
    Material mat;
    mat = materials[materialID];
    
    switch (materialID)
    {
        case MATERIAL_GROUND:
        {
            vec2 uv = position.xz / 30.0;
            uv = vec2(uv.x < 0.0 ? abs(uv.x) + 1.0 : uv.x, uv.y < 0.0 ? abs(uv.y) + 1.0 : uv.y);
            if((int(uv.x) % 2 == 0 && int(uv.y) % 2 == 0) || (int(uv.x) % 2 == 1 && int(uv.y) % 2 == 1))
            {
                mat.color = vec3(1, 1, 1) * 0.3;
            }
        }
        break;
    }
   
    return mat;    
}

void DepthCheck(
    inout float t,
    in float intersectionT, 
    in vec3 intersectionNormal,
    in int intersectionMaterialID,
    out vec3 normal,
    out int materialID
	)
{    
    if(intersectionT > EPSILON && intersectionT < t)
    {
		normal = intersectionNormal;
        materialID = intersectionMaterialID;
        t = intersectionT;
    }
}


float TraceOpaqueObjects(Ray ray, out int materialID, out vec3 normal)
{
    float t = LARGE_NUMBER;
    vec3 intersectionNormal = vec3(0, 0, 0);
    
    for (int i = 0; i < NUMBER_LIGHTS; ++i)
    {
        LightSource light = GetLight(i, iTime);
        
        DepthCheck(
        t, 
        SphereIntersection(ray, light.position, light.radius, intersectionNormal),
        intersectionNormal,
        MATERIAL_LIGHT + i,
        normal,
        materialID);
    }
    
    DepthCheck(
        t,
        PlaneIntersection(ray, vec3(0, 0, 0), vec3(0, 1, 0), intersectionNormal),
        intersectionNormal,
        MATERIAL_GROUND,
        normal,
        materialID);
    
    return t;
}


vec3 GammaCorrect(vec3 color) 
{
    return pow(color, vec3(1.0/2.2));
}

vec3 Render(Ray ray)
{
    vec3 normal;
    int materialID = MATERIAL_INVALID;
    float t = TraceOpaqueObjects(ray, materialID, normal);
    float depth = LARGE_NUMBER;
    
    if (materialID != MATERIAL_INVALID)
    {
        depth = t;
    }
    
    vec3 volumeNormal;
    float volumeDepth = FindVolumeBoundary(ray, depth, iTime, volumeNormal);
    float opaqueVisibility = 1.0f;
    vec3 volumeColor = vec3(0);
    if (volumeDepth > 0.0f)
    {
        opaqueVisibility = 1.0f;
        vec3 position = ray.origin + volumeDepth * ray.direction;
        vec3 materialColor = GetMaterial(MATERIAL_VOLUME, position).color;
        float distanceInVolume = 0.0f;
        float signedDistance = 0.0;
        for(int i = 0; i < MAX_STEPS_VOLUME; i++)
        {
            volumeDepth += max(MARCH_STEP_SIZE, signedDistance);
            if(volumeDepth > depth || opaqueVisibility < ABSORPTION_CUTOFF) break;
            
            position = ray.origin + volumeDepth * ray.direction;

            signedDistance = SDF(position, iTime);
            if(signedDistance < 0.0f)
            {
                distanceInVolume += MARCH_STEP_SIZE;
                float previousOpaqueVisiblity = opaqueVisibility;
                opaqueVisibility *= BeerLambert(ABSORPTION_COEFF * GetFogDensity(position, signedDistance), MARCH_STEP_SIZE);
                float absorptionFromMarch = previousOpaqueVisiblity - opaqueVisibility;
                
                for(int lightIndex = 0; lightIndex < NUMBER_LIGHTS; lightIndex++)
    			{
                    float lightVolumeDepth = 0.0f;
                    vec3 lightDirection = (GetLight(lightIndex, iTime).position - position);
                    float lightDistance = length(lightDirection);
                    lightDirection /= lightDistance;
                    
                    vec3 lightColor = GetLight(lightIndex, iTime).color * AttenuateLight(lightDistance); 
                    if(IsColorInsignificant(lightColor)) continue;
                    
                    Ray rayToLight = Ray(position, lightDirection);
                    float lightVisiblity = GetLightVisiblity(rayToLight, lightDistance, iTime); 
                    volumeColor += absorptionFromMarch * lightVisiblity * materialColor * lightColor;
                }
                volumeColor += absorptionFromMarch * materialColor * GetAmbientLight();
            }
        }
    }

    vec3 color = vec3(0);
    
    if (materialID != MATERIAL_INVALID && opaqueVisibility > ABSORPTION_CUTOFF)
    {
        vec3 position = ray.origin + t * ray.direction;
        Material material = GetMaterial(materialID, position);
        
        if((material.flags & MATERIAL_LIGHT_FLAG) != 0)
        {
            color = min(material.color, vec3(1.0));
        }       
        else
        {
            vec3 reflectionDirection = reflect( ray.direction, normal);
            CalculateLighting(position, normal, reflectionDirection, material, iTime, color);
        }
    }
    return color * opaqueVisibility + min(volumeColor, 1.0f);
}

CameraDescription Camera = CameraDescription(
    vec3(0, 3, 130),
    vec3(0, 3, 0),
    2.0,
    7.0
);

void mainImage(out vec4 fragColor, in vec2 fragCoord) 
{
    materials[MATERIAL_GROUND] = Material(vec3(1), 0);
    materials[MATERIAL_VOLUME] = Material(vec3(1,1,1) * 0.8, 0);
    for(int i = 0; i < NUMBER_LIGHTS; ++i)
    {
        LightSource light = GetLight(i, iTime);
        materials[MATERIAL_LIGHT + i] = Material(light.color, MATERIAL_LIGHT_FLAG);
    }
    
    vec2 uv = fragCoord.xy / iResolution.xy;
    float aspectRatio = iResolution.x /  iResolution.y; 
    float lensWidth = Camera.LensHeight * aspectRatio;
    
    vec3 NonNormalizedCameraView = Camera.LookAt - Camera.Position;
    float ViewLength = length(NonNormalizedCameraView);
    vec3 CameraView = NonNormalizedCameraView / ViewLength;

    mat3 viewMatrix = GetViewMatrix(iMouse, iResolution);
    CameraView = CameraView * viewMatrix;
    vec3 lensPoint = Camera.LookAt - CameraView * ViewLength;
    
    vec3 CameraRight = normalize(cross(CameraView, vec3(0, 1, 0)));    
    vec3 CameraUp = normalize(cross(CameraRight, CameraView));

    vec3 focalPoint = lensPoint - Camera.FocalDistance * CameraView;
    lensPoint += CameraRight * (uv.x * 2.0 - 1.0) * lensWidth / 2.0;
    lensPoint += CameraUp * (uv.y * 2.0 - 1.0) * Camera.LensHeight / 2.0;
    
    Ray ray;
    ray.origin = focalPoint;
    ray.direction = normalize(lensPoint - focalPoint);
    
    vec3 color = Render(ray);
    fragColor = vec4( GammaCorrect(clamp(color, 0.0, 1.0)), 1.0 );
}
