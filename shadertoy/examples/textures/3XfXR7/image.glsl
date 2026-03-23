/**
* Creative Commons CC0 1.0 Universal (CC-0)
*
* A small experimental follow up to my area lights shader (https://www.shadertoy.com/view/3dsBD4)
* with a textured rectangular area light. See Buffer A for more details.
*
*/

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 col = textureLod(iChannel0, uv, 0.).rgb;
    // for yucky color banding artifacts
    col += hash12(fragCoord * iResolution.xy + vec2(iFrame)) * .003;
    fragColor = vec4(pow(col, vec3(.4545)), 1.);
}
