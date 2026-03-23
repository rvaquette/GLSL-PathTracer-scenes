mat2 rot (float a) {
 	return mat2(cos(a), sin(a), -sin(a), cos(a));   
}

float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
    vec3 pa = p - a, ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}

float sphere (vec3 p, float r) {
 	return length(p) - r;   
}

vec2 scene (vec3 p) {
  
    float plane = p.y + 1.0;
    float body = sphere(p, 1.0);
    
    vec3 hp = (p);
    hp.xy = rot(-0.3 + sin(iTime*2.0)*0.2) * hp.xy;
    hp = hp-vec3(-0.25*0.0, 0.95, 0.0);
    float head = sphere(hp, 0.5);
    
    head = min(head, sdCapsule(hp+vec3(-0.1,0.0,0.0), vec3(0.0, 0.7, 0.0), vec3(0.0), 0.025));
    head = min(head, sdCapsule(hp+vec3(-0.1,0.0,0.1), vec3(0.0, 0.9, 0.0), vec3(0.0), 0.0125));
    
    float eye = sphere(hp-vec3(-0.375, 0.265, 0.0), 0.1125);
    eye = min(eye, sphere(hp-vec3(-0.375, 0.2, -0.2), 0.06));
    
    if (plane < body) {
     	if (plane < head) return vec2(plane, 1.0);
        if (head < eye)
        	return vec2(head, 3.0);
        else return vec2(4.0);
    } else {
     	if (body < head) return vec2(body, 2.0);
        if (head < eye)
        	return vec2(head, 3.0);
        else return vec2(eye, 4.0);
    }
}

vec3 normal (vec3 p) {
    vec2 eps = vec2(0.001, 0.0);
    return normalize(vec3(
    	scene(p+eps.xyy).x - scene(p-eps.xyy).x,
        scene(p+eps.yxy).x - scene(p-eps.yxy).x,
        scene(p+eps.yyx).x - scene(p-eps.yyx).x
    ));
}

vec4 raymarch (vec3 ro, vec3 rd) {
    float h = 0.0;
    for (int i = 0; i < 175; ++i) {
        vec3 p = ro+h*rd;
        vec2 test = scene(p);
        h += test.x;
        if (h < 0.01) break;
        if (h > 64.0) break;
        if (test.x < 0.001)
            return vec4(p, test.y);
    }
    return vec4(-1.0);
}

float shadow (vec3 ro, vec3 rd) {
 	float smax = 1.0;
    float smin = 100.0;
    float h = 0.0;
    float shadow = 1.0;
    for (int i = 0; i < 32; ++i) {
        vec3 p = ro+h*rd;
        float test = scene(p).x;
        h += test;
        if (test < 0.0001)
            return 0.0;
        else
            shadow = min(2.5*test/h, shadow);
    }
    
    return shadow;
    
}

float ppp (float x) {
 	if (abs(x) > 0.85) return 0.0;
    return 1.0;
}

mat3 camera () {
    float a =  iMouse.x*0.05 + 2.0;
    vec3 right =	vec3(1.0, 0.0, 0.0);
 	vec3 up =		normalize(vec3(0.0, 1.0, 1.8 + (iMouse.y/iResolution.y*2.0-1.0)*1.5)); 
    
    mat2 ra = rot(a);
    right.xz *= ra;
    up.xz *= ra;
        
    return mat3(right, up, cross(right, up));
}

const float orgl = 0.5;

vec4 bb8Body (vec3 raym) {
    float a = iTime;
    float b = 42.0;
    raym.xy *= mat2(cos(a), sin(a), -sin(a), cos(a));
    raym.xz *= mat2(cos(b), sin(b), -sin(b), cos(b));
    vec4 rust = texture(iChannel1, raym.xz*0.5) + texture(iChannel1, raym.zy*0.5);
    rust.w = 0.0;
    vec4 wh = vec4(0.9, 0.9, 0.9, 0.0);
    vec4 color;
    color = vec4(1.0, 1.0, 1.0, 0.0);
        
    color = mix(vec4(1.0,0.8,0.4, 0.0), color, smoothstep(0.0, 0.1, length(raym.xy)-0.575));
    color = mix(vec4(1.0,0.8,0.4, 0.0), color, smoothstep(0.0, 0.1, length(raym.zy)-0.575));
    color = mix(vec4(1.0,0.8,0.4, 0.0), color, smoothstep(0.0, 0.1, length(raym.xz)-0.575));

    color = mix(vec4(1.0,0.8,0.4, 0.0), color, smoothstep(0.0, 0.075, abs(raym.x)-0.01));
    color = mix(vec4(1.0,0.8,0.4, 0.0), color, smoothstep(0.0, 0.075, abs(raym.y)-0.01));
    color = mix(vec4(1.0,0.8,0.4, 0.0), color, smoothstep(0.0, 0.075, abs(raym.z)-0.01));
    
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.0125, abs(raym.x)-0.0075));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.0125, abs(raym.y)-0.0075));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.0125, abs(raym.z)-0.0075));
    
    color = mix(wh, color, smoothstep(0.0, 0.025, length(raym.xy)-0.5));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.0125, abs(length(raym.xy)-0.5)-0.095));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.025, ppp(raym.z)+abs(raym.x+raym.y)*0.1/(-abs(raym.z)+1.05)-0.1125));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.025, ppp(raym.z)+abs(raym.x-raym.y)*0.1/(-abs(raym.z)+1.05)-0.1125));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.0125, abs(length(raym.xy)-0.5)-0.07));
    color = mix(color*0.75, color, smoothstep(0.0, 0.0125, abs(length(raym.xy)-0.5)-0.005));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.025, ppp(raym.z)+abs(raym.x+raym.y)*0.1/(-abs(raym.z)+1.05)-0.08));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.025, ppp(raym.z)+abs(raym.x-raym.y)*0.1/(-abs(raym.z)+1.05)-0.08));
    color = mix(wh, color, smoothstep(0.0, 0.025, length(raym.xy)-0.25));
    color = mix(vec4(0.5, 0.5, 0.5, 0.0), color, smoothstep(0.0, 0.025, length(raym.xy)-0.2));

    color = mix(wh, color, smoothstep(0.0, 0.025, length(raym.zy)-0.5));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.0125, abs(length(raym.zy)-0.5)-0.095));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.025, ppp(raym.x)+abs(raym.z+raym.y)*0.1/(-abs(raym.x)+1.05)-0.1125));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.025, ppp(raym.x)+abs(raym.z-raym.y)*0.1/(-abs(raym.x)+1.05)-0.1125));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.0125, abs(length(raym.zy)-0.5)-0.07));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.0125, ppp(raym.x)+abs(raym.z+raym.y)*0.1/(-abs(raym.x)+1.05)-0.08));
    color = mix(color*0.75, color, smoothstep(0.0, 0.0125, abs(length(raym.zy)-0.5)-0.005));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.0125, ppp(raym.x)+abs(raym.z-raym.y)*0.1/(-abs(raym.x)+1.05)-0.08));
    color = mix(wh, color, smoothstep(0.0, 0.025, length(raym.zy)-0.25));
    color = mix(vec4(0.5, 0.5, 0.5, 0.0), color, smoothstep(0.0, 0.025, length(raym.zy)-0.2));

    color = mix(wh, color, smoothstep(0.0, 0.025, length(raym.xz)-0.5));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.0125, abs(length(raym.xz)-0.5)-0.095));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.025, ppp(raym.y)+abs(raym.x+raym.z)*0.1/(-abs(raym.y)+1.05)-0.1125));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.025, ppp(raym.y)+abs(raym.x-raym.z)*0.1/(-abs(raym.y)+1.05)-0.1125));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.0125, abs(length(raym.xz)-0.5)-0.07));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.0125, ppp(raym.y)+abs(raym.x+raym.z)*0.1/(-abs(raym.y)+1.05)-0.08));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.0125, ppp(raym.y)+abs(raym.x-raym.z)*0.1/(-abs(raym.y)+1.05)-0.08));
    color = mix(wh, color, smoothstep(0.0, 0.025, length(raym.xz)-0.25));
    color = mix(vec4(0.5, 0.5, 0.5, 0.0), color, smoothstep(0.0, 0.0125, length(raym.xz)-0.2));
    if (raym.y > 0.0) color = mix(wh, color, smoothstep(0.0, 0.0125, length(raym.xz)-0.13));
	
    return color*mix(rust.r*rust.r, 1.0, color.w);
}

vec4 bb8Head (vec3 p) {
    
    p.xy = rot(-0.3 + sin(iTime*2.0)*0.2) * p.xy;
    vec4 rust = texture(iChannel1, p.xz*0.5) + texture(iChannel1, p.zy*0.5);
    rust.w = 0.0;
    vec4 color = vec4(1.0, 1.0, 1.0, 0.0);
    
   // color = mix(vec3(0.0), color, smoothstep(0.0, 0.0125, p.y-0.95));
    color = mix(vec4(0.25, 0.25, 0.25, 0.0), color, smoothstep(0.0, 0.0125, abs(p.y-0.925)-0.05));
    color = mix(vec4(0.5, 0.5, 0.5, 0.0), color, smoothstep(0.0, 0.0125, abs(p.y-0.925)-0.03));

    color = mix(vec4(1.0,0.8,0.4, 0.0), color, smoothstep(0.0, 0.025, abs(p.y-1.3)-0.04));
    color = mix(vec4(1.0,0.5,0.0, 0.0)*0.75, color, smoothstep(0.0, 0.0125, abs(p.y-1.3)-0.03));
    color = mix(vec4(1.0,0.5,0.0, orgl), color, smoothstep(0.0, 0.0125, abs(p.y-1.3)-0.02));

    float angle = atan(p.x/p.z);
    float t = mod(angle, 3.1415/8.0);
    color = mix(mix(vec4(0.25, 0.25, 0.25, 0.0), vec4(1.0, 1.0, 1.0, 0.0), smoothstep(0.0, 0.075, abs(t-0.2)-0.3)), color, smoothstep(0.0, 0.0075, abs(p.y-1.39)-0.025));
    color = mix(mix(vec4(0.5, 0.5, 0.5, 0.5), vec4(0.25), smoothstep(0.0, 0.075, abs(t-0.2)-0.1)), color, smoothstep(0.0, 0.0075, abs(p.y-1.39)-0.02));

    if (p.x < 0.0) {
    	color = mix(vec4(1.0, 1.0, 1.0, 0.0), color, smoothstep(0.0, 0.0125, length((p.zy-vec2(0.0, 1.225))*vec2(1.0, 1.3))-0.175));
    	color = mix(vec4(0.75, 0.75, 0.75, 0.0), color, smoothstep(0.0, 0.0125, abs(length((p.zy-vec2(0.0, 1.225))*vec2(1.0, 1.3))-0.15)));
    }
    
    return color*mix(1.0, rust.r*rust.r, color.b);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;
	
    mat3 cam = camera();
    vec3 ro = cam * vec3(uv, -1.5-iMouse.y/iResolution.y);
    vec3 rd = cam * normalize(vec3(uv, 1.0));
    
    vec4 raym = raymarch(ro, rd);
    if (raym.w > 0.0) {
        
        vec3 light = ro+vec3(-2.0, 4.0, -1.0);
        
        vec3 n = normal(raym.xyz);
        
        float spec = 0.0;
        vec3 droidColor = vec3(0.0);
        if (raym.w == 1.0) {
            spec = 0.25;
            droidColor.rgb = texture(iChannel0, rot(1.0)*(raym.xz*0.05 + vec2(-iTime*0.05, 0.0))).rgb;
        } else if (raym.w == 2.0) {
            vec4 bc = bb8Body(raym.xyz);
            droidColor.rgb = bc.rgb;
            spec = bc.a;
        } else if (raym.w == 3.0) {
            vec4 bc = bb8Head(raym.xyz);
            droidColor.rgb = bc.rgb;
            spec = bc.a;
            
        } else if (raym.w == 4.0) {
         	droidColor.rgb = vec3(0.0);
            if (raym.z < -0.15 && mod(iTime, 1.0) < 0.1) {
                droidColor.rgb = vec3(0.0, 4.1, 0.2);
                spec = 4.0;
            } else spec = 1.0;
        }
        fragColor.rgb = droidColor;
        float shadoww = shadow(raym.xyz+n*0.01, normalize(light-raym.xyz));
        float diff = clamp(dot(n, normalize(light-raym.xyz)/*normalize(vec3(1.0))*/), 0.0, 1.0);
        
        if (raym.w == 1.0) {
         	diff = 1.0; 
        }
        
        fragColor *= mix(0.125, 1.0, shadoww);
        fragColor *= mix(0.125, 1.0, diff);
                
        vec3 sur2light = normalize(light-raym.xyz);
        vec3 sur2eye = normalize(ro - raym.xyz);
        vec3 ref = reflect(sur2eye, n);
        float sp = clamp(dot(ref, -sur2light), 0.0, 1.0);
                
        fragColor.rgb += vec3(pow(sp, 64.0) * shadoww * spec);
        fragColor.rgb += vec3(pow(sp, 128.0) * shadoww * spec);
        fragColor.rgb += vec3(pow(sp, 256.0) * shadoww * spec);
        fragColor.rgb += vec3(pow(sp, 1.0) * shadoww * spec)*0.1;
       
        if (raym.w != 1.0) {
  	       /*vec3 cm = texture(iChannel2, n).rgb;
            cm = pow(cm, vec3(2.0)) * 0.25;
           fragColor.rgb += cm * spec * shadoww;*/
        }
        
        fragColor.rgb = mix(vec3(1.0), fragColor.rgb, exp(-length(raym.xyz)*0.05));
        
        if (raym.w != 1.0) {
        	float asd = clamp(dot(n, sur2eye), 0.0, 1.0);
        	asd = smoothstep(0.25, 0.35, asd);
        	fragColor.rgb = mix(vec3(0), fragColor.rgb, asd);
        }
    } else {
    	fragColor = vec4(1.0);
    }
   
    vec4 c = step(texture(iChannel0, fragCoord/8.), fragColor);
    fragColor = mix(fragColor, c, 0.0);
    fragColor.rgb = pow(fragColor.rgb, vec3(0.77));

}
