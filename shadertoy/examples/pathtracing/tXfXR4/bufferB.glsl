Main {
    vec4 n = A(U+vec2(0,1));
    vec4 e = A(U+vec2(1,0));
    vec4 s = A(U-vec2(0,1));
    vec4 w = A(U-vec2(1,0));
    Q.xy = .5*vec2(e.x-w.x,n.x-s.x);
    Q.z = A(U).x;
}
