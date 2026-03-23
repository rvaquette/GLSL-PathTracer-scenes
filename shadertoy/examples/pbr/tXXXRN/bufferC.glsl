/*

    Specular IBL based on:

    https://learnopengl.com/PBR/IBL/Specular-IBL
    http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
    http://www.pbr-book.org/3ed-2018/Sampling_and_Reconstruction/The_Halton_Sampler.html
    https://google.github.io/filament/Filament.html#annex/choosingimportantdirectionsforsamplingthebrdf
    https://google.github.io/filament/Filament.html#lighting/imagebasedlights/distantlightprobes
    https://google.github.io/filament/Filament.html#toc9.5

    Precompute the specular irradiance maps for varying roughness values and lay them out as 
    equirectangular projections in a texture atlas.

    For each roughness level we sample BufferB map in the specular lobe direction using a low 
    discrepancy sequence. The rougher the surface, the larger the specular lobe and the 
    blurrier the final image. 

    While the result should depend on both the view direction and the normal, we set these to 
    be equal. This results in wrong reflections especially as the view and normal angle 
    increases but it's an acceptable tradeoff for this approximating approach.

    We also generate a BRDF integration map. This 2 channel image will store the BRDF value 
    based on the roughness of the surface and the angle between the normal and the view ray. 
    This does not depend on the environment map and can be calculated independently of any 
    scene.

*/

vec3 getEnvironment(vec3 rayDir, float level){
    vec2 texCoord = vec2((atan(rayDir.z, rayDir.x) / TWO_PI) + 0.5, acos(rayDir.y) / PI);
    return texture(iChannel1, texCoord, level).rgb;
}

// ------------- Hammersley sequence generation using radical inverse -------------

//  http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
//  http://www.pbr-book.org/3ed-2018/Sampling_and_Reconstruction/The_Halton_Sampler.html

//  While it looks like an arcane faerie incantation, it actually makes sense if you follow 
//  the references. Bring some tea.

float radicalInverse(uint bits) {
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}

vec2 hammersley(int i, int N){
    return vec2(float(i)/float(N), radicalInverse(uint(i)));
}

// -------------------------------------------------------------------------------

//  Return a world space sample vector based on a random hemisphere point, the surface normal
//  and the roughness of the surface.
//  https://google.github.io/filament/Filament.html#annex/choosingimportantdirectionsforsamplingthebrdf

// From tangent-space vector to world-space sample vector
vec3 rotateToNormal(vec3 L, vec3 N){
    vec3 tangent;
    vec3 bitangent;

    pixarONB(N, tangent, bitangent);

    tangent = normalize(tangent);
    bitangent = normalize(bitangent);

    return normalize(tangent * L.x + bitangent * L.y + N * L.z);
}

// Return a world-space halfway vector H around N which corresponds to the GGX normal
// distribution. Reflecting the view ray on H will give a light sample direction
vec3 importanceSampleGGX(vec2 Xi, vec3 N, float roughness){
    float a = roughness*roughness;

    // GGX importance sampling
    float cosTheta = sqrt((1.0 - Xi.x) / (1.0 + (a * a - 1.0) * Xi.x));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    float phi = Xi.y * 2.0 * PI;

    vec3 L = normalize(vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta));

    return rotateToNormal(L, N);
}

// Trowbridge-Reitz AKA GGX
float distribution(float NdotH, float roughness){
    float a2 = roughness * roughness;
	return a2 /(PI * pow(NdotH * NdotH * (a2 - 1.0) + 1.0, 2.0));
}

vec3 getPreFilteredColour(vec3 N, float roughness, int sampleCount){
    vec3 R = N;
    vec3 V = R;
    
    float totalWeight = 0.0;
    vec3 prefilteredColor = vec3(0.0);    
    
    // Generate sampleCount number of a low discrepancy random directions in the 
    // specular lobe and add the environment map data into a weighted sum.
    for(int i = ZERO; i < sampleCount; i++){
    
        // Low discrepancy random point in uniform square
        vec2 Xi = hammersley(i, sampleCount);
        // Halfway vector
        vec3 H = importanceSampleGGX(Xi, N, roughness);
        // Light vector
        vec3 L = normalize(reflect(-V, H));

        float NdotL = dot_c(N, L);
        
        if(NdotL > 0.0){
        
            float level = 0.0;
            
        #if ENV_FILTERING == 1
            // Sample the mip levels of the environment map
            // https://placeholderart.wordpress.com/2015/07/28/implementation-notes-runtime-environment-map-filtering-for-image-based-lighting/
            // Vectors to evaluate pdf
            float NdotH = dot_c(N, H);
            float VdotH = dot_c(V, H);

            float pdf = distribution(NdotH, roughness*roughness) * NdotH / (4.0 * VdotH);

            // Solid angle represented by this sample
            float omegaS = 1.0 / (float(sampleCount) * pdf);

            // This should be the size of a level 0 cubemap face. In practice, twice the 
            // resolution works better to get rid of fireflies in specular reflections. 
            // In the current shadertoy code we need another way to find the ratio of pixels
            // at different levels. Not yet implemented.
            float envMapSize = 512.0;
            // Solid angle covered by 1 pixel
            float omegaP = 4.0 * PI / (6.0 * envMapSize * envMapSize);
            // Original paper suggests biasing the mip to improve the results
            float mipBias = 1.0;
            level = max(0.5 * log2(omegaS / omegaP) + mipBias, 0.0);
        #endif
        
            prefilteredColor += getEnvironment(L, level) * NdotL;
            totalWeight      += NdotL;
        }
    }
    prefilteredColor = prefilteredColor / totalWeight;

    return prefilteredColor;
}

// Schlick-Beckmann
float geometry(float cosTheta, float k){
	return (cosTheta) / (cosTheta * (1.0 - k) + k);
}

float smithShadowing(float NdotV, float NdotL, float roughness){
    // IBL uses a different k than direct lighting
    float k = (roughness * roughness) / 2.0; 
	return geometry(NdotV, k) * geometry(NdotL, k);
}

// https://google.github.io/filament/Filament.html#toc9.5
vec2 integrateBRDF(float NdotV, float roughness, int sampleCount){
    
    // Surface normal
    vec3 N = vec3(0.0, 0.0, 1.0);

    // Generate view direction for fragment such that dot(N, V) is uv.x
    vec3 V = normalize(vec3(sqrt(1.0 - NdotV * NdotV), 0.0, NdotV));

    // To accumulate
    vec2 result = vec2(0);
    
    for(int i = ZERO; i < sampleCount; i++){
    
        // Low discrepancy random point in uniform square
        vec2 Xi = hammersley(i, sampleCount);
        // Halfway vector
        vec3 H = importanceSampleGGX(Xi, N, roughness);
        // Light vector
        vec3 L = normalize(reflect(-V, H));

        float NdotL = dot_c(N, L);
        float NdotH = dot_c(N, H);
        float VdotH = dot_c(V, H);

        if(NdotL > 0.0){
            float G = smithShadowing(NdotV, NdotL, roughness);
            float S = (G * VdotH) / (NdotH * NdotV);
            
            // Fresnel-Schlick
            float F = pow(1.0 - VdotH, 5.0);

            // Multiple scattering approach from Filament
            result.x += F * S;
            result.y += S;
        }
    }

    return result / float(sampleCount);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){

    vec3 currentColour = texelFetch(iChannel1, ivec2(4.5, 4.5), 0).rgb;

    // If environment map has changed, we need to rerun the convolution
    bool cubemapChangedFlag = texelFetch(iChannel2, ivec2(4.5, 4.5), 0).rgb != currentColour;
    
    // bool resolutionChanged = texelFetch(iChannel0, ivec2(0.5, 2.5), 0).r > 0.0;
    
    bool run = iFrame == 0 || iFrame == 10 || cubemapChangedFlag;
    
    if(run){
    
        // The loop should not run every frame but Windows FPS drops anyway. 
        // This seems to have fixed it (the shader, not Windows)
        int sampleCount;
        if(run){
            sampleCount = iResolution.x < 2000.0 ? SAMPLE_COUNT : LOW_SAMPLE_COUNT;
        }else{
            sampleCount = 1;
        }
    
        vec3 col = vec3(0);
        float factor = 1.0/2.0;
        float roughness = 0.0;
        
        if(fragCoord.y < 0.5*iResolution.y){
            if(fragCoord.x > 0.5*iResolution.x){
                factor = 1.0/4.0;
                roughness = 0.25;
            }    
            if(fragCoord.x > 0.75*iResolution.x){
                factor = 1.0/8.0;
                roughness = 0.5;
            }
            if(fragCoord.x > 0.875*iResolution.x){
                factor = 1.0/16.0;
                roughness = 0.75;
            }  
            if(fragCoord.x > 0.9375*iResolution.x){
                factor = 1.0/32.0;
                roughness = 1.0;
            }

            vec2 texCoord = fragCoord.xy / (iResolution.xy * factor);
            vec2 thetaphi = ((texCoord * 2.0) - vec2(1.0)) * vec2(PI, HALF_PI); 
            vec3 rayDir = vec3( cos(thetaphi.y) * cos(thetaphi.x), 
                               -sin(thetaphi.y), 
                                cos(thetaphi.y) * sin(thetaphi.x));
            
            // Don't do costly prefiltering for roughness 0 and perfect reflection
            if(fragCoord.x < 0.5 * iResolution.x){
                col = getEnvironment(rayDir, 0.0);
            }else{
                col = getPreFilteredColour(rayDir, roughness, sampleCount);
            }    
        }else{
            if(fragCoord.x < 0.5*iResolution.x){
                // Only render the BRDF in the first frames
                if(iFrame == 0 || iFrame == 10){
                    vec2 texCoord = vec2(2.0*fragCoord.x/iResolution.x, 
                                         2.0*(fragCoord.y/iResolution.y - 0.5));
                    vec2 c = integrateBRDF(texCoord.x, texCoord.y, 
                    iResolution.x < 2000.0 ? BRDF_SAMPLE_COUNT : BRDF_LOW_SAMPLE_COUNT);
                    col = vec3(c.x, c.y, 0.0);
                }else{
                    col = texture(iChannel2, fragCoord.xy/iResolution.xy).rgb;
                }
            }
        }
        // Store current colour of the environment map from BufferB to detect change
        if(fragCoord.x == 4.5 && fragCoord.y == 4.5){
             col = texelFetch(iChannel1, ivec2(4.5, 4.5), 0).rgb;
        }
        
        // Store the size of the render
        if(fragCoord.x == 5.5 && fragCoord.y == 5.5){
             col = vec3(iResolution.xy, 0.0);
        }
        
        fragColor = vec4(col, 1.0);
        
    }else{
        fragColor = texture(iChannel2, fragCoord.xy/iResolution.xy);
    } 
}
