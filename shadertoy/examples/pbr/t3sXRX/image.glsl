
// Thanks a lot to iq for awesome articles (https://iquilezles.org/index.html)
// Most of techniques are from the page.

const int obj_num = 2;

vec3 calc_ray(inout mat4 cam,in float x,in float z);
float distance_func(in mat4 obj,in vec3 pos);
vec3 calc_norm(in mat4 objs[obj_num],in vec3 hitpos);
float Basicrand(in vec2 co);
float fbm( in vec3 x);
float box_df(in vec3 p,in vec3 size);
float round_box(in vec3 p,in vec3 size,float r);
float noised( in vec3 x );
float map(in mat4[obj_num] objs,in vec3 pos);
int whichhit(in mat4[obj_num] objs,in vec3 hitpos);
float marching(in mat4[obj_num] objs,in vec3 origin, in vec3 ray);
float smstep(in float x,in float a,in float b);
float softshadow(in mat4[obj_num] objs,in vec3 origin, in vec3 ray);

float pbr_D(in float roughness,in vec3 n,in vec3 h);
float pbr_V(in float roughness, in vec3 n,in vec3 v,in vec3 l);
vec3 pbr_F(in vec3 f0, in vec3 l,in vec3 h);
vec3 material_color(in mat3 mat,in vec3 n,in vec3 v,in vec3 l);
vec3 color(in mat4[obj_num] objs,in vec3 origin,in vec3 ray,in float totdis,in vec3 lightvec,in vec3 lpow);





void mainImage(out vec4 fragColor, in vec2 fragCoord){
    const float PI = 3.1415926535;
    vec2 st = (fragCoord*2.0-iResolution.xy)/min(iResolution.x,iResolution.y);
    //vec2 st = (gl_FragCoord.xy*2.0-resolution.xy)/min(resolution.x,resolution.y);

    mat4 cam;
    cam[0].xyz = vec3(0.0,0.0,3.0);//pos
    cam[1].xyz = normalize(vec3(0.0,8.0,-4.0));//lookat vec
    cam[2].xyz = normalize(vec3(0.0,0.0,1.0));//up
    cam[3].x = (PI*30.0)/(2.0*180.0);//fov

    vec3 ray = calc_ray(cam,st.x,st.y);

    mat4 objs[obj_num];

    objs[0][0].xyz = vec3(0.0,5.0,0.0);
    objs[0][2] = vec4(0.0,vec3(1.0,0.5,0.2));//size
    objs[0][3].x=0.08;//round

    objs[1][0].xyz = vec3(0.0,5.0,-0.4);
    objs[1][2] = vec4(1.0,vec3(2.0,3.0,0.2));//size

    float totdis = marching(objs,cam[0].xyz,ray);//if ishit > 0 is returned;
    bool ishit = totdis>0.0;


    if (ishit){
        vec3 lvec = normalize(vec3(1.2,-1.5,1.0));
        vec3 lpow = vec3(12.0);
        vec3 hitpos = cam[0].xyz+ray*totdis;
        vec3 norm = calc_norm(objs,hitpos);

        vec3 col = color(objs,cam[0].xyz,ray,totdis,lvec,lpow);

        fragColor = vec4(col,1.0);


    }else{
        fragColor = vec4(vec3(0.1),1.0);
    }

    
}
float softshadow(in mat4[obj_num] objs,in vec3 origin, in vec3 ray){
    float max_dis = 100.0;
    float min_dis = 0.001;
    float totdis = 0.0;
    const int max_loop = 100;
    vec3 rayhead;
    float dist;
    bool ishit = false;
    float ret = 1.0;
    float k = 4.0;
    for (int i = 0; i < max_loop; ++i){
        rayhead = origin+ray*totdis;
        dist = map(objs,rayhead);
        if (dist < 0.001) return 0.0;
        ret = min(ret,k*dist/totdis);
        ishit = dist<min_dis && totdis <= max_dis;
        if (ishit) break;
        if (totdis>max_dis) break;
        totdis += dist;
    }
    return ret;
}

float marching(in mat4[obj_num] objs,in vec3 origin, in vec3 ray){
    float max_dis = 100.0;
    float min_dis = 0.0001;
    float totdis = 0.0;
    const int max_loop = 200;
    vec3 rayhead;
    float dist;
    bool ishit = false;
    for (int i = 0; i < max_loop; ++i){
        rayhead = origin+ray*totdis;
        dist = map(objs,rayhead);
        ishit = dist<min_dis && totdis <= max_dis;
        if (ishit) break;
        if (totdis>max_dis) break;
        totdis += dist;
    }
    float ret = (ishit)?totdis:-1.0;
    return ret;
}

vec3 calc_ray(inout mat4 cam,in float x,in float z){
    vec3 lookAt = cam[1].xyz;
    vec3 up = cam[2].xyz;
    vec3 side = normalize(cross(lookAt,up));
    float fov = cam[3].x;
    vec3 trueup = normalize(cross(side,lookAt));
    cam[2].xyz=trueup;
    return normalize(sin(fov)*x*side+cos(fov)*lookAt+sin(fov)*z*up);
}

float map(in mat4[obj_num] objs,in vec3 pos){
    vec3 p = pos-objs[0][0].xyz;
    float hoge = round_box(p,objs[0][2].yzw,objs[0][3].x);
    float ret = 1e9;
    if (hoge>0.1){
        p = pos-objs[1][0].xyz;
        float fuga = box_df(p,objs[1][2].yzw);
        ret = min(fuga,hoge);
    }else{
        for (int i = 0; i < obj_num; ++i){
            float d = distance_func(objs[i],pos);
            ret = min(ret,d);
        }
    }

    return ret;
}

int whichhit(in mat4[obj_num] objs,in vec3 hitpos){
    int ret = -1;
    for (int i = 0; i < obj_num; ++i){
        float d = distance_func(objs[i],hitpos);
        if (d<0.001) {ret = i; break;}
    }
    return ret;
}

float distance_func(in mat4 obj,in vec3 pos){
    //objectとposから距離を求める距離関数のラッパー
    vec3 p = pos-obj[0].xyz;
    vec4 mask = vec4(0.0,1.0,2.0,3.0);
    mask = 1.0-step(0.3,abs(vec4(obj[2].x)-mask));
    // float d1 = box_df(p,obj[2].yzw)+fbm(p*2.0)*0.02;
    // float d1 = round_box(p,obj[2].yzw,obj[3].x)+fbm(p*vec3(2.8))*0.03+fbm(p*vec3(100.0,50.0,30.0))*0.002;
    float d1 = round_box(p,obj[2].yzw,obj[3].x)+fbm(p*vec3(3.0))*0.03;
    // float d1 = round_box(p,obj[2].yzw,obj[3].x)+fbm(p*vec3(2.0,3.0,5.0))*0.03;
    //ここのfbmの周期が等方性なのがキモいかも。実際は異方性なので、floatじゃなくてvec3でかけるがよし?→かわらんかったわ。
    float d2 = box_df(p,obj[2].yzw);
    float d3 = 0.0;
    float d4 = 0.0;
    return dot(mask,vec4(d1,d2,d3,d4));
}

vec3 calc_norm(in mat4 objs[obj_num],in vec3 hitpos){
    float eps = 0.00001;
    return normalize(
        vec3(
            map(objs,hitpos+vec3(eps,0.0,0.0))-map(objs,hitpos+vec3(-eps,0.0,0.0)),
            map(objs,hitpos+vec3(0.0,eps,0.0))-map(objs,hitpos+vec3(0.0,-eps,0.0)),
            map(objs,hitpos+vec3(0.0,0.0,eps))-map(objs,hitpos+vec3(0.0,0.0,-eps))
        )
    );
}

float Basicrand(in vec3 co){
    return fract(sin(dot(co.xyz ,vec3(12.9898,78.233,23.615))) * 43758.5453);
}


float fbm( in vec3 x)
{   
    const mat3 m3  = mat3( 0.00,  0.80,  0.60,
                      -0.80,  0.36, -0.48,
                      -0.60, -0.48,  0.64 );

    // float Gain = exp2(-1.0);//exp(-H)
    float Gain = exp2(-1.0);//exp(-H)
    float freq = 2.0;
    float amp = 1.0;
    float ret = 0.0;
    const int numOctaves = 5;
    for( int i=0; i<numOctaves; i++ )
    {
        float n = noised(x);
        ret += amp*n;
        amp *= Gain;
        x = freq*m3*x;
    }
    return ret;
}

float box_df(in vec3 p,in vec3 size){
    vec3 q = abs(p)-size;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float round_box(in vec3 p,in vec3 size,float r){
      vec3 q = abs(p)-size;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0)-r;
}

 float noised( in vec3 x )
 {
    vec3 p = floor(x);
    vec3 w = fract(x);

    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);

    float a = Basicrand( p+vec3(0,0,0) );
    float b = Basicrand( p+vec3(1,0,0) );
    float c = Basicrand( p+vec3(0,1,0) );
    float d = Basicrand( p+vec3(1,1,0) );
    float e = Basicrand( p+vec3(0,0,1) );
    float f = Basicrand( p+vec3(1,0,1) );
    float g = Basicrand( p+vec3(0,1,1) );
    float h = Basicrand( p+vec3(1,1,1) );

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;


    return -1.0+2.0*(k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z);
 }

 float smstep(in float x,in float a,in float b){
     if (x < a) return 0.0;
     if (x > b) return 1.0;
     float d = (x-a)/(b-a);
     return d*d*(3.0-2.0*d);
 }

float pbr_D(in float roughness,in vec3 n,in vec3 h){
    const float PI = 3.1415926535;
    float al2 = roughness*roughness*roughness*roughness;
    float dotNH2 = dot(n,h)*dot(n,h);
    float base = PI*((dotNH2*(al2-1.0)+1.0)*(dotNH2*(al2-1.0)+1.0));
    return clamp(al2/base,0.0,1.0);
}
float pbr_V(in float roughness, in vec3 n,in vec3 v,in vec3 l){
    float al2 = roughness*roughness*roughness*roughness;
    float dotNL = dot(n,l);
    float dotNV = dot(n,v);

    float base1 = dotNV*sqrt(dotNL*dotNL*(1.0-al2)+al2);
    float base2 = dotNL*sqrt(dotNV*dotNV*(1.0-al2)+al2);

    return clamp(0.5/(base1+base2),0.0,1.0);
}
vec3 pbr_F(in vec3 f0, in vec3 l,in vec3 h){
    float dotLH = dot(l,h);
    float hoge = pow((1.0-dotLH),5.0);

    return clamp(f0+(vec3(1.0)-f0)*hoge,0.0,1.0);
}

vec3 material_color(in mat3 mat,in vec3 n,in vec3 v,in vec3 l){
    const float PI = 3.1415926535;
    vec3 h = normalize(l+v);
    float pbr_d = pbr_D(mat[2].x,n,h);
    float pbr_v = pbr_V(mat[2].x,n,v,l);
    vec3 pbr_f = pbr_F(mat[1],l,h);
    vec3 diff = mat[0]/PI;
    return (vec3(1.0)-pbr_f)*diff+pbr_d*pbr_f*pbr_v;
}

vec3 color(in mat4[obj_num] objs,in vec3 origin,in vec3 ray,in float totdis,in vec3 lvec,in vec3 lpow){
        vec3 hitpos = origin + totdis*ray;
        vec3 norm = calc_norm(objs,hitpos);
        float ldot = clamp(dot(lvec,norm),0.0,1.0);
        int which = whichhit(objs,hitpos);
        float shadow_fac = 0.0;
        shadow_fac = softshadow(objs,hitpos+norm*0.03,lvec);
        // shadow_fac = (marching(objs,hitpos+norm*0.03,lvec)>0.0)?0.2:1.0;
        shadow_fac = 0.3+clamp(shadow_fac,0.05,0.7);
        lpow = lpow*shadow_fac*ldot;
        float AO = 0.0;
        float ao_step=0.01;
        float ao_length = ao_step;
        float k = 2.0;
        for (int i = 0; i < 8; ++i){
            float d = map(objs,hitpos+ao_length*norm);
            AO += (ao_length-d)*k;
        }
        AO = clamp(1.0-AO,0.0,1.0);
        lpow *= AO;


        vec3 white = vec3(0.23,0.22,0.22);
        vec3 black = vec3(0.19,0.18,0.18);
        float stonemix = 1.0-smstep(fbm(hitpos*4.0),-0.3,0.1);
        mat3 material;
        material[0] = (which==0)?mix(white,black,stonemix):vec3(0.5,0.5,0.5);//albedo
        material[1] = (which==0)?vec3(0.05,0.05,0.05):vec3(0.1,0.1,0.1);//f0
        material[2].x = (which==0)?0.3:0.05;//roughness

        vec3 brdf = material_color(material,norm,origin-hitpos,lvec);
        return brdf*lpow;
    }

