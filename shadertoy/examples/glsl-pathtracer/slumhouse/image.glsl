#ifndef OPT_SHADERTOY_LIGHT
in vec2 TexCoords;
#else
#define TexCoords (fragCoord.xy / iResolution.xy)
#endif

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	fragColor = texture(iChannel0, TexCoords);
}

