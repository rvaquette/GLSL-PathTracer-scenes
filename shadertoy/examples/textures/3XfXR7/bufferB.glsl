/**
* Creative Commons CC0 1.0 Universal (CC-0)
*
* A basic TAA implementation based on the variance clipping technique by Marco Salvi (Nvidia).
*
*/

const ivec2 offsets[8u] = ivec2[]
(
    ivec2(-1,-1), ivec2(-1, 1), 
	ivec2(1, -1), ivec2(1, 1), 
	ivec2(1, 0),  ivec2(0, -1), 
	ivec2(0, 1),  ivec2(-1, 0)
);

const float gaussian[8u] = float[]
(
    .0625, .0625,
    .0625, .0625,
    .125,  .125,
    .125,  .125
);

vec3 RGBToYCoCg(vec3 RGB)
{
    float Y = dot(RGB, vec3(1, 2,  1))  * .25;
    float Co= dot(RGB, vec3(2, 0, -2))  * .25 + (.5 * 256./255.);
    float Cg= dot(RGB, vec3(-1, 2, -1)) * .25 + (.5 * 256./255.);
    return vec3(Y, Co, Cg) * (1. / (1. + Y)); // tonemap
}

vec3 YCoCgToRGB(vec3 YCoCg)
{
    YCoCg *= 1. / (1. - YCoCg.x); // tonemap
	float Y= YCoCg.x;
	float Co= YCoCg.y - (.5 * 256. / 255.);
	float Cg= YCoCg.z - (.5 * 256. / 255.);
	float R= Y + Co - Cg;
	float G= Y + Cg;
	float B= Y - Co - Cg;
	return vec3(R, G, B);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 currentBuffer = RGBToYCoCg(textureLod(iChannel0, uv, 0.).rgb);
    vec3 historyBuffer = RGBToYCoCg(textureLod(iChannel1, uv, 0.).rgb);

    vec3 mean = currentBuffer;
    vec3 variance = currentBuffer * currentBuffer;
    vec3 filtered = currentBuffer * .25;
    
    // Marco Salvi's Implementation (by Chris Wyman)
    for(int i = 0; i < 8; i++)
    {
        vec3 neighborTexel = RGBToYCoCg(texelFetch(iChannel0, ivec2(fragCoord.xy) + offsets[i], 0).rgb);
        mean += neighborTexel;
        variance += neighborTexel * neighborTexel;
        filtered += neighborTexel * gaussian[i];
    }
    
    mean /= 9.;
    variance /= 9.;
    const float stDevMultiplier = 1.5;
	vec3 sigma = sqrt(abs(variance - mean * mean));
	vec3 colorMin = min(filtered, mean - stDevMultiplier * sigma);
	vec3 colorMax = max(filtered, mean + stDevMultiplier * sigma);
    
    historyBuffer = clamp(historyBuffer, colorMin, colorMax);
    
    vec3 outColor = mix(historyBuffer, filtered, .05);

	fragColor = vec4(YCoCgToRGB(outColor), 1.);
}
