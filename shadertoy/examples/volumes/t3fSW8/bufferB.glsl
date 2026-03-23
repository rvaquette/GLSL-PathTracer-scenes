Main {
    Q = B(U);
    vec3 p = A(U).xyz;
    vec3 o = normalize(vec3(2.*(U-.5*R)/R.y,1));
    vec3 light = vec3(-4,3,-5);
    vec4 h = hash44(vec4(U,iTime,iFrame));
    float a = h.x*2.*pi;
    float b = h.y*pi;
    vec3 n = normal(p);
    vec3 d = reflect(o,n);
    if (h.w < .95) d = refract(o,n,.8);
    d += .1*vec3(vec2(cos(a),sin(a))*sin(b),cos(b));
    d = normalize(d);
    //p += .01*d;
    for (float i = 0.; i < 50.; i++){
        float n = map(p);
        float m = min(n,length(p-light)-2.);
        p += d*max(abs(m),.01);
        vec4 h = hash44(vec4(p*1000.,i));
        float a = h.x*2.*pi;
        float b = h.y*pi;
        vec3 dd = pow(h.z*h.w,2.)*vec3(vec2(cos(a),sin(a))*sin(b),cos(b));
        if (m < 0.0) d = normalize(d+10.*dd);
        if (m > 10.) break;
    
    }
    
    Q.xyz += 100.*(exp(-4.*max(length(p-light)-2.,0.)))*max(sin(-2.+6.*d.y+vec3(1,2,3)),0.);

}
