
vec3 lightpos = vec3(0),lpRot;
float scatter =0.;
float g;

float map(in vec3 p){
    
    
    const vec2 n = vec2(0.0, 1.0);
    mat3 r = rot(n.yxx, 0.3*iTime) * rot(n.xyx, 0.5*iTime) * rot(n.xxy, 0.7*iTime);
    mat3 r2 = rot(n.yxx, -0.6*iTime) * rot(n.xyx, -0.2*iTime) * rot(n.xxy, 0.3*iTime);
    vec3 t = vec3(vec2(1.0, .75)*sin(vec2(0.6, 0.3)*iTime), 0.0);
 
    float d = sdTorus(r * (p - t), vec2(.65, .3)+ 0.016*prod3(sin(40.0*p)));
    
    //float s = sdTorus(r * (p - t - lightpos) ,vec2(.75, .5))/length(lpRot*lpRot);
    //scatter += max(-s,0.)*0.4;
    
    d = smin(d, sdTorus(r2 * (p + t), vec2(.65, .3)+ 0.00025*prod3(sin(60.0*p))), .9);
	
    vec3 pp = p;
    pp *= rot(vec3(0., 0., 1.), iTime * .6); 
   	lpRot=(pp-lightpos);
    pR(lpRot.zx,iMouse.x*-0.03+0.08);
    pR(lpRot.yz,iMouse.y*0.003-.5);
	
    float s = sdBox(lpRot, vec3(.9))/length(lpRot*lpRot);
    scatter += max(-s,0.)*0.17;
    
    return d;
}

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal( in vec3 pos )
{
    const float ep = 0.0001;
    vec2 e = vec2(1.0,-1.0)*0.5773;
    return normalize( e.xyy*map( pos + e.xyy*ep ) + 
					  e.yyx*map( pos + e.yyx*ep ) + 
					  e.yxy*map( pos + e.yxy*ep ) + 
					  e.xxx*map( pos + e.xxx*ep ) );
}


void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    
    float tt=mod(iTime,62.8318);
    
   	vec3 tot = vec3(.5,0.0,0.0);
    
 
    vec2 p = (-iResolution.xy + 2.0*fragCoord)/iResolution.y;

    vec3 ro = vec3(0.0,2.25,5.0);
    vec3 rd = normalize(vec3(p-vec2(0.0,1.6),-3.5));

    float t = .1;
    for( int i=0; i<64; i++ ){
        vec3 p = ro + t*rd;
        float h = map(p);
        if( abs(h)<0.001 || t>21.0 ) break;
        t+=h;
       
    }
	
    float theta = iTime * 3.141592 * 0.20;
    lightpos = vec3(5. * cos(theta), 0.7 + 0.2 * sin(theta*2.0),-2.5); 
    
    float fog = smoothstep(0.0, .95, t/21.);
    
    vec3 col = vec3(.1,.3,.45); 
    col*=-p.y*.5*cos(p.x);
    
	
    
    if( t<21.0 ){
        
        
        vec3 pos = ro + t*rd;
        vec3 nor = calcNormal(pos);
        vec3 refl = reflect(rd, nor);
        vec3 r = texture(iChannel0,refl).rgb;
        float fre = pow( clamp( 1. + dot(nor,rd),0.0,1.0), 2. ); 
        
        col += (vec3(.75, .5, .25)  ) * scatter * .5 + r * .5  ;// * intensity;
    }

    
	fragColor = vec4( col , 1.0 );
    
}
