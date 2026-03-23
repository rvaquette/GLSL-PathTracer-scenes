#define Kernel 8

float normpdf(in float x, in float sigma)
{
	return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;

    vec3 col = vec3(0.0);
    float z = 0.0;
    float k =  (iMouse.x == 0.0) ? 0.5 + 0.5*cos(iTime) : iMouse.x/iResolution.x;
    if(uv.x > k){
        vec4 n0 = texture(iChannel1, uv).xyzw;

        //create the 1-D kernel
        float sigma = 6.0;
        float kernel[Kernel*2+1];
        for (int j = 0; j <= Kernel; ++j)
        {
            kernel[Kernel+j] = kernel[Kernel-j] = normpdf(float(j), sigma);
        }

        for(int i = - Kernel; i <= Kernel; i++){
        for(int j = - Kernel; j <= Kernel; j++){
            vec4 n = texture(iChannel1, uv + vec2(i, j)/iResolution.xy);
            if (dot(n.xyz*2.0-1.0, n0.xyz*2.0-1.0)>0.95 && abs(n0.w-n.w)<0.03){
                col += kernel[Kernel+j]*kernel[Kernel+i]*texture(iChannel0, uv + vec2(i, j)/iResolution.xy).rgb;
                z += kernel[Kernel+j]*kernel[Kernel+i];
            }
        }
        }
        col /= z;
    
    }else{
        col =  texture(iChannel0, uv).rgb;
    }
    
    //col *= 10.0;
    col = 1.0-exp(-9.0*col); 
    col = pow(col, vec3(0.7));
    
    col *= 0.5 + 0.5*pow( 16.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y), 0.8 );
    fragColor = vec4(col,1.0);
}
