#define R iResolution.xy
#define Main void mainImage(out vec4 Q, in vec2 U)
#define A(U) texture(iChannel0,(U)/R)
#define B(U) texture(iChannel1,(U)/R)
#define ei(a) mat2(cos(a),sin(a),-sin(a),cos(a))
vec4 hash(vec4 p4)
{
    p4 = fract(p4  * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}

