const float gamma=2.2;


vec3 ACESFilm( vec3 x )
{
    float tA = 2.51;
    float tB = 0.03;
    float tC = 2.43;
    float tD = 0.59;
    float tE = 0.14;
    return clamp((x*(tA*x+tB))/(x*(tC*x+tD)+tE),0.0,1.0);
}

vec2 uv00;
vec4 Load(){
    return texture(iChannel0,uv00);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    uv00=uv;
    vec3 tc=Load().xyz;
    tc=ACESFilm(tc);tc=pow(tc,vec3(1./gamma));
    fragColor=vec4(tc,1);
   
}
