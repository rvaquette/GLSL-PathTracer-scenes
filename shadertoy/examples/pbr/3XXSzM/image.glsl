float SphereDist(vec3 ro, vec3 rd, vec3 center, float r) {
    vec3 oc = center - ro;
    float lenOC = length(oc);
    if (lenOC < r) {
        return -1.; // ro is inside the sphere.
    }
    float lenProjedOC = dot(oc, rd);
    if (lenProjedOC < 0.) {
        return -1.;
    }
    vec3 projedOC = rd * lenProjedOC;
    vec3 perpendicular = oc - projedOC;
    float lenPerpendicular = length(perpendicular);
    if (lenPerpendicular > r) {
        return -1.;
    }
    float dist = lenProjedOC - sqrt(r*r - lenPerpendicular * lenPerpendicular);
    return dist;
}

vec3 SphereNormal(vec3 p, vec3 center) {
    return normalize(p - center);
}

vec3 SphereTangent(vec3 pos, vec3 normal) {
    vec3 posOffseted = pos;
    posOffseted.y += 1.;
    float D = - dot(normal, pos);
    float distToPlane = dot(normal, posOffseted) + D;
    vec3 proj = posOffseted - normal * distToPlane;
    vec3 tangent = normalize(proj - pos);
    return tangent;
}

vec3 ViewDir(vec2 fragCoord, float fov) {
    vec2 xy = fragCoord - iResolution.xy * .5;
    float z = iResolution.y * .5 / tan(radians(fov * .5));
    return normalize(vec3(xy, -z));
}

mat3 ViewToWorldMat(vec3 ro, vec3 target, vec3 up) {
    vec3 front = normalize(target - ro);
    vec3 right = normalize(cross(front, up));
    up = cross(right, front);
    return mat3(right, up, -front);
}

vec3 ShiftTangent(vec3 tangent, vec3 normal, float shift) {
    vec3 shiftedTangent = tangent + normal * shift;
    return normalize(shiftedTangent);
}

const int SHIFT_KEY = 16;

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec3 col = vec3(0.);
    
    vec3 ro = vec3(0., 1.5, 4.1);
    // turing camera aroung when shift is pressing.
    {
        
        if (texelFetch( iChannel1, ivec2(SHIFT_KEY,0), 0 ).x > 0.) {
            ro = vec3(4.1*cos(iTime), 1.5, 4.1*sin(iTime));
        }        
    }
    vec3 rd = ViewDir(fragCoord, 45.);
    mat3 invViewMat = ViewToWorldMat(ro, vec3(0.,0.,0.), vec3(0.,1.,0.));
    rd = invViewMat * rd;
    
    vec4 sphere = vec4(vec3(0., 0., 0.), 1.);
    
    float dist = SphereDist(ro, rd, sphere.xyz, sphere.w);
    
    if (dist > 0.) {
        vec3 lightColor = vec3(1.,1.,1.);
        vec3 albedo = vec3(1.,.2,.2);
        vec3 specColor = vec3(1.,1.,1.);
        vec3 lightDir = normalize(vec3(0.,.5,1.));
        vec3 pos = ro + rd * dist;
        vec3 normal = SphereNormal(pos, sphere.xyz);
        float nl = dot(normal, lightDir);
        vec3 viewDir = -rd;
        vec3 halfDir = normalize(viewDir + lightDir);
        
#if 0
        // Blinn-Phong specular highlight
        float nh = dot(normal, halfDir);
        float spec = pow(nh, 400.);        
        col += nl * lightColor * albedo + nl * specColor * spec;
#else
        // anisotropic highlighting
        // http://web.engr.oregonstate.edu/~mjb/cs519/Projects/Papers/HairRendering.pdf
        
        vec3 tangent = SphereTangent(pos, normal);
        float shift = texelFetch(iChannel0, ivec2(0), 0).r;
        
        shift = shift * 2. - 1.;
        tangent = ShiftTangent(tangent, normal, shift);
        
        float dotTH = dot(tangent, halfDir);
        float sinTH = sqrt(1. - dotTH * dotTH);
        float dirAtten = smoothstep(-1., 0., dotTH);
        
        // Kajiya-Kay Model
        col += nl * lightColor * albedo + step(0., nl) * dirAtten * specColor * pow(sinTH, 400.);
#endif
    }
   
    // GUI
    vec2 uv = (fragCoord - .5) / iResolution.xy;
    vec4 gui = texture(iChannel0, uv);
    col = mix(col, gui.rgb, gui.a);
    fragColor = vec4(col,1.0);
}
