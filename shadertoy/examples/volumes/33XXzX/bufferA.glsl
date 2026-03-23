const float NOISE_SCALE = 3.;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    vec4 pre = texture(iChannel0, uv);
    if (pre.w >= 0. && any(greaterThan(abs(iResolution.xy-pre.zw)*iResolution.xy, vec2(.7))))
    {
        // Res change;
        pre = vec2(0.,-two2three(uv, iResolution.xy).z).xxxy; // We use w to time the reset
    }
    
    if (pre.w > 0.5) // Already initialized
    {
        fragColor = pre;
        return;
    }
    
    pre.w -= 69./64.;
    
    if (pre.w <= -1.)
    {
        vec3 p = two2three(uv, iResolution.xy);
        float noil = fbm(p, NOISE_SCALE, NOISE_SCALE);
        vec3 q = p;
        q.z = fract(q.z + 0.015625);
        float noih = fbm(q, NOISE_SCALE, NOISE_SCALE);
    	fragColor = vec4(noil,noih,iResolution.xy);
    }
    else
        fragColor = vec4(pre.xyzw);
}
