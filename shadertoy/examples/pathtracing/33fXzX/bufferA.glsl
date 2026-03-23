//#define SphereProjection
const float EPSILONS = 0.000005;
const float EPSILONS_MIN = 0.001;
const int MaxReflect=5;
const int MaxRayStep=400;
const float Far=500.0;
const float FogS=0.125;
const float FogStart=400.0;
const float SSAA=16.;
const float ShadowOffset=0.;
const vec2 DOF_Pos=vec2(0);
const float DOF_R=0.;
const float FOV=0.5;
const float Marching_S=1.;
const float cut=32.;
const vec3 lightDir=normalize(vec3(0.5,-0.5,.25));//Sun light direction
//#define EnableObjectLight

#ifdef EnableObjectLight
vec4 centers[1]=vec4[1](vec4(0,0,0,1));
int ids[1]=int[1](2);
#endif


#define Rayleigh 1.
#define Mie 1.
#define RayleighAtt 1.
#define MieAtt 1.2

float g = -0.99;

#if 1
vec3 _betaR = vec3(1.95e-2, 1.1e-1, 2.94e-1); 
vec3 _betaM = vec3(4e-2, 4e-2, 4e-2);
#else
vec3 _betaR = vec3(6.95e-2, 1.18e-1, 2.44e-1); 
vec3 _betaM = vec3(4e-2, 4e-2, 4e-2);
#endif

struct object{
    float d;float d2;int id;int i_id;
};
struct material{
    vec3 Cs;vec3 Cd;vec3 S;vec2 R;vec3 light;
};


vec3 Position_00;

vec3 colors[MaxReflect];
vec3 LightColors[MaxReflect];
vec3 fog0[MaxReflect+1];
float Gs0[MaxReflect+1];

float iFrame_;
object hit;
vec3 pos_0;




bool enablewater=true;
vec4 ObjectLight(vec3 ro,vec3 rd,vec3 n,vec3 center,float R,int id);

float rand(vec2 pos){
    return fract(sin(dot(pos.xy*0.123 ,vec2(12.9898,78.233))) * 43758.5453);
}
float randT2(vec2 pos){
    pos+=float(iFrame);
    return fract(sin(dot(pos.xy*0.123 ,vec2(12.9898,78.233))) * 43758.5453);
}
float rand3(vec3 pos){
    return fract(sin(dot(pos*0.123 ,vec3(12.9898,78.233,233.2342))) * 43758.5453);
}
float rand_i=0.;
float rand(vec3 pos){
    rand_i+=4.4;
    pos+=rand_i+float(iFrame_);
    return fract(sin(dot(pos*0.123 ,vec3(12.9898,78.233,265.2431))) * 43758.5453);
}
vec3 rndS(vec3 pos){
    return normalize(tan(vec3(rand(pos.xy)-0.5,rand(pos.yz)-0.5,rand(pos.zx)-0.5)))*rand(pos);
}
float randAB(float A,float B,float s,vec3 pos){
    return mix2(A,B,float(s>rand(pos)));
}


object DE(vec3 pos) {
    vec4 hit0=vec4(-1,Far,-1,Far);
    vec3 pos0=pos;object hit1;

    hit0=near(hit0,vec3(1,pos.y+1.,1));
    vec2 p=pos.xz;p=mod(p+1.5,3.)-1.5;
    hit0=near(hit0,vec3(2,max(sdSphere(vec3(p.x,pos.y,p.y),1.),sdBox(pos,vec3(10,1,10))),2));  

    hit1.id=int(hit0.x);hit1.d=hit0.y;
    hit1.d2=hit0.w;hit1.i_id=int(hit0.z);
    return hit1;
}
material newMaterial(vec3 Cs,vec3 Cd,vec3 S,vec2 R,vec3 light){
    material a;a.Cs=Cs;a.Cd=Cd;a.S=S;a.R=R;a.light=light;return a;
}
material Material(vec3 pos,vec3 nor,object o){
    if(o.id==2){
        vec2 p=clamp(floor(pos.xz/3.+3.5)/6.,0.,1.);
        return newMaterial(vec3(1,1,1),vec3(0.,0.8,0.8),vec3(p,0),vec2(0,1),vec3(0));
     }
    return newMaterial(vec3(1),vec3(0.9,0.9,0.9),vec3(0,0,0),vec2(0,0.2),vec3(0));
}

vec4 InsideMaterial(vec3 pos,object o){
    if(o.i_id==1) return vec4(2.51,0,0,0);
    if(o.i_id==2) return vec4(2.301,0,0,0);
    return vec4(1,vec3(0));
}
vec4 InsideFog(vec3 pos,object o){
    return vec4(0);
}

vec4 getObjectLight(vec3 ro,vec3 rd,vec3 n){
#ifdef EnableObjectLight
    vec4 color=vec4(0);
    int id=int(clamp(floor(rand3(ro+iFrame)*ids.length()),0,ids.length()));
    color+=ObjectLight(ro,rd,n,centers[id].xyz,centers[id].w,ids[id]);
    color.w*=ids.length();
    return max(color,0.);
#else
    return vec4(0);
#endif
}



vec3 Rcolor(vec3 light,vec3 color,vec3 s){
    vec3 hsv=rgb2hsv(light);
    vec3 hsv2=rgb2hsv(color);
    hsv.xy=mix(hsv.xy,hsv2.xy,s.x);
    hsv.z*=hsv2.z;
    return mix(hsv2rgb(hsv),light*color,s.y);
}


vec4 background(in vec3 pos, in vec3 n,in vec3 lightDir ) {


    float M = 1.0; //canvas.innerWidth/M //canvas.innerHeight/M --res

    vec3 O =pos;
	 vec3 D =n;
	 vec3 color = vec3(0.);
    
    float t = max(0.001, D.y);

      // optical depth -> zenithAngle
    float divt=1./t;
    float sR = RayleighAtt * divt ;
    float sM = MieAtt * divt ;

  	 float cosine = clamp(dot(D,lightDir),0.0,1.0);
    vec3 extinction = exp(-(_betaR * sR + _betaM * sM));

       // scattering phase
    float g2 = g * g;
    float fcos2 = cosine * cosine;
    float miePhase = Mie * pow(1. + g2 + 2. * g * cosine, -1.5) * (1. - g2) / (2. + g2);
        //g = 0;
    float rayleighPhase = Rayleigh;

    vec3 inScatter = (1. + fcos2) * vec3(rayleighPhase + _betaM / _betaR * miePhase);

    color = inScatter*(1.0-extinction); // *vec3(1.6,1.4,1.0)

        // sun
    color += 0.47*vec3(1.6,1.4,1.0)*pow( cosine, 350.0 ) * extinction;
      // sun haze
    color += 0.4*vec3(0.8,0.9,1.0)*pow( cosine, 2.0 )* extinction;

	 return vec4(clamp(color,0.,50.),1.);
}

vec3 estimateNormal(vec3 pos) {
    float EPSILON=EPSILONS*distance(pos,pos_0);
    vec2 e = vec2(1.0,-1.0)*0.5773*EPSILON;
    return normalize( e.xyy*DE( pos + e.xyy ).d2 + 
					  e.yyx*DE( pos + e.yyx ).d2 + 
					  e.yxy*DE( pos + e.yxy ).d2 + 
					  e.xxx*DE( pos + e.xxx ).d2 );
}



vec3 raycast(vec3 ro,vec3 rd,out float distance_,float alpha){
    float lastd0=0.;
    bool hit00=false;
    vec3 ro0=ro;
    for(int i=0;i<MaxRayStep;i++){
        float d0=DE(ro).d;
        float EPSILON=max(EPSILONS*distance(ro,pos_0),EPSILONS_MIN);
        if(d0<=EPSILON&&d0<lastd0){hit00=true; break;}
        float t=distance(ro,pos_0);
        if(t>Far) break;
        float d_d=d0*Marching_S;
        rd=mix(rndS(ro),rd,float(rand(ro)<exp(-d_d*alpha)));
        lastd0=d0;ro+=d_d*rd;
    }
    distance_=mix2(-1.,distance(ro,ro0),float(hit00));
    return ro;
}

vec3 GGXNormal(vec3 normal,float roughness,vec2 X,vec2 Y,vec3 pos){
    vec3 randN0;randN0.y=-length(normal.xz);
    if(length(normal.xz)<=0.)
        randN0.xz=vec2(1,0);
    else
        randN0.xz=normalize(normal.xz)*normal.y;
    vec3 randN1=cross(normal,randN0);
    float alpha=mix2(X.x,X.y,rand(pos))*2.*PI;
    float tmp=mix2(Y.x,Y.y,rand(pos));
    float beta=acos(clamp(sqrt(max(0.,(1.-tmp)/(1.+tmp*(roughness*roughness-1.)))),0.,1.));
        
    return (cos(beta))*normal+sin(beta)*(cos(alpha)*randN0+sin(alpha)*randN1);
}
vec3 GGXNormal(vec3 normal,float roughness,vec3 pos){
    vec3 randN0;randN0.y=-length(normal.xz);
    if(length(normal.xz)<=0.)
        randN0.xz=vec2(1,0);
    else
        randN0.xz=normalize(normal.xz)*normal.y;
    vec3 randN1=cross(normal,randN0);
    float alpha=rand(pos)*2.*PI;
    float tmp=rand(pos);
    float beta=acos(clamp(sqrt(max(0.,(1.-tmp)/(1.+tmp*(roughness*roughness-1.)))),0.,1.));
        
    return (cos(beta))*normal+sin(beta)*(cos(alpha)*randN0+sin(alpha)*randN1);
}
float GGXdf(float theta,float a){
    float a2=a*a;
    float cos2=cos(theta);cos2*=cos2;
    float a2m1=a2-1.;
    return (1.-cos2)/(1.+a2m1*cos2);
}



vec4 ObjectLight(vec3 ro,vec3 rd,vec3 n,vec3 center,float sR,int id){
    object thit=hit;
    float d=distance(ro,center);
    float CosAlpha;
    vec3 tnor;
    float tmp=rand(ro);
    float cosD_S;

    if(d<=sR){
        CosAlpha=-1.;
        tnor=reflect(rd,n);
    }else{
        float RDivd=sR/d;
        CosAlpha=1./sqrt(1.+RDivd*RDivd);
        tnor=normalize(center-ro);
    }
    cosD_S=sqrt(0.5*(1.+CosAlpha));
    float D_S=abs(acos(cosD_S));
    
    float EPSILON=max(EPSILONS*distance(ro,pos_0),EPSILONS_MIN);
    object oA=DE(ro);
    object oB=DE(ro-n*EPSILON*2.);
    vec4 MaterialA=InsideMaterial(ro,oA);vec4 MaterialB=InsideMaterial(ro,oB);
    float rs=MaterialB.x/MaterialA.x;
    material mt=Material(ro,n,oA);
    float k=fresnel(-rd,GGXNormal(n,mt.R.x,ro),rs);
    float S=0.;
    float p=mixp(k,mt.S.xy);

    vec3 A,rnd;
    if(rand(ro)<p||rand(ro)>mt.S.z){
        A=normalize(tnor-rd);
    }else{
        vec3 n0=refract(rd,n,1./rs);
        if(n0!=vec3(0)){
            ro-=n*EPSILON*2.;
            A=normalize(tnor+rd*rs);
            if(length(A)<0.5) A=vec3(0,1,0);
        }else{
            A=-normalize(tnor+rd);
        }
    }
    float Ny=abs(dot(n,A));
    float Nbeta=abs(acos(Ny));
    vec3 N0;N0.y=-length(n.xz);
    N0.xz=(float(length(n.xz)==0.)*vec2(1,0)+normalize(n.xz))*n.y;
    vec3 N1=cross(n,N0);
    float Nalpha=atan(dot(A,N1),dot(A,N0));

    const float PIdiv2=PI/2.;
    const float divPI=1./PI;
    float Ny2=Ny*Ny;
    float deta=cosD_S*cosD_S-Ny2;
    vec2 X,Y;
    
    float R=mix2(mt.R.y,mt.R.x,float(rand(ro)<p));
    
    if(deta<0.){
        float a1=abs(acos(cosD_S/Ny));
        float S0=0.5*GGXdf(a1,R);
        float S1=0.5*GGXdf(Nbeta+D_S,R);S=(S0+S1);
        if(rand(ro)<S0/(S0+S1)){
            X=vec2(0,a1);Y=-Nalpha+vec2(-PIdiv2,PIdiv2);
        }else{
            X=vec2(0,Nbeta+D_S);Y=Nalpha+vec2(-PIdiv2,PIdiv2);
        }
    }else{
        float cosF=sqrt(deta/(1.-Ny2));
        float F=acos(cosF);
        S=F*divPI*(GGXdf(min(Nbeta+D_S,PIdiv2),R)-GGXdf(Nbeta-D_S,R));
        X=vec2(Nbeta-D_S,min(Nbeta+D_S,PIdiv2));Y=(Nalpha+vec2(-F,F));
    }
    X.x=GGXdf(X.x,R);X.y=GGXdf(X.y,R);Y=Y*divPI*0.5;
    vec3 n0;
    if(CosAlpha==-1.){
        n0=GGXNormal(n,R,ro);S=1.;
    }else{
        n0=GGXNormal(n,R,Y,X,ro);
    }
    
    if(length(n0)<0.5) n0=n;
    rnd=reflect(rd,n0);
    
    S=abs(S);

    float t;
    vec4 fog=InsideFog(ro,oA);
    vec3 tp=raycast(ro+rnd*ShadowOffset,rnd,t,fog.x);
    if(t<-0.5){
        hit=thit;
        return vec4(0);
    }
    oA=DE(tp);
    vec3 pos=tp;
    vec3 normal=estimateNormal(pos);
    mt=Material(pos,normal,oA);
    hit=thit;
    return vec4(100.*mt.light*clamp(dot(faceforward(n,rd,n),rnd),0.,1.),S);

}

vec4 SunLight(vec3 ro,vec3 rd,vec3 n){
    const float S_R=0.125;
    float cosD_S=1./sqrt(1.+S_R*S_R);cosD_S=sqrt(0.5*(1.+cosD_S));
    float D_S=abs(acos(cosD_S));

    float EPSILON=max(EPSILONS*distance(ro,pos_0),EPSILONS_MIN);
    object oA=DE(ro);
    object oB=DE(ro-n*EPSILON*2.);
    vec4 MaterialA=InsideMaterial(ro,oA);vec4 MaterialB=InsideMaterial(ro,oB);
    float rs=MaterialB.x/MaterialA.x;
    material mt=Material(ro,n,oA);
    float k=fresnel(-rd,GGXNormal(n,mt.R.x,ro),rs);
    float S=0.;


    float p=mixp(k,mt.S.xy);

    vec3 A,rnd;
    if(rand(ro)<p||rand(ro)>mt.S.z){
        A=-normalize(lightDir+rd);
    }else{
        vec3 n0=refract(rd,n,1./rs);
        if(n0!=vec3(0)){
            ro-=n*EPSILON*2.;
            A=normalize(lightDir+rd*rs);
            if(length(A)<0.5) A=vec3(0,1,0);
        }else{
            A=-normalize(lightDir+rd);
        }
    }
    float Ny=abs(dot(n,A));
    float Nbeta=abs(acos(Ny));
    vec3 N0;N0.y=-length(n.xz);
    N0.xz=(float(length(n.xz)==0.)*vec2(1,0)+normalize(n.xz))*n.y;
    vec3 N1=cross(n,N0);
    float Nalpha=atan(dot(A,N1),dot(A,N0));


    const float PIdiv2=PI/2.;
    const float divPI=1./PI;
    float Ny2=Ny*Ny;
    float deta=cosD_S*cosD_S-Ny2;
    vec2 X,Y;
    
    float R=mix2(mt.R.y,mt.R.x,float(rand(ro)<p));
    
    if(deta<0.){
        float a1=abs(acos(cosD_S/Ny));
        float S0=0.5*GGXdf(a1,R);
        float S1=0.5*GGXdf(Nbeta+D_S,R);S=(S0+S1);
        if(rand(ro)<S0/(S0+S1)){
            X=vec2(0,a1);Y=-Nalpha+vec2(-PIdiv2,PIdiv2);
        }else{
            X=vec2(0,Nbeta+D_S);Y=Nalpha+vec2(-PIdiv2,PIdiv2);
        }
    }else{
        float cosF=sqrt(deta/(1.-Ny2));
        float F=acos(cosF);
        S=F*divPI*(GGXdf(min(Nbeta+D_S,PIdiv2),R)-GGXdf(Nbeta-D_S,R));
        X=vec2(Nbeta-D_S,min(Nbeta+D_S,PIdiv2));Y=(Nalpha+vec2(-F,F));
    }
    X.x=GGXdf(X.x,R);X.y=GGXdf(X.y,R);Y=Y*divPI*0.5;
    vec3 n0=GGXNormal(n,R,Y,X,ro);
    if(length(n0)<0.5) n0=n;
    rnd=reflect(-rd,n0);
    if(dot(rnd,lightDir)<0.) return vec4(0);
    float t;

    vec4 fog=InsideFog(ro,oA);
    vec3 tp=raycast(ro-rnd*ShadowOffset,-rnd,t,fog.x);
    if(t>-0.5) return vec4(0);
    vec4 tmp=background(ro,-rnd,-lightDir);

    S=abs(S);
    vec3 sampleColor=tmp.xyz*100.;
    return max(vec4(0),vec4(sampleColor,S)*(dot(rnd,lightDir)-0.997>0.?1.:0.));
}

vec2 Projection(vec2 p,float S){
    #ifdef SphereProjection
        if(length(p)==0) return p;
        return normalize(p)*tan(length(p)*S);
    #else
        return p*S;
    #endif
}
vec3 frag_0;
void Store(vec4 c){
    frag_0=c.xyz;
}
vec2 uv00;
vec4 Load(){
    return texture(iChannel0,uv00);
}

void F(float x,float y,vec3 Eye_Direction,vec3 Position){
    if(abs(y)>9.0/16.) {Store(Load());return;}
    iFrame_=floor(float(iFrame)/cut);
    float divCut=1.0/cut;
    float iFrame_offset=mod(float(iFrame),cut)*divCut;
    if(0.5*y+0.5<iFrame_offset||0.5*y+0.5>=iFrame_offset+divCut||float(iFrame_)>SSAA*SSAA) {Store(Load());return;}
    float x0=mod(float(iFrame_),SSAA)/SSAA;
    float y0=floor(float(iFrame_)/SSAA)/SSAA;
    float iW=iResolution.x;
    x+=1.0/iW*x0;
    y+=1.0/iW*y0;
    
    vec3 n=normalize((rot(vec3(Projection(vec2(x,y),FOV),1),Eye_Direction)).xyz);
    vec3 n_m=normalize((rot(vec3(Projection(DOF_Pos,FOV),1),Eye_Direction)).xyz);
    vec3 pos=Position;
    
    float DOF=0.1;
    if(DOF_R!=0.) raycast(pos,n_m,DOF,0.);
    if(DOF<-0.5) DOF=Far;
    vec3 Q=pos+n*DOF;
    vec3 X;X.y=-length(n.xz);
    vec3 Y;Y.xz=(float(length(n.xz)==0.)*vec2(1,0)+normalize(n.xz))*n.y;
    Y=cross(n,X);float tmp_1=rand(pos+vec3(x,float(iFrame),y))*2.*PI;
    float tmp_2=rand(pos+vec3(x,float(iFrame),y+5.));
    n=normalize(n+tmp_2*DOF_R/DOF*(X*sin(tmp_1)+Y*cos(tmp_1)));
    pos=Q-DOF*n;
    
    vec3 pos00=pos;
    pos_0=pos00;
    vec3 tcolor=vec3(0);
    for(int i=0;i<=MaxReflect;i++) {fog0[i]=vec3(1.);Gs0[i]=1.;}
    float distance0=0.;
    int reflectstep=0;
    bool hit0=false;float rand0=0.;
    float depth=Far*10.;
    vec3 back=background(pos,n,-lightDir).xyz;

    object oA0=DE(pos);
    vec3 fogS_=InsideMaterial(pos,oA0).yzw;
    vec4 fog=InsideFog(pos,oA0);
    vec3 n_0=n;

    for(reflectstep=0;reflectstep<MaxReflect;reflectstep++){
        float t=0.;
        vec3 nextpos=raycast(pos,n,t,fog.x);
        if(t<-0.5) break;
        pos=nextpos;
        float EPSILON=max(EPSILONS*distance(pos,pos_0),EPSILONS_MIN);
        object oA=DE(pos);
        vec3 normal=estimateNormal(pos);
        normal=faceforward(normal,normal,n);
        object oB=DE(pos-normal*EPSILON*2.);
        vec4 MaterialA=InsideMaterial(pos,oA);vec4 MaterialB=InsideMaterial(pos,oB);
        float rs=MaterialB.x/MaterialA.x;
        material material=Material(pos,normal,oA);


        fog0[reflectstep]=exp(-t*fogS_);
        LightColors[reflectstep]=material.light;
        n_0=n;
        
        vec3 I=vec3(1);int i=0;
        do{
            i++;
            bool refract_;
            vec3 randN=GGXNormal(normal,material.R.x,pos);
            float F=fresnel(-n,randN,rs);
            float p=mixp(F,material.S.xy);
            if(rand(pos)<p){
                I*=material.Cs;refract_=false;
            }else{
                I*=material.Cd;randN=GGXNormal(normal,material.R.y,pos);
                refract_=rand(pos)<material.S.z;
            }
            vec3 v0=mix(reflect(n,randN),refract(n,randN,1./rs),float(refract_));
            bool a; fogS_=MaterialA.yzw;
            if(refract_){
                if(v0==vec3(0)){
                    v0=reflect(n,randN);a=dot(normal,v0)>0.;
                }else{
                    pos-=2.*EPSILON*normal;a=dot(normal,v0)<0.;
                    fogS_=MaterialB.yzw;
                }
            }else{a=dot(normal,v0)>0.;}
            n=v0;if(a) break;
        }while(i<16);


        colors[reflectstep].xyz=I;
        Gs0[reflectstep]=1.;

        if(!hit0) {depth=distance(pos,pos00);rand0=1.;}
        hit0=true;
        oA=DE(pos);
        fog=InsideFog(pos,oA);
        
        if(distance(pos,pos00)>Far) {break;}
    }
    fog0[reflectstep]=exp(-1e10*fogS_);
    enablewater=false;
    vec3 normal=estimateNormal(pos);
    vec4 sunL=SunLight(pos,n_0,normal);
    vec4 objL=getObjectLight(pos,n_0,normal);

    tcolor=(background(pos,n,-lightDir).xyz+sunL.xyz*sunL.w+objL.xyz*objL.w)/(1.+sunL.w+objL.w);

    if(!hit0) tcolor*=fog0[reflectstep];
    for(int i=reflectstep-1;i>=0;i--){
        tcolor=fog0[i+1]*tcolor*colors[i]+LightColors[i];
    }
    tcolor=mix(tcolor,back,clamp(1.-exp(min(0.,FogS*(FogStart-depth))),0.,1.)*float(hit0));
    tcolor=!hit0?back:tcolor;
    tcolor=clamp(tcolor,0.,16.);
    
    if(iFrame_<=1.){
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
    vec3 m=vec3(0.5,0,0);
    vec3 p=vec3(0,13,-27);
    F(2.*uv.x-1.,(2.*uv.y-1.)/iResolution.x*iResolution.y,m,p);

    fragColor = vec4(frag_0,1.0);
}

