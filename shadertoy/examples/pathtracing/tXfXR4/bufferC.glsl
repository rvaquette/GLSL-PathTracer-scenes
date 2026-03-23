
Main {
    Q = A(U);
    vec4 h = hash(vec4(U,iFrame,1));
    vec2 d = vec2(cos(2.*3.14159*h.x),sin(2.*3.14159*h.x));
    for (float i = 0.;i < 50.; i++) {
        U += d;
        vec4 b = B(U);
        d += (1.+h.z)*30.*b.xy;
        d = normalize(d);
        Q += .4*exp(-10.*length(d-vec2(0,-1)))*max(sin(-2.+6.*h.z+vec4(1,2,3,4)),0.);
        Q -= vec4(1,2,3,4)*.0005*b.z;
    }
}
