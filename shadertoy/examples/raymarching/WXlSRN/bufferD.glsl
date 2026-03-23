//by musk License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
//third blur pass

const vec2 dir = vec2(0.00,0.04);//blur direction
const float thresh = .5;//depth threshold

float weight(float x){
	return 1.0-x*x*x*x;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 uvs = (fragCoord.xy-iResolution.xy*.5)/iResolution.yy;
    
    float dist = texture(iChannel0,uv).a;
    float totalw = .0;
    
    vec3 color = vec3(0,0,0);
    for (int i=0; i<=20; i++){
        vec2 p = uv;
        float fi = float(i-10)/10.0;
        p.xy+=dir*fi*dist;
        
        float w = weight(fi);
        
    	vec4 c = texture(iChannel0,p);
        if (dist>=c.a){
            w*=max(.0,1.0-(dist-c.a)/thresh);
        }
        color += c.xyz*w;
        totalw+=w;
    }
    color/=totalw;
	fragColor = vec4(color,dist);
}
