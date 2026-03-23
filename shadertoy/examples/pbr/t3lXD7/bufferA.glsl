//Pre Integrated sss LUT
//Based on GPU pro 2 Pre Integrated subsurface scattering by Penner

#define samples 360.0f
#define PI 3.14159265359f


float Gaussian ( float v, float r )
{
	return 1.0f/sqrt(2.0f*PI*v)*exp(-(r*r)/(2.0f*v));
}

vec3 Scatter ( float r )
{
    return Gaussian ( 0.0064f * 1.414f , r ) * vec3( 0.233f , 0.455f , 0.649f ) +
    	   Gaussian ( 0.0484f * 1.414f , r ) * vec3( 0.100f , 0.336f , 0.344f ) +
    	   Gaussian ( 0.1870f * 1.414f , r ) * vec3( 0.118f , 0.198f , 0.000f ) +
    	   Gaussian ( 0.5670f * 1.414f , r ) * vec3( 0.113f , 0.007f , 0.007f ) +
    	   Gaussian ( 1.9900f * 1.414f , r ) * vec3( 0.358f , 0.004f , 0.000f ) +
    	   Gaussian ( 7.4100f * 1.414f , r ) * vec3( 0.078f , 0.000f , 0.000f ) ;
}


vec3 CalculateSS( float r, float angle ){
    vec2 L = vec2(1.0f,0.0f);
	float stepOffset = 2.0f*PI/samples;
    
    float angleOffset = 0.0f;
    
    vec3 totalLight = vec3(0.0f);
    vec3 totalWeights = vec3(0.0f);
    
    for( float i = 0.0f; i < samples; i++){
    	
        float segment = 2.0f * r * sin(angleOffset*0.5f);
        
        float surfacePointAngle =  angle + angleOffset + 2.0f * PI;
        float NdotL = max(0.0f,cos(surfacePointAngle));
        
        vec3 weights = Scatter(segment);
        totalWeights += weights;
        totalLight += NdotL * weights;
        
        angleOffset += stepOffset;
    }
    
    return totalLight/totalWeights;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    
    if( texelFetch(iChannel0,ivec2(0,0),0).a == iResolution.x)
        discard;
    else{
		vec2 uv = fragCoord.xy / iResolution.xy;
		fragColor.rgb = CalculateSS(1.0f/(uv.y*2.0f),uv.x*PI);
        
        fragColor.a = fragCoord.x == 0.0f && fragCoord.y == 0.0f ? iResolution.x : 0.0f;
    }
}
