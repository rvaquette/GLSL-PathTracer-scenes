#define R iResolution.xy
#define A(U) texture(iChannel0,(U)/R)
#define B(U) texture(iChannel1,(U)/R)
#define Main void mainImage(out vec4 Q, in vec2 U) 
#define ei(a) mat2(cos(a),sin(a),-sin(a),cos(a))
float map (vec3 p) {
    p *= 1.5;
    p.xz *= ei(-.4);
        p.yz *= ei(.1);
    p.x += .1;
    vec3 w = p;
    float dz = 1.;
    for (float i = 0.; i < 3.; i++) {
    
        dz = 4.0*pow(length(w),3.)*dz;
      
        float r = length(w);
        float b = 4.0*acos( w.z/r)+.7;
        float a = 4.0*atan( w.y, w.x );
        w = p + pow(r,4.0) * vec3( sin(b)*cos(a), sin(b)*sin(a), cos(b) );
        
        if (length(w)>20.) break;
    }

    return 0.1*log(dot(w,w))*length(w)/dz;
}
vec3 normal (vec3 p) {
    vec2 e = vec2(1e-4,0);
    return normalize(vec3(
        map(p+e.xyy)-map(p-e.xyy),
        map(p+e.yxy)-map(p-e.yxy),
        map(p+e.yyx)-map(p-e.yyx)
    ));
}
vec4 hash44(vec4 p4)
{
	p4 = fract(p4  * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}

#define pi 3.14159265359
