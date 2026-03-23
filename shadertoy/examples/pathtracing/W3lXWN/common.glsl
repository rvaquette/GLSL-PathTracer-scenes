const float PI = 3.14159265359;
const float TWO_PI = 2.0 * PI;
const float INV_PI = 1.0 / PI;
const float INV_TWO_PI = 0.5 * INV_PI;
const vec3 background = vec3(0.0);
const vec3 X = vec3(1, 0, 0);
const vec3 Y = vec3(0, 1, 0);
const vec3 Z = vec3(0, 0, 1);
#define VNDF
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
#define BLINN_PHONG 1
#define OREN_NAYAR 2
#define DISNEY_DIFFUSE 3
#define GGX_MICROFACET 4
#define GGX_MICROFACET_ANISO 5
#define GGX_GLASS 6
#define DISNEY_PRINCIPLED 7
#define EMISSIVE 8
#define MAT_TYPE(x) materials[x * 2]
#define MAT_ID(x) materials[x * 2 + 1]

#define saturate(x) clamp(x, 0.0, 1.0)

// counts
const int obj_cnt = 9;
const int texture_cnt = 7;
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

struct oren_nayar{
    int diffuse_reflectance_id;
    float roughness;
    //float sigma;
};

struct blinn_phong{
    int specular_reflectance_id;
    float roughness;
};

struct microfacet_ggx{
    int specular_reflectance_id; // F0
    float roughness;
};

struct microfacet_ggx_aniso{
    int specular_reflectance_id; // F0
    vec2 roughness;
};

struct glass_ggx{
    int base_color_id;
    float roughness;
    float anisotropic;
    float eta; // 外 -> 内
};

struct disney_principled{
    int baseColor_id; // 基本纹理
    float subsurface; // 次表面散射程度（用于diffuse和次表面散射之间插值）
    float roughness; 
    float metallic; // 金属度
    float specular; // 高光度
    float specularTint; // 高光向基本颜色靠拢的程度
    float anisotropic; // 
    float sheen; // 模拟边缘明亮效果
    float sheenTint; 
    float clearcoat; // 额外的高光项，模拟清漆
    float clearCoatGloss; // 清漆的光滑度
    float specular_transmission;
    float eta;
};

struct emissive{
    int emit_color_id;
    float strength;
};

// objects
triangle triangles[] = triangle[2](
    triangle(
        vec3(-1.0,-0.0,-2.0), // p0
        vec3(1.0,-0.0,-2.0), // p1
        vec3(0.0,3.0,-2.0), // p2
        vec3(0, 0, 1), // flat normal
        1 // mat_id
    ),
    triangle(
        vec3(3,-0.5,-2.0), // p0
        vec3(3,-0.5,2.0), // p1
        vec3(3, 2,0.0), // p2
        vec3(-1, 0, 0), // flat normal
        2 // mat_id
    )
);

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

// textures
vec3 constant_colors[] = vec3[7](
    vec3(.8, .8, .8),
    vec3(0.815, .00418501512, .00180012),
    vec3(0.815, .418501512, .00180012),
    vec3(0.815, .00418501512, .00180012),
    vec3(0.9, 0.4,0.3),
    vec3(0.5, .1501512, .80012),
    vec3(0.025, .2501512, .0180012)
);

int textures[] = int[texture_cnt * 2](
    COL, 0,
    COL, 1,
    COL, 2,
    COL, 3,
    COL, 4,
    COL, 5,
    COL, 6
);

// materials
lambertian lambertian_array[] = lambertian[4](
    lambertian(0),
    lambertian(1),
    lambertian(2),
    lambertian(3)
);

emissive emissive_array[] = emissive[1](
    emissive(0, 3.)
);

blinn_phong blinn_phong_array[] = blinn_phong[3](
    blinn_phong(4, 0.01),
    blinn_phong(4, 0.05),
    blinn_phong(4, 0.1)
);

oren_nayar oren_nayar_array[] = oren_nayar[1](
    oren_nayar(0, 1.0)
);

microfacet_ggx microfacet_ggx_array[] = microfacet_ggx[3](
    microfacet_ggx(4, 0.01),
    microfacet_ggx(4, 0.05),
    microfacet_ggx(4, 0.1)
);

microfacet_ggx_aniso microfacet_ggx_aniso_array[] = microfacet_ggx_aniso[1](
    microfacet_ggx_aniso(4, vec2(0.3, 0.1))
);

glass_ggx glass_ggx_array[] = glass_ggx[1](
    glass_ggx(4, 0.3, 0.1, 1.0 / 2.4)
);

disney_principled disney_principled_array[] = disney_principled[6](
    disney_principled(
        1, // base color
        0.0, // subsurface 
        1.0, // roughness
        0.0, // metallic
        0.0, // specular
        0.0, // specularTint
        0.0, // anisotropic
        1., // sheen
        0., // sheenTint
        0., // clearcoat
        0.0, // clearCoatGloss
        0.0, // specular_transmission
        1. / 1. // eta
    ),
    disney_principled(
        2, // base color
        0.0, // subsurface 
        0.53, // roughness
        1.0, // metallic
        0.0, // specular
        0.0, // specularTint
        0.0, // anisotropic
        1., // sheen
        0., // sheenTint
        0., // clearcoat
        0.0, // clearCoatGloss
        0.0, // specular_transmission
        1. / 1. // eta
    ),
    disney_principled(
        3, // base color
        1.0, // subsurface 
        1.0, // roughness
        0.0, // metallic
        0.0, // specular
        0.0, // specularTint
        0.0, // anisotropic
        1., // sheen
        0., // sheenTint
        0., // clearcoat
        0.0, // clearCoatGloss
        0.0, // specular_transmission
        1. / 1. // eta
    ),
    disney_principled(
        4, // base color
        0.0, // subsurface 
        0.9, // roughness
        1.0, // metallic
        0.1, // specular
        0.0, // specularTint
        1.0, // anisotropic
        1., // sheen
        0., // sheenTint
        0., // clearcoat
        0.0, // clearCoatGloss
        0.0, // specular_transmission
        1. / 1. // eta
    ),
    disney_principled(
        5, // base color
        0.0, // subsurface 
        0.1, // roughness
        0.0, // metallic
        0.1, // specular
        0.0, // specularTint
        0.0, // anisotropic
        1., // sheen
        0., // sheenTint
        0., // clearcoat
        1.0, // clearCoatGloss
        0.0, // specular_transmission
        1. / 1. // eta
    ),
    disney_principled(
        6, // base color
        0.1, // subsurface 
        1.0, // roughness
        0.0, // metallic
        0.1, // specular
        0.0, // specularTint
        0.0, // anisotropic
        1., // sheen
        0., // sheenTint
        1., // clearcoat
        1.0, // clearCoatGloss
        0.0, // specular_transmission
        1. / 1. // eta
    ) 
);

int materials[] = int[material_cnt * 2](
    EMISSIVE, 0,
    LAMBERTIAN, 0,
    DISNEY_PRINCIPLED, 0,
    DISNEY_PRINCIPLED, 1,
    DISNEY_PRINCIPLED, 2,
    DISNEY_PRINCIPLED, 3,
    DISNEY_PRINCIPLED, 4,
    DISNEY_PRINCIPLED, 5
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
    //vec3 Y = vec3(0, 1, 0);
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

float beckmann_alpha_to_phong_shininess(float a){
    return 2.0 / min(0.9999, max(0.0002, (a * a))) - 2.0;
}

float beckmann_alpha_to_oren_nayar_sigma(float a){
    return 0.7071067 * atan(a);
}

float ggx_ndf(float a2, float NoH) {
	float b = ((a2 - 1.0f) * NoH * NoH + 1.0);
	return a2 / (PI * b * b);
}
float ggx_ndf_aniso(vec2 a, vec3 h){ // in local space
    float part1 = PI * a.x * a.y;
    float part2 = pow(h.x / a.x, 2.) + pow(h.y / a.y, 2.) + h.z;
    return 1. / (part1 * part2 * part2);
}
float smith_shadowing_g1(float a2, float NoX) {
    NoX = max(NoX, 0.0001);
    float NoX2 = max(NoX * NoX, 0.0001);
	return 2.0 * NoX / (sqrt(a2 * (1.0 - NoX2) + NoX2) + NoX);
}
float smith_shadowing_g1_aniso(vec2 a, vec3 x){ // local space
    float b = sqrt(
        1. + (sqr(a.x * x.x) + sqr(a.y * x.y)) / sqr(x.z)
    );
    return 2. / (1. + b);
}
float fresnel_schlick(float VoH){
    float t = 1.0 - VoH;
    float p5 = t * t;
    p5 *= p5 * t;
	return p5;
}
float vndf_wi_pdf(float a, float NoH, float VoH) {
	NoH = max(0.00001, NoH);
	VoH = max(0.00001, VoH);
    float a2 = max(0.00001, a * a);
	return (ggx_ndf(a2, NoH) * smith_shadowing_g1(a2, VoH)) / (4.0 * VoH);
}
float vndf_wi_pdf_aniso(vec2 a, vec3 h_local, vec3 v_local) {
    float VoH = dot(v_local, h_local);
	return (ggx_ndf_aniso(a, h_local) * smith_shadowing_g1_aniso(a, v_local)) / (4.0 * VoH);
}
vec3 sample_ggx_vndf(vec3 Ve, float alpha_x, float alpha_y, float U1, float U2){
	vec3 Vh = normalize(vec3(alpha_x * Ve.x, alpha_y * Ve.y, Ve.z));
	float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
	vec3 T1 = lensq > 0. ? vec3(-Vh.y, Vh.x, 0.) * inversesqrt(lensq) : vec3(1,0,0);
	vec3 T2 = cross(Vh, T1);
	float r = sqrt(U1);
	float phi = 2.0 * PI * U2;
	float t1 = r * cos(phi);
	float t2 = r * sin(phi);
	float s = 0.5 * (1.0 + Vh.z);
	t2 = (1.0 - s)*sqrt(1.0 - t1*t1) + s*t2;
	vec3 Nh = t1*T1 + t2*T2 + sqrt(max(0.0, 1.0 - t1*t1 - t2*t2))*Vh;
	vec3 Ne = normalize(vec3(alpha_x * Nh.x, alpha_y * Nh.y, max(0.0, Nh.z)));
	return Ne;
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

vec3 sample_ggx_importance_aniso(vec2 uv, vec2 a){
    float phi = 0.0;
    if(uv.x < 0.25) phi = atan(a.y / a.x * tan(TWO_PI * uv.x));
    else if(uv.x == 0.25 || uv.x == 0.75) phi = 0.5 * PI;
    else if(uv.x > 0.25 && uv.x < 0.75) phi = atan(a.y / a.x * tan(TWO_PI * uv.x)) + PI;
    else if(uv.x > 0.75) phi = atan(a.y / a.x * tan(TWO_PI * uv.x)) + TWO_PI;
    //return vec3(phi / TWO_PI);
    float cos_phi = cos(phi);
    float sin_phi = sin(phi);
    float inner = uv.y / 
        ((1. - uv.y) * (sqr(cos_phi / a.x) + sqr(sin_phi / a.y)));
    float theta = atan(sqrt(max(inner, 0.0001)));
    float cos_theta = cos(theta);
    float sin_theta = sin(theta);
    return vec3(sin_theta * cos_phi, sin_theta * sin_phi, cos_theta);
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

vec3 sample_phong(vec2 u, float shininess){
	float cosine = pow(1.0f - u.x, 1.0f / (1.0f + shininess)); // cosine value between r and v
	float sine = sqrt(1.0f - cosine * cosine);
	float phi = TWO_PI * u.y;
	return vec3(cos(phi) * sine, sin(phi) * sine, cosine);
}

vec3 sample_disney_clearcoat(vec2 uv, float a){
    float cos_theta = sqrt(
        (1. - pow(a * a, 1. - uv.x)) / (1. - a * a)
    );
    float phi = TWO_PI * uv.y;
    float sin_theta = sqrt(1. - cos_theta * cos_theta);
    return vec3(sin_theta * cos(phi), sin_theta * sin(phi), cos_theta);
}

float GTR1(float NdotH, float a)
{
    if (a >= 1.) return 1./PI;
    float a2 = a*a;
    float t = 1. + (a2-1.)*NdotH*NdotH;
    return (a2-1.) / (PI*log(a2)*t);
}

float fresnel(float VoH, float LoH, float eta){
    float Rs = (VoH - eta * LoH) / (VoH + eta * LoH);
    float Rp = (eta * VoH - LoH) / (eta * VoH + LoH);
    return 0.5 * (Rs * Rs + Rp * Rp);
}

bool same_hemi(const in vec3 a, const in vec3 b){
    return a.z > 0.0 && b.z > 0.0;
}

bool sample_brdf(out vec3 wi, out vec3 weight, const in vec3 wo, record rec){
    int type = MAT_TYPE(rec.mat_id);
    int id = MAT_ID(rec.mat_id);
    vec3 n = rec.out_normal;
    vec3 wo_local = reoriant(n, Z, wo);
    if(type == LAMBERTIAN){ // cosine weighed sample
        vec3 wi_local = cosine_hemi(vec2(rnd(), rnd()));
        if(!same_hemi(wi_local, wo_local)) return false;
        weight = pick_texture(lambertian_array[id].diffuse_reflectance_id);
        wi = reoriant(Z, n, wi_local);
    }else if(type == OREN_NAYAR){
        vec3 wi_local = cosine_hemi(vec2(rnd(), rnd()));
        if(!same_hemi(wi_local, wo_local)) return false;
        vec3 diffuse_reflectance = pick_texture(oren_nayar_array[id].diffuse_reflectance_id);
        float sigma = beckmann_alpha_to_oren_nayar_sigma(oren_nayar_array[id].roughness);
        float NoL = dot(n, wi);
        float NoV = dot(n, wo);
        float theta_l = acos(NoL);
        float theta_v = acos(NoV);
        float alpha = max(theta_l, theta_v);
        float beta = min(theta_l, theta_v);
        vec3 v = normalize(wo - NoV * n);
        vec3 l = normalize(wi - NoL * n);
        float cosine_diff = max(0., dot(v, l));
        float sigma2 = sigma * sigma;
        float A = 1.0 - 0.5 * (sigma2 / (sigma2 + 0.33));
        float B = 0.45 * (sigma2 / (sigma2 + 0.09));
        weight = diffuse_reflectance * 
               (A + B * cosine_diff * sin(alpha) * tan(beta));
        wi = reoriant(Z, n, wi_local);
    }else if(type == BLINN_PHONG){
        vec3 specular_reflectance = pick_texture(blinn_phong_array[id].specular_reflectance_id);
        float shininess = 
            beckmann_alpha_to_phong_shininess(blinn_phong_array[id].roughness);
        vec3 reflect_dir = reflect(-wo, n);
        vec3 wi_local = sample_phong(vec2(rnd(), rnd()), shininess);
        if(!same_hemi(wi_local, wo_local)) return false;
        weight = max(vec3(0.0f, 0.0f, 0.0f), specular_reflectance * dot(wi, n));
        wi = reoriant(Z, reflect_dir, wi_local);
    }else if(type == GGX_MICROFACET){
        float a = microfacet_ggx_array[id].roughness;
        vec3 specular_reflectance = pick_texture(microfacet_ggx_array[id].specular_reflectance_id);
        float a2 = a * a;
#ifdef VNDF
        vec3 h_local = sample_ggx_vndf(wo_local, a, a, rnd(), rnd());
        vec3 wi_local = reflect(-wo_local, h_local);
        if(!same_hemi(wi_local, wo_local)) return false;
        float VoH = saturate(dot(wo_local, h_local));
        float NoH = saturate(h_local.z);
        float NoL = saturate(wi_local.z);
        vec3 F = mix(specular_reflectance, vec3(1.0), fresnel_schlick(VoH));
        float D = ggx_ndf(a2, NoH);
        float G1 = smith_shadowing_g1(a2, NoL);
        weight = G1 * F;
        wi = reoriant(Z, n, wi_local);
#else
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
#endif
    }else if(type == GGX_MICROFACET_ANISO){
        vec2 a = microfacet_ggx_aniso_array[id].roughness;
        vec3 specular_reflectance = pick_texture(microfacet_ggx_aniso_array[id].specular_reflectance_id);
#ifdef VNDF
        vec3 h_local = sample_ggx_vndf(wo_local, a.x, a.y, rnd(), rnd());
        vec3 wi_local = reflect(-wo_local, h_local);
        if(!same_hemi(wi_local, wo_local)) return false;
        float VoH = saturate(dot(wo_local, h_local));
        vec3 F = mix(specular_reflectance, vec3(1.0), fresnel_schlick(VoH));
        float D = ggx_ndf_aniso(a, h_local);
        float G1 = smith_shadowing_g1_aniso(a, wi_local);
        weight = G1 * F;
        wi = reoriant(Z, n, wi_local);
#else
        vec3 h_local = sample_ggx_importance_aniso(vec2(rnd(), rnd()), a);
        vec3 wi_local = reflect(-wo_local, h_local);
        if(!same_hemi(wi_local, wo_local)) return false;
        float VoH = saturate(dot(wo_local, h_local));
        float NoH = saturate(h_local.z);
        float NoL = saturate(wi_local.z);
        float NoV = saturate(wo_local.z);
        vec3 F = mix(specular_reflectance, vec3(1.0), fresnel_schlick(VoH));
        float G2 = smith_shadowing_g1_aniso(a, wi_local) * smith_shadowing_g1_aniso(a, wo_local);
        if(NoH <= 0.0 || NoV <= 0.0) weight = vec3(0);
        else weight = G2 * F * VoH / (NoH * NoV);
        wi = reoriant(Z, n, wi_local);
#endif
    }else if(type == GGX_GLASS){
        vec3 base_color = pick_texture(glass_ggx_array[id].base_color_id);
        float roughness = glass_ggx_array[id].roughness;
        float roughness2 = roughness * roughness;
        float eta = glass_ggx_array[id].eta;
        float anisotropic = glass_ggx_array[id].anisotropic;
        float aspect = sqrt(1. - .9 * anisotropic);
        float ax = max(0.0001, roughness2 / aspect);
        float ay = max(0.0001, roughness2 * aspect);
        vec3 wo_local = reoriant(n, Z, wo); 
        // 普通采样ggx aniso 分布函数
        // vec3 h_local = sample_ggx_importance_aniso(vec2(rnd(), rnd()), vec2(ax, ay));
        // vndf采样 ggx aniso 分布函数
        vec3 h_local = sample_ggx_vndf(wo_local, ax, ay, rnd(), rnd());
        float VoH = abs(dot(wo_local, h_local));
        float NoH = saturate(h_local.z);
        float NoV = saturate(wo_local.z);
        float F = fresnel_schlick(VoH);
        if(rec.is_back_face) eta = 1.0 / eta;
        vec3 wi_local = refract(-wo_local, h_local, eta);
        if(F > rnd() || wi_local == vec3(0)){ // 
            wi_local = reflect(-wo_local, h_local);
            if(!same_hemi(wi_local, wo_local)) return false;
            /*
            float NoL = saturate(wi_local.z);
            float G2 = smith_shadowing_g1_aniso(vec2(ax, ay), wi_local) * smith_shadowing_g1_aniso(vec2(ax, ay), wo_local);
            if(NoH <= 0.0 || NoV <= 0.0) weight = vec3(0);
            else weight = G2 * base_color * VoH / (NoH * NoV);
            */
            float G1 = smith_shadowing_g1_aniso(vec2(ax, ay), wi_local);
            weight = G1 * base_color;
            wi = reoriant(Z, n, wi_local);
        }else{
            /*
            float G2 = smith_shadowing_g1_aniso(vec2(ax, ay), wi_local) * smith_shadowing_g1_aniso(vec2(ax, ay), wo_local);
            float LoH = dot(wi_local, -h_local);
            if(NoH <= 0.0 || NoV <= 0.0) weight = vec3(0);
            else weight = G2 * sqrt(base_color) * LoH / (NoH * NoV);
            */
            if(!same_hemi(wi_local, -wo_local)) return false;
            float G1 = smith_shadowing_g1_aniso(vec2(ax, ay), wi_local);
            weight = G1 * sqrt(base_color);
            wi = reoriant(Z, n, wi_local);
        }
    }else if(type == DISNEY_PRINCIPLED){
        // 依概率分别采样
        disney_principled m = disney_principled_array[id];
        vec3 base_color = pick_texture(m.baseColor_id);
        float roughness = m.roughness;
        float roughness2 = roughness * roughness;
        float subsurface = m.subsurface;
        float anisotropic = m.anisotropic;
        float sheenTint = m.sheenTint;
        float specular = m.specular;
        float specularTint = m.specularTint;
        float metallic = m.metallic;
        float aspect = sqrt(1. - .9 * anisotropic);
        float ax = max(0.0001, roughness2 / aspect);
        float ay = max(0.0001, roughness2 * aspect);
        float eta = rec.is_back_face ? 1.0 / m.eta : m.eta;
        float clearcoat = m.clearcoat;
        float clearCoatGloss = m.clearCoatGloss;
        float specular_transmission = m.specular_transmission;
        float ag = (1. - clearCoatGloss) * 0.1 + clearCoatGloss * 0.001;
        vec3 wo_local = reoriant(n, Z, wo);
        float lum = .3*base_color.x + .6*base_color.y  + .1*base_color.z;
        vec3 c_tint = base_color / (lum <= 0.0 ? 1. : lum);
        /*
            // diffuse sample
            wi = reoriant(Z, n, cosine_hemi(vec2(rnd(), rnd())));
            float NoL = dot(n, wi);
            float NoV = dot(n, wo);
            vec3 h = normalize(wi + wo);
            float LoH = dot(wi, h);
            float FL = fresnel_schlick(NoL), FV = fresnel_schlick(NoV);
            float Fd90 = 0.5 + 2. * LoH*LoH * roughness;
            float Fd = mix(1.0, Fd90, FL) * mix(1.0, Fd90, FV);
            float Fss90 = LoH*LoH*roughness;
            float Fss = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
            float ss = 1.25 * (Fss * (1. / (NoL + NoV) - .5) + .5);
            weight = base_color * mix(Fd, ss, subsurface);
        */
        /*
            // metal sample
            vec3 v_local = reoriant(n, Z, wo);
            vec3 h = reoriant(Z, n, sample_ggx_vndf(v_local, ax, ay, rnd(), rnd()));
            wi = reflect(-wo, h);
            vec3 h_local = reoriant(n, Z, h);
            vec3 l_local = reoriant(n, Z, wi);
            float VoH = dot(wo, h);
            vec3 F = mix(base_color, vec3(1.0), fresnel_schlick(VoH));
            float D = ggx_ndf_aniso(vec2(ax, ay), h_local);
            float G1 = smith_shadowing_g1_aniso(vec2(ax, ay), l_local);
            weight = G1 * F;
        */
        /*
            // clearcoat sample
            vec3 h_local = sample_disney_clearcoat(vec2(rnd(), rnd()), ag);
            vec3 wi_local = reflect(-wo_local, h_local);
            float VoH = saturate(dot(wo_local, h_local));
            float NoH = saturate(h_local.z);
            float NoV = saturate(wo_local.z);
            float NoL = saturate(wi_local.z);
            float Dr = GTR1(NoH, mix(.1,.001,clearCoatGloss));
            float Fr = mix(.04, 1.0, fresnel_schlick(VoH));
            float Gr = smith_shadowing_g1(.625, NoL) * smith_shadowing_g1(.625, NoV);
            if(NoV <= 0. || NoH <= 0.) weight = vec3(0);
            else weight = vec3(Fr * Gr * VoH / (NoH * NoV)); // Fr * Gr * VoH / (v_local.z * h_local.z)
            wi = reoriant(Z, n, wi_local);
        */
        /*
            if(rec.is_back_face) eta = 1.0 / eta;
             // glass
            vec3 h_local = sample_ggx_importance_aniso(vec2(rnd(), rnd()), vec2(ax, ay));
            float VoH = abs(dot(wo_local, h_local));
            float NoH = abs(h_local.z);
            float NoV = abs(wo_local.z);
            vec3 wi_refract = refract(-wo_local, h_local, eta);
            vec3 wi_reflect = reflect(-wo_local, h_local);
            float reflect_prob = fresnel(VoH, dot(wi_reflect, h_local), eta);

            if(reflect_prob > rnd() || wi_refract == vec3(0)){ //
                float G2 = smith_shadowing_g1_aniso(vec2(ax, ay), wi_reflect) * smith_shadowing_g1_aniso(vec2(ax, ay), wo_local);
                weight = G2 * base_color * VoH / max(NoH * NoV, 0.0001);
                wi = reoriant(Z, n, wi_reflect);
            }else{
                float G2 = smith_shadowing_g1_aniso(vec2(ax, ay), wi_refract) * smith_shadowing_g1_aniso(vec2(ax, ay), wo_local);
                float LoH = saturate(dot(wi_refract, -h_local));
                weight = G2 * sqrt(base_color) * LoH / max(NoH * NoV, 0.0001);
                wi = reoriant(Z, n, wi_refract);
            }
        */
        /*
            //sheen
            vec3 wi_local = cosine_hemi(vec2(rnd(), rnd()));
            vec3 h_local = normalize(wi_local + wo_local);
            float lum = .3*base_color.x + .6*base_color.y  + .1*base_color.z;
            vec3 c_tint = base_color / (lum <= 0.0 ? 1. : lum);
            vec3 c_sheen = (1. - sheenTint) + sheenTint * c_tint;
            weight = PI * c_sheen * fresnel_schlick(dot(wi_local, h_local));
            wi = reoriant(Z, n, wi_local);
        */
        
        float diffuseWeight = (1. - metallic) * (1. - specular_transmission);
        float metalWeight = (1. - specular_transmission * (1. - metallic));
        float glassWeight = (1. - metallic) * specular_transmission;
        float clearcoatWeight = 0.25 * clearcoat;
        float weight_sum = diffuseWeight + metalWeight + glassWeight + clearcoatWeight;
        diffuseWeight /= weight_sum;
        metalWeight /= weight_sum;
        glassWeight /= weight_sum;
        clearcoatWeight /= weight_sum;
        float r = rnd();
        if(r < diffuseWeight){
            vec3 wi_local = cosine_hemi(vec2(rnd(), rnd()));
            if(!same_hemi(wi_local, wo_local)) return false;
            vec3 h_local = normalize(wi_local + wo_local);
            float VoH = saturate(dot(wo_local, h_local));
            float NoL = saturate(wi_local.z);
            float NoV = saturate(wo_local.z);
            float FL = fresnel_schlick(NoL), FV = fresnel_schlick(NoV);
            float Fd90 = 0.5 + 2. * VoH * VoH * roughness;
            float Fd = mix(1.0, Fd90, FL) * mix(1.0, Fd90, FV);
            float Fss90 = VoH * VoH * roughness;
            float Fss = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
            float ss = 1.25 * (Fss * (1. / (NoL + NoV) - .5) + .5);
            if(rec.is_back_face) weight = vec3(0);
            else weight = base_color * mix(Fd, ss, subsurface);
            wi = reoriant(Z, n, wi_local);
        }else if(r >= diffuseWeight && r < diffuseWeight + metalWeight){
            vec3 h_local = sample_ggx_vndf(wo_local, ax, ay, rnd(), rnd());
            vec3 wi_local = reflect(-wo_local, h_local);
            if(!same_hemi(wi_local, wo_local)) return false;
            float VoH = dot(wo_local, h_local);
            vec3 Ks = (1. - specularTint) + specularTint * c_tint;
            vec3 C0 = specular * pow((eta - 1.) / (eta + 1.), 2.) * (1. - metallic) * Ks + metallic * base_color;
            vec3 F = mix(base_color, vec3(1.0), fresnel_schlick(VoH));
            float D = ggx_ndf_aniso(vec2(ax, ay), h_local);
            float G1 = smith_shadowing_g1_aniso(vec2(ax, ay), wi_local);
            if(rec.is_back_face) weight = vec3(0);
            else weight = G1 * F;
            wi = reoriant(Z, n, wi_local);
        }else if(r >= diffuseWeight + metalWeight && r < diffuseWeight + metalWeight + glassWeight){
             // glass
            vec3 h_local = sample_ggx_importance_aniso(vec2(rnd(), rnd()), vec2(ax, ay));
            float VoH = abs(dot(wo_local, h_local));
            float NoH = abs(h_local.z);
            float NoV = abs(wo_local.z);
            vec3 wi_refract = refract(-wo_local, h_local, eta);
            vec3 wi_reflect = reflect(-wo_local, h_local);
            float reflect_prob = fresnel(VoH, dot(wi_reflect, h_local), eta);

            if(reflect_prob > rnd() || wi_refract == vec3(0)){ //
                if(!same_hemi(wi_reflect, wo_local)) return false;
                float G2 = smith_shadowing_g1_aniso(vec2(ax, ay), wi_reflect) * smith_shadowing_g1_aniso(vec2(ax, ay), wo_local);
                weight = G2 * base_color * VoH / max(NoH * NoV, 0.0001);
                wi = reoriant(Z, n, wi_reflect);
            }else{
                if(!same_hemi(-wi_refract, wo_local)) return false;
                float G2 = smith_shadowing_g1_aniso(vec2(ax, ay), wi_refract) * smith_shadowing_g1_aniso(vec2(ax, ay), wo_local);
                float LoH = abs(dot(wi_refract, -h_local));
                weight = G2 * sqrt(base_color) * LoH / max(NoH * NoV, 0.0001);
                wi = reoriant(Z, n, wi_refract);
                //weight = vec3(h_local * 100.);
            }
        }else{
            vec3 h_local = sample_disney_clearcoat(vec2(rnd(), rnd()), ag);
            vec3 wi_local = reflect(-wo_local, h_local);
            if(!same_hemi(wi_local, wo_local)) return false;
            float VoH = abs(dot(wo_local, h_local));
            float NoH = abs(h_local.z);
            float NoV = abs(wo_local.z);
            float NoL = saturate(wi_local.z);
            float Dr = GTR1(NoH, mix(.1,.001,clearCoatGloss));
            float Fr = mix(.04, 1.0, fresnel_schlick(VoH));
            float Gr = smith_shadowing_g1(.625, NoL) * smith_shadowing_g1(.625, NoV);
            if(rec.is_back_face) weight = vec3(0);
            else weight = vec3(Fr * Gr * VoH / max(NoH * NoV, 0.0001)); // Fr * Gr * VoH / (v_local.z * h_local.z)
            wi = reoriant(Z, n, wi_local);
        }
    }
    return true;
}

vec3 trace(ray r, int max_depth){
    vec3 color = vec3(0);
    vec3 throughput = vec3(1);
    record rec;
    bool valid;
    int depth = 0;
    while(depth < max_depth){
        hit(r, rec, valid);
        if(!valid){
            color += throughput * background;
            break;
        }
        if(MAT_TYPE(rec.mat_id) == EMISSIVE){
            if(rec.is_back_face) break;
            int texture_id = emissive_array[MAT_ID(rec.mat_id)].emit_color_id;
            float strength = emissive_array[MAT_ID(rec.mat_id)].strength;
            color += throughput * pick_texture(texture_id) * strength;
            break;
        }
        vec3 wo = normalize(-r.B);
        vec3 wi, weight;
        if(sample_brdf(wi, weight, wo, rec)){
            throughput *= weight;
            r = ray(rec.pos, wi);
            depth ++;
        }else{
            break;
        }
    }
    return color;
}

