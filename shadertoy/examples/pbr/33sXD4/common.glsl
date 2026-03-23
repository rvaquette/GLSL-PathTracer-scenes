const float PI = 3.14159265359;
const float TWO_PI = 2.0 * PI;
const float INV_PI = 1.0 / PI;
const float INV_TWO_PI = 0.5 * INV_PI;
const vec3 background = vec3(0.0);
const vec3 X = vec3(1, 0, 0);
const vec3 Y = vec3(0, 1, 0);
const vec3 Z = vec3(0, 0, 1);
// obj
#define TRI 0
#define SPH 1
#define RECT 2
#define OBJ_TYPE(x) objectives[x * 2]
#define OBJ_ID(x) objectives[x * 2 + 1]

// texture
#define COL 0
#define IMG 1
#define TEX_TYPE(x) textures[x * 2]
#define TEX_ID(x) textures[x * 2 + 1]

// material
#define LAMBERTIAN 0
#define GGX_MICROFACET 1
#define EMISSIVE 2
#define MAT_TYPE(x) materials[x * 2]
#define MAT_ID(x) materials[x * 2 + 1]

#define saturate(x) clamp(x, 0.0, 1.0)

// counts
const int obj_cnt = 9;
const int texture_cnt = 2;
const int material_cnt = 8;

struct ray{
    vec3 A;
    vec3 B;
};

struct record{
    float t; 
    vec3 normal;
    vec3 out_normal; // same side with hit ray
    bool is_back_face;
    vec3 pos;
    int mat_id;
    int obj_id;
};

struct triangle{
    vec3 p0, p1, p2; // right hand
    vec3 normal; // flat shading
    //vec3 n0, n1, n2; 
    //vec2 t0, t1, t2
    int mat_id;
};

struct sphere{
    vec3 o;
    float r;
    int mat_id;
};

struct rectangle{
    vec3 p0, p1, p2, p3;
    vec3 normal;
    int mat_id;
};

struct lambertian{
    int diffuse_reflectance_id;
};

struct microfacet_ggx{
    int specular_reflectance_id; // F0
    float roughness;
};

struct emissive{
    int emit_color_id;
    float strength;
};

// objects
triangle triangles[1];
sphere spheres[] = sphere[6](
    sphere(
        vec3(-1.25, 0.2, 0.0), 0.2, 2
    ),
    sphere(
        vec3(-.75, 0.2, 0.0), 0.2, 3
    ),
    sphere(
        vec3(-.25, 0.2, 0.0), 0.2, 4
    ),
    sphere(
        vec3(.25, 0.2, 0.0), 0.2, 5
    ),
    sphere(
        vec3(.75, 0.2, 0.0), 0.2, 6
    ),
    sphere(
        vec3(1.25, 0.2, 0.0), 0.2, 7
    )
);

rectangle rectangles[] = rectangle[3](
    rectangle(
        vec3(0.5, 1.2, -0.5),
        vec3(0.5, 1.2, 0.5),
        vec3(-0.5, 1.2, 0.5),
        vec3(-0.5, 1.2, -0.5),
        vec3(0, -1, 0),
        0
    ),
    rectangle(
        vec3(-5, 5, -1.5),
        vec3(-5, -0.1, -1.5),
        vec3(5, -0.1, -1.5),
        vec3(5, 5, -1.5),
        vec3(0, 0, 1),
        1
    ),
    rectangle(
        vec3(-5, -0.1, -1.5),
        vec3(-5, -0.1, 5),
        vec3(5, -0.1, 5),
        vec3(5, -0.1, -1.5),
        vec3(0, 1, 0),
        1
    )
    
);

int objectives[] = int[obj_cnt * 2](
    RECT, 0,
    RECT, 1,
    RECT, 2,
    SPH, 0,
    SPH, 1,
    SPH, 2,
    SPH, 3,
    SPH, 4,
    SPH, 5
);

const int light_cnts = 1;
int lights[] = int[light_cnts](0);

// textures
vec3 constant_colors[] = vec3[2](
    vec3(.8, .8, .8), // light color
    vec3(0.9, 0.4, 0.3) // object color
);

int textures[] = int[texture_cnt * 2](
    COL, 0,
    COL, 1
);

// materials
lambertian lambertian_array[] = lambertian[1](
    lambertian(0)
);

emissive emissive_array[] = emissive[1](
    emissive(0, 3.)
);

microfacet_ggx microfacet_ggx_array[] = microfacet_ggx[6](
    microfacet_ggx(1, 0.01),
    microfacet_ggx(1, 0.02),
    microfacet_ggx(1, 0.04),
    microfacet_ggx(1, 0.08),
    microfacet_ggx(1, 0.16),
    microfacet_ggx(1, 0.32)
);

int materials[] = int[material_cnt * 2](
    EMISSIVE, 0,
    LAMBERTIAN, 0,
    GGX_MICROFACET, 0,
    GGX_MICROFACET, 1,
    GGX_MICROFACET, 2,
    GGX_MICROFACET, 3,
    GGX_MICROFACET, 4,
    GGX_MICROFACET, 5
);

float seed;

float rnd() { 
    return fract(sin(seed++)*43758.5453123); 
}

vec3 uniform_hemi(vec2 uv){
    float z = uv.x;
    float r = sqrt(max(0.0, 1.0 - z * z));
    float phi = 2.0 * PI * uv.y;
    return vec3(r * cos(phi), r * sin(phi), z);
}

vec2 uniform_disk(vec2 uv){
    float r = sqrt(uv.x);
    float theta = 2.0 * PI * uv.y;
    return r * vec2(cos(theta), sin(theta));
}

vec3 cosine_hemi(vec2 uv){
    vec2 uv1 = uniform_disk(uv);
    float z = sqrt(max(0.0, 1.0 - uv1.x * uv1.x - uv1.y * uv1.y));
    return vec3(uv1, z);
}

vec4 qmul(vec4 r, vec4 s){
    vec4 res;
    res.x=(r[0]*s[0]-r[1]*s[1]-r[2]*s[2]-r[3]*s[3]);
    res.y=(r[0]*s[1]+r[1]*s[0]-r[2]*s[3]+r[3]*s[2]);
    res.z=(r[0]*s[2]+r[1]*s[3]+r[2]*s[0]-r[3]*s[1]);
    res.w=(r[0]*s[3]-r[1]*s[2]+r[2]*s[1]+r[3]*s[0]);
    return res;
}

vec3 rotate_vec(vec3 v, vec3 axis, float theta){
    vec4 q = vec4(cos(theta * 0.5), sin(theta * 0.5) * axis);
    vec4 q_inv = vec4(q.x, -q.yzw);
    vec4 p = vec4(0, v);
    vec4 res = qmul(qmul(q_inv, p),q);
    return res.yzw;    
}

vec3 reoriant(vec3 n1, vec3 n2, vec3 x){
    float dotv = clamp(dot(n1, n2), -1.0, 1.0);
    float dotv_abs = abs(dotv);
    if(dotv_abs == 1.0) return dotv * x;
    vec3 axis = normalize(cross(n1, n2));
    float theta = acos(dotv);
    return rotate_vec(x, axis, theta);
}

vec3 to_gamma(vec3 c){
    return pow(c, vec3(1.0 / 2.2));
}

vec3 to_linear(vec3 c){
    return pow(c, vec3(2.2));
}

vec3 at(ray r, float t){
    return r.A + t * r.B;
}

float sqr(float a){
    return a * a;
}

vec3 pick_texture(int x){
    if(TEX_TYPE(x) == COL) return constant_colors[TEX_ID(x)];
}

float ggx_ndf(float a2, float NoH) {
	float b = ((a2 - 1.0f) * NoH * NoH + 1.0);
	return a2 / (PI * b * b);
}

float smith_shadowing_g1(float a2, float NoX) {
    NoX = max(NoX, 0.0001);
    float NoX2 = max(NoX * NoX, 0.0001);
	return 2.0 * NoX / (sqrt(a2 * (1.0 - NoX2) + NoX2) + NoX);
}

float fresnel_schlick(float VoH){
    float t = 1.0 - VoH;
    float p5 = t * t;
    p5 *= p5 * t;
	return p5;
}

vec3 sample_ggx_importance(vec2 uv, float a2){ // sample isotropic H
    float cosine_theta = sqrt(max(
        (1. - uv.x) /
        (uv.x * (a2 - 1.) + 1.)
    , 0.0001));
    float sine_theta = sqrt(max(1. - cosine_theta * cosine_theta, 0.0001));
    float phi = TWO_PI * uv.y;
    return vec3(sine_theta * cos(phi), sine_theta * sin(phi), cosine_theta);
}

// ray tracing
void intersect_triangle(ray r, triangle tri, out bool valid, out record rec){
    const float EPS = 0.000001;
    vec3 p0 = tri.p0, p1 = tri.p1, p2 = tri.p2;
    vec3 B = r.B;
    vec3 A = r.A;
    vec3 E1 = p1 - p0;
    vec3 E2 = p2 - p0;
    vec3 S = A - p0;
    vec3 S1 = cross(B,E2);
    vec3 S2 = cross(S,E1);
    float t = dot(S2,E2) / dot(S1,E1);
    float b1 = dot(S1,S) / dot(S1,E1);
    float b2 = dot(S2,B) / dot(S1, E1);
    if (t < EPS || b1 < EPS || b2 < EPS || b1 + b2 - 1.0 > EPS) return;
    valid = true;
    rec.t = t;
    rec.pos = at(r, rec.t);
    rec.normal = tri.normal;
    rec.out_normal = rec.normal;
    rec.is_back_face = false;
    if(dot(-r.B, rec.normal) < 0.){
        rec.out_normal *= -1.;
        rec.is_back_face = true;
    }
    rec.mat_id = tri.mat_id;
}

bool solve_quadratic(float A, float B, float C, out float t0, out float t1){
    float discrim = B*B-4.0*A*C;
    if ( discrim < 0.0 )
            return false;
    float rootDiscrim = sqrt(discrim);
    float Q = (B > 0.0) ? -0.5 * (B + rootDiscrim) : -0.5 * (B - rootDiscrim); 
    float t_0 = Q / A; 
    float t_1 = C / Q;
    t0 = min( t_0, t_1 );
    t1 = max( t_0, t_1 );
    return true;
}

void intersect_sphere(ray r, sphere sph, out bool valid, out record rec){
    const float EPS = 0.0001;
	float t0, t1, t = -1.0;
	vec3 L = r.A - sph.o;
	float a = dot(r.B, r.B);
	float b = 2.0 * dot(r.B, L);
	float c = dot(L, L) - (sph.r * sph.r);
	if (!solve_quadratic(a, b, c, t0, t1)) return;
	if (t1 > EPS)
        t = t1;
	if (t0 >= EPS)
		t = t0;
    if(t != -1.){
        valid = true;
        rec.t = t;
        rec.pos = at(r, rec.t);
        rec.normal = normalize(rec.pos - sph.o);
        rec.out_normal = rec.normal;
        rec.is_back_face = false;
        if(dot(-r.B, rec.normal) < 0.){
            rec.out_normal *= -1.;
            rec.is_back_face = true;
        }
        rec.mat_id = sph.mat_id;
    }
}

void intersect_rectangle(ray r, rectangle rect, out bool valid, out record rec){
    triangle tri1 = triangle(
        rect.p0, rect.p1, rect.p2,
        rect.normal,
        rect.mat_id
    );
    triangle tri2 = triangle(
        rect.p0, rect.p2, rect.p3,
        rect.normal,
        rect.mat_id
    );
    intersect_triangle(r, tri1, valid, rec);
    if(valid) return;
    intersect_triangle(r, tri2, valid, rec);
}

void intersect(ray r, int i, out bool valid, out record rec){
    int type = OBJ_TYPE(i);
    int id = OBJ_ID(i);
    if(type == TRI)
        intersect_triangle(r, triangles[id], valid, rec);
    else if(type == SPH)
        intersect_sphere(r, spheres[id], valid, rec);
    else if(type == RECT)
        intersect_rectangle(r, rectangles[id], valid, rec);
}

void hit(ray r, out record rec, out bool valid){
    float minv = 0.0001, maxv = 1e18;
    valid = false;
    for(int i = 0; i < obj_cnt; i ++){
        bool flag = false;
        record temp;
        intersect(r, i, flag, temp);
        if(flag && temp.t >= minv && temp.t <= maxv){
            temp.obj_id = i;
            rec = temp;
            maxv = rec.t;
            valid = true;
        }
    }
}

bool same_hemi(const in vec3 a, const in vec3 b){
    return a.z > 0.0 && b.z > 0.0;
}

vec3 eval(const in vec3 wi, const in vec3 wo, const in record rec){
    int type = MAT_TYPE(rec.mat_id);
    int id = MAT_ID(rec.mat_id);
    vec3 n = rec.out_normal;
    vec3 wo_local = reoriant(n, Z, wo);
    vec3 wi_local = reoriant(n, Z, wi);
    if(type == LAMBERTIAN){ // cosine weighed sample
        if(!same_hemi(wi_local, wo_local)) return vec3(0);
        return pick_texture(lambertian_array[id].diffuse_reflectance_id) * INV_PI;
    }else if(type == GGX_MICROFACET){
        float a = microfacet_ggx_array[id].roughness;
        vec3 specular_reflectance = pick_texture(microfacet_ggx_array[id].specular_reflectance_id);
        float a2 = a * a;
        vec3 h_local = normalize(wi_local + wo_local);
        if(!same_hemi(wi_local, wo_local)) return vec3(0);
        float VoH = saturate(dot(wo_local, h_local));
        float NoH = saturate(h_local.z);
        float NoL = saturate(wi_local.z);
        float NoV = saturate(wo_local.z);
        float D = ggx_ndf(a2, NoH);
        vec3 F = mix(specular_reflectance, vec3(1.0), fresnel_schlick(VoH));
        float G2 = smith_shadowing_g1(a2, NoL) * smith_shadowing_g1(a2, NoV);
        return G2 * F * D / max(4. * NoV * NoL, 0.0001);
    }
}

float get_pdf(const in vec3 wi, const in vec3 wo, const in record rec){
    vec3 n = rec.out_normal;
    vec3 wo_local = reoriant(n, Z, wo);
    vec3 wi_local = reoriant(n, Z, wi);
    int type = MAT_TYPE(rec.mat_id);
    int id = MAT_ID(rec.mat_id);
    if(type == LAMBERTIAN){ // cosine weighed sample
        return saturate(wi_local.z) * INV_PI;
    }else if(type == GGX_MICROFACET){
        float a = microfacet_ggx_array[id].roughness;
        float a2 = a * a;
        vec3 h_local = normalize(wo_local + wi_local);
        float NoH = saturate(h_local.z);
        float VoH = saturate(dot(wo_local, h_local)); 
        float D = ggx_ndf(a2, NoH);
        return D * NoH / max(4. * VoH, 0.0001);
    }
}

bool sample_brdf(out vec3 wi, out vec3 weight, const in vec3 wo, const in record rec){
    int type = MAT_TYPE(rec.mat_id);
    int id = MAT_ID(rec.mat_id);
    vec3 n = rec.out_normal;
    vec3 wo_local = reoriant(n, Z, wo);
    if(type == LAMBERTIAN){ // cosine weighed sample
        vec3 wi_local = cosine_hemi(vec2(rnd(), rnd()));
        if(!same_hemi(wi_local, wo_local)) return false;
        weight = pick_texture(lambertian_array[id].diffuse_reflectance_id);
        wi = reoriant(Z, n, wi_local);
    }else if(type == GGX_MICROFACET){
        float a = microfacet_ggx_array[id].roughness;
        vec3 specular_reflectance = pick_texture(microfacet_ggx_array[id].specular_reflectance_id);
        float a2 = a * a;
        vec3 h_local = sample_ggx_importance(vec2(rnd(), rnd()), a2);
        vec3 wi_local = reflect(-wo_local, h_local);
        if(!same_hemi(wi_local, wo_local)) return false;
        float VoH = saturate(dot(wo_local, h_local));
        float NoH = saturate(h_local.z);
        float NoL = saturate(wi_local.z);
        float NoV = saturate(wo_local.z);
        vec3 F = mix(specular_reflectance, vec3(1.0), fresnel_schlick(VoH));
        float G2 = smith_shadowing_g1(a2, NoL) * smith_shadowing_g1(a2, NoV);
        if(NoH == 0.0 || NoV == 0.0) weight = vec3(0); 
        else weight = G2 * F * VoH / (NoV * NoH);
        wi = reoriant(Z, n, wi_local);
    }
    return true;
}

bool sample_brdf(out vec3 wi, const in vec3 wo, const in record rec){
    int type = MAT_TYPE(rec.mat_id);
    int id = MAT_ID(rec.mat_id);
    vec3 n = rec.out_normal;
    vec3 wo_local = reoriant(n, Z, wo);
    if(type == LAMBERTIAN){ // cosine weighed sample
        vec3 wi_local = cosine_hemi(vec2(rnd(), rnd()));
        if(!same_hemi(wi_local, wo_local)) return false;
        wi = reoriant(Z, n, wi_local);
    }else if(type == GGX_MICROFACET){
        float a = microfacet_ggx_array[id].roughness;
        float a2 = a * a;
        vec3 h_local = sample_ggx_importance(vec2(rnd(), rnd()), a2);
        vec3 wi_local = reflect(-wo_local, h_local);
        if(!same_hemi(wi_local, wo_local)) return false;
        wi = reoriant(Z, n, wi_local);
    }
    return true;
}


float MISWeight(float a,float b){
	float a2 = a*a;
	float b2 = b*b;
	return a2/(a2+b2);
}

float MISWeight(float coffe_a,float aPDF,float coffe_b,float bPDF){
    return MISWeight(coffe_a * aPDF,coffe_b*bPDF);
}

bool is_visible(const in vec3 a, const in vec3 b, out vec3 color){
    ray r = ray(a, b - a);
    record rec;
    bool valid;
    hit(r, rec, valid);
    if(valid && (abs(rec.t - 1.) < 0.0001) && !rec.is_back_face){
        int texture_id = emissive_array[MAT_ID(rec.mat_id)].emit_color_id;
        float strength = emissive_array[MAT_ID(rec.mat_id)].strength;
        color = pick_texture(texture_id) * strength;
        return true;
    }
    return false;
}

void sample_from_light(out vec3 p, out vec3 n, out float pdf){
    int idx = int(rnd() * float(light_cnts - 1));
    int light_id = lights[idx];
    if(OBJ_TYPE(light_id) == RECT){
        rectangle rect = rectangles[OBJ_ID(light_id)];
        vec3 u = rect.p1 - rect.p0;
        vec3 v = rect.p3 - rect.p0;
        p = rnd() * u + rnd() * v + rect.p0;
        pdf = 1. / (length(u) * length(v));
        n = rect.normal;
    }
}

vec4 light_info(int light_id){
    if(OBJ_TYPE(light_id) == RECT){
        rectangle rect = rectangles[OBJ_ID(light_id)];
        vec3 u = rect.p1 - rect.p0;
        vec3 v = rect.p3 - rect.p0;
        int texture_id = emissive_array[MAT_ID(rect.mat_id)].emit_color_id;
        float strength = emissive_array[MAT_ID(rect.mat_id)].strength;
        return vec4(pick_texture(texture_id) * strength, length(u) * length(v));
    }
    return vec4(0);
}

vec4 get_light_info(const in record rec){
    bool flag = false;
    for(int i = 0; i < light_cnts; i ++){
        if(lights[i] == rec.obj_id && !rec.is_back_face){
            return light_info(rec.obj_id);
        }
    }
    return vec4(0);
}

bool direct_lighting(inout ray r, out vec3 color, out vec3 path_weight, int depth){
    record rec;
    bool valid;
    hit(r, rec, valid);
    if(!valid){
        color = background;
        return false;
    }
    if(MAT_TYPE(rec.mat_id) == EMISSIVE){
        if(rec.is_back_face || depth > 0){
            return false;
        }
        int texture_id = emissive_array[MAT_ID(rec.mat_id)].emit_color_id;
        float strength = emissive_array[MAT_ID(rec.mat_id)].strength;
        color = pick_texture(texture_id) * strength;
        return false;
    }
    vec3 surf_normal = rec.out_normal;
    vec3 a = rec.pos;
    vec3 b;
    vec3 Li = vec3(0);
    float light_pdf = 0.;
    vec3 light_normal;
    vec3 wo = -normalize(r.B);
    sample_from_light(b, light_normal, light_pdf);
    if(is_visible(a, b, Li)){
        vec3 dir = b - a;
        vec3 wi = normalize(dir);
        if(dot(wi, surf_normal) > 0.){
            float weight = MISWeight(1., light_pdf, 1., get_pdf(wi, wo, rec));
            color += eval(wi, wo, rec) * 
                     Li * dot(surf_normal, wi) * 
                     dot(light_normal, -wi) / dot(dir, dir) / light_pdf * weight;
        }
    }
    // brdf sample
    vec3 wi;
    if(sample_brdf(wi, path_weight, wo, rec)){
        ray shadow_ray = ray(rec.pos, wi);
        r = shadow_ray;
        record shadow_rec;
        bool valid;
        hit(shadow_ray, shadow_rec, valid);
        if(valid){
            vec4 info = get_light_info(shadow_rec);
            vec3 Li = info.xyz;
            float light_pdf = info.w;
            if(light_pdf == 0.){
                return true;
            }
            float scatter_pdf = get_pdf(wi, wo, rec);
            vec3 b = at(shadow_ray, shadow_rec.t);
            vec3 dir = b - rec.pos;
            float weight = MISWeight(1., scatter_pdf, 1., light_pdf);
            color += eval(wi, wo, rec) * Li * dot(surf_normal, wi) * 
                 dot(light_normal, -wi) / dot(dir, dir) / scatter_pdf * weight;
        }
        return true;
    }else{
        return false;
    }
}



vec3 trace(ray r, int max_depth){
    //return direct_lighting(r);
    vec3 color = vec3(0);
    vec3 throughput = vec3(1);
    record rec;
    bool valid;
    int depth = 0;
    while(depth < max_depth){
    /*
        hit(r, rec, valid);
        if(!valid){
            color += throughput * background;
            break;
        }
        */
        /*
        if(MAT_TYPE(rec.mat_id) == EMISSIVE){
            if(rec.is_back_face) break;
            int texture_id = emissive_array[MAT_ID(rec.mat_id)].emit_color_id;
            float strength = emissive_array[MAT_ID(rec.mat_id)].strength;
            color += throughput * pick_texture(texture_id) * strength;
            break;
        }*/
        //vec3 wo = normalize(-r.B);
        //vec3 wi, weight;
        vec3 temp_color = vec3(0);
        vec3 path_weight;
        if(direct_lighting(r, temp_color, path_weight, depth)){
            color += temp_color * throughput;
            throughput *= path_weight;
            depth ++;
        }else{
           color += temp_color * throughput;
           break;
        }
        /*
        if(sample_brdf(wi, weight, wo, rec)){
            throughput *= weight;
            r = ray(rec.pos, wi);
            depth ++;
        }else{
            break;
        }*/
    }
    return color;
}

