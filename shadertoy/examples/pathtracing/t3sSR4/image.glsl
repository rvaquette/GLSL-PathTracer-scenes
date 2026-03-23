/*
 * Port of https://github.com/knightcrawler25/GLSL-PathTracer
 * Copyright(c) 2019-2021 Asif Ali
 *
 * v0.1 - Initial Release
 *
 */

float Luminance(vec3 c)
{
    return 0.212671 * c.x + 0.715160 * c.y + 0.072169 * c.z;
}

vec3 Tonemap(in vec3 c, float limit)
{
    return c * 1.0 / (1.0 + Luminance(c) / limit);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy;
	fragColor = texture(iChannel0, uv);
    fragColor.rgb = Tonemap(fragColor.rgb, 1.5);
    fragColor.rgb = pow(fragColor.rgb, vec3(0.4545));
}
