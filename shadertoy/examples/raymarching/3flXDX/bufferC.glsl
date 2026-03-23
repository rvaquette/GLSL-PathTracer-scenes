//
//	Diffuse IBL using spherical harmonics
//
// 	Read the environment map and calculate 9 spherical harmonics coefficients for each channel.
//	The coefficients will describe the low frequency data of the environment. We can use them
//	to construct a matrix which, when multiplied with a view vector, will give the data in 
//	that direction. The low frequency data is similar to a convoluted irradiance map and is 
//	used for diffuse image based lighting, which gives us the ambient colour for shading. 
//
//	Based on:
//	[1] https://cseweb.ucsd.edu/~ravir/papers/envmap/envmap.pdf
//	[2] http://orlandoaguilar.github.io/sh/spherical/harmonics/irradiance/map/2017/02/12/SphericalHarmonics.html
//	[3] https://metashapes.com/blog/realtime-image-based-lighting-using-spherical-harmonics/
//	[4]	https://stackoverflow.com/questions/9600801/evenly-distributing-n-points-on-a-sphere/26127012#26127012
//	[5] https://bduvenhage.me/geometry/2019/07/31/generating-equidistant-vectors.html
//  [6] https://andrew-pham.blog/2019/08/26/spherical-harmonics/
//
//	This tab writes the matrix from equaton 12 of [1] used in lighting calculations later.

//Constants cn from equation 12 in [1]
const float c1 = 0.429043;
const float c2 = 0.511664;
const float c3 = 0.743125;
const float c4 = 0.886227;
const float c5 = 0.247708;

//First 9 spherical harmonic coefficients from equation 3 in [1]
const float Y00 = 0.282095;
const float Y1n = 0.488603; // 3 direction dependent values
const float Y2n = 1.092548; // 3 direction dependent values
const float Y20 = 0.315392;
const float Y22 = 0.546274;

vec3 getRadiance(vec3 dir){
    //Shadertoy textures are gamma corrected. Undo for lighting calculations.
    vec3 col = inv_gamma(texture(iChannel2, dir).rgb);
    // Add some bloom to the environment
    col += 0.5 * pow(col, vec3(2));
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){

    vec3 currentColour = texture(iChannel2, vec3(1,1,1)).rgb;

    bool cubemapChangedFlag = texelFetch(iChannel1, ivec2(4.5, 4.5), 0).rgb != currentColour;
    bool resolutionChanged = texelFetch(iChannel0, ivec2(0.5, 2.5), 0).r > 0.0;
    bool run = iFrame == 0 || cubemapChangedFlag || resolutionChanged;
     
    //Cubemap load may take a while. Run code first frame and while last frame flag was 0
    if(run){
    
    vec4 col = vec4(0);
        
        //  Store an equirectangular projection of the environment map. Subsequent code will
        //  overwrite specific pixels to store the SPH matrices and state flags but this 
        //  should not be visible in the final redner.
        vec2 texCoord = fragCoord.xy / iResolution.xy;
        vec2 thetaphi = ((texCoord * 2.0) - vec2(1.0)) * vec2(PI, HALF_PI); 
        vec3 rayDir = vec3( cos(thetaphi.y) * cos(thetaphi.x), 
                           -sin(thetaphi.y), 
                            cos(thetaphi.y) * sin(thetaphi.x));

        col = vec4(getRadiance(rayDir), 1.0);
        //Ensure radiance is not 0
        col.x = max(col.x, 1e-5);
        col.y = max(col.y, 1e-5);
        col.z = max(col.z, 1e-5);

        //Coefficient values to accumulate
        vec3 L00 = vec3(0);
        vec3 L1_1 = vec3(0);
        vec3 L10 = vec3(0);
        vec3 L11 = vec3(0);

        vec3 L2_2 = vec3(0);
        vec3 L2_1 = vec3(0);
        vec3 L20 = vec3(0);
        vec3 L21 = vec3(0);
        vec3 L22 = vec3(0);

        //To make the sampling rate scalable and independent of the cubemap dimensions, we can 
        //sample a set number of equidistant directions on a sphere. While this is not doable 
        //for all number of directions, a good approximation is the Fibonacci spiral on a 
        //sphere.

        //From [4]
        //Golden angle in radians
        float phi = PI * (3.0 - sqrt(5.0));
        float pointCount;
        
        if(run){
            pointCount = 1024.0;
        }else{
            pointCount = 1.0;
            return;
        }

        for(float i = 0.0; i < pointCount; i++){

            float y = 1.0 - (i / pointCount) * 2.0;
            //Radius at y
            float radius = sqrt(1.0 - y * y);  

            //Golden angle increment
            float theta = phi * i;

            float x = cos(theta) * radius;
            float z = sin(theta) * radius;

            //Sample directiion
            vec3 dir = normalize(vec3(x, y, z));

            //Envronment map value in the direction (interpolated)
            vec3 radiance = getRadiance(dir);

            //Accumulate value weighted by spherical harmonic coefficient in the direction
            L00 += radiance * Y00;
            L1_1 += radiance * Y1n * dir.y;
            L10 += radiance * Y1n * dir.z;
            L11 += radiance * Y1n * dir.x;
            L2_2 += radiance * Y2n * dir.x * dir.y;
            L2_1 += radiance * Y2n * dir.y * dir.z;
            L20 += radiance * Y20 * (3.0 * pow(dir.z, 2.0) - 1.0);
            L21 += radiance * Y2n * dir.x * dir.z;
            L22 += radiance * Y22 * (pow(dir.x, 2.0) - pow(dir.y, 2.0));
        }

        //Scale the sum of coefficents on a sphere
        float factor = 4.0*PI / pointCount;
        
        L00 *= factor;
        L1_1 *= factor;
        L10 *= factor;
        L11 *= factor;
        L2_2 *= factor;
        L2_1 *= factor;
        L20 *= factor;
        L21 *= factor;
        L22 *= factor;

        //Write 4x4 matrix to bufferB
        //GLSL matrices are column major
        if(fragCoord.x < 3.0 && fragCoord.y < 4.0){

            int idxM = int(fragCoord.y-0.5);

            if(fragCoord.x == 0.5){
                mat4 redMatrix;
                redMatrix[0] = vec4(c1*L22.r, c1*L2_2.r, c1*L21.r, c2*L11.r);
                redMatrix[1] = vec4(c1*L2_2.r, -c1*L22.r, c1*L2_1.r, c2*L1_1.r);
                redMatrix[2] = vec4(c1*L21.r, c1*L2_1.r, c3*L20.r, c2*L10.r);
                redMatrix[3] = vec4(c2*L11.r, c2*L1_1.r, c2*L10.r, c4*L00.r-c5*L20.r);
                col = redMatrix[idxM];
            }

            if(fragCoord.x == 1.5){
                mat4 grnMatrix;
                grnMatrix[0] = vec4(c1*L22.g, c1*L2_2.g, c1*L21.g, c2*L11.g);
                grnMatrix[1] = vec4(c1*L2_2.g, -c1*L22.g, c1*L2_1.g, c2*L1_1.g);
                grnMatrix[2] = vec4(c1*L21.g, c1*L2_1.g, c3*L20.g, c2*L10.g);
                grnMatrix[3] = vec4(c2*L11.g, c2*L1_1.g, c2*L10.g, c4*L00.g-c5*L20.g);
                col = grnMatrix[idxM];
            }

            if(fragCoord.x == 2.5){
                mat4 bluMatrix;
                bluMatrix[0] = vec4(c1*L22.b, c1*L2_2.b, c1*L21.b, c2*L11.b);
                bluMatrix[1] = vec4(c1*L2_2.b, -c1*L22.b, c1*L2_1.b, c2*L1_1.b);
                bluMatrix[2] = vec4(c1*L21.b, c1*L2_1.b, c3*L20.b, c2*L10.b);
                bluMatrix[3] = vec4(c2*L11.b, c2*L1_1.b, c2*L10.b, c4*L00.b-c5*L20.b);
                col = bluMatrix[idxM];
            }
        }
        
                //Store a sample colour of the cubemap to detect load and change
        if(fragCoord.x == 4.5 && fragCoord.y == 4.5){
              col = vec4(texture(iChannel2, vec3(1,1,1)).rgb, 1.0);
        }
        
        fragColor = col;
    }else{
        //Reuse SH matrices
        fragColor = texture(iChannel1, fragCoord.xy/iResolution.xy);
    }
}