const float pi=4.*atan(1.);
const float ang=(3.-sqrt(5.))*pi;
float gamma=1.8;

const float SAMPLES=150.;
vec3 bokeh(sampler2D samp,vec2 uv,vec2 radius,float lod){
	vec3 col = vec3(0);
    for(float i=0.;i<SAMPLES;i++){
        float d=i/SAMPLES;
    	vec2 p=vec2(sin(ang*i),cos(ang*i))*sqrt(d)*radius;
        col+=pow(texture(samp,uv+p,lod).rgb,vec3(gamma));
    }
    return pow(col/SAMPLES,vec3(1./gamma));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
	vec2 uv = fragCoord/iResolution.xy;
	
	vec2 pix=1./iResolution.xy;
	
	float r=sin(iTime);
	r*=r*20.;
    if(iMouse.z>0.)r=iMouse.x/iResolution.y*100.;
	float lod=log2(r/SAMPLES*pi*5.);
	//lod=0.;
	vec3 col = bokeh(iChannel0,uv,r*pix,lod);
	
	fragColor = vec4(col,1.0);
	
	if(SAMPLES==0.)fragColor=texture(iChannel0,uv);
}
