// ---------------------------------------------
// Raw Frame
// ---------------------------------------------


// ---------------------------------------------
// Material
// ---------------------------------------------
struct Material {
    vec3 albedo;
    float metallic;
    float roughness;
    vec3 emissive;
    
    float specTrans;
    float ior;
    float absorption;
};
Material newMaterial() {
    Material mat;
    mat.albedo = vec3(1.);
    mat.metallic = 0.;
    mat.roughness = .0;
    mat.emissive = vec3(0.);
    mat.specTrans = 0.;
    mat.ior = 1.33;
    mat.absorption = 1.;
    
    return mat;
}
Material getMaterial(vec3 p, inout vec3 n) {
    
    Material mat = newMaterial();
        
    
    float d = map(p);
    if (d == bowl(p)) { // Bowl
        mat.metallic = 0.0;
        mat.albedo = vec3(1.);
        mat.specTrans = 1.;
        mat.absorption = 0.;
        mat.roughness = .1;
        mat.ior = 1.5;
    } else if (d == teapot2(p)) { // Teapot
        mat.metallic = 0.0;
        mat.albedo = vec3(1.);
        mat.specTrans = 0.;
        mat.absorption = 0.;
        mat.roughness = .1;
        mat.ior = 1.5;
    } else if (d == tea(p)) { // Tea
        mat.metallic = 0.0;
        mat.albedo = vec3(0.,-1.,-2.);
        mat.specTrans = 1.;
        mat.absorption = 5.;
        mat.roughness = .05;
        mat.ior = 1.33;
    } else if (d == boxLight(p)) { // Area light
        mat.emissive = vec3(3.0);
    } else { // Ground
        mat.metallic = 1.;
        mat.specTrans = 0.;
        mat.albedo = texture(iChannel2,p.zx).rgb;
        n = bumpMapping(iChannel2, p.zyx,n, 0.01);
        mat.roughness = luma(mat.albedo);
    }
    
    return mat;
}

// ---------------------------------------------
// State
// ---------------------------------------------
struct State {
    bool isRefracted;
    bool hasBeenRefracted;
    float lastIOR;
};

State initState() {
    State s;
    s.hasBeenRefracted = false;
    s.isRefracted = false;
    s.lastIOR = 1.;
    
    return s;
}


// ---------------------------------------------
// BSDF
// ---------------------------------------------
vec3 evalDisneyDiffuse(Material mat, float NoL, float NoV, float LoH, float roughness) {
    float FD90 = 0.5 + 2. * roughness * pow(LoH,2.);
    float a = F_Schlick(1.,FD90, NoL);
    float b = F_Schlick(1.,FD90, NoV);
    
    return mat.albedo * (a * b / PI);
}

vec3 evalDisneySpecularReflection(Material mat, vec3 F, float NoH, float NoV, float NoL) {
    float roughness = pow(mat.roughness, 2.);
    float D = D_GTR(roughness, NoH,2.);
    float G = GeometryTerm(NoL, NoV, pow(0.5+mat.roughness*.5,2.));

    vec3 spec = D*F*G / (4. * NoL * NoV);
    
    return spec;
}

vec3 evalDisneySpecularRefraction(Material mat, float F, float NoH, float NoV, float NoL, float VoH, float LoH, float eta, out float pdf) {
    float roughness = pow(mat.roughness, 2.);
    float D = D_GTR(roughness, NoH, 2.);
    float G = GeometryTerm(NoL, NoV, pow(0.5+mat.roughness*.5, 2.));
    float denom = pow(LoH + VoH*eta, 2.);

    float jacobian = abs(LoH) / denom;
    pdf = SmithG(abs(NoL), roughness*roughness) * max(0.0, VoH) * D * jacobian / NoV;
    
    vec3 spec = pow(1.-mat.albedo, vec3(0.5))  * D * (1.-F) * G * abs(VoH) * jacobian * pow(eta, 2.) / abs(NoL * NoV);
    return spec;
}

vec4 sampleDisneyBSDF(vec3 v, vec3 n, in Material mat, out vec3 l, inout State state) {
    state.hasBeenRefracted = state.isRefracted;
    
    float roughness = pow(mat.roughness, 2.);

    // sample microfacet normal
    vec3 t,b;
    basis(n,t,b);
    vec3 V = toLocal(t,b,n,v);
    vec3 h = SampleGGXVNDF(V, roughness,roughness, frand(), frand());
    if (h.z < 0.0)
        h = -h;
    h = toWorld(t,b,n,h);

    // fresnel
    float VoH = dot(v,h);
    vec3 f0 = mix(vec3(0.04), mat.albedo, mat.metallic);
    vec3 F = F_Schlick(f0, VoH);
    float dielF = Fresnel(state.lastIOR, mat.ior, abs(VoH), 0., 1.);
    
    // lobe weight probability
    float diffW = (1.-mat.metallic) * (1.-mat.specTrans);
    float reflectW = luma(F);
    float refractW = (1.-mat.metallic) * (mat.specTrans) * (1.-dielF);
    float invW = 1./(diffW + reflectW + refractW);
    diffW *= invW;
    reflectW *= invW;
    refractW *= invW;
    
    // cdf
    float cdf[3];
    cdf[0] = diffW;
    cdf[1] = cdf[0] + reflectW;
    //cdf[2] = cdf[1] + refractW;
    
    
    vec4 bsdf = vec4(0.);
    float rnd = frand();
    if (rnd < cdf[0]) // diffuse
    {
        l = cosineSampleHemisphere(n);
        h = normalize(l+v);
        
        float NoL = dot(n,l);
        float NoV = dot(n,v);
        if ( NoL <= 0. || NoV <= 0. ) { return vec4(0.); }
        float LoH = dot(l,h);
        float pdf = NoL/PI;
        
        vec3 diff = evalDisneyDiffuse(mat, NoL, NoV, LoH, roughness) * (1.-F);
        bsdf.rgb = diff;
        bsdf.a = diffW * pdf;
    } 
    else if(rnd < cdf[1]) // reflection
    {
        l = reflect(-v,h);
        
        float NoL = dot(n,l);
        float NoV = dot(n,v);
        if ( NoL <= 0. || NoV <= 0. ) { return vec4(0.); }
        float NoH = min(0.99,dot(n,h));
        float pdf = GGXVNDFPdf(NoH, NoV, roughness);
        
        vec3 spec = evalDisneySpecularReflection(mat, F, NoH, NoV, NoL);
        bsdf.rgb = spec;
        bsdf.a = reflectW * pdf;
    }
    else // refraction
    {
        state.isRefracted = !state.isRefracted;
        float eta = state.lastIOR/mat.ior;
        l = refract(-v,h, eta);
        state.lastIOR = mat.ior;
        
        float NoL = dot(n,l);
        if ( NoL <= 0. ) { return vec4(0.); }
        float NoV = dot(n,v);
        float NoH = min(0.99,dot(n,h));
        float LoH = dot(l,h);
        
        float pdf;
        vec3 spec = evalDisneySpecularRefraction(mat, dielF, NoH, NoV, NoL, VoH, LoH, eta, pdf);
        
        bsdf.rgb = spec;
        bsdf.a = refractW* pdf;
    }
    
    bsdf.rgb *= abs(dot(n,l));

    return bsdf;
}


// ---------------------------------------------
// Pathtrace
// ---------------------------------------------
vec4 pathtrace(vec3 ro, vec3 rd) {
    
    State state = initState();
    float firstDepth = 0.;
    vec3 acc = vec3(0.);
    vec3 abso = vec3(1.);
    
    for(int i=0; i<8; i++) {
        // raytrace
        float t = trace(ro,rd, vec2(0.01, 1000.));
        vec3 p = ro + rd * t;
        if (i == 0) firstDepth = t;
        
        // sky intersection ?
        if (t >= 1000.) {
            //acc += skyColor(rd, sundir) * abso;
            acc += pow(texture(iChannel3, rd).rgb, vec3(2.2)) * abso;
            break;
        }
        
        // info at intersection point
        vec3 n = normal(p, t);
        if (state.isRefracted) n = -n;
        Material mat = getMaterial(p,n);
        
        // sample BSDF
        vec3 outDir;
        vec4 bsdf = sampleDisneyBSDF(-rd,n, mat, outDir, state);
        
        // add emissive part of the current material
        acc += mat.emissive * abso;
            
        // bsdf absorption (pdf are in bsdf.a)
        if ( bsdf.a > 0.)
            abso *= bsdf.rgb / bsdf.a;
        
        // medium absorption
        if (state.hasBeenRefracted) {
            abso *= exp(-t * ((vec3(1.)-mat.albedo)*mat.absorption));
        }
        
        // next direction
        ro = p;
        rd = outDir;
        if (state.isRefracted ) {
            ro += -n*0.01;
        } else if (state.hasBeenRefracted && !state.isRefracted) {
            ro += -n*0.01;
            state.lastIOR = 1.;
        } else {
            ro += n*0.01;
        }
        
        // random early exit taking account energy loss
        #if 1
        {
            float q = max(abso.r, max(abso.g, abso.b));
            if (frand() > q)
                break;

            abso /= q;
        }
        #endif
        
    }

    return vec4(acc, firstDepth);
}


// ---------------------------------------------
// Entrypoint
// ---------------------------------------------
void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 invRes = vec2(1.) / iResolution.xy;
    srand(ivec2(fragCoord), iFrame);
    
    // read data
    Data data = readData(iChannel0, invRes);
    if (iFrame == 0) data = initData();
    
    // setup ray
    vec2 uv = (fragCoord + frand2()-.5) * invRes;
    vec3 ro = data.ro;
    vec2 v = uv*2.-1.;
    v.x *= iResolution.x * invRes.y;
    
    // setup camera
    const vec3 up = vec3(0.,1.,0.);
    vec3 fw = normalize(data.ta-data.ro);
    vec3 uu = normalize(cross(fw, up));
    vec3 vv = normalize(cross(uu, fw));
    vec3 er = normalize(vec3(v,FOCAL_LENGTH));
    vec3 rd = uu * er.x + vv * er.y + fw * er.z;
    
    // depth of field with autofocus
    #if 1
    float focusDistance = trace(ro,  fw, vec2(0.01, 100.));
    vec3 focalPoint = ro + rd * focusDistance;
    
    float blurAmount = 0.015;
    vec3 go = blurAmount*vec3( normalize(frand2()*2.-1.)*sqrt(frand()), 0.0 );
    ro += go.x*uu + go.y*vv;
    
    rd = normalize(focalPoint - ro);
    #endif
    
    
    // pathtrace
    vec4 col = pathtrace(ro, rd);
    
    fragColor = vec4(min(col.rgb,vec3(10.)), col.a > 1000. ? -1. : col.a);
}
