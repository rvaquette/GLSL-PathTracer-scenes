#define SKYTYPE 2 // 0: No sky, 1: Sky used in RIOW, 2: Physically-based Sky
#define USE_LENS
#define DISPERSION
//#define ANTI_REFLECTION_COATING
//#define FILM_GRAIN

//#define RUSSIAN_ROULETE

#define ZERO min(0, iFrame)

#define R iResolution

const float TAU    = 6.28318530717958647693,
            PI     = 3.14159265358979323846,
            INVPI  =  .31830988618379067154,
            INV4PI =  .07957747154594766788;

#define sqr(x) (x) * (x)
#define dot2(x) dot(x, x)

// parameters

const float flim_pre_exposure = 3.5;
const vec3 flim_pre_formation_filter = vec3(1.);
const float flim_pre_formation_filter_strength = 0.;

const float flim_extended_gamut_red_scale = 1.05;
const float flim_extended_gamut_green_scale = 1.12;
const float flim_extended_gamut_blue_scale = 1.045;
const float flim_extended_gamut_red_rot = .5;
const float flim_extended_gamut_green_rot = 2.;
const float flim_extended_gamut_blue_rot = .1;
const float flim_extended_gamut_red_mul = 1.;
const float flim_extended_gamut_green_mul = 1.;
const float flim_extended_gamut_blue_mul = 1.;

const float flim_sigmoid_log2_min = -10.;
const float flim_sigmoid_log2_max = 22.;
const float flim_sigmoid_toe_x = .44;
const float flim_sigmoid_toe_y = .28;
const float flim_sigmoid_shoulder_x = .591;
const float flim_sigmoid_shoulder_y = .779;

const float flim_negative_film_exposure = 6.;
const float flim_negative_film_density = 5.;

const vec3 flim_print_backlight = vec3(1);
const float flim_print_film_exposure = 6.;
const float flim_print_film_density = 27.5;

const float flim_black_point = -1.; // -1 = auto
const vec3 flim_post_formation_filter = vec3(1);
const float flim_post_formation_filter_strength = 0.;
const float flim_midtone_saturation = 1.02;

// flim's utility functions

float flim_rgb_avg(vec3 col)
{
    return (col.x + col.y + col.z) / 3.;
}

float flim_rgb_sum(vec3 col)
{
    return col.x + col.y + col.z;
}

float flim_rgb_max(vec3 col)
{
    return max(max(col.x, col.y), col.z);
}

float flim_rgb_min(vec3 col)
{
    return min(min(col.x, col.y), col.z);
}

float flim_remap(
    float v,
    float inp_start,
    float inp_end,
    float out_start,
    float out_end
)
{
    return out_start
        + ((out_end - out_start) / (inp_end - inp_start)) * (v - inp_start);
}

float flim_remap01(
    float v,
    float inp_start,
    float inp_end
)
{
    return clamp((v - inp_start) / (inp_end - inp_start), 0., 1.);
}

vec3 flim_blender_rgb_to_hsv(vec3 rgb)
{
    float cmax, cmin, h, s, v, cdelta;
    vec3 c;

    cmax = flim_rgb_max(rgb);
    cmin = flim_rgb_min(rgb);
    cdelta = cmax - cmin;

    v = cmax;
    s = cmax > 0. ? cdelta / cmax : 0.;

    if (s > 0.)
    {
        c = (cmax - rgb) / cdelta;
        
        h = rgb.x == cmax ? c.z - c.y :
            rgb.y == cmax ? c.x - c.z + 2. :
                            c.y - c.x + 4.;

        h /= 6.;

        if (h < 0.) h++;
    }
    
    else h = 0.;

    return vec3(h, s, v);
}

vec3 flim_blender_hsv_to_rgb(vec3 hsv)
{
    float f, p, q, t, h, s, v;
    vec3 rgb;

    h = hsv.x;
    s = hsv.y;
    v = hsv.z;

    if (s > 0.)
    {
        if (h == 1.) h = 0.;

        h *= 6.;
        int i = int(floor(h));
        f = h - float(i);
        p = v * (1. - s);
        q = v * (1. - s * f);
        t = v * (1. - s * (1. - f));

        rgb = i == 0 ? vec3(v, t, p) :
              i == 1 ? vec3(q, v, p) :
              i == 2 ? vec3(p, v, t) :
              i == 3 ? vec3(p, q, v) :
              i == 4 ? vec3(t, p, v) :
                       vec3(v, p, q);
    }
    else rgb = vec3(v);

    return rgb;
}

vec3 flim_blender_hue_sat(vec3 col, float hue, float sat, float value)
{
    vec3 hsv = flim_blender_rgb_to_hsv(col);

    hsv.x = fract(hsv.x + hue + .5);
    hsv.y = clamp(hsv.y * sat, 0., 1.);
    hsv.z *= value;

    return flim_blender_hsv_to_rgb(hsv);
}

vec3 flim_rgb_uniform_offset(vec3 col, float black_point, float white_point)
{
    float mono = flim_rgb_avg(col);
    float mono2 = flim_remap01(
        mono, .001 * black_point,
        1. - .001 * white_point
    );
    return col * mono2 / mono;
}

// https://www.desmos.com/calculator/khkztixyeu
float flim_super_sigmoid(
    float v,
    float toe_x,
    float toe_y,
    float shoulder_x,
    float shoulder_y
)
{
    // clip
    v = clamp(v, 0., 1.);
    toe_x = clamp(toe_x, 0., 1.);
    toe_y = clamp(toe_y, 0., 1.);
    shoulder_x = clamp(shoulder_x, 0., 1.);
    shoulder_y = clamp(shoulder_y, 0., 1.);

    // calculate straight line slope
    float slope = (shoulder_y - toe_y) / (shoulder_x - toe_x);

    // toe
    if (v < toe_x) return toe_y * pow(v / toe_x, slope * toe_x / toe_y);

    // straight line
    if (v < shoulder_x) return slope * (v - toe_x) + toe_y;

    // shoulder
    float shoulder_pow = slope * (1. - shoulder_x) / (1. - shoulder_y);
    return
        (1. - pow((1. - v) / (1. - shoulder_x), shoulder_pow))
        * (1. - shoulder_y)
        + shoulder_y;
}

float flim_dye_mix_factor(float mono, float max_density)
{
    // log2 and map range
    float offset = exp2(flim_sigmoid_log2_min);
    float fac = flim_remap01(
        log2(mono + offset),
        flim_sigmoid_log2_min,
        flim_sigmoid_log2_max
    );

    // calculate amount of exposure from 0 to 1
    fac = flim_super_sigmoid(
        fac,
        flim_sigmoid_toe_x,
        flim_sigmoid_toe_y,
        flim_sigmoid_shoulder_x,
        flim_sigmoid_shoulder_y
    );

    // calculate dye density + mix factor
    return exp2(-fac * max_density);
}

vec3 flim_rgb_develop(vec3 col, float exposure, float max_density)
{
    // exposure
    col *= exp2(exposure);
    
    // red, green, and blue-sensitive layer
    return vec3(flim_dye_mix_factor(col.x, max_density),
                flim_dye_mix_factor(col.y, max_density),
                flim_dye_mix_factor(col.z, max_density));
}

vec3 flim_gamut_extension_mat_row(
    float primary_hue,
    float scale,
    float rotate,
    float mul
)
{
    vec3 result = flim_blender_hsv_to_rgb(vec3(
        fract(primary_hue + (rotate / 360.)),
        1. / scale,
        1.
    ));
    result /= flim_rgb_sum(result);
    result *= mul;
    return result;
}

mat3 flim_gamut_extension_mat(
    float red_scale,
    float green_scale,
    float blue_scale,
    float red_rot,
    float green_rot,
    float blue_rot,
    float red_mul,
    float green_mul,
    float blue_mul
)
{
    mat3 m;
    m[0] = flim_gamut_extension_mat_row(
        0.,
        red_scale,
        red_rot,
        red_mul
    );
    m[1] = flim_gamut_extension_mat_row(
        1. / 3.,
        green_scale,
        green_rot,
        green_mul
    );
    m[2] = flim_gamut_extension_mat_row(
        2. / 3.,
        blue_scale,
        blue_rot,
        blue_mul
    );
    return m;
}

vec3 negative_and_print(vec3 col, vec3 backlight_ext)
{
    // develop negative
    col = flim_rgb_develop(
        col,
        flim_negative_film_exposure,
        flim_negative_film_density
    );

    // backlight
    col *= backlight_ext;

    // develop print
    col = flim_rgb_develop(
        col,
        flim_print_film_exposure,
        flim_print_film_density
    );

    return col;
}

// the flim transform

vec3 flimTransform(vec3 col)
{
    // eliminate negative values
    col = max(col, 0.);

    // pre-Exposure
    col *= exp2(flim_pre_exposure);

    // clip very large values for float precision issues
    col = min(col, 5000.);

    // gamut extension matrix (Linear BT.709)
    mat3 extend_mat = flim_gamut_extension_mat(
        flim_extended_gamut_red_scale,
        flim_extended_gamut_green_scale,
        flim_extended_gamut_blue_scale,
        flim_extended_gamut_red_rot,
        flim_extended_gamut_green_rot,
        flim_extended_gamut_blue_rot,
        flim_extended_gamut_red_mul,
        flim_extended_gamut_green_mul,
        flim_extended_gamut_blue_mul
    );
    mat3 extend_mat_inv = inverse(extend_mat);

    // backlight in the extended gamut
    vec3 backlight_ext = flim_print_backlight * extend_mat;

    // upper limit in the print (highlight cap)
    vec3 white_cap = negative_and_print(vec3(1e7), backlight_ext);

    // pre-formation filter
    col = mix(
        col,
        col * flim_pre_formation_filter,
        flim_pre_formation_filter_strength
    );

    // convert to the extended gamut
    col *= extend_mat;

    // negative & print
    col = negative_and_print(col, backlight_ext);

    // convert from the extended gamut
    col *= extend_mat_inv;

    // eliminate negative values
    col = max(col, 0.);

    // white cap
    col /= white_cap;

    // black cap (-1 = auto)
    if (flim_black_point == -1.)
    {
        vec3 black_cap = negative_and_print(vec3(0.), backlight_ext);
        black_cap /= white_cap;
        col = flim_rgb_uniform_offset(
            col,
            flim_rgb_avg(black_cap) * 1e3,
            0.
        );
    }
    else
    {
        col = flim_rgb_uniform_offset(col, flim_black_point, 0.);
    }

    // post-formation filter
    col = mix(
        col,
        col * flim_post_formation_filter,
        flim_post_formation_filter_strength
    );

    // clip
    col = clamp(col, 0., 1.);

    // midtone saturation
    float mono = flim_rgb_avg(col);
    float mix_fac =
        (mono < .5)
        ? flim_remap01(mono, .05, .5)
        : flim_remap01(mono, .95, .5);
    col = mix(
        col,
        flim_blender_hue_sat(col, .5, flim_midtone_saturation, 1.),
        mix_fac
    );

    return col;
}

#define translate(p) mat4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, p, 1)

mat2 rot(float a){
    float c = cos(a);
    float s = sin(a);
	return mat2(c, -s, s, c);
}

mat4 rotateX(float a)
{
    float s = sin(a), c = cos(a);

    return mat4(1, 0,  0, 0,
                0, c, -s, 0,
                0, s,  c, 0,
			    0, 0,  0, 1);
}

mat4 rotateY(float a)
{
    float s = sin(a), c = cos(a);

    return mat4( c, 0, s, 0,
                 0, 1, 0, 0,
                -s, 0, c, 0,
			     0, 0, 0, 1);
}

mat4 rotateZ(float a)
{
    float s = sin(a), c = cos(a);

    return mat4(c, -s, 0, 0,
                s,  c, 0, 0,
                0,  0, 1, 0,
			    0,  0, 0, 1);
}

const mat4 noTransform = mat4(1);

float deNaN (float v)
{
    return v != v ? 0. : v;
}

vec3 deNaN(vec3 v)
{
    return vec3(deNaN(v.x), deNaN(v.y), deNaN(v.z));
}

struct ray
{
    vec3 o, d;
};

struct material
{
    vec3 baseColor, emission;
    
    float anisotropic,
          metallic,
          roughness,
          subsurface,
          specularTint,
          sheen,
          sheenTint,
          clearcoat,
          clearcoatRoughness,
          specTrans,
          IOR, ax, ay;
};

const material initMat = material(vec3(0), vec3(0), 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 1., 0., 0.);

struct hitRecord
{
    float eta, t;
    vec3 p, n;
    material mat;
    bool isVolume;
};

struct cam
{
    vec3 o, llc, hor, ver, u, v, w;
    float rad;
};

uvec4 seed;

vec4 PCG(inout uvec4 v)
{
    v = v * 1664525u + 1013904223u;
    
    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;
    
    v ^= v >> 16u;
    
    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;
    
    return vec4(v) / 4294967296.;
}

#define rand  rand4.x
#define rand2 rand4.xy
#define rand3 rand4.xyz
#define rand4 PCG(seed)


vec4 hash4(vec4 p)
{
	uvec4 v = floatBitsToUint(p);
    return PCG(v);
}

vec4 hash4(float v) {return hash4(vec4(v));}
vec4 hash4(vec2 v)  {return hash4(v.xyxy);}
vec4 hash4(vec3 v)  {return hash4(v.xyzx);}

#define hash(v)  hash4(v).x
#define hash2(v) hash4(v).xy
#define hash3(v) hash4(v).xyz

// Samples the radix-2 Halton sequence from seed value, i
float halton(uint i)
{    
    i = ((i & 0xffffu) << 16u) | (i >> 16u);
    i = ((i & 0x00ff00ffu) << 8u) | ((i & 0xff00ff00u) >> 8u);
    i = ((i & 0x0f0f0f0fu) << 4u) | ((i & 0xf0f0f0f0u) >> 4u);
    i = ((i & 0x33333333u) << 2u) | ((i & 0xccccccccu) >> 2u);
    i = ((i & 0x55555555u) << 1u) | ((i & 0xaaaaaaaau) >> 1u);
    
    return float(i) / 4294967296.;
}

#define toWorld(x, y, z, v) mat3(x, y, z) * (v)
#define toLocal(x, y, z, v) (v) * mat3(x, y, z)

vec2 ranDir()
{
    float phi = TAU * rand;
    return vec2(cos(phi), sin(phi));
}

float gaussian()
{
    return sqrt(-2. * log(rand)) * cos(TAU * rand);
}

vec2 gaussian2D()
{
    return sqrt(-2. * log(rand)) * ranDir();
}

#define ranDisk() sqrt(rand) * ranDir()

// Sampling Functions

float GTR1(float NoH, float a)
{
    if (a >= 1.) return INVPI;
    float a2 = a * a;
    return (a2 - 1.) / (PI * log(a2) * (1. + (a2 - 1.) * NoH * NoH));
}

vec3 sampleGTR1(float a)
{
    float a2 = a * a;

    float cos2T = (1. - pow(a2, rand)) / (1. - a2);

    return vec3(sqrt(1. - cos2T) * ranDir(), sqrt(cos2T));
}

vec3 sampleGGXVNDF(vec3 V, float ax, float ay)
{
    V = normalize(vec3(ax * V.x, ay * V.y, V.z));
    
    vec2 t   = ranDisk();
         t.y = mix(sqrt(1. - t.x * t.x), t.y, .5 + .5 * V.z);
    
    float l2 = dot2(V.xy);
    
    vec3 T1 = l2 > 0. ? vec3(-V.y, V.x, 0) * inversesqrt(l2) : vec3(1, 0, 0),
         T2 = cross(V, T1),
         N  = mat3(T1, T2, V) * vec3(t, sqrt(1. - dot2(t)));

    return normalize(vec3(ax * N.x, ay * N.y, max(0., N.z)));
}

float GTR2Aniso(float NoH, float HoX, float HoY, float ax, float ay)
{
    if(ax * ay == 0.) return 1.;
    return INVPI / (ax * ay * sqr(dot2(vec3(HoX / ax, HoY / ay, NoH))));
}

float smithG(float NoV, float alphaG)
{
    float a = alphaG * alphaG,
          b = NoV * NoV;
    
    return 2. * NoV / (NoV + sqrt(a + b - a * b));
}

float smithGAniso(float NoV, float VoX, float VoY, float ax, float ay)
{
    if(ax * ay == 0.) return 1.;
    
    float a = VoX * ax,
          b = VoY * ay,
          c = NoV;
    
    return 2. * NoV / (NoV + sqrt(a * a + b * b + c * c));
}

float schlickWeight(float u)
{
    float m = min(1. - u, 1.),
          m2 = m * m;
    
    return m2 * m2 * m;
}

float dielectricFresnel(float cosI, float eta)
{
    float sin2T = eta * eta * (1. - cosI * cosI);

    // Total internal reflection
    
    if (sin2T > 1.) return 1.;

    float cosT = sqrt(1. - sin2T);

    float rs = (eta * cosT - cosI) / (eta * cosT + cosI),
          rp = (eta * cosI - cosT) / (eta * cosI + cosT);

    return .5 * (rs * rs + rp * rp);
}

float ARC(float r1, float r2, float beta)
{
    beta *= 2.;
    
    float r12 = r1 * r1,
          r22 = r2 * r2;
    
    return (r12 + r22 + 2. * r1 * r2 * cos(beta)) / (1. + r12 * r22 + 2. * r1 * r2 * cos(beta));
}

// lambda   - Wavelength of light being tested for reflectance
// d        - Thickness of the anti-reflectance coating (lambda0 / 4.0f / n1) where
//              lambda0 is the wavelenght of light the coating was designed for, typically
//              a midrange wavelenght like green (550 nm)
// theta1   - Angle of incidence at the edge of the coating
// n1       - The Index of Refraction for the incoming material
// n2       - The Index of Refraction for the coating, max(sqrt(n1 * n2), 1.38) where 1.38
//              is the index of refraction for a common magnesium floride coating.
// n3       - The Index of Refraction for the outgoing material

float Reflectance(float lambda, float d, float theta1, float n1, float n2, float n3)
{
    // Apply Snell's law to get the other angles
    float theta2 = asin(n1 * sin(theta1) / n2);
    float theta3 = asin(n1 * sin(theta1) / n3);
 
    float cos1 = cos(theta1);
    float cos2 = cos(theta2);
    float cos3 = cos(theta3);
 
    float beta = TAU / lambda * n2 * d * cos2;
 
    // Compute the fresnel terms for the first and second interfaces for both s and p polarized
    // light
    
    float rp = ARC((n2 * cos1 - n1 * cos2) / (n2 * cos1 + n1 * cos2),
                   (n3 * cos2 - n2 * cos3) / (n3 * cos2 + n2 * cos3), beta);
 
    float rs = ARC((n1 * cos1 - n2 * cos2) / (n1 * cos1 + n2 * cos2),
                   (n2 * cos2 - n3 * cos3) / (n2 * cos2 + n3 * cos3), beta);
 
    return (rs + rp) * .5;
}

vec3 ranCos()
{
    float r = rand;
    return vec3(sqrt(r) * ranDir(), sqrt(1. - r));
}

vec3 ranSph()
{
    float h = rand * 2. - 1.;
	return vec3(sqrt(1. - h * h) * ranDir(), h);
}

vec3 ranHemi(vec3 n)
{
    vec3 d = ranSph();
    return d * sign(dot(d, n));
}

void onb(vec3 N, out vec3 T, out vec3 B) 
{
    float s = N.z > 0. ? 1. : -1.,
          a = s + N.z,
          b = -N.x * N.y / a;
    
    T = s * vec3(s - N.x * N.x / a, b, -N.x);
    B =     vec3(b, s - N.y * N.y / a, -N.y);
}

// Disney BSDF

#define luma(v) dot(v, vec3(.3, .6, .1))

void tint(material mat, float eta, out float F0, out vec3 Csheen, out vec3 Cspec)
{
    float lum = luma(mat.baseColor);
    vec3 tint = lum > 0. ? mat.baseColor / lum : vec3(1);

    F0 = sqr((1. - eta) / (1. + eta));
    
    Cspec  = mix(vec3(1), tint, mat.specularTint) * F0;
    Csheen = mix(vec3(1), tint, mat.sheenTint);
}

vec3 diffuse(material mat, vec3 Csheen, vec3 V, vec3 L, vec3 H, out float pdf)
{
    float LoH = dot(L, H),
          Rr  = 2. * mat.roughness * LoH * LoH,

    // Diffuse
    
    FL     = schlickWeight(L.z),
    FV     = schlickWeight(V.z),
    Fretro = Rr * (FL + FV + FL * FV * (Rr - 1.)),
    Fd     = (1. - .5 * FL) * (1. - .5 * FV),

    // Fake subsurface
    
    Fss90 = .5 * Rr,
    Fss   = mix(1., Fss90, FL) * mix(1., Fss90, FV),
    ss    = 1.25 * (Fss * (1. / (L.z + V.z) - .5) + .5);

    // Sheen
    
    vec3 Fsheen = schlickWeight(LoH) * mat.sheen * Csheen;

    pdf = L.z * INVPI;
    
    return INVPI * mat.baseColor * mix(Fd + Fretro, ss, mat.subsurface) + Fsheen;
}

vec3 reflection(material mat, vec3 V, vec3 L, vec3 H, vec3 F, out float pdf)
{
    float D  = GTR2Aniso(H.z, H.x, H.y, mat.ax, mat.ay),
          G1 = smithGAniso(abs(V.z), V.x, V.y, mat.ax, mat.ay),
          G2 = smithGAniso(abs(L.z), L.x, L.y, mat.ax, mat.ay) * G1;

    pdf = .25 * G1 * D / V.z;
    
    return F * D * G2 / (4. * L.z * V.z);
}

vec3 refraction(material mat, float eta, vec3 V, vec3 L, vec3 H, vec3 F, out float pdf)
{
    float LoH = dot(L, H), VoH = dot(V, H),

    D  = GTR2Aniso(H.z, H.x, H.y, mat.ax, mat.ay),
    G1 = smithGAniso(abs(V.z), V.x, V.y, mat.ax, mat.ay),
    G2 = smithGAniso(abs(L.z), L.x, L.y, mat.ax, mat.ay) * G1;
    
    float jacobian = abs(LoH) / sqr(LoH + VoH * eta);

    pdf = G1 * max(0., VoH) * D * jacobian / V.z;
    
    return sqrt(mat.baseColor) * (1. - F) * D * G2 * abs(VoH) * jacobian * eta * eta / abs(L.z * V.z);
}

float clearcoat(material mat, vec3 V, vec3 L, vec3 H, out float pdf)
{
    float VoH = dot(V, H),

    F = mix(.04, 1., schlickWeight(VoH)),
    D = GTR1(H.z, mat.clearcoatRoughness),
    G = smithG(L.z, .25) * smithG(V.z, .25);

    pdf = .25 * D * H.z / VoH;
    
    return F * D * G;
}

vec3 DisneyBSDF(hitRecord rec, vec3 V, vec3 N, vec3 L, out float pdf)
{
    if(rec.isVolume)
    {
        pdf = INV4PI;
        return rec.mat.baseColor * INV4PI;
    }
    
    float aspect = sqrt(1. - rec.mat.anisotropic * .9);
    rec.mat.ax = rec.mat.roughness / aspect;
    rec.mat.ay = rec.mat.roughness * aspect;
    
    pdf = 0.;
    vec3 f = vec3(0);

    vec3 T, B;
    onb(N, T, B);

    V = toLocal(T, B, N, V);
    L = toLocal(T, B, N, L);

    vec3 H = normalize(L.z > 0. ? L + V : L + V * rec.eta);

    if (H.z < 0.) H = -H;

    // Tint colors
    
    vec3 Csheen, Cspec;
    float F0;
    tint(rec.mat, rec.eta, F0, Csheen, Cspec);

    // Model weights
    
    float dielectricW = (1. - rec.mat.metallic) * (1. - rec.mat.specTrans);
    float metalW      = rec.mat.metallic;
    float glassW      = (1. - rec.mat.metallic) * rec.mat.specTrans;

    // Lobe probabilities
    
    float schlickW = schlickWeight(V.z);

    float diffP       = dielectricW * luma(rec.mat.baseColor);
    float dielectricP = dielectricW * mix(luma(Cspec), 1., schlickW);
    float metalP      = metalW * mix(luma(rec.mat.baseColor), 1., schlickW);
    float glassP      = glassW;
    float clearCoatP  = .25 * rec.mat.clearcoat;

    // Normalize probabilities
    
    float norm = 1. / (diffP + dielectricP + metalP + glassP + clearCoatP);
    
    diffP       *= norm;
    dielectricP *= norm;
    metalP      *= norm;
    glassP      *= norm;
    clearCoatP  *= norm;

    bool reflect = L.z > 0.;

    float tmpPdf = 0.;
    float VoH = abs(dot(V, H));

    // Diffuse
    if (diffP > 0. && reflect)
    {
        f += diffuse(rec.mat, Csheen, V, L, H, tmpPdf) * dielectricW;
        pdf += tmpPdf * diffP;
    }

    // Dielectric Reflection
    if (dielectricP > 0. && reflect)
    {
        float F = (dielectricFresnel(VoH, 1. / rec.eta) - F0) / (1. - F0);

        f += reflection(rec.mat, V, L, H, mix(Cspec, vec3(1), F), tmpPdf) * dielectricW;
        pdf += tmpPdf * dielectricP;
    }

    // Metallic Reflection
    if (metalP > 0.0 && reflect)
    {
        // Tinted to base color
        vec3 F = mix(rec.mat.baseColor, vec3(1), schlickWeight(VoH));

        f += reflection(rec.mat, V, L, H, F, tmpPdf) * metalW;
        pdf += tmpPdf * metalP;
    }

    // Glass/Specular BSDF
    if (glassP > 0.0)
    {
        // Dielectric fresnel (achromatic)
        float F = dielectricFresnel(VoH, rec.eta);

        if (reflect)
        {
            f += reflection(rec.mat, V, L, H, vec3(F), tmpPdf) * glassW;
            pdf += tmpPdf * glassP * F;
        }
        else
        {
            f += refraction(rec.mat, rec.eta, V, L, H, vec3(F), tmpPdf) * glassW;
            pdf += tmpPdf * glassP * (1. - F);
        }
    }

    // Clearcoat
    if (clearCoatP > 0. && reflect)
    {
        f += clearcoat(rec.mat, V, L, H, tmpPdf) * .25 * rec.mat.clearcoat;
        pdf += tmpPdf * clearCoatP;
    }

    return f * abs(L.z);
}

vec3 DisneySample(hitRecord rec, vec3 V, out vec3 L, out float pdf)
{
    if(rec.isVolume)
    {
        L = ranSph();
        pdf = INV4PI;
        return rec.mat.baseColor * INV4PI;
    }
    
    float aspect = sqrt(1. - rec.mat.anisotropic * .9);
    rec.mat.ax = rec.mat.roughness / aspect;
    rec.mat.ay = rec.mat.roughness * aspect;
    
    pdf = 0.;

    vec3 N = rec.n, T, B;
    onb(N, T, B);

    V = toLocal(T, B, N, V);

    // Tint colors
    vec3 Csheen, Cspec;
    float F0;
    tint(rec.mat, rec.eta, F0, Csheen, Cspec);

    // Model weights
    float dielectricW = (1. - rec.mat.metallic) * (1. - rec.mat.specTrans);
    float metalW      = rec.mat.metallic;
    float glassW      = (1. - rec.mat.metallic) * rec.mat.specTrans;

    // Lobe probabilities
    float schlick = schlickWeight(V.z);

    float diffP       = dielectricW * luma(rec.mat.baseColor);
    float dielectricP = dielectricW * mix(luma(Cspec), 1., schlick);
    float metalP      = metalW * mix(luma(rec.mat.baseColor), 1., schlick);
    float glassP      = glassW;
    float clearCoatP  = .25 * rec.mat.clearcoat;

    // Normalize probabilities
    float norm = 1. / (diffP + dielectricP + metalP + glassP + clearCoatP);
    diffP *= norm;
    dielectricP *= norm;
    metalP *= norm;
    glassP *= norm;
    clearCoatP *= norm;

    // CDF of the sampling probabilities
    vec3 cdf;
    cdf.x = diffP;
    cdf.y = cdf.x + dielectricP + metalP;
    cdf.z = cdf.y + glassP;

    // Sample a lobe based on its importance
    float r = rand;
    
    if (r < cdf.x) // Diffuse
    {
        L = ranCos();
    }
    else if (r < cdf.y) // Dielectric + Metallic reflection
    {
        vec3 H = sampleGGXVNDF(V, rec.mat.ax, rec.mat.ay);
        L = reflect(-V, H);
    }
    else if (r < cdf.z) // Glass
    {
        vec3 H = sampleGGXVNDF(V, rec.mat.ax, rec.mat.ay);
        
        float F = dielectricFresnel(abs(dot(V, H)), rec.eta);
        
        L = rand < F ? reflect(-V, H) : refract(-V, H, rec.eta);
    }
    else // Clearcoat
    {
        vec3 H = sampleGTR1(rec.mat.clearcoatRoughness);

        L = reflect(-V, H);
    }

    L = toWorld(T, B, N, L);
    V = toWorld(T, B, N, V);

    return DisneyBSDF(rec, V, N, L, pdf);
}

float noise(vec3 x)
{
    vec3 p = floor(x), f = smoothstep(0., 1., fract(x));
	
    return mix(mix(mix(hash(p                ), 
                       hash(p + vec3(1, 0, 0)), f.x),
                   mix(hash(p + vec3(0, 1, 0)), 
                       hash(p + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash(p + vec3(0, 0, 1)), 
                       hash(p + vec3(1, 0, 1)), f.x),
                   mix(hash(p + vec3(0, 1, 1)), 
                       hash(p +            1.), f.x), f.y), f.z);
}

float fbm(vec3 p, int o)
{
    float a = 0., w = 1.;
     
    for (int i = 0; i < o; i++)
    {
        w *= .5;
        a += w * noise(p);
        p *= 2.;
    }
    return a;
}

