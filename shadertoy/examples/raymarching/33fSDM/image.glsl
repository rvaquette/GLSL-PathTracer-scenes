// Comparaison of the reflectance of different metals
//  using Lazanyi approximation with RGB rendering versus exact fresnel with spectral rendering 
// BufferA contains the code for the RGB rendering
// BufferB contains the code for the spectral rendering
// BufferC was used to find the reflection coefficients for Lazanyi
// Common contains the metal models, the fresnel functions, and some pieces of code used in multiple buffers
//
// To look at another metal, edit the first 3 lines of the "Common" tab accordingly
// Supported metals are: Iron, Gold(un-normalized!), Aluminium, Chromium, Copper(un-normalized), Lead, Platinium, Silver

//To find the values for a new metal, import a table contating 
// the index of refraction and extinction coefficient for several visible wavelegth
// and write a function to interolate this data (you can look at resampleIor_49() in common tab)
// then redefine getIOR(w) to point towards your new interpolation function
// then you can uncomment the following line: 

// #define showF082

//and the output will be an image filled with f0 on the left, and f82 on the right
// by default it is gamma corrected, but the values should be used in linear space, 
// so you can comment the following lines to get the raw result

#define GAMMA
#define DITHER

// you can then save the image and look at the pixel values

// sometimes some channel gets boosed instead of attenuated (example:gold, and some models of copper)
// if some channel of the final image is reaching 255., uncomment the following line and see if anything shows up

// #define showOvershoot

// (the overshoot is magnified 16 times, so it is easier to see)

//if there is too much noise when looking at the f0/f82 reflection coefficients,
// increase the following values to enable spatial filtering
#define denoiseF0F82 0.

//Tonemapping is disabled by default for color accuracy, but you can enable it to make the image looks nicer
#define tonemap(x) (x)
// #define tonemap(x) ACES(x)
// #define tonemap(x) HLG_tm(x)


// Thanks to jessie for telling me about Lazanyi, and to the researchers who made the reasurements I found on refractiveindex.info
// anyone is free to use the code and values contained in this shader

vec3 RRTAndODTFit(vec3 v) 
{
    vec3 a = v * (v + 0.0245786);
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}
vec3 ACES(vec3 color){
    const mat3 ACESInputMat = mat3(
        0.59719, 0.35458, 0.04823,
        0.07600, 0.90834, 0.01566,
        0.02840, 0.13383, 0.83777
    );
    const mat3 ACESOutputMat = mat3(
         1.60475, -0.53108, -0.07367,
        -0.10208,  1.10813, -0.00605,
        -0.00327, -0.07276,  1.07602
    );
    color = color * ACESInputMat;
    color = RRTAndODTFit(color);
    color = color * ACESOutputMat;
    return clamp(color, 0.0, 1.0);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    vec2 m = iMouse.x>0.?iMouse.xy:vec2(iResolution.x*.5);

    // left side: RGB, right side: spectral
    vec4 col = fragCoord.x>m.x?texture(iChannel0,uv):texture(iChannel1,uv);col/=col.a;
    
    // show relative difference
    //vec4 col0 = texture(iChannel0,uv);col0/=col0.a;
    //vec4 col1 = texture(iChannel1,uv);col1/=col1.a;
    //vec4 col = abs(col0-col1)/(col0*.5+col1*.5);
    
    
    #ifdef showF082
    vec4 tc = texture(iChannel2,vec2(.9));tc/=tc.a;
    col*=0.;
    for(float x=-denoiseF0F82;x<=denoiseF0F82;x++){
        for(float y=-denoiseF0F82;y<=denoiseF0F82;y++)
            col+=texture(iChannel2,uv+vec2(x,y)/iResolution.xy);
    }
    col/=col.a;
    col/=tc;
    #endif
    
    fragColor = vec4(
        #ifdef GAMMA
        pow(
        #endif
            tonemap(col.rgb
                   ///HLG_MAX
                   #ifdef showOvershoot
                   *16.-16.
                   #endif
                   )
            #ifdef GAMMA
            ,vec3(1./2.2))
            #endif
    ,1.0);
    
   #ifdef DITHER
   vec4 noise = texture(iChannel3,(fragCoord)/iChannelResolution[3].xy);
    //merge channels for better noise precision;
    noise = noise*255./256.+noise.yzwx*255./(256.*256.);
    noise+=noise.zwxy/(256.*256.); // the two last channels
    
    
    const float prec = float((1<<8)-1); //8-bit color range: 0.->255.
        
    vec3 l = fragColor.rgb; //gamma-space value
    vec3 lin = pow(l,vec3(2.2)); //linear-space value
    
    // get quantization "bounds"
    vec3 lfg = floor(l*prec)/prec;
    vec3 lcg = ceil(l*prec)/prec;
    
    // convert bounts to linear
    vec3 lfl = pow(lfg,vec3(2.2));
    vec3 lcl = pow(lcg,vec3(2.2));
    
    //vec3 xg = (l  -lfg)/(lcg-lfg); // == fract(l*prec)
    vec3 xl = (lin-lfl)/(lcl-lfl);
    
    vec3 dithered = mix(lfg,lcg,step(noise.xyz,xl)); 
    fragColor.rgb = dithered;
   #endif
    
}
