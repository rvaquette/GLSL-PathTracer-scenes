/**
* Creative Commons CC0 1.0 Universal (CC-0)
*
* My implementation of 3 types of real-time area light sources (sphere, line, and rectangle).
* See Buffer A for more details.
*
*/

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 col = textureLod(iChannel0, uv, 0.).rgb;
    // for yucky color banding artifacts
    col += hash12(fragCoord * iResolution.xy + vec2(iFrame)) * .00392;
    fragColor = vec4(pow(col, vec3(.4545)), 1.);
}
