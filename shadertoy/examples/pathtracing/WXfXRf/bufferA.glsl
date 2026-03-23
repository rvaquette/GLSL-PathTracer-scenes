/*
"Wet stone" by Alexander Alekseev aka TDM - 2014
License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
Contact: tdmaav@gmail.com
*/
float time;
vec3 wl;

vec3 quadsorb(
  float c,
  float w) {
  return 1.0 + pow(abs((wl - c) / w), vec3(2.0)); }

const float eps = 1e-5;

// https://www.shadertoy.com/view/lfs3Wn
vec2 triangle_wave(vec2 a){
    vec2 a2 =
        vec2(1.,0.5)
    ,
    a1 = a+a2;
    return abs(fract((a1)*(a2.x+a2.y))-.5);
}


void transform(inout vec2 uv, inout vec2 t2){
        t2 = triangle_wave(uv+.5);
        uv =
            t2-triangle_wave(uv.yx)-fract(t2/2.)
        ;
        //{t2.x = (t2.x+1.5*sign(t2.y-t2.x)); }
        //{uv.x = (uv.x+1.5*sign(uv.y-uv.x)); }
}

vec2 rotate(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, s, -s, c);
	return m * v;
}

vec3 carpet(vec2 uv){
    vec3 col = vec3(0.);
    vec2 t2 = vec2(0.);
    vec3 col1 = col;
    float c1=0.;
    for(int k = 0; k < 15; k++){
        float warp_scale = 16.;
        vec2 warp =
            //abs(.5-fract(uv*3.))*3.
            //abs(.5-fract(t2*3.))*3.
            vec2(sin((t2.x)*warp_scale),cos((t2.y)*warp_scale))
            //vec2(sin((uv.x)*warp_scale),cos((uv.y)*warp_scale))
        ;
        uv.y -= 1./4.;
        float scale = 1.5;

        uv = (uv+t2)/scale;
        
        uv = (fract(vec2(uv+vec2(.5,1.5))*scale)-.5)/scale;
        col.x =
            max(length(uv-t2-c1)/3.,col.x);
        
        ;
        if(k>1)
        warp = warp*warp/warp_scale;
        else
        warp = vec2(0);

        vec2 uv_1 =
            uv + warp.yx
        ,
        t2_1=
            t2 + warp.yx
        ;
        vec3 col_1 = col;
        transform(uv,t2);

        transform(uv_1,t2_1);
        //uv_1 = rotate(uv_1,t2.x*2.);
        //t2_1 = rotate(t2_1,t2.x*2.);
        
        c1 =
            max(abs(uv_1.y+uv_1.x)/2.,c1)
            //max(abs(uv_1.y-uv_1.x),c1)
        ;
        c1 =
            max(1.-abs(2.*c1-1.),c1/4.)
        ;
        col.x =
            max(length(uv_1-t2_1-c1)/3.,col.x)

        ;
        col =
            abs(col-(1.-(c1*col.x)));
        col1 =
            abs(col1*c1-col-1.).yzx
            //abs(col1*c1*sign(t2.y-t2.x)/2.-col-1.).yzx
            //abs(col1*c1-col+sign(t2.x-t2.y)).yzx
        ;
    }
    return col1;
}

float hash11(float p) {
  return fract(sin(p * 727.1)*435.545); }
vec3 hash31(float p) {
  vec3 h = vec3(127.231, 491.7, 718.423) * p;	
  return fract(sin(h) * 435.543); }

// world
float rock(vec3 p) {    
  float d = sphere(p, 1.0);    
  for(int i = 0; i < 9; i++) {
    float ii = float(i);
    float r = 2.5 + hash11(ii);
    vec3 v = normalize(hash31(ii) * 2.0 - 1.0);
    d = smax(d, -sphere(p + v * r, r * 0.8), 0.03); }
  return d; }

vec4 rockg(mat4 p) {    
  vec4 d = sphereg(p, 1.0);    
  for(int i = 0; i < 9; i++) {
    float ii = float(i);
    float r = 2.5 + hash11(ii);
    vec3 v = normalize(hash31(ii) * 2.0 - 1.0);
    d = smaxg(d, -sphereg(p + constg(v * r), r * 0.8), 0.03); }
  return d; }

float df(vec3 p) {
  float f = 0.1 * fractal3(0, 4.0 * p, 0.4, 2.96, 5);
  float d = 0.6 * (rock(p) + f);
  return d; }

vec4 dfg(mat4 p) {
  vec4 f = 0.1 * fractal3g(0, 4.0 * p, 0.4, 2.96, 5);
  vec4 d = 0.6 * (rockg(p) + f);
  return d; }

// numerically estimated normals
vec3 nfd(vec3 p) {
	float d = df(p);
    vec2 e = vec2(eps, 0);
    vec3 n = d - vec3(
        df(p-e.xyy),
        df(p-e.yxy),
        df(p-e.yyx));
    return normalize(n);
}

// analytic normals, slower, more accurate
vec3 nfg(vec3 p) {
    return normalize(dfg(ivg(p)).xyz);
}

vec3 nf(vec3 p) {
    return nfd(p); }

vec3 power_icdf(vec3 spec_dir, float power) {
  return axial(spec_dir, pow(unitrand(), 1.0 / (power + 1.0))); }

float power_pdf(
  vec3 spec_dir,
  float power,
  vec3 rd) {
  return (power + 1.0) / (2.0 * pi) * pow(max(0.0, dot(spec_dir, rd)), power); }

// corrected blinn-phong radiance coefficient
vec3 blinn_phong_coef(vec3 ri, vec3 ro, vec3 n, vec3 albedo, vec3 specularity, vec3 power) {
  vec3 r = albedo * dot(n, ri) * (1.0 - specularity) / pi;
  float rr = dot(n, normalize(ri - ro));
  r += specularity * (power + 2.0) / (2.0 * pi) * pow(vec3(rr), power); 
  return r; }

float fresnel_reflectance(vec3 rd, vec3 n, float ior) {
  n = -n;
  float dt1 = dot(rd, n);
  float ior2 = pow(ior, 2.0);
  float dt12 = pow(dt1, 2.0);
  float discriminant = -1.0 + ior2 + dt12;
  if (discriminant < 0.0) return 1.0;
  // fresnel reflectance for positive discriminant
  vec3 refracted_heading = normalize(
    rd + (-dt1 + sqrt(discriminant)) * n);
  float dt2 = dot(refracted_heading, n);
  float dt22 = pow(dt2, 2.0);
  float k1 = dt12 + ior2 * dt22;
  float k2 = ior2 * dt12 + dt22;
  float v = 2.0 * ior * dt1 * dt2;
  return clamp(0.5 * (
    (k1 - v) / (k1 + v)
    + (k2 - v) / (k2 + v)), 0.0, 1.0); }

float pick;
float pickone(vec3 v) {
  if (pick < 1.0 / 3.0) {
    return v.x; }
  else if (pick < 2.0 / 3.0) {
    return v.y; }
  else {
    return v.z; } }
    
vec3 scene(vec3 ro, vec3 rd) {
  vec3 throughput = vec3(1.0), Lo = vec3(0.0);
  for (int i = 0; i < 1024; ++i) {
    // compute distances
    float dmin = 1.0 / zero;
    float drock = 1.0 / zero;
    if (length(ro) < 1.0 || dot(-ro, rd) > sqrt(1.0 - pow(1.0 / length(ro), 2.0))) {
      drock = df(ro);
      dmin = min(drock, dmin); }
    float dplane = 1.0 / zero;
    if (ro.y > -1.0 && rd.y < 0.0) {
      dplane = -(ro.y + 1.0) / rd.y;
      dmin = min(dplane, dmin); }
    // shading setup
    vec3 n;
    vec3 albedo;
    float specularity;
    if (dmin == 1.0 / zero) {
      vec3 room = srgb_igamma(texture(iChannel3, rd).bgr);
      Lo += throughput * room / (1.2 - room);
      return Lo; }
    else if (dmin == dplane) {
      ro += dplane * rd;
      n = dy.xyz;
      albedo = srgb_igamma(0.5 * carpet((ro.xz + vec2(0.0, 20.0)) / 400.0).bgr);
      vec3 ior = vec3(1.8);
      specularity = fresnel_reflectance(rd, n, 1.8); }
     else if (dmin == drock) {
      ro += drock * rd;
      if (drock > eps) {
        continue; }
      n = nf(ro);
      if (dot(rd, n) > 0.0) {
        ro += eps * rd;
        continue; }
      albedo = 0.6 / quadsorb(700.0, 30.0);
      vec3 ior = vec3(1.5);
      specularity = fresnel_reflectance(rd, n, 1.5); }
    if (unitrand() < specularity) {
      rd = reflect(rd, n); }
    else {
      throughput *= albedo;
      rd = power_icdf(n, 1.0); } } }

#define INTERACT 1

void mainImage(out vec4 o, in vec2 xy) {
  srand(ivec3(xy, iFrame + int(iFrameRate * iTime)));
  time = (iTime + unitrand() * iTimeDelta);
  float wl_min = 360.0;
  float wl_max = 800.0;
  float wl_rng = wl_max - wl_min;
  vec2 wl_pts = wl_min + vec2(1.0, 2.0) * wl_rng / 3.0;
  wl = mix(
    vec3(wl_min, wl_pts.x, wl_pts.y),
    vec3(wl_pts.x, wl_pts.y, wl_max),
    vec3(unitrand(), unitrand(), unitrand()));
  mat4 view =
    rotate(dy, 2.9
#if INTERACT
      - 3.0 * pi * (iMouse.x / iResolution.x)
#endif
      ) *
    rotate(dx, -0.2
#if INTERACT
      + 3.0 * pi * (iMouse.y / iResolution.y)
#endif
    ) *
    translate(vec4(0.0, 0.0, -4.0, 0.0));
  vec2 lens_uv = sqrt(unitrand()) 
      * dir2(6.28318530718 * boxrand());
  vec2 lenspoint = 0.005 * lens_uv;
  vec3 ro = vec3(lenspoint, 0.0);
  vec3 rd = normalize(vec3(
    (xy - 0.5 * iResolution.xy + vec2(boxrand(), boxrand()))
    / (iResolution.y * 1.4)
    - (lenspoint / 3.5),
    1.0));
  ro = (view * vec4(ro, 1.0)).xyz;
  rd = (view * vec4(rd, 0.0)).xyz;
  o = vec4(srgbcmf(wl, scene(ro, rd)), 1.0);
  if (iFrame != 0
#if INTERACT
    && iMouse.z <= 0.0
#endif
    ) {
    o += texelFetch(iChannel0, ivec2(xy), 0); } }

