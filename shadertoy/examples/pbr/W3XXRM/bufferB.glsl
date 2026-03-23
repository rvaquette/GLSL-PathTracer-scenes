// Copyright © 2019-2023 HK-SHAO
// MIT Licensed: https://shao.fun/blog/w/taichi-ray-tracing.html

#define load(P) texelFetch(iChannel1, ivec2(P), 0)

// 摄像机参数
const float camera_vfov       = 30.0;                 // 摄像机的纵向视野
const float camera_focus      = 2.0;                  // 摄像机的对焦距离
const float camera_aperture   = 0.002;                // 摄像机的光圈大小
const float camera_exposure   = 0.6;                  // 摄像机曝光值
const float light_quality     = 128.0;                // 间接光质量
const float gamma             = 2.2;                  // 伽马矫正值

// 配置常量
const float TMIN         = 0.005;                     // 光开始传播的起始偏移，避免光线自相交
const float TMAX         = 2000.0;                    // 最大单次光线传播距离 (相当于可见范围)
const float PRECISION    = 0.0005;                    // 需小于 TMIN，否则光线无法正常离开物体表面
const float VISIBILITY   = pow(1.0 / 256.0, gamma);   // 亮度可见度

const uint  MAX_RAYMARCH = 512U;                      // 最大光线步进次数
const uint  MAX_RAYTRACE = 128U;                      // 最大光线追踪次数

const float ENV_IOR      = 1.000277;                  // 环境的折射率 （空气）

// 枚举形状
const int SHAPE_SPHERE   = 0;
const int SHAPE_BOX      = 1;
const int SHAPE_CYLINDER = 2;

// 物体材质
struct material {
    vec3  albedo;       // 反照率
    vec3  emission;     // 自发光
    vec3  normal;       // 切线空间法线
    float roughness;    // 粗糙度
    float metallic;     // 金属度
    float transmission; // 透明度
    float ior;          // 折射率
};

// 物体变换
struct transform {
    vec3 position;      // 位置
    vec3 rotation;      // 旋转
    vec3 scale;         // 缩放
};

// SDF 物体
struct object {
    int       shape;    // 形状
    float     dis;      // 距离物体表面
    transform trs;      // 变换
    material  mtl;      // 材质
};

// 光线
struct ray {
    vec3 origin;        // 光的起点
    vec3 direction;     // 光的方向
    vec3 color;         // 光的颜色
};

// 光子击中的记录
struct record {
    object obj;         // 物体
    vec3   pos;         // 击中的位置
    vec3   normal;      // 世界空间法线
    bool   hit;         // 是否击中
};

// 摄像机
struct camera {
    vec3  lookfrom;     // 视点位置
    vec3  lookat;       // 目标位置
    vec3  vup;          // 向上的方向
    float vfov;         // 视野
    float aspect;       // 传感器长宽比
    float aperture;     // 光圈大小
    float focus;        // 对焦距离
};

// SDF 球体
float sd_sphere(vec3 p, float s) {
    return length(p) - s;
}

// SDF 盒子
float sd_box(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - 0.02;
}

// SDF 圆柱
float sd_cylinder(vec3 p, vec2 rh) {
    vec2 d = abs(vec2(length(p.xz),p.y)) - rh;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// 地图列表
const object[] map = object[] (
    object(SHAPE_SPHERE, ZERO,
        transform(  vec3(0, -100.501, 0),
                    vec3(0, 0, 0),
                    vec3(100, 100, 100)
        ),
        material(   vec3(1.0, 1.0, 1.0)*0.6, // 基础色
                    vec3(1), // 自发光
                    vec3(0, 0, 1), // 切线空间法线
                    0.9, // 粗糙度
                    0.1, // 金属度
                    0.0, // 透明度
                    1.635  // 折射率 （沥青）
        )
    ),
    object(SHAPE_SPHERE, ZERO,
        transform(  vec3(0, 0, 0),
                    vec3(0, 0, 0),
                    vec3(0.5, 0.5, 0.5)
        ),
        material(   vec3(1.0, 1.0, 1.0), // 基础色
                    vec3(0.1, 1.0, 0.1)*10.0, // 自发光
                    vec3(0, 0, 1), // 切线空间法线
                    0.0, // 粗糙度
                    1.0, // 金属度
                    0.0, // 透明度
                    1.000  // 折射率 （真空）
        )
    ),
    object(SHAPE_CYLINDER, ZERO,
        transform(  vec3(-1.0, -0.2, 0),
                    vec3(0, 0, 0),
                    vec3(0.3, 0.3, 0.3)
        ),
        material(   vec3(1.0, 0.2, 0.2), // 基础色
                    vec3(1), // 自发光
                    vec3(0, 0, 1), // 切线空间法线
                    0.1, // 粗糙度
                    0.0, // 金属度
                    0.0, // 透明度
                    1.460  // 折射率 （塑料）
        )
    ),
    object(SHAPE_SPHERE, ZERO,
        transform(  vec3(1.0, -0.2, 0),
                    vec3(0, 0, 0),
                    vec3(0.3, 0.3, 0.3)
        ),
        material(   vec3(0.2, 0.2, 1.0), // 基础色
                    vec3(1), // 自发光
                    vec3(0, 0, 1), // 切线空间法线
                    0.2, // 粗糙度
                    1.0, // 金属度
                    0.0, // 透明度
                    1.100  // 折射率 （铜）
        )
    ),
    object(SHAPE_SPHERE, ZERO,
        transform(  vec3(0.0, -0.2, 2),
                    vec3(0, 0, 0),
                    vec3(0.3, 0.3, 0.3)
        ),
        material(   vec3(1.0, 1.0, 1.0)*0.9, // 基础色
                    vec3(1), // 自发光
                    vec3(0, 0, 1), // 切线空间法线
                    0.0, // 粗糙度
                    0.0, // 金属度
                    1.0, // 透明度
                    1.500  // 折射率 （玻璃）
        )
    ),
    object(SHAPE_BOX, ZERO,
        transform(  vec3(0, 0, 5),
                    vec3(0, 0, 0),
                    vec3(2, 1, 0.2)
        ),
        material(   vec3(1.0, 1.0, 0.2)*0.9, // 基础色
                    vec3(1), // 自发光
                    vec3(0, 0, 1), // 切线空间法线
                    0.0, // 粗糙度
                    1.0, // 金属度
                    0.0, // 透明度
                    0.470  // 折射率 （金）
        )
    ),
    object(SHAPE_BOX, ZERO,
        transform(  vec3(0, 0, -1),
                    vec3(0, 0, 0),
                    vec3(2, 1, 0.2)
        ),
        material(vec3(1.0, 1.0, 1.0)*0.9, // 基础色
                    vec3(1), // 自发光
                    vec3(0, 0, 1), // 切线空间法线
                    0.0, // 粗糙度
                    1.0, // 金属度
                    0.0, // 透明度
                    2.950  // 折射率 （铁）
        )
    )
);

float seed; // 随机数种子

// 用随机数种子产生归一化的随机数
float rand13(vec3 x) {
    uvec3 p = floatBitsToUint(x);
    p = 1103515245U * ((p.xyz >> 1U) ^ (p.yzx));
    uint h32 = 1103515245U * ((p.x ^ p.z) ^ (p.y >> 3U));
    uint n = h32 ^ (h32 >> 16U);
    return float(n) * (1.0 / float(0xffffffffU));
}

float rand11() {
    uvec2 n = floatBitsToUint(seed++) * uvec2(1597334673U, 3812015801U);
    uint q = (n.x ^ n.y) * 1597334673U;
    return float(q) * (1.0 / float(0xffffffffU));
}

vec2  rand21() {
    uvec2 n = floatBitsToUint(seed++) * uvec2(1597334673U, 3812015801U);
    n = (n.x ^ n.y) * uvec2(1597334673U, 3812015801U);
    return vec2(n) * (1.0 / float(0xffffffffU));
}

// 光子在射线所在的位置
vec3 at(ray r, float t) {
    return r.origin + t * r.direction;
}

// 单位圆内随机取一点
vec2 random_in_unit_disk() {
    vec2 r = rand21() * vec2(1.0, TAU);
    return sqrt(r.x) * vec2(sin(r.y), cos(r.y));
}

// 从摄像机获取光线
ray get_ray(camera c, vec2 uv, vec3 color) {
    // 根据 VFOV 和显示画布长宽比计算传感器长宽
    float theta = radians(c.vfov);
    float half_height = tan(theta * 0.5);
    float half_width = c.aspect * half_height;
    
    // 以目标位置到摄像机位置为 Z 轴正方向
    vec3 z = normalize(c.lookfrom - c.lookat);
    // 计算出摄像机传感器的 XY 轴正方向
    vec3 x = normalize(cross(c.vup, z));
    vec3 y = cross(z, x);
    
    vec3 hwfx = half_width  * c.focus * x;
    vec3 hhfy = half_height * c.focus * y;
    
    vec3 lower_left_corner = c.lookfrom - hwfx - hhfy - c.focus * z;
    
    vec3 horizontal = 2.0 * hwfx;
    vec3 vertical   = 2.0 * hhfy;
    
    // 模拟光进入镜头光圈
    float lens_radius = c.aperture * 0.5;
    vec2 rud = lens_radius * random_in_unit_disk();
    vec3 offset = x * rud.x + y * rud.y;
    
    // 计算光线起点和方向
    vec3 ro = c.lookfrom + offset;
    vec3 po = lower_left_corner + uv.x * horizontal
                                + uv.y * vertical;
    vec3 rd = normalize(po - ro);
    
    return ray(ro, rd, color);
}

// 从欧拉角计算旋转矩阵
mat3 angle(vec3 a) {
    vec3 s = sin(a), c = cos(a);
    return mat3(vec3( c.z,  s.z,    0),
                vec3(-s.z,  c.z,    0),
                vec3(   0,    0,    1)) *
           mat3(vec3( c.y,    0, -s.y),
                vec3(   0,    1,    0),
                vec3( s.y,    0,  c.y)) *
           mat3(vec3(   1,    0,    0),
                vec3(   0,  c.x,  s.x),
                vec3(   0, -s.x,  c.x));
}

// 计算有向距离 (物体内部距离为负)
float signed_distance(object obj, vec3 pos) {
    vec3 position = obj.trs.position;
    vec3 rotation = obj.trs.rotation;
    vec3 scale    = obj.trs.scale;
    
    vec3 p = pos - position;
    
    // 会重复的将欧拉角转换成旋转矩阵，实际上只用在第一次计算就行了
    // 也有可能被编译器优化掉了
    p *= angle(radians(rotation));
    
    switch(obj.shape) {
        case SHAPE_SPHERE:
            return sd_sphere(p, scale.x);
        case SHAPE_BOX:
            return sd_box(p, scale);
        case SHAPE_CYLINDER:
            return sd_cylinder(p, scale.xy);
        default:
            return sd_sphere(p, scale.x);
    }
}

// 找到最近的物体并计算距离
object nearest_object(vec3 p) {
    object o; o.dis = TMAX;
    for (int i = 0; i < map.length(); i++) {
        object oi = map[i];
        oi.dis = abs(signed_distance(oi, p));
        if (oi.dis < o.dis) o = oi;
    }
    return o;
}

// 计算物体法线 from https://iquilezles.org/articles/normalsSDF/
vec3 calc_normal(object obj, vec3 p) {
    vec2 e = vec2(1, -1) * 0.5773 * 0.0005;
    return normalize( e.xyy*signed_distance(obj, p + e.xyy) + 
                      e.yyx*signed_distance(obj, p + e.yyx) + 
                      e.yxy*signed_distance(obj, p + e.yxy) + 
                      e.xxx*signed_distance(obj, p + e.xxx) );
}

// 构建正交基旋转矩阵 from https://graphics.pixar.com/library/OrthonormalB/paper.pdf
mat3 TBN(vec3 N) {
    float s = N.z >= 0.0 ? 1.0 : -1.0;
    float a = -1.0 / (s + N.z);
    float b = N.x * N.y * a;
    vec3  T = vec3(1.0 + s * N.x * N.x * a, s * b, -s * N.x);
    vec3  B = vec3(b, s + N.y * N.y * a, -N.y);
    
    return mat3(T, B, N);
}

// 使用光线步进 (Ray March) 检测第一个交点
record raycast(ray r) {
    record rec; float t = TMIN;
    for(uint i = 0U; i < MAX_RAYMARCH && t < TMAX && !rec.hit; i++) {
        rec.pos = at(r, t);
        rec.obj = nearest_object(rec.pos);
        rec.hit = rec.obj.dis < PRECISION;
        t      += rec.obj.dis;
    }
    return rec;
}

// 采样立方体贴图
vec4 mix_cube_lod(samplerCube sharp, samplerCube blur, vec3 dir, float lod) {
    return mix(textureLod(sharp, dir, lod), textureLod(blur, dir, lod), lod);
}

// 采样天空
vec3 sky(ray r, float brightness, float lod) {
    vec4 ibl = mix_cube_lod(iChannel2, iChannel3, r.direction, lod); // 天空盒 IBL 照明
    return pow(ibl.rgb * ibl.a * brightness, vec3(gamma)); // gamma 矫正
}

// 菲涅尔反射近似值
float fresnel_schlick(float cosine, float F0) {
    return mix(pow(abs(1.0 - cosine), 5.0), 1.0, F0);
}

// 用粗糙度计算菲涅尔
float fresnel_schlick(float cosine, float F0, float roughness) {
    return mix(fresnel_schlick(cosine, F0), F0, roughness);
}

// 在切线空间半球采样
vec3 hemispheric_sampling() {
    vec2 r = rand21() * vec2(1.0, TAU);

    vec2  v = vec2(cos(r.y), sin(r.y));
    float z = sqrt(r.x);
    vec2 xy = sqrt(1.0 - r.x) * v; 

    return vec3(xy, z);
}

// 用粗糙度在切线空间半球采样
vec3 hemispheric_sampling(float roughness) {
    vec2 r = rand21() * vec2(1.0, TAU);

    float shiny = pow(roughness, 5.0); // 光感越大高光越锐利
    // ToDo: 除零怎么办 ????!!
    r.x = shiny < 0.000001 ? 1.0 : (1.0 - r.x) / (1.0 + (shiny - 1.0) * r.x);
    
    vec2  v = vec2(cos(r.y), sin(r.y));
    float z = sqrt(r.x);
    vec2 xy = sqrt(1.0 - r.x) * v;
    
    return vec3(xy, z);
}

// 应用 PBR 材质
ray BSDF(ray r, record rec) {
    // 材质参数
    vec3  albedo       = rec.obj.mtl.albedo;
    float roughness    = rec.obj.mtl.roughness;
    float metallic     = rec.obj.mtl.metallic;
    float transmission = rec.obj.mtl.transmission;
    vec3  normal       = rec.obj.mtl.normal;
    float ior          = rec.obj.mtl.ior;
    
    normal = TBN(rec.normal) * normal; // 将切线空间法线转换到世界空间
    float outer = -sign(dot(normal, r.direction)); // 光正在从外面穿入物体表面
    
    // 光线和物体表面参数
    vec3 I  =  r.direction;
    vec3 V  = -r.direction;
    vec3 N  =  normal *= outer; // 如果处于 SDF 物体内部就反过来
    vec3 C  =  r.color;
    vec3 L;
    
    N = TBN(N) * hemispheric_sampling(roughness); // 用粗糙度半球采样
    float NoV = dot(N, V);

    float eta = outer > 0.0 ? ENV_IOR / ior : ior / ENV_IOR; // 计算折射率之比
    float k   = 1.0 - eta * eta * (1.0 - NoV * NoV); // 小于 0 为全反射
    float F0  = (eta - 1.0) / (eta + 1.0); F0 *= 3.0*F0; // 让透明材质的反射更明显一些
    float F   = fresnel_schlick(NoV, F0, roughness); // 菲涅尔

    vec2 rand2 = rand21(); // 取两个随机数
    if (rand2.y < F + metallic || k < 0.0) {
            L = I + 2.0 * NoV * N; // 包含镜面反射、菲涅尔反射、全反射
            // 下面可以提高帧数，但是会导致透明材质发黑，需要优化
            C *= float(dot(L, normal) > 0.0); // 如果光穿入或穿出表面就直接吸收掉
    } else {
        if (rand2.x < transmission) {
            L = eta * I - (sqrt(k)- eta * NoV) * N; // 斯涅尔折射
        } else {
            L = TBN(normal) * hemispheric_sampling(); // 漫反射
        }
    }


    C *= albedo;

    // 更新光的方向和颜色
    r.color     = C;
    r.direction = L;
    
    return r;
}

// RGB 亮度
float brightness(vec3 rgb) {
    return dot(rgb, vec3(0.299, 0.587, 0.114));
}

// 光线追踪
ray raytrace(ray r) {
    for (uint i = 0U; i < MAX_RAYTRACE; i++) {
        // 俄罗斯轮盘赌概率，防止光线过分的反复反射
        float inv_pdf = exp(float(i) / light_quality);
        float roulette_prob = 1.0 - (1.0 / inv_pdf);
    
        // 光线被毙掉就不用继续了
        if (rand11() < roulette_prob) { // discard;
            r.color *= roulette_prob;
            break;
        }
        
        // 能量守恒
        r.color *= inv_pdf;
        
        // 与地图求交
        record rec = raycast(r);
        
        // 没击中物体就肯定击中天空
        if (!rec.hit) {
            r.color *= sign(float(i)); // 纯黑色背景
            r.color *= sky(r, 2.0, 1.0 - 1.0 / (1.0 + 0.1 * float(i)));
            break;
        }
        
        // 计算法线
        rec.normal = calc_normal(rec.obj, rec.pos);
        
        // 更新光子的位置
        r.origin = rec.pos;
        
        // 应用 PBR 材质更新光线
        r = BSDF(r, rec);
        
        // 处理自发光
        float intensity = brightness(r.color);
        r.color *= rec.obj.mtl.emission;
        float visible   = brightness(r.color);
        
        // 光太暗或者击中光源
        if (intensity < visible || visible < VISIBILITY) break;
    }

    return r;
}

// Paniq's ACES fitted from https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
vec3 ACESFitted(vec3 color) {
	// ODT_SAT => XYZ => D60_2_D65 => sRGB
    color *= mat3(
        0.59719, 0.35458, 0.04823,
        0.07600, 0.90834, 0.01566,
        0.02840, 0.13383, 0.83777
    );
    // Apply RRT and ODT
    vec3 a = color * (color + 0.0245786) - 0.000090537;
    vec3 b = color * (0.983729 * color + 0.4329510) + 0.238081;
    color  = a / b;
	// Back to color space
    color *= mat3(
         1.60475, -0.53108, -0.07367,
        -0.10208,  1.10813, -0.00605,
        -0.00327, -0.07276,  1.07602
    );
    // Clamp to [0, 1]
    return clamp(color, 0.0, 1.0);
}

// 片段着色器程序入口
vec4 fragment(vec2 uv, vec2 SCREEN_PIXEL_SIZE) {
    // 计算摄像机方位和视线
    vec3  lookfrom  = load(POSITION).xyz;
    vec2  rotation  = load(ROTATION).xy;
    vec3  direction = CameraRotation(rotation) * vec3(0, 0, -1);
    vec3  lookat    = lookfrom + direction;
    float aspect    = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;;
    
    // 初始化摄像机
    camera cam;
    cam.lookfrom = lookfrom;
    cam.lookat   = lookat;
    cam.aspect   = aspect;
    cam.vfov     = camera_vfov;
    cam.vup      = vec3(0, 1, 0);
    cam.focus    = camera_focus;
    cam.aperture = camera_aperture;
    
    // 用 UV 和时间初始化随机数发生器种子
    seed = rand13(vec3(uv, iTime*iTimeDelta));

    // 超采样
    uv += rand21() * SCREEN_PIXEL_SIZE;
    
    // 对每个光子经过的表面采样一次
    ray r = get_ray(cam, uv, vec3(1));
    
    // 处理颜色
    vec3 color = raytrace(r).color;

    // 色调映射
    color *= camera_exposure;
    color  = ACESFitted(color);
    
    // 伽马矫正
    color = pow(color, vec3(1.0 / gamma));

    return vec4(color, brightness(r.color));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 SCREEN_PIXEL_SIZE = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * SCREEN_PIXEL_SIZE;
    
    fragColor = fragment(uv, SCREEN_PIXEL_SIZE); // 获取片元颜色
    
    if (bool(load(MOVING).x)) return; // 如果正在移动就不积累上一帧
    
    fragColor += texture(iChannel0, uv); // 积累帧进行降噪
}
