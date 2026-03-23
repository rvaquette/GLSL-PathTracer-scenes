// procedural craters based on https://www.shadertoy.com/view/MtjGRD
float craters(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
    float va = 0.;
    float wt = 0.;
    for (int i = -2; i <= 2; i++) for (int j = -2; j <= 2; j++) for (int k = -2; k <= 2; k++) {
        vec3 g = vec3(i,j,k);
        vec3 o = 0.8 * hash33(p + g);
        float d = distance(f - g, o);
        float w = exp(-4. * d);
        va += w * sin(2.*PI * sqrt(d));
        wt += w;
	}
    return abs(va / wt);
}

void mainCubemap( out vec4 fragColor, in vec2 fragCoord, in vec3 rayOri, in vec3 rayDir ) {
    if (iFrame > 1) discard; // cache
    vec3 p = 1.5 * rayDir;
    fragColor.x = 0.;
    for (float i = 0.; i < 5.; i++) {
        float c = craters(0.4 * pow(2.2, i) * p);
        float noise = 0.4 * exp(-3. * c) * FBM(10. * p);
        float w = clamp(3. * pow(0.4, i), 0., 1.);
		fragColor.x += w * (c + noise);
	}
    fragColor.x = pow(fragColor.x, 3.);
}
