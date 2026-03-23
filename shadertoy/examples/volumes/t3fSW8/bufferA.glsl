
Main {
    if (iFrame >1) {Q = A(U);return;}
    vec3 p = vec3(0,0,-1);
    vec3 d = normalize(vec3(2.*(U-.5*R)/R.y,1));
    Q = vec4(0);
    
    for (float i = 0.;i < 150.; i++) {
        float m = map(p);
        p += d*m;
        
        if (m < 1e-4) {Q.xyz = p;break;}
        if (m > 10.) break;
    }

}
