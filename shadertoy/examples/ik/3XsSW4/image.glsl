#define UI_AXIS 0
#define UI_GRID_2D 0
#define UI_GRID_3D 0
#define UI_ISOLINE 0

#define VIEW_QUAD 1

#define DBG_MATCAP 0
#define DBG_NORMAL 0
#define DBG_COST 0

#define CAM_SCALE .75
#define TURN_TABLE 0
#define TURN_TABLE_SPEED .5

struct IKBone{
    float len;
    vec3 tip;
    float pitch;
};

struct IKArmature{
    IKBone[3] bon;
    float yaw;
    bool inverted;
};

// Ref:"Foundation ActionScript 3.0 Animation" P.367
// Ref: https://www.alanzucconi.com/2020/09/14/inverse-kinematics-in-3d/
void calcIK(inout IKArmature ika){
    vec3 CA = ika.bon[0].tip-ika.bon[2].tip;
    ika.yaw = atan(CA.x, CA.z);
    ika.bon[2].tip.xz=rot(ika.bon[2].tip.xz,-ika.yaw);
    vec3 C = ika.bon[2].tip-ika.bon[0].tip;
    float a = ika.bon[1].len, b = ika.bon[2].len, c = min(a+b, length(C));
    float aB = acos((b*b-a*a-c*c)/(-2.*a*c));
    float aC = acos((c*c-a*a-b*b)/(-2.*a*b));
    float aD = atan(C.z, C.y);
    float dir = (ika.inverted) ? 1. : -1.;
    float aDB = PI*.5-(aD+aB*dir);
    float aE = aD+aB*dir+PI+aC*dir;
    ika.bon[1].tip = vec3(0,sin(aDB),cos(aDB))*a+ika.bon[0].tip;
    ika.bon[2].pitch = PI*.5-aE;
    ika.bon[1].pitch = aDB;
    ika.bon[1].tip.xz=rot(ika.bon[1].tip.xz,ika.yaw);
    ika.bon[2].tip.xz=rot(ika.bon[2].tip.xz,ika.yaw);
}

// https://suricrasia.online/demoscene/functions/
vec3 erot(vec3 p, vec3 ax, float ro) {
  return mix(dot(ax, p)*ax, p, cos(ro)) + cross(ax,p)*sin(ro);
}

float sdSphere(vec3 p,float s){
    return length(p)-s;
}

float sdCapsule(vec3 p,vec3 pos1,vec3 pos2,float r){
    vec3 ap=p-pos1,ab=pos2-pos1;
    float pro=clamp(dot(ap,ab)/dot(ab,ab),0.,1.);
    return length(ab*pro-ap)-r;
}

float sdBox( vec3 p, vec3 b ){
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdArc( in vec2 p, in vec2 sc, in float ra, float rb ){
    p.x = abs(p.x);
    return ((sc.y*p.x>sc.x*p.y) ? length(p-sc*ra) : 
                                  abs(length(p)-ra)) - rb;
}

float map(vec3 p){
    p.y+=.3;
    float t = iTime*1.;
    
    // init IK Armature(Bones)
    IKArmature ika;
    ika.inverted = true;
    ika.bon[0].len = 0.;
    ika.bon[1].len = .4;
    ika.bon[2].len = .5;

    ika.bon[0].tip = vec3(0,.2,0);
    vec3 offC = vec3(sin(t*.5), 0, cos(t*.5))*.5;
    float radC = .3;
    ika.bon[2].tip = vec3(sin(t)*radC, sin(t*.3)*.2+.3, cos(t)*radC) + offC;
    
    // calc IK
    calcIK(ika);
    
    // draw result
    float d = 3e38;
    bool drawBones = false;//int(floor(t*.1))%2 > 0;
    if(drawBones){
        // draw IK Bones
        d=min(d, sdCapsule(p,vec3(0),ika.bon[0].tip,.005));
        d=min(d, sdCapsule(p,ika.bon[0].tip,ika.bon[1].tip,.005));
        d=min(d, sdCapsule(p,ika.bon[1].tip,ika.bon[2].tip,.005));
        d=min(d, length(p-ika.bon[0].tip)-.025);
        d=min(d, length(p-ika.bon[1].tip)-.025);
        d=min(d, length(p-ika.bon[2].tip)-.025);
        d=min(d, max(abs(length(p.xz-offC.xz)-radC)-.01, abs(p.y-ika.bon[2].tip.y)-.01));
    }
    else{
    
        vec3 q = p;

        // roll along vector of root to tip
        #if 0
        vec3 axis = normalize(ika.bon[0].tip-ika.bon[2].tip);
        q-=ika.bon[0].tip;
        q = erot(q, axis, t);
        q+=ika.bon[0].tip;
        #endif
        
        // draw rigged primitives
        vec3 p0 = p-ika.bon[0].tip;
        p0.xz = rot(p0.xz, -ika.yaw);
        d=min(d, sdBox(p0+vec2(0,.1).xyx, vec2(.025,.1).xyx));
        d=min(d, max(length(p0.yz)-.025, abs(p0.x)-.025));

        // segment1
        vec3 p1 = q-ika.bon[1].tip;
        p1.xz = rot(p1.xz, -ika.yaw);
        p1.yz = rot(p1.yz, -ika.bon[1].pitch);
        d=min(d, sdBox(p1+vec2(0,ika.bon[1].len*.5).xxy, vec2(.025, ika.bon[1].len).xxy*.5));
        d=min(d, max(length(p1.yz)-.025, abs(p1.x)-.025));

        // segment2
        vec3 p2 = q-ika.bon[2].tip;
        p2.xz = rot(p2.xz, -ika.yaw);
        p2.yz = rot(p2.yz, -ika.bon[2].pitch);
        float hr = .1;
        d=min(d, sdBox(p2+vec2(0,ika.bon[2].len*.5+hr*.5).xxy, vec2(.025, ika.bon[2].len-hr).xxy*.5));
        
        // head
        p2.xy = rot(p2.xy, (sin(iTime*1.))*10.);
        d=min(d, max(length(p2.xz+vec2(0,hr))-.025, abs(p2.y)-.025));
        float an = -2.7+floor(sin(t*1.)*20.)*.05;
        vec2 c = vec2(sin(an),cos(an));
        d=min(d, max(sdArc(p2.xz+vec2(0,hr*.5), c, hr*.5, .01), abs(p2.y)-.01));
        
        // target
        d=min(d, length(p-ika.bon[2].tip)-.025);
    }
    
    // draw a stage
    d=min(d, max(length(p.xz)-.5, abs(p.y+.0125)-.0125));
        
    return d;
}

render();

