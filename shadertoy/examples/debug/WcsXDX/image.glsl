#define col_grey(v) vec4(v,v,v,0)

//Distance fields for drawing
//taken basically from iquilez https://www.shadertoy.com/view/XdVBWd
float length2( in vec2 v ) { return dot(v,v); }

float sdSegmentSq( in vec2 p, in vec2 a, in vec2 b )
{
	vec2 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length2( pa - ba*h );
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
	return sqrt(sdSegmentSq(p,a,b));
}

float udBezier(vec2 p0, vec2 p1, vec2 p2, in vec2 p3, vec2 pos)
{   
    const int kNum = 15;
    vec2 res = vec2(1e10,0.0);
    vec2 a = p0;
    for( int i=1; i<kNum; i++ )
    {
        float t = float(i)/float(kNum-1);
        float s = 1.0-t;
        vec2 b = p0*s*s*s + p1*3.0*s*s*t + p2*3.0*s*t*t + p3*t*t*t;
        float d = sdSegmentSq( pos, a, b );
        if( d<res.x ) res = vec2(d,t);
        a = b;
    }
    
    return res.x;
}

float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

//Taken Fabrice Neyret for algorhitm https://www.shadertoy.com/view/llySRh
//Awesome
#define C(c) U.x-=.5; O+= char(U,64+c)

vec4 char(vec2 p, int c) 
{
    if (p.x<.0|| p.x>1. || p.y<0.|| p.y>1.) return vec4(0,0,0,1e5);
	return textureGrad( iChannel1, p/16. + fract( vec2(c, 15-c/16) / 16. ), dFdx(p/16.),dFdy(p/16.) );
}

vec4 printNumber(vec2 uv, float f, int digits, int decimals)
{
    
    vec4 O = vec4(0.0);
    float FontSize = 3.;
    vec2 position = vec2(0.01,0.01);
    vec2 U = ( uv - position)*64.0*vec2(1.5,1.)/FontSize;
    
    for(int i=digits-decimals;i>-1;i--)
    {
          C(int(int(f)/10^i)%10-16);
    }
    
    return O;
}



void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    
    vec2 uv = fragCoord/iResolution.xy;
    
    //The idea would be trying to do some ultra-simple editor
    //Here we woould a red persistent node/postion/etc from texture
    //vec4 readtex = texture(iChannel0,uv);
    
    //World editor position
    vec2 uvworld = uv - 0.5; uvworld.x *= iResolution.x/iResolution.y;
    uvworld *= 4.0;    
    
    //Initialize editor layaout composition 
    vec4 col = vec4(0, 0, 0, 0);
    

    // Setup background color (similar to UE4 editor)
    col = col_grey(0.1);
    {
        float width = 0.005;
        float scale = 10.;
        float mask = fract(scale * uvworld.x); mask = smoothstep(width * scale ,0.8*width * scale,abs(mask));
        col = mix(col, col_grey(0.15), mask);
        mask = fract(scale * uvworld.y); mask = smoothstep(width * scale,0.8*width * scale,abs(mask));
        col = mix(col, col_grey(0.15), mask);
    }
    
    {
        float width = 0.01;
        float scale = 2.5;
        float mask = fract(scale * uvworld.x); mask = smoothstep(width * scale,0.8*width * scale,abs(mask));
        col = mix(col, col_grey(0.07), mask);
        mask = fract(scale * uvworld.y); mask = smoothstep(width * scale,0.8*width * scale,abs(mask));
        col = mix(col, col_grey(0.07), mask);
    }
    
    
    //Here the node info
    //First position
    vec2[] poss = vec2[](vec2(-1.+0.3*cos(1.1*iTime),0.3*sin(1.21*iTime)),vec2(1.+0.4*sin(1.05*iTime+0.2),0.5-0.3*cos(1.71*iTime-0.2)),vec2(0.5-0.3*sin(1.3*iTime),-0.5+0.3*cos(1.13*iTime-0.2)));
    for(int i=0;i<3;i++)
    {
        poss[i] += (0.5+0.3*sin(iTime+0.131*float(i)+0.1))*normalize(poss[i]);
    }
    
    //Draw links between nodes (painful part)
    float f = udBezier(poss[0]+vec2(0.1,0),poss[0]+vec2(1,0),poss[1]+vec2(-1.,0.),poss[1]+vec2(-0.25,0),uvworld);
    f = min(f,udBezier(poss[1]+vec2(0.3,0),poss[1]+vec2(1.5,0),poss[2]+vec2(-1.,0.05),poss[2]+vec2(-0.25,0.05),uvworld));
    f = min(f,udBezier(poss[0]+vec2(0.1,0),poss[0]+vec2(1,0),poss[2]+vec2(-1.,-0.05),poss[2]+vec2(-0.25,-0.05),uvworld));
    col = mix(col,vec4(1,1,1,0),smoothstep(0.0002,0.00,f));
   
   
    //one node
    {
        vec2 pos_box = poss[0];
        float f = sdBox(uvworld-pos_box,vec2(0.2, 0.2));
        col = mix(col, col_grey(0.0), 0.8*smoothstep(0.12,0.,f));
        col = mix(col, col_grey(0.025), 0.8*step(f-0.05,0.)*step(-0.15,pos_box.y-uvworld.y));
        col = mix(col, vec4(0.3, 0.4, 0.2, 0), 1.0*step(f-0.05,0.)*step(0.15,uvworld.y-pos_box.y));
        col += col_grey(0.3)*step(f-0.05,0.)*smoothstep(0.0,0.1,f);   
        
        //print node name
        {
            vec4 O = vec4(0.0);
            float FontSize = 6.;
            vec2 position = vec2(-0.25,0.15);
            vec2 U = ( uvworld - pos_box - position)*64.0*vec2(1.,1.)/FontSize;
            C(1);C(36);C(36);
            col = mix(col,col_grey(1.),0.75*O.x); 
            
        }
    }
    
    //other node
    {
        vec2 pos_box = poss[1];
        float f = sdBox(uvworld-pos_box,vec2(0.4, 0.2));
        col = mix(col, col_grey(0.0), 0.8*smoothstep(0.12,0.,f));
        col = mix(col, col_grey(0.025), 0.8*step(f-0.05,0.)*step(-0.15,pos_box.y-uvworld.y));
        col = mix(col, vec4(0.6, 0.2, 0.2, 0), 1.0*step(f-0.05,0.)*step(0.15,uvworld.y-pos_box.y));
        col += col_grey(0.3)*step(f-0.05,0.)*smoothstep(0.0,0.1,f); 
        
        //print node name
        {
            vec4 O = vec4(0.0);
            float FontSize = 6.;
            vec2 position = vec2(-0.45,0.15);
            vec2 U = ( uvworld - pos_box - position)*64.0*vec2(1.,1.)/FontSize;
            C(19);C(45);C(47);C(47);C(52);C(40);C(51);C(52);C(37);C(48);
            col = mix(col,col_grey(1.),0.75*O.x); 
            
        }
    }
    
    //even one more node
    {
        vec2 pos_box = poss[2];
        float f = sdBox(uvworld-pos_box,vec2(0.3, 0.4));
        col = mix(col, col_grey(0.0), 0.8*smoothstep(0.12,0.,f));
        col = mix(col, col_grey(0.025), 0.8*step(f-0.05,0.)*step(-0.35,pos_box.y-uvworld.y));
        col = mix(col, vec4(0.6, 0.4, 0.2, 0), 1.0*step(f-0.05,0.)*step(0.35,uvworld.y-pos_box.y));
        col += col_grey(0.3)*step(f-0.05,0.)*smoothstep(0.0,0.1,f);  
        
        //A preview subwindow
        vec2 uvnode = fract(8.*(uvworld-pos_box)+5.1*vec2(0.1,0.2)*iTime);
        f = sdBox(uvworld-pos_box - vec2(0.,-0.05),vec2(0.25, 0.25));
        col = mix(col,vec4(uvnode,0,0),step(f,0.01));
        
        
        //print node name
        {
            vec4 O = vec4(0.0);
            float FontSize = 6.;
            vec2 position = vec2(-0.35,0.35);
            vec2 U = ( uvworld - pos_box - position)*64.0*vec2(1.,1.)/FontSize;
            C(16);C(33);C(46);C(46);C(37);C(50);
            col = mix(col,col_grey(1.),0.75*O.x); 
            
        }
    }
   
   
    //for debug
    //{
    //    vec4 number = printNumber(uv,100.0,4,1);
    //    col = mix(col,number.xxxx,number.x);
    //}
    
    float gamma = 1.;
    col.x = pow(col.x,gamma);
    col.y = pow(col.y,gamma);
    col.z = pow(col.z,gamma);
    
    fragColor = col;
}
