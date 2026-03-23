//   __  __    __    ____  ____  _____  _  _ 
//  (  \/  )  /__\  (  _ \(_  _)(  _  )( \/ )
//   )    (  /(__)\  )___/  )(   )(_)(  \  / 
//  (_/\/\_)(__)(__)(__)   (__) (_____) (__) 
//
//  Version: 1.0.5
//
//  This is a "Maptoy" template.
//  I wanted an editor dedicated to distance functions, so I created it in Shadertoy.
//  You can bookmark this page, fork, and edit it.
//  I've tried to keep everything but the map functions in the Common tab.
//
//  Update:
//
//  1.0.5 @ 2022/09/14    
//        - Fixed long compilation in Quad view.
//
//  1.0.4 @ 2021/11/03    
//        - Added Isoline draw.
//
//  1.0.3 @ 2021/10/22    
//        - Added Matcap debug mode.
//
//  1.0.2 @ 2021/10/20    
//        - Added Quad view mode.
//
//  1.0.1 @ 2021/10/15    
//        - Added Axis draw.
//        - Added Hotkeys for Camera View angle.
//         ( Numpad-1:Front / Numpad-3:Side / Numpad-7:Top / Numpad-0:Toggle free/fixed )
//
//  1.0.0 @ 2021/10/14   
//        - Released.
//
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// Setting
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#define THM_BACKGROUND (vec3(0.071,0.071,0.071)*.8)
#define THM_GRID vec3(0.078,0.078,0.078)
#define THM_ISOLINE vec3(.2)
#define THM_ISOMIX .8
#define THM_GEOM_DARK vec3(0.000,0.000,0.000)
#define THM_GEOM_LIGHT vec3(0.820,0.820,0.820)
#define THM_MATCAP_TYPE 1
// Matcaps 0:CURVATURE/1:METAL/2:RED_WAX

#define DIST_MIN .001
#define DIST_MAX 10.
#define STEP_MAX 100
#define INIT_CAM_POS vec3(-2,-.5,0)

// Utils
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#define PI acos(-1.)
#define HALF_PI (PI*.5)
#define TAU (PI*2.)
#define saturate(x) clamp(x, 0.0, 1.0)
#define R(p, a) p=p*mat2(cos(a),sin(a),-sin(a),cos(a))
vec2 rot(vec2 p, float r){ R(p, r); return p; }
vec3 rot(vec3 p, vec3 r){ R(p.xz, r.y), R(p.yx, r.z), R(p.zy, r.x); return p; }

// Borrowed from "Infinite 3D Grid Planes" by peepsalot:
// https://www.shadertoy.com/view/Ndy3Rm
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
float plane( in vec3 ro, in vec3 rd, in vec4 p ){
    return -(dot(ro,p.xyz)+p.w)/dot(rd,p.xyz);
}

float grid(in vec2 p, in vec2 dpdx, in vec2 dpdy, float N){
    const float scl = 0.5;
    vec2 w = max(abs(dpdx), abs(dpdy));
    vec2 a = p + 1.0 / N - w; // see 
    vec2 b = p - w;
    vec2 i = clamp(
      ( floor(a) + min(fract(a) * N, 1.0)
       -floor(b) - min(fract(b) * N, 1.0)
      ) / (N*w)
      , vec2(0), vec2(1));
    return (1.0 - i.x) * (1.0 - i.y);
}
float grid_lookup(in vec3 ro, in vec3 rd, float resDist, in vec4 pln, float scale, float lineRatio){
    float t = plane(ro, rd, pln);
    if (t > 0.0 && t<resDist)
    {
        vec3 p = (ro + t * rd);
        vec2 uv = scale*(p.yz * pln.x + p.xz * pln.y + p.xy * pln.z);
        return clamp(1.0 - grid(uv, dFdx(uv), dFdy(uv), 2.0 * lineRatio), 0.0, 1.0);
    } else {
        return 0.0;
    }
}

// https://iquilezles.org/articles/intersectors
// infinite cylinder defined by a base point cb, a normalized axis ca and a radious cr
vec2 cylIntersect( in vec3 ro, in vec3 rd, in vec3 cb, in vec3 ca, float cr )
{
    vec3  oc = ro - cb;
    float card = dot(ca,rd);
    float caoc = dot(ca,oc);
    float a = 1.0 - card*card;
    float b = dot( oc, rd) - caoc*card;
    float c = dot( oc, oc) - caoc*caoc - cr*cr;
    float h = b*b - a*c;
    if( h<0.0 ) return vec2(-1.0); //no intersection
    h = sqrt(h);
    return vec2(-b-h,-b+h)/a;
}



// "iResolution, iMouse, iDate, etc" by FabriceNeyret2:
// https://www.shadertoy.com/view/llySRh
// --- chars
int CAPS=0;
#define low CAPS=32;
#define caps CAPS=0;
#define spc  U.x-=.5;
#define C(c) spc col+= char(U,64+CAPS+c).rgb;
#define _a 1
#define _b 2
#define _c 3
#define _d 4
#define _e 5
#define _f 6
#define _g 7
#define _h 8
#define _i 9
#define _j 10
#define _k 11
#define _l 12
#define _m 13
#define _n 14
#define _o 15
#define _p 16
#define _q 17
#define _r 18
#define _s 19
#define _t 20
#define _u 21
#define _v 22
#define _w 23
#define _x 24
#define _y 25
#define _z 26

// render(): general ray marching code.
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
float cost = 0.;
#define C_MOUSE vec2(0,0)
#define C_CAMERA vec2(1,0)
#define C_MOUSE_VEC vec2(2,0)
#define C_MOUSE_POS vec2(3,0)
#define CAM_DIST 6.
#define render() \
int char_id = -1; vec2 char_pos, dfdx, dfdy; \
vec4 char(vec2 p, int c) {\
    vec2 dFdx = dFdx(p/16.), dFdy = dFdy(p/16.);\
    if ( p.x>.25&& p.x<.75 && p.y>.1&& p.y<.85 ) /* thighly y-clamped to allow dense text*/\
        char_id = c, char_pos = p, dfdx = dFdx, dfdy = dFdy;\
    return vec4(0);\
}\
vec4 draw_char() {\
    int c = char_id; vec2 p = char_pos;\
    return (c < 0)? vec4(0,0,0,1e5) : textureGrad( iChannel1, p/16. + fract( vec2(c, 15-c/16) / 16. ), dfdx, dfdy );\
}\
vec4 fetch(vec2 coord){\
    return texelFetch(iChannel0, ivec2(coord), 0);\
}\
struct Ray{\
	vec3 origin;\
	vec3 direction;\
}ray;\
vec3 calcNormal(vec3 p){\
  vec3 n=vec3(0);\
  for(int i=0; i<4; i++){\
    vec3 e=DIST_MIN*(vec3(9>>i&1, i>>1&1, i&1)*2.-1.);\
    n+=e*map(p+e);\
  }\
  return normalize(n);\
}\
/* Camera localized normal*/\
vec3 campos, camup;\
vec3 localNormal(vec3 p) {\
    vec3 n = calcNormal(p), ln;\
    vec3 side = cross(campos, camup);\
    return vec3(dot(n,  side), dot(n,  camup), dot(n,  -ray.direction));\
}\
float march(vec3 ro, vec3 rd){\
    float t=DIST_MIN, d;\
    for(int i=0; i<STEP_MAX; i++)\
    {\
        t+=d=map(ro+rd*t);\
        if (d<DIST_MIN) return t;\
        if (t>DIST_MAX) return DIST_MAX;\
        cost++;\
    }\
    return DIST_MAX;\
}\
vec2 forceView = vec2(0);\
void setupRay(vec2 uv){\
	vec3 up = vec3(0,1,0);\
    vec3 pos = normalize(vec3(1)) * CAM_DIST;\
    if(sign(iMouse.z)>.0 && (forceView.x<.5))\
        pos = normalize(vec3(sin(iMouse.x/iResolution.x*PI*2.), (iMouse.y/iResolution.y-.5)*4., cos(iMouse.x/iResolution.x*PI*2.))) * CAM_DIST;\
    else if(fetch(C_CAMERA).y<.5 && bool(TURN_TABLE))\
        pos = normalize(vec3(sin(iTime*TURN_TABLE_SPEED), -1, cos(iTime*TURN_TABLE_SPEED))) * CAM_DIST;\
    else if(fetch(C_CAMERA).y>.5 || forceView.x>.5){\
        int num;\
        if(forceView.x>.5) num = int(forceView.y);\
        else num = int(fetch(C_CAMERA).x);\
        if(num==1) pos = vec3(0,0,1) * CAM_DIST;/*FRONT*/\
        if(num==3) pos = vec3(-1,0,0) * CAM_DIST;/*SIDE(LEFT)*/\
        if(num==7) {up=vec3(0,0,1); pos = vec3(0,-1,0) * CAM_DIST;/*TOP*/\
        if(num==0) pos = normalize(vec3(sin(iMouse.x/iResolution.x*PI*2.), (iMouse.y/iResolution.y-.5)*4., cos(iMouse.x/iResolution.x*PI*2.))) * CAM_DIST;}\
    }\
    else {\
        vec4 mou = abs(texelFetch(iChannel0, ivec2(C_MOUSE), 0));\
        pos = normalize(vec3(sin(mou.x/iResolution.x*PI*2.), (mou.y/iResolution.y-.5)*4., cos(mou.x/iResolution.x*PI*2.))) * CAM_DIST;\
        if(length(mou.xyz)<=.0)pos=INIT_CAM_POS;\
    }\
    vec3 cw = normalize(-pos);\
    vec3 cu = normalize(cross(cw, up));\
    vec3 cv = normalize(cross(cu, cw));\
    campos = cw, camup = cv;\
	uv *= CAM_SCALE/CAM_DIST;\
	float perspective = 1.5;\
	float fv = acos(dot(cw, normalize(cu * uv.x)));\
	float screenSize = (CAM_DIST*perspective / (2.0 * tan(abs(fv) / 2.0)));\
	vec3 virtscreen = pos + cw * 2.0 + (cu * uv.x + cv * uv.y) * screenSize;\
	ray.origin = -pos + (cu * uv.x + cv * uv.y) * (0.7 + 0.2 * perspective) * screenSize;\
	ray.direction = normalize(virtscreen - ray.origin);\
}\
float plaIntersect( in vec3 ro, in vec3 rd, in vec4 p )\
{\
    return -(dot(ro,p.xyz)+p.w)/dot(rd,p.xyz);\
}\
vec3 renderRect(vec2 fragCoord){\
    vec2 uv = (fragCoord.xy*2.-iResolution.xy)/iResolution.y, U;\
    setupRay(uv);\
    vec3 col= THM_BACKGROUND;\
    float t= march(ray.origin, ray.direction);\
    if(t<DIST_MAX){\
        vec3 p = ray.origin + ray.direction * t;\
        col = vec3(.5);\
        vec3 n = localNormal(p);\
		vec3 lightPos = vec3(-2,2,-2);\
    	vec3 li = normalize(lightPos-p);\
		float dif = dot(n,li)*.5+.5;\
        col = mix(THM_GEOM_DARK, THM_GEOM_LIGHT, dif);\
        if(bool(DBG_NORMAL))col = (n*.5+.5)*.5;\
        if(bool(DBG_MATCAP)){\
            float depth = distance(ray.origin, p);/*/DIST_MAX;*/\
            n = localNormal(p);\
            /* Compute curvature */\
            vec3 dx = dFdx(n);\
            vec3 dy = dFdy(n);\
            vec3 xneg = n - dx;\
            vec3 xpos = n + dx;\
            vec3 yneg = n - dy;\
            vec3 ypos = n + dy;\
            float sgn = (dot(localNormal(p),vec3(1,0,0))>0.)? 1. : -1.;\
            float curvature = (cross(xneg, xpos).y - cross(yneg, ypos).x) * 4.0 / depth;\
            /* Compute surface properties */\
            if(THM_MATCAP_TYPE == 0){\
                vec3 light = vec3(0.0);\
                vec3 ambient = vec3(curvature + 0.5);\
                vec3 diffuse = vec3(0.0);\
                vec3 specular = vec3(0.0);\
                float shininess = 0.0;\
                /* Compute final color */\
                float cosAngle = dot(n, light);\
                col = ambient +\
                diffuse * max(0.0, cosAngle) +\
                specular * pow(max(0.0, cosAngle), shininess);\
            }else if(THM_MATCAP_TYPE == 1){\
                float corrosion = clamp(-curvature * 8.0, 0.0, 1.0);\
                float shine = clamp(curvature * 3.0, 0.0, 1.0);\
                vec3 light = normalize(vec3(0.0, 1.0, 10.0));\
                vec3 ambient = vec3(0.047,0.067,0.094);\
                vec3 diffuse = mix(mix(vec3(0.259,0.380,0.290), vec3(0.431,0.549,0.549), corrosion),\
                vec3(0.761,0.655,0.439), shine) - ambient;\
                vec3 specular = mix(vec3(0), vec3(1) - ambient - diffuse, shine);\
                float shininess = 128.0;\
                /* Compute final color */\
                float cosAngle = dot(n, light);\
                col = ambient +\
                diffuse * max(0.0, cosAngle) +\
                specular * pow(max(0.0, cosAngle), shininess);\
            }else if(THM_MATCAP_TYPE == 2){\
                float dirt = clamp(0.15 - curvature * 5.0, 0.0, 1.0);\
                vec3 light = normalize(vec3(0.0, 1.0, 10.0));\
                vec3 ambient = vec3(0.251,0.082,0.008);\
                vec3 diffuse = mix(vec3(0.565,0.224,0.078), vec3(0.996,0.843,0.843), dirt) - ambient;\
                vec3 specular = mix(vec3(0.3) - ambient, vec3(0.0), dirt);\
                float shininess = 16.0;\
                /* Compute final color */\
                float cosAngle = dot(n, light);\
                col = ambient +\
                diffuse * max(0.0, cosAngle) +\
                specular * pow(max(0.0, cosAngle), shininess);\
            }\
            col = pow(col, vec3(2.));\
        }\
    }\
    float gsi = 2.;\
    float gsf = 10.;\
    float gli = 50.;\
    float glf = 20.;\
    float gx = max(grid_lookup(ray.origin, ray.direction, t, vec4(1, 0, 0, 0), gsf, glf), grid_lookup(ray.origin, ray.direction, t, vec4(1, 0, 0, 0), gsi, gli));\
    float gz = max(grid_lookup(ray.origin, ray.direction, t, vec4(0, 1, 0, 0), gsf, glf), grid_lookup(ray.origin, ray.direction, t, vec4(0, 1, 0, 0), gsi, gli));\
    float gy = max(grid_lookup(ray.origin, ray.direction, t, vec4(0, 0, 1, 0), gsf, glf), grid_lookup(ray.origin, ray.direction, t, vec4(0, 0, 1, 0), gsi, gli));\
    vec3 g=vec3(0);\
    if(bool(UI_GRID_2D))\
        g = vec3(gz);\
    if(iMouse.z<.5 && (fetch(C_CAMERA).y>.5 || bool(UI_GRID_3D) || forceView.x>.5))\
        g = vec3(gx+gy+gz)*.333;\
    if(bool(DBG_COST))\
        col.r+=cost/float(STEP_MAX);\
    col = mix(col, THM_GRID, g);\
    if(bool(UI_ISOLINE)) {\
        vec4 n;\
        int num;\
        if(forceView.x>.5) num = int(forceView.y);\
        else num = int(fetch(C_CAMERA).x);\
        if(num==1) n = vec4(0,0,1,0);\
        if(num==7) n = vec4(0,1,0,0);\
        if(num==3) n = vec4(1,0,0,0);\
        if(num==0) n = vec4(0,1,0,0);\
        float pd = plaIntersect(ray.origin, ray.direction, normalize(n));\
        float inpd = map(ray.origin + ray.direction * pd);\
        float major = smoothstep(.0051, .005, abs(mod(inpd, 1.)-.5));\
        float minor = smoothstep(.0051, .005, abs(mod(inpd+.05, .1)-.05));\
        col = mix(col, THM_BACKGROUND*.5, (1.-float(pd<t))*THM_ISOMIX);\
        col = mix(col, vec3(.35)*col, step(0., -inpd));\
        col = mix(col, mix(col, vec3(THM_ISOLINE), mix(major, minor, .333)), .9);\
    }\
    col = pow(col, vec3(.4545));\
    if(bool(UI_AXIS)){\
        float at = .005;\
        float axisX = cylIntersect(ray.origin, ray.direction, vec3(0), vec3(1,0,0), at).x;\
        if(axisX>0. && (bool(UI_ISOLINE) || axisX<t))col=vec3(0.451,0.145,0.110);\
        float axisY = cylIntersect(ray.origin, ray.direction, vec3(0), vec3(0,1,0), at).x;\
        if(axisY>0. && (bool(UI_ISOLINE) || axisY<t))col=vec3(0.267,0.471,0.129);\
        float axisZ = cylIntersect(ray.origin, ray.direction, vec3(0), vec3(0,0,1), at).x;\
        if(axisZ>0. && (bool(UI_ISOLINE) || axisZ<t))col=vec3(0.267,0.424,0.671);\
    }\
    U = ( fragCoord/iResolution.y - vec2(0, (1.-.075)) ) * 20.;\
    int num;\
    if(forceView.x>.5) num = int(forceView.y);\
    else num = int(fetch(C_CAMERA).x);\
    caps C(_c) low C(_a)C(_m)C(_e)C(_r)C(_a) caps C(-6) spc\
    if(num==1){caps C(_f) low C(_r)C(_o)C(_n)C(_t)}\
    if(num==7){caps C(_t) low C(_o)C(_p)}\
    if(num==3){caps C(_s) low C(_i)C(_d)C(_e)}\
    if(num==0){caps C(_f) low C(_r)C(_e)C(_e)}\
    col = mix(col, pow(vec3(.8),vec3(.4545)), draw_char().xxx);\
    return col;\
}\
void mainImage( out vec4 fragColor, in vec2 fragCoord ){\
    if(bool(VIEW_QUAD)){\
        vec3 Res = vec3(iResolution.xy, 0);\
        forceView = vec2(1,1);\
        vec2 offset;\
        if(fragCoord.x<Res.x*.5-2. && fragCoord.y<Res.y*.5-1. )\
        {forceView = vec2(1,1);offset=Res.zz;}\
        else if(fragCoord.x<Res.x*.5-2. && fragCoord.y>Res.y*.5+1. )\
        {forceView = vec2(1,7);offset=Res.zy;}\
        else if(fragCoord.x>Res.x*.5+1. && fragCoord.y<Res.y*.5-1. )\
        {forceView = vec2(1,3);offset=Res.xz;}\
        else if(fragCoord.x>Res.x*.5+1. && fragCoord.y>Res.y*.5+1. )\
        {forceView = vec2(0,0);offset=Res.xy;}\
        fragColor = vec4(renderRect(fragCoord*2.-offset),1);\
        if((fragCoord.x>Res.x*.5-1. && fragCoord.x<Res.x*.5+1.) || (fragCoord.y>Res.y*.5-1. && fragCoord.y<Res.y*.5+1.))fragColor = vec4(pow(THM_GRID,vec3(.4545)),1);\
    }else{\
        fragColor = vec4(renderRect(fragCoord),1);\
    }\
}int dummy\


