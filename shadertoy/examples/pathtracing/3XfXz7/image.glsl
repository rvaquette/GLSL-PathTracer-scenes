
// PBR GGX BRDF by gelami
// https://www.shadertoy.com/view/DtBGRW

/* 
 * Implementing GGX for PBR with approximate multiscattering for learning
 * Has depth of field with a number of custom bokeh shapes to choose from
 * 
 * Mouse drag to look around
 * Defines in Common
 * 
 * List of bokeh shapes:
 *   Circle, Square, Polygon, Star, Heart,
 *   Crescent (Rejection sampling and approx.), Cross + 4 Circles, Annulus / 2D Torus, E
 * 
 * For the crescent shape, there seems to be no exact way to uniformly sample it
 * You can do rejection sampling, but it takes too many tries when the crescent becomes thin
 * So an approximation I did is to sample on the two arcs of the cresent in a sine PDF,
 * and interpolate between them
 * 
 * Here's the Desmos graph for the sampling:
 * https://www.desmos.com/calculator/uwcqvxdsjc
 * 
 * I tried to implement random-walk multiscattering
 * but haven't gotten it to work yet though T_T
 * 
 * Resources:
 * 
 * - PBR implementation:
 * 
 * Physically Based Rendering in Filament
 * https://google.github.io/filament/Filament.md.html
 *
 * - Multiscattering GGX approximation:
 * 
 * A Multi-Faceted Exploration
 * https://blog.selfshadow.com/2018/05/13/multi-faceted-part-1/
 * 
 * Revisiting Physically Based Shading at Imageworks
 * https://blog.selfshadow.com/publications/s2017-shading-course/imageworks/s2017_pbs_imageworks_slides_v2.pdf
 * 
 * Multiscattering BRDF Energy Compensation
 * https://patapom.com/blog/BRDF/MSBRDFEnergyCompensation/
 */

// Fork of "Gelami Raymarching Template" by gelami. https://shadertoy.com/view/mslGRs
// 2023-01-04 08:38:20

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    initState(fragCoord, iFrame);
    vec3 col = texelFetch(iChannel0, ivec2(fragCoord), 0).rgb;

    if (int(fragCoord.x) == 0 && int(fragCoord.y) == 0)
        col = texelFetch(iChannel0, ivec2(1, 0), 0).rgb;
    
    col *= exp2(EXPOSURE);
    
    col = max(col, vec3(0));
    col = col / (1. + col);
    
    fragColor = vec4(linearTosRGB(col), 1);
    fragColor += hash13(vec3(fragCoord, iTime)) / 256.;
}
