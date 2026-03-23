// iChannel0[t,0].xy = iMouse.xy at frame t>0
// iChannel0[0,0].xy = (num_points, is_closed)

void mainImage(out vec4 o, in vec2 p) {
    vec4 conf = texelFetch(iChannel0, ivec2(0), 0);
    bool is_drawing = iMouse.z > 0.;
    bool is_closed = conf.y > 0.;
    int num_pts = int(conf.x);
    
    if (p.y > 1.0)
        discard;
    
    if (num_pts == 0 && textureSize(iChannel0,0).x > SIG.length()) {
        o.xy = p.x > 1.0 ? SIG[int(p.x)-1] :
            vec2(SIG.length(), 1);
        return;
    }
    
    if (p.x > 1.0) {
        o = texelFetch(iChannel0, ivec2(p), 0);
        if (is_drawing && int(p.x) >= num_pts)
            o.xy = iMouse.xy/iResolution.xy;
    }
    
    if (max(p.x, p.y) < 1.) {
        o = conf;
        
        if (!is_drawing) {
            o.y = 1.;
            return;
        }
        
        if (iFrame%FPS == 0)
            o.x = float(num_pts + 1);

        if (is_closed)
            o.x = 1., o.y = 0.;
    }
}

