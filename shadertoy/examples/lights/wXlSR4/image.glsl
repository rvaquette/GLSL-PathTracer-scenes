vec2 pos(int i, int n) {
    i = clamp(i, 1, n);
    vec4 r = texelFetch(iChannel0, ivec2(i,0), 0);
    return r.xy*iResolution.xy;
}

float sdLine(vec2 p, vec2 a, vec2 b) {
    p -= a, b -= a;
    float t = dot(p,b)/dot(b,b);
    t = clamp(t, 0., 1.);
    return length(p-b*t);
}

float glow(float d) {
    return pow(R0/abs(d), 1.5);
}

vec3 color(vec2 p, int n) {
    if (n < 2) return vec3(0);
    vec3 res, col = RGB;
    vec2 p0, p1, p2, p3;
    
    // pos(0)=pos(1) and pos(n+1)=pos(n)
    // to duplicate the end control points
    for (int i = 0; i <= n+1; i++) {
        p0=p1, p1=p2, p2=p3, p3=pos(i,n);
        
        float r = length(p - p3);
        res += glow(abs(r - R2))/25.;
        if (length(p2) == 0.) continue;
        float d = sdLine(p, p2, p3);
        res += glow(d)/30.;
        
        if (length(p0) == 0.) continue;
        mat4x2 bbox = mat4x2(p0,p1,p2,p3);
        vec2 s0, s1;
        
        for (int j = 0; j <= BSEG; j++) {
            float s = float(j)/float(BSEG);
            vec4 sss = pow(vec4(s), vec4(3,2,1,0));
            s0=s1, s1=bbox*transpose(BSPLINE)*sss;
            if (length(s0) == 0.) continue;
            float d = sdLine(p, s0, s1);
            res = max(res, glow(d)*col);
        }
        
        // the equivalent bezier control points:
        // the bspline curve is contained in bbox2
        mat4x2 bbox2 = bbox*transpose(BSPLINE)*inverse(transpose(BEZIER));
        for (int k = 0; k < 4; k++) {
            float d = abs(R2*0.5 - length(p - bbox2[k]));
            //res = max(res, vec3(0,1,0)*glow(d)/25.);
        }
        
        col = col.bgr; // alternate colors
    }
    
    return res;
}

void mainImage(out vec4 o, vec2 p) {
    vec4 conf = texelFetch(iChannel0, ivec2(0), 0);
    o = vec4(color(p, int(conf.x)), 1);
    o = sqrt(o);
    if (p.y < 1.0 && p.x < conf.x)
        o.rgb = RGB*p.x/conf.x*2.;
}
