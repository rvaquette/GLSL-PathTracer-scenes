#define FBM_Iteration 6
#define pi 3.14159

vec3 hash3(vec3 p){
    p=vec3( dot( p, vec3(127.1, 311.7,121.1) ),
            dot( p, vec3(269.5, 183.3,234.5) ),
            dot( p, vec3(629.5, 43.3,32.1) ) );

    return -1.0+2.0*fract(sin(p)*43758.5453123 );
}

vec3 cubemap( sampler2D sam, in vec3 d )
{
    vec3 n = abs(d);

#if 0
    // sort components (small to big)    
    float mi = min(min(n.x,n.y),n.z);
    float ma = max(max(n.x,n.y),n.z);
    vec3 o = vec3( mi, n.x+n.y+n.z-mi-ma, ma );
    return texture( sam, .1*o.xy/o.z ).xyz;
#else
    vec2 uv = (n.x>n.y && n.x>n.z) ? d.yz/d.x: 
              (n.y>n.x && n.y>n.z) ? d.zx/d.y:
                                     d.xy/d.z;
    return texture( sam, uv ).xyz;
    
#endif    
}
float perlin_noise3(vec3 p){
 
    /*
     not perlin noise anymore*/
    
    vec3 tex = cubemap(iChannel1,p);
    return length(p+tex*.5)*0.5;
}


float fbm3(vec3 p){
    float n=0.0;
    n=perlin_noise3(p);

    float a=0.1;
    for (int i=0;i<FBM_Iteration;i++){
        n+=a*perlin_noise3(p);
        p=p*2.0;
        a=a*0.5;
    }
    return n;
}

float sphere(vec3 p,float r){
    //+cos(iTime+p.x*5.)*0.1+sin(iTime+p.z*5.)*0.1
       vec3 tex = cubemap(iChannel1,p);
    return length(p+cos(p.x*5.)*0.07+sin(p.z*5.)*0.05)- (r+ 0.1*( 0.5 + ( 0.5 * fbm3( p * 5.0  )  ) ) ) ;
}


vec2 map(vec3 p){
    vec2 res=vec2(0.0,0.4);
    float planeCol=0.4;
    float sphereCol=14.3;

    res=vec2( sphere(p-vec3(0.0,0.5,0.0),0.5), sphereCol  ) ;
    return res;
}

vec3 caclNormal(vec3 p){
    vec3 eps=vec3(0.001,0.0,0.0);
    return normalize( vec3(
            map(p+eps.xyy).x- map(p-eps.xyy).x,
            map(p+eps.yxy).x- map(p-eps.yxy).x,
            map(p+eps.yyx).x- map(p-eps.yyx).x ) );
}

mat3 rotate(float an){
    return mat3(cos(an),0,-sin(an),
                0,1,0,
                sin(an),0,cos(an)
    );
}

const float precis=0.002;
vec2 raymarch(in vec3 ro, in vec3 rd){
    float tmin=1.0;
    float tmax=20.0;
    
    float t=tmin;
    float m=-1.0;
    
    for(int i=0;i<100;i++){
        vec2 res=map(ro+rd*t);
        if (res.x<precis || t>tmax) break;
        
        t+=res.x*0.7;
        m=res.y;
    }
    
    if(t>tmax) m=-1.0;
    return vec2(t,m);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{

    vec2 uv=fragCoord.xy / iResolution.xy;

    vec2 p=uv-vec2(0.5);

	p.y=p.y*iResolution.y/iResolution.x;
    float precis=0.01;

    float angle=0.2*iTime;

    float watchDist=3.0;
    vec3 pos= vec3(watchDist* sin(angle),0.5, -watchDist* cos(angle));

    vec3 ro=pos;
    vec3 rd=normalize(vec3(p.x,p.y,1.0) );
    

    rd=rd*rotate(angle);

    
    vec3 amb=vec3(0.11,0.1,0.13);
    vec3 finalCol=vec3(1.0);
    //finalCol=texture(iChannel0,uv).xyz;
    vec2 res=raymarch(ro,rd);
    float t=res.x;
    float m=res.y;
     float specular;
    vec3 bgCol=finalCol;
    if (m>-0.5){
        //directional light
        vec3 lig=normalize(vec3(.0,-1.0,0.0));
        vec3 hit=ro+rd*t;
        vec3 nor=caclNormal(hit);

        vec3 resCol=1.0 * sin( vec3(0.06,0.08,0.1)* res.y );

        
        float diffuse=1.0*max(0.0,dot(-lig,nor) );
        vec3 ref=reflect(-rd,nor);
        vec3 h=normalize(-lig-rd);
        specular=1.0*pow(max(0.0,dot(h, nor) ),40.0 );
        
        

        finalCol=vec3(1.,215./255.,0.)*texture(iChannel0,reflect(nor,rd)).xyz
            +resCol*(diffuse+specular-0.6)*0.6 +amb*2.;
        
        //float edge = smoothstep(0., 0.2, dot(hit, nor));
		//finalCol= mix(bgCol, finalCol, edge);


    }
    else{

        vec3 bghit=ro-rd*100.0;
        finalCol=texture (iChannel0,-bghit).xyz;
    }


    fragColor = vec4(finalCol.xyz,specular);
}

