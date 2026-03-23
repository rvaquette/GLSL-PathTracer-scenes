void TestSceneTrace(in vec3 rayPos, in vec3 rayDir, inout SRayHitInfo hitInfo)
{    
    // to move the scene around, since we can't move the camera yet
    vec3 sceneTranslation = vec3(0.0f, 0.0f, 10.0f);
    vec4 sceneTranslation4 = vec4(sceneTranslation, 0.0f);
    
    // back wall
    {
        vec3 A = vec3(-12.6f, -12.6f, 25.0f) + sceneTranslation;
        vec3 B = vec3( 12.6f, -12.6f, 25.0f) + sceneTranslation;
        vec3 C = vec3( 12.6f,  12.6f, 25.0f) + sceneTranslation;
        vec3 D = vec3(-12.6f,  12.6f, 25.0f) + sceneTranslation;
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material.albedo = vec3(0.8f, 0.5f, 0.2f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
            hitInfo.material.percentSpecular = 0.2f;
            hitInfo.material.roughness = 0.8f;
            hitInfo.material.specularColor = vec3(1.0f, 0.6f, 0.0f);
        }
	}
    
    // floor
    {
        vec3 A = vec3(-12.6f, -12.45f, 25.0f) + sceneTranslation;
        vec3 B = vec3( 12.6f, -12.45f, 25.0f) + sceneTranslation;
        vec3 C = vec3( 12.6f, -12.45f, 15.0f) + sceneTranslation;
        vec3 D = vec3(-12.6f, -12.45f, 15.0f) + sceneTranslation;
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material.albedo = vec3(0.3f, 0.6f, 0.7f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
            hitInfo.material.percentSpecular = 0.5f;
            hitInfo.material.roughness = 0.0f;
            hitInfo.material.specularColor = vec3(0.3f, 0.6f, 0.8f);            
        }        
    }
    
    // cieling
    {
        vec3 A = vec3(-12.6f, 12.5f, 25.0f) + sceneTranslation;
        vec3 B = vec3( 12.6f, 12.5f, 25.0f) + sceneTranslation;
        vec3 C = vec3( 12.6f, 12.5f, 15.0f) + sceneTranslation;
        vec3 D = vec3(-12.6f, 12.5f, 15.0f) + sceneTranslation;
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material.albedo = vec3(0.7f, 0.7f, 0.7f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
            hitInfo.material.percentSpecular = 0.0f;
            hitInfo.material.roughness = 0.0f;
            hitInfo.material.specularColor = vec3(0.0f, 0.0f, 0.0f);
        }        
    }    
    
    // left wall
    {
        vec3 A = vec3(-12.5f, -12.6f, 25.0f) + sceneTranslation;
        vec3 B = vec3(-12.5f, -12.6f, 15.0f) + sceneTranslation;
        vec3 C = vec3(-12.5f,  12.6f, 15.0f) + sceneTranslation;
        vec3 D = vec3(-12.5f,  12.6f, 25.0f) + sceneTranslation;
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material.albedo = vec3(0.7f, 0.1f, 0.1f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
            hitInfo.material.percentSpecular = 0.6f;
            hitInfo.material.roughness = 0.4f;
            hitInfo.material.specularColor = vec3(0.7f, 0.0f, 0.0f);
        }        
    }
    
    // right wall 
    {
        vec3 A = vec3( 12.5f, -12.6f, 25.0f) + sceneTranslation;
        vec3 B = vec3( 12.5f, -12.6f, 15.0f) + sceneTranslation;
        vec3 C = vec3( 12.5f,  12.6f, 15.0f) + sceneTranslation;
        vec3 D = vec3( 12.5f,  12.6f, 25.0f) + sceneTranslation;
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material.albedo = vec3(0.1f, 0.7f, 0.1f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
            hitInfo.material.percentSpecular = 0.4f;
            hitInfo.material.roughness = 0.2f;
            hitInfo.material.specularColor = vec3(0.0f, 0.7f, 0.0f);            
        }        
    }
    
    //// left box_1 - left face 
    //{
    //    vec3 A = vec3( -4.5f, -2.0f, 10.0f) + sceneTranslation;
    //    vec3 B = vec3( -4.5f, -2.0f, 5.0f) + sceneTranslation;
    //    vec3 C = vec3( -4.5f,  2.0f, 5.0f) + sceneTranslation;
    //    vec3 D = vec3( -4.5f,  2.0f, 10.0f) + sceneTranslation;
    //    if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
    //    {
    //        hitInfo.material.albedo = vec3(0.8f, 0.8f, 0.8f);
    //        hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
    //        hitInfo.material.percentSpecular = 0.0f;
    //        hitInfo.material.roughness = 0.0f;
    //        hitInfo.material.specularColor = vec3(0.0f, 0.0f, 0.0f);            
    //    }        
    //}
    //
    //// left box_1 - right face 
    //{
    //    vec3 A = vec3( -1.5f, -2.0f, 10.0f) + sceneTranslation;
    //    vec3 B = vec3( -1.5f, -2.0f, 5.0f) + sceneTranslation;
    //    vec3 C = vec3( -1.5f,  2.0f, 5.0f) + sceneTranslation;
    //    vec3 D = vec3( -1.5f,  2.0f, 10.0f) + sceneTranslation;
    //    if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
    //    {
    //        hitInfo.material.albedo = vec3(0.9f, 0.5f, 0.9f);
    //        hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
    //        hitInfo.material.percentSpecular = 0.0f;
    //        hitInfo.material.roughness = 0.01;
    //        hitInfo.material.specularColor = vec3(0.9f, 0.5f, 0.9f);            
    //    }        
    //}
    //
    //// left box_1 - cieling
    //{
    //    vec3 A = vec3(-4.5f, 2.0f, 10.0f) + sceneTranslation;
    //    vec3 B = vec3(-1.5f, 2.0f, 10.0f) + sceneTranslation;
    //    vec3 C = vec3(-1.5f, 2.0f, 5.0f) + sceneTranslation;
    //    vec3 D = vec3(-4.5f, 2.0f, 5.0f) + sceneTranslation;
    //    if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
    //    {
    //        hitInfo.material.albedo = vec3(0.7f, 0.7f, 0.7f);
    //        hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
    //        hitInfo.material.percentSpecular = 0.0f;
    //        hitInfo.material.roughness = 0.0f;
    //        hitInfo.material.specularColor = vec3(0.0f, 0.0f, 0.0f);
    //    }        
    //}
    //
    //// left box_1 - flooar
    //{
    //    vec3 A = (vec3(-4.5f, -2.0f, 10.0f) + sceneTranslation) * rotateY(sin(90.0f));
    //    vec3 B = (vec3(-1.5f, -2.0f, 10.0f) + sceneTranslation) * rotateY(sin(90.0f));
    //    vec3 C = (vec3(-1.5f, -2.0f, 5.0f) + sceneTranslation) *  rotateY(sin(90.0f));
    //    vec3 D = (vec3(-4.5f, -2.0f, 5.0f) + sceneTranslation) *  rotateY(sin(90.0f));
    //    if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
    //    {
    //        hitInfo.material.albedo = vec3(0.7f, 0.7f, 0.7f);
    //        hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
    //        hitInfo.material.percentSpecular = 0.0f;
    //        hitInfo.material.roughness = 0.0f;
    //        hitInfo.material.specularColor = vec3(0.0f, 0.0f, 0.0f);
    //    }        
    //}
    //
    //// left box_1 - back wall
    //{
    //    vec3 A = (vec3(-4.5f, -2.0f, 5.0f) + sceneTranslation) * rotateZ(0.0f);
    //    vec3 B = (vec3(-1.5f, -2.0f, 5.0f) + sceneTranslation) * rotateZ(0.0f);
    //    vec3 C = (vec3(-1.5f,  2.0f, 5.0f) + sceneTranslation) * rotateZ(0.0f);
    //    vec3 D = (vec3(-4.5f,  2.0f, 5.0f) + sceneTranslation) * rotateZ(0.0f);
    //    if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
    //    {
    //        hitInfo.material.albedo = vec3(0.8f, 0.2f, 0.2f);
    //        hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);
    //        hitInfo.material.percentSpecular = 0.2f;
    //        hitInfo.material.roughness = 0.8f;
    //        hitInfo.material.specularColor = vec3(1.0f, 0.2f, 0.0f);
    //    }
	//}
    
    
    // light
    {
        vec3 A = vec3(-5.0f, 12.4f,  22.5f) + sceneTranslation;
        vec3 B = vec3( 5.0f, 12.4f,  22.5f) + sceneTranslation;
        vec3 C = vec3( 5.0f, 12.4f,  17.5f) + sceneTranslation;
        vec3 D = vec3(-5.0f, 12.4f,  17.5f) + sceneTranslation;
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material.albedo = vec3(0.0f, 0.0f, 0.0f);
            hitInfo.material.emissive = vec3(1.0f, 0.9f, 0.7f) * 20.0f;
            hitInfo.material.percentSpecular = 0.0f;
            hitInfo.material.roughness = 0.0f;
            hitInfo.material.specularColor = vec3(0.0f, 0.0f, 0.0f);            
        }        
    }
    
    
	if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-6.0f, -9.5f, 20.0f, 3.0f)+sceneTranslation4))
    {
        hitInfo.material.albedo = vec3(0.9f, 0.6f, 0.1f);
        hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
        hitInfo.material.percentSpecular = 0.6f;
        hitInfo.material.roughness = 0.6f;
        hitInfo.material.specularColor = vec3(0.9f, 0.6f, 0.1f);        
    } 
    
	if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(6.0f, -9.5f, 20.0f, 3.0f)+sceneTranslation4))
    {
        hitInfo.material.albedo = vec3(0.9f, 0.5f, 0.9f);
        hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);   
        hitInfo.material.percentSpecular = 0.6f;
        hitInfo.material.roughness = 0.2;
        hitInfo.material.specularColor = vec3(0.2f, 0.2f, 0.2f);        
    }  
    
    // blue balls
    for (int i = 0; i < 5; i++){
        if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-10.0f + float(i) * 5.0f, 10.0f, 23.0f, 1.75f)+sceneTranslation4))
        {
            hitInfo.material.albedo = vec3(1.0f, 1.0f, 1.0f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.percentSpecular = 1.0f;
            hitInfo.material.roughness = 2.0f * float(i + 1) / 10.0f;
            hitInfo.material.specularColor = vec3(0.4f, 0.6f, 0.9f);       
        }  
    }
    
    // Pink balls
    for (int i = 0; i < 5; i++){
        if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-10.0f + float(i) * 5.0f, 4.0f, 23.0f, 1.75f)+sceneTranslation4))
        {
            hitInfo.material.albedo = vec3(1.0f, 1.0f, 1.0f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.percentSpecular = 1.0f;
            hitInfo.material.roughness = 2.0f * float(i + 1) / 10.0f;
            hitInfo.material.specularColor = vec3(0.9f, 0.5f, 0.9f);       
        }  
    }
    
    // gold balls
    for (int i = 0; i < 5; i++){
        if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-10.0f + float(i) * 5.0f, -2.0f, 23.0f, 1.75f)+sceneTranslation4))
        {
            hitInfo.material.albedo = vec3(1.0f, 1.0f, 1.0f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.percentSpecular = 1.0f;
            hitInfo.material.roughness = 2.0f * float(i + 1) / 10.0f;
            hitInfo.material.specularColor = vec3(0.9f, 0.6f, 0.1f);       
        }  
    }
}

vec3 GetColorForRay(in vec3 startRayPos, in vec3 startRayDir, inout uint rngState)
{
    // initialize
    vec3 ret = vec3(0.0f, 0.0f, 0.0f);
    vec3 throughput = vec3(1.0f, 1.0f, 1.0f);
    vec3 rayPos = startRayPos;
    vec3 rayDir = startRayDir;
     
    for (int bounceIndex = 0; bounceIndex <= c_numBounces; ++bounceIndex)
    {
        // shoot a ray out into the world
        SRayHitInfo hitInfo;
        hitInfo.dist = c_superFar;
        TestSceneTrace(rayPos, rayDir, hitInfo);
         
        // if the ray missed, we are done
        if (hitInfo.dist == c_superFar)
        {
            ret += SRGBToLinear(texture(iChannel1, rayDir).rgb) * throughput;
            break;
        }
         
        // update the ray position
        rayPos = (rayPos + rayDir * hitInfo.dist) + hitInfo.normal * c_rayPosNormalNudge;
         
        // calculate whether we are going to do a diffuse or specular reflection ray 
        float doSpecular = (RandomFloat01(rngState) < hitInfo.material.percentSpecular) ? 1.0f : 0.0f;

        // Calculate a new ray direction.
        // Diffuse uses a normal oriented cosine weighted hemisphere sample.
        // Perfectly smooth specular uses the reflection ray.
        // Rough (glossy) specular lerps from the smooth specular to the rough diffuse by the material roughness squared
        // Squaring the roughness is just a convention to make roughness feel more linear perceptually.
        vec3 diffuseRayDir = normalize(hitInfo.normal + RandomUnitVector(rngState));
        vec3 specularRayDir = reflect(rayDir, hitInfo.normal);
        specularRayDir = normalize(mix(specularRayDir, diffuseRayDir, hitInfo.material.roughness * hitInfo.material.roughness));
        rayDir = mix(diffuseRayDir, specularRayDir, doSpecular);

        // add in emissive lighting
        ret += hitInfo.material.emissive * throughput;

        // update the colorMultiplier
        throughput *= mix(hitInfo.material.albedo, hitInfo.material.specularColor, doSpecular);   
        
        // Russian Roulette
        // As the throughput gets smaller, the ray is more likely to get terminated early.
        // Survivors have their value boosted to make up for fewer samples being in the average.
        {
        	float p = max(throughput.r, max(throughput.g, throughput.b));
        	if (RandomFloat01(rngState) > p)
            	break;

        	// Add the energy we 'lose' by randomly terminating paths
        	throughput *= 1.0f / p;            
        }
    }
  
    // return pixel color
    return ret;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{

    // initialize a random number state based on frag coord and frame
    uint rngState = uint(uint(fragCoord.x) * uint(1973) + uint(fragCoord.y) * uint(9277) + uint(iFrame) * uint(26699)) | uint(1);


    // The ray starts at the camera position (the origin)
    vec3 rayPosition = vec3(0.0f, 0.0f, 0.0f);//sin(iTime));
     
    // calculate the camera distance
    float cameraDistance = 1.0f / tan(c_FOVDegrees * 0.5f * c_pi / 180.0f);        
     
    // Anti - Aliasing
    // calculate subpixel camera jitter for anti aliasing
    vec2 jitter = vec2(RandomFloat01(rngState), RandomFloat01(rngState)) - 0.5f;
     
    // calculate coordinates of the ray target on the imaginary pixel plane.
    // -1 to +1 on x,y axis. 1 unit away on the z axis
    vec3 rayTarget = vec3(((fragCoord+jitter)/iResolution.xy) * 2.0f - 1.0f, cameraDistance);
    
    // correct for aspect ratio
    float aspectRatio = iResolution.x / iResolution.y;
    rayTarget.y /= aspectRatio;
     
    // calculate a normalized vector for the ray direction.
    // it's pointing from the ray position to the ray target.
    vec3 rayDir = normalize(rayTarget - rayPosition);
 
    // raytrace for this pixel
    vec3 color = vec3(0.0f, 0.0f, 0.0f);
    for (int index = 0; index < c_numRendersPerFrame; ++index)
    	color += GetColorForRay(rayPosition, rayDir, rngState) / float(c_numRendersPerFrame);
    
    // see if space was pressed. if so we want to restart our render.
    // This is useful for when we go fullscreen for a bigger image.
    bool spacePressed = (texture(iChannel2, vec2(KEY_SPACE,0.25)).x > 0.1);
    
    // average the frames together
    vec4 lastFrameColor = texture(iChannel0, fragCoord / iResolution.xy);
    float blend = (lastFrameColor.a == 0.0f || spacePressed) ? 1.0f : 1.0f / (1.0f + (1.0f / lastFrameColor.a));
    color = mix(lastFrameColor.rgb, color, blend);

    // show the result
    fragColor = vec4(color, blend);
}
