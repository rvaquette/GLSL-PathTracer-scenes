//#define SphereProjection
#define FixCaustics
const float EPSILONS = 0.0001;
const float EPSILONS_MIN = 0.001;
const int MaxReflect=1;//change it if your computer is too slow
const int MaxRayStep=20;
const float Far=500.0;
const float FogS=0.125;
const float FogStart=400.0;
const float AA=16.;
const float ShadowOffset=0.;
const vec2 DOF_Pos=vec2(0);
const float DOF_R=0.05;
const float FOV=0.5;
const float Marching_S=1.;
const float cut=1.;//change it if your computer is too slow
const int Type_Smoke=1;
const vec3 lightDir=normalize(vec3(0,-0.5,-0.5));//Sun light direction
#define EnableObjectLight
//#define EnableVoxel

#ifdef EnableObjectLight
vec4 centers[1]=vec4[1](vec4(0,0,0,1));
int ids[1]=int[1](2);
#endif

vec3 Position_00;

vec3 colors[MaxReflect];
vec3 LightColors[MaxReflect];
vec3 fog0[MaxReflect+1];
vec3 ro0s[MaxReflect];
vec3 rd0s[MaxReflect+1];
vec3 rd1s[MaxReflect+1];
vec4 rdinfo[MaxReflect+1];
float distance0s[MaxReflect+1];
float roughness0[MaxReflect];
vec3 directLight0[MaxReflect];
vec3 n0s[MaxReflect+1];
vec3 n1s[MaxReflect+1];
vec3 fog1_p[MaxReflect+1];
vec3 fog1_n[MaxReflect+1];
float fog1_s[MaxReflect+1];

float iFrame_;
object hit;
vec3 pos_0;




bool enablewater=true;
vec4 ObjectLight(vec3 ro,vec3 rd,vec3 n,vec3 center,float R,int id);
vec3 VoxelMap(vec3 pos);
object Voxel(object hit,vec3 p,vec3 rd);
float Smoke(vec3 p,vec3 rd,float density);

vec3 VoxelMap(vec3 pos){
    //inside voxel,voxel id,voxel inside material id
    return vec3(float(false),0,0);
}
object DE(vec3 pos,vec3 rd) {
    object hit0=newObj(Far,Far,-1,-1,0);
    vec3 pos0=pos;
    #ifdef EnableVoxel
        hit0=Voxel(hit0,pos,rd);
    #endif
    
    //near(material id,distance,inside material id)

    hit0=near(hit0,vec3(1,dPlane(pos,rd,vec4(0,1,0,1)),2));
    hit0=near(hit0,vec3(7,dSphere(pos,rd,1.),1));
    pos.z-=3.;
    pos.x+=3.;
    hit0=near(hit0,vec3(2,min(dBox(pos+vec3(0,1,0),rd,vec3(1,0.5,1)),dSphere(pos,rd,1.)),2));    
    pos.z+=3.;
    hit0=near(hit0,vec3(3,min(dBox(pos+vec3(0,1,0),rd,vec3(1,0.5,1)),dSphere(pos,rd,1.)),1));
    pos.z+=3.;
    hit0=near(hit0,vec3(4,min(dBox(pos+vec3(0,1,0),rd,vec3(1,0.5,1)),dSphere(pos,rd,1.)),1));
    pos.z+=3.;
    hit0=near(hit0,vec3(5,min(dBox(pos+vec3(0,1,0),rd,vec3(1,0.5,1)),dSphere(pos,rd,1.)),1));
    pos.x-=3.;
    hit0=near(hit0,vec3(6,min(dBox(pos+vec3(0,1,0),rd,vec3(1,0.5,1)),dSphere(pos,rd,1.)),1));

    return hit0;
}
material newMaterial(vec3 Cs,vec3 Cd,vec2 S,vec4 R,vec3 light){
    /*
    Cs:specular color
    Cd:diffuse color
    S:specular factor,transparent factor
    R:specular roughness,diffuse roughness,specular g,diffuse g
    light:light color
    
    g is a factor which controls the HGGX function.When it is set to (num1,num1+1e-4),it is GGX
    */
    material a;a.Cs=Cs;a.Cd=Cd;a.S=S;a.R=R;a.light=light;return a;
}
material Material(vec3 pos,vec3 nor,object o){
    if(o.id==2) return newMaterial(vec3(0.1),vec3(1),vec2(0,1),vec4(0,0,2,1.9),vec3(0));
    if(o.id==1) return newMaterial(vec3(0.025),texture(iChannel1,pos.xz).rgb,vec2(1,0),vec4(0.01,1,2,1.9),vec3(0));
    if(o.id==3) return newMaterial(vec3(0.1),vec3(0.5,1,0.6),vec2(1,0),vec4(0,1,2,1.9),vec3(0));
    if(o.id==4) return newMaterial(vec3(1),vec3(0.01),vec2(1,0),vec4(0.2,1,2,1.8),vec3(0));
    if(o.id==5) return newMaterial(vec3(0.1),vec3(1,0.5,0.3),vec2(0,0),vec4(0,1,2,1.9),vec3(0));
    if(o.id==6) return newMaterial(vec3(0.1),vec3(0.5,0.2,1),vec2(1,0),vec4(0.1,1,2,1.),vec3(0));
    if(o.id==7) return newMaterial(vec3(0.1),vec3(1,0.5,0.3),vec2(0,0),vec4(0,1,2,1.9),vec3(3,10,5));
    
    return newMaterial(vec3(1),vec3(1),vec2(1,0),vec4(0,1,2,2),vec3(0));}

vec4 InsideMaterial(vec3 pos,object o){
    /*
    x:dielectric refractive index
    y:medium type
    */
    if(o.i_id==1) return vec4(1.331,0,0,0);
    if(o.i_id==2) return vec4(1.301,0,0,0);

    return vec4(1,vec3(0));
}
vec4 InsideFog(vec3 pos,object o){
    /*
    x:scattering
    yzw:absorption
    */
    if(o.i_id==2) return vec4(0,5,0,0.25);
    return vec4(0);
}


float Smoke(vec3 pos,vec3 rd,float density){
    float s=0.01+hash13(pos+float(iFrame)+rd)*0.99;
    float d=-log(s)/density;
    return d;
}
object Voxel(object hit0,vec3 pos,vec3 rd){    
    object hit1=hit0;
    if(dot(rd,rd)<0.5){
        hit1=near(hit1,vec3(1,-sdBox(fract(pos)-0.5,vec3(0.5)),1));
    }else{

        vec3 lpos=fract(pos);
        vec3 rd0=max(abs(rd),1e-5)*sign(rd);
        vec3 A=min(max(-lpos/rd0,(1.-lpos)/rd0),1e5);
        float d=min(A.x,min(A.y,A.z));
        const float E=0.0025;
        vec3 map=VoxelMap(floor(pos+(d+E)*rd));
        d+=E*(map.x>0.?-1.:1.);
        d=max(0.,d);
        hit1=near(hit0,vec3(map.y,d,map.z));
    }
    return hit1;
}
vec4 getObjectLight(vec3 ro,vec3 rd,vec3 n){
#ifdef EnableObjectLight
    vec4 color=vec4(0);
    int id=int(clamp(floor(hash13(ro+float(iFrame))*float(ids.length())),0.,float(ids.length())));
    color+=ObjectLight(ro,rd,n,centers[id].xyz,centers[id].w,ids[id]);
    color.w*=float(ids.length());
    return max(color,0.);
#else
    return vec4(0);
#endif
}

const vec3 b_P=vec3(30000);//atmosphere thickness
const float b_k=0.25;//mix

 
const vec3 Mie=vec3(0.2);

const vec3 Rayleigh=5e10*pow(vec3(1./700.,1./520.,1./450.),vec3(4));
  
const vec3 b_k0=mix(Rayleigh,Mie,b_k);

const vec3 b_Q=b_k0/(b_P*b_P);//absorption
const vec3 b_Sun=0.8*vec3(10,10,10);//sun color
const vec3 b_g0=mix(Rayleigh*0.01,vec3(0.9),b_k);//single scatter
vec4 background(in vec3 pos, in vec3 n,in vec3 lightDir ) {
    vec3 n0=n;

    n.y=max(n.y,1e-5);
    vec3 g=3./(8.*PI)*(1.+pow(dot(n,lightDir),2.))*(1.-b_g0*b_g0)/(2.+b_g0*b_g0)/pow(1.+b_g0*b_g0-2.*b_g0*dot(lightDir,n),vec3(1.5));
    vec3 t=b_Q*0.5*(b_P-pos.y)*(b_P-pos.y);
    vec3 c=b_Sun*g*(exp(-t/n.y)-exp(-t/lightDir.y))/(n.y-lightDir.y)*max(lightDir.y,0.);

    c+=exp(-t/n.y)*b_Sun*smoothstep(0.997,0.9975,dot(n0,lightDir));
	 return vec4(clamp(c,0.,50.),1);
}
vec4 background(in vec3 pos, in vec3 n,in vec3 lightDir,float s,vec3 col ) {
    vec3 n0=n;
    if(n.y>0.) s=min((b_P.x-pos.y)/n.y,s);
    vec3 g=3./(8.*PI)*(1.+pow(dot(n,lightDir),2.))*(1.-b_g0*b_g0)/(2.+b_g0*b_g0)/pow(1.+b_g0*b_g0-2.*b_g0*dot(lightDir,n),vec3(1.5));
    vec3 t=b_Q*0.5*(b_P-pos.y)*(b_P-pos.y);
    vec3 s1=exp(b_Q*s*(0.5*s*n.y-(b_P-pos.y))*(1.-n.y/lightDir.y));
    vec3 c=b_Sun*g*exp(-t/lightDir.y)*(1.-s1)/(-n.y+lightDir.y)*max(lightDir.y,0.);
    c=abs(c);
    c=clamp(c,0.,50.);
    c+=exp(b_Q*0.5*n.y*s*s-b_Q*(b_P-pos.y)*s)*col;
	 return vec4(c,1);
}
float rand_i=0.;
float rand(vec3 p3)
{
    rand_i += 0.4;
    p3 += rand_i+float(iFrame_);
    p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}
float rand(vec2 p)
{
    rand_i += 0.4;
    p += rand_i+float(iFrame_);
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 = fract(tan(dot(p3,p3)*20.*atan(p3))) ;
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 rndS(vec3 pos){
    return normalize(tan(vec3(rand(pos)-0.5,rand(pos)-0.5,rand(pos)-0.5)))*rand(pos);
}
vec3 estimateNormal(vec3 pos) {
    float EPSILON=EPSILONS*distance(pos,pos_0);
    vec2 e = vec2(1.0,-1.0)*0.5773*EPSILON;
    vec3 rd=vec3(0,0,0);
    return normalize( e.xyy*DE( pos + e.xyy ,rd).d2 + 
					  e.yyx*DE( pos + e.yyx ,rd).d2 + 
					  e.yxy*DE( pos + e.yxy ,rd).d2 + 
					  e.xxx*DE( pos + e.xxx ,rd).d2 );
}


vec3 raycast(vec3 ro,vec3 rd,out float distance_,float alpha,out bool ifSmoke){
    float lastd0=0.;
    bool hit00=false;
    vec3 ro0=ro;
    vec3 rd0=rd;
    bool a=false;
    ifSmoke=false;
    float t=0.;
    float Marching_S_2=1.;
    int sgn =DE(ro,rd).s;
    for(int i=0;i<MaxRayStep;i++){
        object o=DE(ro,rd);
        if(o.s!=sgn){
            ro=ro0;rd=rd0;
            Marching_S_2*=0.75;
            continue;
        }
        ro0=ro;rd0=rd;
        float d0=o.d;
        float EPSILON=max(EPSILONS*distance(ro,pos_0),EPSILONS_MIN);
        bool b=a&&int(InsideMaterial(ro,o).y)==Type_Smoke;
        bool c=d0<=EPSILON&&d0<lastd0||Marching_S_2<=EPSILONS_MIN||b;
        if(c||distance(ro,Position_00)>Far){
            ifSmoke=b;hit00=c; break;
        }
        a=true;
        if(distance(ro,Position_00)>Far) break;
        float d_d=d0*Marching_S*Marching_S_2;
        float rnd_d=sqrt(-log(rand(ro))/max(alpha,1e-10));
        float no_rnd=float(rnd_d>d_d||alpha==0.);
        rd=mix(rndS(ro),rd,no_rnd);
        d_d=no_rnd==0.?rnd_d:d_d;
        lastd0=d0;ro+=d_d*rd;t+=d_d;

    }
    distance_=mix2(-1.,t,float(hit00));
    return ro;
}

/*
This distribution was inspired by GGX function

I replaced the denominator of the GGX distribution with a general quadratic function,then I got it

This distribution can be written in anisotropic form

Replace the roughness parameter "a" if you want the anisotropic distribution
*/

float HGGX_Lamda(float VoN,float a,vec2 g){
    float tan2=1./(VoN*VoN)-1.;
    vec2 A=sqrt(1.+g*a*a*tan2);
    return (log((1.+A.y)/(1.+A.x))-A.y+A.x)/log(g.x/g.y);
}

float HGGX_G2(float VoN,float LoN,float a,vec2 g){
    float L1=HGGX_Lamda(VoN,a,g);float L2=HGGX_Lamda(LoN,a,g);
    return clamp((1.+L1)/(1.+L2+L1),0.,1.);
}
vec3 HGGXNormal(vec3 normal,float roughness,vec2 g,vec3 pos){
    vec3 randN0;randN0.y=-length(normal.xz);
    if(length(normal.xz)<=0.)
        randN0.xz=vec2(1,0);
    else
        randN0.xz=normalize(normal.xz)*normal.y;
    vec3 randN1=cross(normal,randN0);
    float alpha=rand(pos)*2.*PI;
    float tmp=rand(pos);
    vec2 A=pow(g,vec2(tmp-1.));
    float beta=roughness*atan(dot(A,vec2(-g.x,g.y))/(A.x-A.y));
    
    return (cos(beta))*normal+sin(beta)*(cos(alpha)*randN0+sin(alpha)*randN1);
}
float HGGXdf(float theta,float fai,float a,vec2 g){
    float a2=a*a;
    float cos2=cos(theta);cos2*=cos2;
    vec2 A=1.+(g*a2-1.)*cos2;
    return 1.-log(A.x/A.y)/log(g.x/g.y);
}
float HGGXpdf(float theta,float fai,float a,vec2 g){
    float a2=a*a;
    float cos2=cos(theta);cos2*=cos2;
    vec2 A=1.+(g*a2-1.)*cos2;
    return a2*(g.x-g.y)*cos(theta)/(log(g.x/g.y)*PI*A.x*A.y);
}



//sample direct light
vec4 ObjectLight(vec3 ro,vec3 rd,vec3 n,vec3 center,float sR,int id){
    object thit=hit;
    float d=distance(ro,center);
    vec3 tnor;
    float cosD_S;

    if(d<=sR){
        cosD_S=-1.;
        tnor=reflect(rd,n);
    }else{
        float RDivd=sR/d;
        cosD_S=1./sqrt(1.+RDivd*RDivd);
        tnor=normalize(center-ro);
    }
    

    float EPSILON=max(EPSILONS*distance(ro,pos_0),EPSILONS_MIN);
    object oA=DE(ro,vec3(0));
    object oB=DE(ro-n*EPSILON*2.,vec3(0));
    vec4 MaterialA=InsideMaterial(ro,oA);vec4 MaterialB=InsideMaterial(ro-n*EPSILON*2.,oB);
    float rs=MaterialB.x/MaterialA.x;
    material mt=Material(ro,n,oA);
    
    
    vec3 randN=HGGXNormal(n,mt.R.x,mt.R.zw,ro);
    float k=fresnel(-n,randN,rs);
    vec4 rC=rColor(mt.Cs,max(dot(-rd,randN),0.));
    float p=mixp(rC.w,mt.S.x);
    float spec=float(rand(ro)<p);
    float R=mix(mt.R.y,mt.R.x,spec);
    
    float S=0.;    
    float r1=rand(ro);
    float alpha=rand(ro)*2.*PI;
    float beta=acos(1.-r1*(1.-cosD_S));

    vec3 lD=tnor;
    //local axis
    vec3 randN0;randN0.y=-length(lD.xz);
    if(length(lD.xz)<=0.)
        randN0.xz=vec2(1,0);
    else
        randN0.xz=normalize(lD.xz)*lD.y;
    vec3 randN1=cross(lD,randN0);
    
    vec3 rnd=(cos(beta))*lD+sin(beta)*(cos(alpha)*randN0+sin(alpha)*randN1);

    lD=n;
    randN0;randN0.y=-length(lD.xz);
    if(length(lD.xz)<=0.)
        randN0.xz=vec2(1,0);
    else
        randN0.xz=normalize(lD.xz)*lD.y;
    randN1=cross(lD,randN0);
    beta=acos(clamp(-dot(normalize(-rnd+rd),n),0.,1.));
    alpha=0.;

    float t=0.;
    vec4 fog=InsideFog(ro,oA);
    bool ifSmoke;
    vec3 tp=raycast(ro+rnd*ShadowOffset,rnd,t,fog.x,ifSmoke);
    if(t<-0.5) return vec4(0);


    oA=DE(tp,vec3(0));
    vec3 pos=tp;
    vec3 normal=estimateNormal(pos);
    mt=Material(pos,normal,oA);
    hit=thit;

    S=HGGXpdf(beta,alpha,R,mt.R.zw);
    
    vec3 sampleColor=mt.light;
    rC=rColor(mt.Cs,max(dot(rd,normalize(-rnd+rd)),0.));
    sampleColor*=mt.Cd*(1.-mt.S.x*rC.rgb)+mt.S.x*rC.rgb;

    float G1=max(dot(rnd,n),0.);
    float IoN=abs(dot(rd,n));
    float OoN=abs(dot(rnd,n));
    float IoH=abs(dot(rd,randN));
    float NoH=abs(dot(n,randN));
    float G2=HGGX_G2(IoN,OoN,R,mt.R.zw);
    spec*=G2;
    sampleColor*=mix2(G1,G2*0.25/IoH,spec);
   
    return max(vec4(0),vec4(sampleColor,S*(1.-cosD_S)*50.));

}

vec4 SunLight(vec3 ro,vec3 rd,vec3 n){
    const float S_R=0.125;
    float cosD_S=1./sqrt(1.+S_R*S_R);

    float EPSILON=max(EPSILONS*distance(ro,pos_0),EPSILONS_MIN);
    object oA=DE(ro,vec3(0));
    object oB=DE(ro-n*EPSILON*2.,vec3(0));
    vec4 MaterialA=InsideMaterial(ro,oA);vec4 MaterialB=InsideMaterial(ro-n*EPSILON*2.,oB);
    float rs=MaterialB.x/MaterialA.x;
    material mt=Material(ro,n,oA);
    
    
    vec3 randN=HGGXNormal(n,mt.R.x,mt.R.zw,ro);
    float k=fresnel(-n,randN,rs);
    vec4 rC=rColor(mt.Cs,max(dot(-rd,randN),0.));
    float p=mixp(rC.w,mt.S.x);
    float spec=float(rand(ro)<p);
    float R=mix(mt.R.y,mt.R.x,spec);
    
    float S=0.;    
    float r1=rand(ro);
    float alpha=rand(ro)*2.*PI;
    float beta=acos(1.-r1*(1.-cosD_S));

    vec3 lD=lightDir;
    //local axis
    vec3 randN0;randN0.y=-length(lD.xz);
    if(length(lD.xz)<=0.)
        randN0.xz=vec2(1,0);
    else
        randN0.xz=normalize(lD.xz)*lD.y;
    vec3 randN1=cross(lD,randN0);
    
    vec3 rnd=(cos(beta))*lD+sin(beta)*(cos(alpha)*randN0+sin(alpha)*randN1);

    lD=n;
    randN0;randN0.y=-length(lD.xz);
    if(length(lD.xz)<=0.)
        randN0.xz=vec2(1,0);
    else
        randN0.xz=normalize(lD.xz)*lD.y;
    randN1=cross(lD,randN0);
    beta=acos(clamp(-dot(normalize(rnd+rd),n),0.,1.));
    alpha=0.;

    float t=0.;
    vec4 fog=InsideFog(ro,oA);
    bool ifSmoke;
    vec3 tp=raycast(ro-rnd*ShadowOffset,-rnd,t,fog.x,ifSmoke);
    if(t>-0.5) return vec4(0);
    vec4 tmp=background(ro,-rnd,-lightDir);

    S=HGGXpdf(beta,alpha,R,mt.R.zw);
    
    vec3 sampleColor=tmp.xyz;
    rC=rColor(mt.Cs,max(dot(rd,normalize(rnd+rd)),0.));
    sampleColor*=mt.Cd*(1.-mt.S.x*rC.rgb)+mt.S.x*rC.rgb;

    float G1=max(dot(-rnd,n),0.);
    float IoN=abs(dot(rd,n));
    float OoN=abs(dot(rnd,n));
    float IoH=abs(dot(rd,randN));
    float NoH=abs(dot(n,randN));
    float G2=HGGX_G2(IoN,OoN,R,mt.R.zw);
    spec*=G2;
    sampleColor*=mix2(G1,G2*0.25/IoH,spec);
    return max(vec4(0),vec4(sampleColor,S)*(dot(rnd,lightDir)-0.997>0.?1.:0.));
}

float calcS(vec4 r1,vec4 r2,vec3 n,float K,float u){//an interesting equation
    float t1=dot(r1.xyz,n);
    float t2=dot(r2.xyz,n);
    return (K*dot(r1.xyz*r1.w+r2.xyz*r2.w,n)-u*r1.w*t1*t1)/max(r2.w*t2*t2,1e-4);
}

float calcK(vec3 ro,vec3 n){//calculate the normal curvature of an sdf
    float EPSILON=max(EPSILONS*distance(ro,pos_0),EPSILONS_MIN);

    vec3 p[4];
    p[0]=normalize(vec3(1,1,1))*EPSILON;
    p[1]=normalize(vec3(1,-1,-1))*EPSILON;
    p[2]=normalize(vec3(-1,-1,1))*EPSILON;
    p[3]=normalize(vec3(-1,1,-1))*EPSILON;
    #define z0 vec3(0)
    float s[10];
    int i0=0;
    for(int i=0;i<4;i++){
        for(int j=i;j<4;j++){
            s[i0]=DE(ro+p[i]+p[j],z0).d2;
            i0++;
        }
    }
        
    vec3 dDE=s[0]*p[0]+s[4]*p[1]+s[7]*p[2]+s[9]*p[3];
    vec3 N=cross(n,dDE);
    float t1=dot(p[0],N);
    float t2=dot(p[1],N);
    float t3=dot(p[2],N);
    float t4=dot(p[3],N);
    
    float k=2./(dot(p[0],p[0])*pow(length(N),3.));
    k*=s[0]*t1*t1+s[4]*t2*t2+s[7]*t3*t3+s[9]*t4*t4
        +2.*(s[1]*t1*t2+s[2]*t1*t3+s[3]*t1*t4+s[5]*t2*t3+s[6]*t2*t4+s[8]*t3*t4);
    return k*0.75;
}
vec2 Projection(vec2 p,float S){
    #ifdef SphereProjection
        if(length(p)==0) return p;
        return normalize(p)*tan(length(p)*S);
    #else
        return p*S;
    #endif
}
vec4 frag_0;
void Store(vec4 c){
    frag_0=c;
}
vec2 uv00;
vec4 Load(){
    return texture(iChannel0,uv00);
}

vec3 bloom(vec2 pos){
    vec2 p0=pos;
    vec3 c=vec3(0);
    const int amount=4;
    for(int i=0;i<amount;i++){
        pos=p0;
        float a=2.*PI*rand(pos*50.+float(iFrame));
        float b=sqrt(-log(0.975*rand(pos*50.+float(iFrame)+10.)+0.075));
        
        //bloom shape
        vec2 tmp=vec2(cos(a)*1.5,sin(a)*1.);
        pos+=b*pow(abs(tmp),vec2(1.5))*sign(tmp);
        
        pos-=p0;
        pos=normalize(pos)*pow(length(pos),6.)*10e-3;
        vec4 A=texture(iChannel0,clamp(vec2(0,0.5)+(pos+p0-vec2(0,0.5))*vec2(1,iResolution.x/iResolution.y),0.,1.));
        if(iFrame_==0.)
            c+=vec3(0);
        else
            c+=max(A.xyz,0.);
    }
    c/=float(amount);
    float l=luma(c);
    return c*smoothstep(0.25,2.,l)*1.5;
}
void F(float x,float y,vec3 Eye_Direction,vec3 Position){
    if(abs(y)>9.0/16.) {Store(Load());return;}
    iFrame_=floor(float(iFrame)/cut);
    float divCut=1.0/cut;
    float iFrame_offset=mod(float(iFrame),cut)*divCut;
    if(0.5*y+0.5<iFrame_offset||0.5*y+0.5>=iFrame_offset+divCut||float(iFrame_)>AA*AA) {Store(Load());return;}
    float x0=mod(float(iFrame_),AA)/AA;
    float y0=floor(float(iFrame_)/AA)/AA;
    float iW=iResolution.x;
    x+=1.0/iW*x0;
    y+=1.0/iW*y0;
    
    vec3 n=normalize((rot(vec3(Projection(vec2(x,y),FOV),1),Eye_Direction)).xyz);
    vec3 n_m=normalize((rot(vec3(Projection(DOF_Pos,FOV),1),Eye_Direction)).xyz);

    vec3 pos=Position;
    float DOF=0.1;
    bool ifSmoke;
    if(DOF_R>0.) raycast(pos,n_m,DOF,0.,ifSmoke);
    if(DOF<-0.5) DOF=Far;
    vec3 Q=pos+n*DOF;
    vec3 X;X.y=-length(n.xz);
    vec3 Y;Y.xz=(float(length(n.xz)==0.)*vec2(1,0)+normalize(n.xz))*n.y;
    Y=cross(n,X);float tmp_1=rand(pos+vec3(x,iFrame,y))*2.*PI;
    float tmp_2=rand(pos+vec3(x,iFrame,y+5.));
    n=normalize(n+tmp_2*DOF_R/DOF*(X*sin(tmp_1)+Y*cos(tmp_1)));
    pos=Q-DOF*n;
    
    vec3 pos00=pos;
    pos_0=pos00;
    vec3 tcolor=vec3(0);
    for(int i=0;i<=MaxReflect;i++) {
        fog0[i]=vec3(1);
        rdinfo[i]=vec4(0,0,0,1);
    }

    int reflectstep=0;
    bool hit0=false;
    float depth=Far;
    vec3 back=background(pos,n,-lightDir).xyz;

    object oA0=DE(pos,vec3(0));
    vec3 fogS_=InsideFog(pos,oA0).yzw;

    vec3 n_0=n;
    vec4 fog=InsideFog(pos,oA0);

    for(reflectstep=0;reflectstep<MaxReflect;reflectstep++){
        float t=0.;
        bool ifSmoke;
        vec3 nextpos=raycast(pos,n,t,fog.x,ifSmoke);
        if(t<-0.5) break;
        distance0s[reflectstep]=t;
        pos=nextpos;
        float EPSILON=max(EPSILONS*distance(pos,pos_0),EPSILONS_MIN);
        object oA=DE(pos,vec3(0));
        vec3 normal=ifSmoke?rndS(pos):estimateNormal(pos);
        n1s[reflectstep]=normal; 
        normal=faceforward(normal,normal,n);
        n0s[reflectstep]=normal;
        object oB=DE(pos-normal*EPSILON*2.,vec3(0));
        vec4 MaterialA=InsideMaterial(pos,oA);
        vec4 MaterialB=InsideMaterial(pos-normal*EPSILON*2.,oB);
        vec4 FogA=InsideFog(pos,oA);
        vec4 FogB=InsideFog(pos-normal*EPSILON*2.,oB);
        float rs=MaterialB.x/MaterialA.x;
        material material=Material(pos,normal,oA);


        fog0[reflectstep]=exp(-t*fogS_);
        fog1_s[reflectstep]=t;
        fog1_p[reflectstep]=pos;
        fog1_n[reflectstep]=n;
        LightColors[reflectstep]=material.light;
 
        rd0s[reflectstep]=n;
        ro0s[reflectstep]=pos;
        
        vec3 I_=vec3(1);int i=0;
        float R;
        vec4 rdinfo_;
        rdinfo_.w=1.;
        rdinfo_.y=MaterialA.x;
        vec3 n0,randN;
        float spec;
        bool refract_;
        #if 0
        do{//this code has some weird bugs on several platforms 
            i++;refract_=false;
            n0=n;
            randN=HGGXNormal(normal,material.R.x,material.R.zw,pos);
            float F=fresnel(-n,randN,rs);
            
            vec4 rC=rColor(material.Cs,max(dot(-n,randN),0.));
            roughness0[reflectstep]=material.R.x;
            
            float p=mixp(rC.w,material.S.x);
            bool b0=rand(pos)<p;
            R=mix(material.R.y,material.R.x,float(b0));
            spec=float(b0);
            if(b0){
                I_*=rC.rgb*(1.+(material.S.x-1.)*rC.w)/max(rC.w,1e-5);
                refract_=false;
            }else{
                I_*=material.Cd*(1.+(material.S.x-1.)*rC.w)/max(1.-rC.w,1e-5)*(1.-material.S.x*rC.rgb);
                randN=HGGXNormal(normal,material.R.y,material.R.zw,pos);
                refract_=rand(pos)<material.S.y*(1.-F);
                roughness0[reflectstep]=material.R.y;
            
            }
            vec3 v0=mix(reflect(n,randN),refract(n,randN,1./rs),float(refract_));
            bool a; fogS_=FogA.yzw;
            rdinfo_.z=MaterialA.x;
            if(refract_){
                if(v0==vec3(0)){
                    v0=reflect(n,randN);a=dot(normal,v0)>0.;
                    refract_=false;
                }else{
                    rdinfo_.z=MaterialB.x;
                    pos-=2.*EPSILON*normal;a=dot(normal,v0)<0.;
                    fogS_=FogB.yzw;
                }
            }else{a=dot(normal,v0)>0.;rdinfo_.w*=float(b0);}
            n=v0;if(a) break;
        }while(i<16);
        #else
        {
            do{
                  randN=HGGXNormal(normal,material.R.x,material.R.zw,pos);
                  vec3 n00=reflect(randN,n);
                  if(dot(n00,normal)>0.) break;
                  i++;
            }while(i<16);
            
            
            n0=n;
            float F=fresnel(-n,randN,rs);
            
            vec4 rC=rColor(material.Cs,max(dot(-n,randN),0.));
            roughness0[reflectstep]=material.R.x;
            
            float p=mixp(rC.w,material.S.x);
            bool b0=rand(pos)<p;
            R=mix(material.R.y,material.R.x,float(b0));
            spec=float(b0);
            if(b0){
                I_*=rC.rgb*(1.+(material.S.x-1.)*rC.w)/max(rC.w,1e-5);
                refract_=false;
            }else{
                I_*=material.Cd*(1.+(material.S.x-1.)*rC.w)/max(1.-rC.w,1e-5)*(1.-material.S.x*rC.rgb);
                randN=HGGXNormal(normal,material.R.y,material.R.zw,pos);
                refract_=rand(pos)<material.S.y*(1.-F);
                roughness0[reflectstep]=material.R.y;
            
            }
            vec3 v0=mix(reflect(n,randN),refract(n,randN,1./rs),float(refract_));
            bool a; fogS_=FogA.yzw;
            rdinfo_.z=MaterialA.x;
            if(refract_){
                if(v0==vec3(0)){
                    v0=reflect(n,randN);a=dot(normal,v0)>0.;
                    refract_=false;
                }else{
                    rdinfo_.z=MaterialB.x;
                    pos-=2.*EPSILON*normal;a=dot(normal,v0)<0.;
                    fogS_=FogB.yzw;
                }
            }else{a=dot(normal,v0)>0.;rdinfo_.w*=float(b0);}
            n=v0;
            
        }
        
        #endif
        
        float IoN=abs(dot(n0,normal));
        float OoN=abs(dot(n,normal));
        float IoH=abs(dot(n0,randN));
        float NoH=abs(dot(normal,randN));
        float G0=HGGX_G2(IoN,OoN,R,material.R.zw);
        float G2=G0;
        spec*=G2;
        float G1=(refract_?1.:max(dot(n,normal),0.));

        I_*=mix2(G1,G2,spec);

        colors[reflectstep].xyz=I_;
        rd1s[reflectstep]=n;
        #ifdef FixCaustics
        vec3 td=cross(n,rd0s[reflectstep]);
        td=td==vec3(0,0,0)?cross(rd0s[reflectstep].yzx,rd0s[reflectstep]):td;
        rdinfo_.x=calcK(pos,normalize(td));
        rdinfo[reflectstep]=rdinfo_;
        #endif

        if(!hit0) {depth=distance(pos,pos00);}
        hit0=true;
        oA=DE(pos,vec3(0));
        fog=FogA;

        if(distance(pos,pos00)>Far) break;
    }
    fog0[reflectstep]=exp(-1e10*fogS_);
    enablewater=false;

    tcolor=background(pos,n,-lightDir).xyz;
    if(!hit0) tcolor*=fog0[reflectstep];
    enablewater=false;
    int j0=-1,j1=-1;float p_0=0.,p_1=0.;
    float A=0.;
    for(int i=reflectstep-1;i>=0;i--) {
        A+=roughness0[i]*roughness0[i];
        directLight0[i]=vec3(0);
    }
    float A_0=A;
    //sample Sun and Objects

    if(A>0.){
        bool a=true;
        bool c0=true,c1=true;
        for(int i=reflectstep-1;i>=0&&a;i--){
            float p=roughness0[i]*roughness0[i]/A;
            bool b0=rand(pos)<p&&c0;
            j0=b0?i:j0;p_0=b0?p:p_0;
            c0=b0?false:c0;
            b0=rand(pos)<p&&c1;
            j1=b0?i:j1;p_1=b0?p:p_1;
            c1=b0?false:c1;
            a=c0||c1;
            A-=roughness0[i]*roughness0[i];
        }
    }

    if(j0>=0){
        vec4 sunL=SunLight(ro0s[j0],rd0s[j0],n0s[j0]);
        directLight0[j0]+=sunL.xyz*sunL.w/p_0;
    }
    if(j1>=0){
        vec4 objL=getObjectLight(ro0s[j1],rd0s[j1],n0s[j1]);
        directLight0[j1]+=objL.xyz*objL.w/p_1;
    }
    
    float L_S=1.;
    
    for(int i=reflectstep-1;i>=0;i--){
        vec3 a=tcolor;
        a=background(fog1_p[i+1],fog1_n[i+1],lightDir,fog1_s[i+1],a).xyz;
        bool diffuse=rdinfo[i].w==0.;
        tcolor=mix2(L_S,1.,rdinfo[i].w)*a*fog0[i+1]*colors[i]+directLight0[i]+LightColors[i];
        #ifdef FixCaustics
        if(diffuse) L_S=1.;
        else{
            float b=rdinfo[i].z*dot(rd1s[i],n0s[i])/(rdinfo[i].y*dot(rd0s[i],n0s[i]));
            L_S*=b*b;
        }
        #endif

    }
    if(hit0) tcolor=fog0[0]*background(fog1_p[0],fog1_n[0],-lightDir,fog1_s[0]*FogS,tcolor).xyz;


    tcolor=!hit0?back:tcolor;
    tcolor=clamp(tcolor,0.,4.);

    //bloom
    vec3 bloom=bloom(vec2(x,y)*0.5+0.5);
    tcolor=max(tcolor,bloom);
    
    if(iFrame_<=0.){
        Store(vec4(tcolor,0.));
    }else{
        vec4 temp0=Load();
        Store((temp0*float(iFrame_)+vec4(tcolor,0))/(float(iFrame_)+1.));
    }
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;
    uv00=uv;
    vec3 m=vec3(0.57,-7.42,0);//camera rotation
    vec3 p=vec3(-12.5,6.65,-6.82);//camera position

    F(2.*uv.x-1.,(2.*uv.y-1.)/iResolution.x*iResolution.y,m,p);

    fragColor = frag_0;
}

