//By Nestor Vina

vec3 dof(sampler2D buffer, vec2 uv, float distanceOfFocus){    
	vec3 finalColor = vec3(0);
    const float squareEdge = 2.0;
    const float iters = (squareEdge*2.0+1.0)*(squareEdge*2.0+1.0);
    float l = abs(distanceOfFocus-texture(buffer,uv).a);
    float radiousOfDepth = 7.0;
    float dofLevel = clamp((l-radiousOfDepth )*0.1,0.0,1.0);    
    
    for( float i = -squareEdge; i <= squareEdge; i++)
        for( float j = -squareEdge; j <= squareEdge; j++)
            finalColor += texture(buffer,uv+vec2(i,j)*0.0015*dofLevel).xyz;
        
    finalColor /= iters;
    return finalColor;
}

vec3 GammaCorrection(vec3 inColor){
	const vec3 gammaExp = vec3(1.0/2.2);
    return pow(inColor,gammaExp);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy;
    
	fragColor = vec4(dof(iChannel0,uv,7.0f*5.0),1.0);
    fragColor.xyz = GammaCorrection(fragColor.xyz);
}
