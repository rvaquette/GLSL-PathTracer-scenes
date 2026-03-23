
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	fragColor = pow(texture(iChannel0,fragCoord/iResolution.xy)/10., vec4(1./2.2));
}
