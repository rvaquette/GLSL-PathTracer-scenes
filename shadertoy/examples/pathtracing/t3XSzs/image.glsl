// White Layer over Lambert
// Created by TinyTexel
// Creative Commons Attribution-ShareAlike 4.0 International Public License

/*
non-absorptive layer over red lambertian surface

camera controls via mouse + shift key
light controls via WASD/Arrow keys
*/

const float Pi = 3.14159265359;

#define Time iTime
#define Frame iGlobalFrame
#define PixelCount iResolution.xy
#define clamp01(x) clamp(x, 0.0, 1.0)

vec3 GammaEncode(vec3 x) {return pow(x, vec3(1.0 / 2.2));}

void mainImage( out vec4 fragColor, in vec2 uv0 )
{
    vec2 uv = uv0 - 0.5;
    //vec2 uv = floor(fragCoord.xy);
	vec2 tex = uv0.xy / PixelCount;
    
    vec3 col = textureLod(iChannel0, tex, 0.0).rgb;
    vec3 colpt = textureLod(iChannel0, tex - vec2(0.5, 0.0), 0.0).rgb;
    
    if(false)
    if(uv.x > PixelCount.x * 0.5)
    col = (col - colpt);
    
    //if(false)
    {
    	col = 1.0 - exp2(-col * 3.0);
        col = mix(col, col*col, 0.9);
    }
    
    fragColor = vec4(GammaEncode(clamp01(col)), 0.0);
    
    if(false)
    if(uv.x > PixelCount.x * 0.5)
    fragColor = vec4(col, 0.0);
}
