void mainImage(out vec4 o,vec2 u){
    o = pow(texelFetch(iChannel0,ivec2(u),0),vec4(.5))*1.3;
}
