vec3 ACESFilm( vec3 x )
{
	float a = 2.51f;
	float b = 0.03f;
	float c = 2.43f;
	float d = 0.59f;
	float e = 0.14f;
	return clamp( ( x * ( a * x + b ) ) / ( x * ( c * x + d ) + e ), vec3( 0.f ), vec3( 1.f ) );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    if(fragCoord.x == 0. && fragCoord.y == 0.)
        return;
        
    vec4 data = texelFetch( iChannel0, ivec2(fragCoord), 0 );
    vec3 col = data.xyz;
    if( data.w > 0.)
        col /= data.w;
    
    fragColor = vec4(pow(col, vec3(1./2.2)), 1.0 );
}
