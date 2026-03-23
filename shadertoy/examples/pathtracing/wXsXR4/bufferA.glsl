vec2 hash21(float p){
	vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

float hash13(vec3 p3){
	p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3){
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
}

struct ray{
    vec3 pos;
    vec3 dir;
};

// Returns the point at distance t along ray r
vec3 at(ray r,float t){
    return r.pos + r.dir*t;
}

mat4 createCamMatrix(vec3 pos,vec3 dir,vec3 up){
    vec3 right = normalize(cross(dir,up));
    up = normalize(cross(right,dir));
    return mat4(
        vec4(right,0.0),
        vec4(up,   0.0),
        vec4(dir,  0.0),
        vec4(pos,  1.0)
    );
}

ray getCamRay(mat4 cam,vec2 UV){
    return ray(cam[3].xyz,cam[0].xyz*UV.x+cam[1].xyz*UV.y+cam[2].xyz);
}

struct refInfo{
    vec3 reflected;
    vec3 refracted;
    float refFac;
};

refInfo getRefInfo(vec3 dir, vec3 norm, float n1, float n2){
    vec3 refl = reflect(dir,norm);
    vec3 refr = refract(dir,norm,n1/n2);
    float incidence = dot(dir,-norm);
    float transmission = dot(refr,-norm);
    float refS = (n1*incidence - n2*transmission)/
                 (n1*incidence + n2*transmission);
    float refP = (n2*incidence - n1*transmission)/
                 (n2*incidence + n1*transmission);
    
    float ref = mix(refS*refS,refP*refP,0.5);
    
    return refInfo(refl,refr,ref);
}

float sphereIntersect(ray r, vec4 sphere){
    vec3 oc = sphere.xyz-r.pos;
    float a = dot(r.dir,r.dir); // Squared length of ray direction
    float h = dot(r.dir,oc);
    float c = dot(oc,oc) - sphere.w*sphere.w;
    float discriminant = h*h - a*c;
    
    if (discriminant<0.0){
        return -1.0;
    }else{
        float sq = sqrt(discriminant);
        float near = (h-sq)/a;
        if (near>0.0){
            return near;
        }
        return (h+sq)/a; // far intersection if inside the sphere
    }
}

struct mat{
    vec3 col;
    float roughness;
    int type; // 0:Metal 1:Specular 2:Glass 3:Emissive
    float IOR;
};

struct hitInfo{
    vec3 pos;
    vec3 norm;
    float dist;
    mat material;
};

hitInfo trace(ray r, float SEED){
    hitInfo hit = hitInfo(vec3(0.0),vec3(0.0),10.0e20,mat(vec3(0.0),0.0,3,1.3));
    bool missed = true;
    float floorDist = r.pos.y/-r.dir.y;
    if (floorDist>0.0){
        missed = false;
        hit.dist = floorDist;
        hit.pos = at(r,floorDist);
        hit.norm = vec3(0.0,1.0,0.0);
        hit.material.col = vec3(0.1);
        if (mod(hit.pos.x,2.0)>1.0==mod(hit.pos.z,2.0)>1.0){
            hit.material.col = vec3(0.9);
        }
        hit.material.roughness = 0.1;
        hit.material.type = 1;
        hit.material.IOR = 2.6;
    }
    
    for (int x=0;x<10;x++){
        for (int y=0;y<10;y++){
            float rad = 0.05+0.2*hash13(vec3(x,y,SEED));
            vec3 spherePos = vec3(float(x)-4.5,rad+0.25,float(y)-4.5);
            float dist = sphereIntersect(r,vec4(spherePos,rad));
            if (dist>0.0 && dist<hit.dist){
                hit.dist = dist;
                hit.pos = at(r,dist);
                hit.norm = normalize(hit.pos-spherePos);
                vec3 matProps = hash33(vec3(x,y,SEED+1.0));
                hit.material.col = hash33(vec3(x,y,SEED+2.0));
                hit.material.roughness = matProps.x*matProps.x;
                hit.material.type = int(matProps.y*3.5);
                hit.material.IOR = 1.15+matProps.z;
                if (hit.material.type==2){
                    hit.material.roughness *= hit.material.roughness;
                }
                if (hit.material.type==3){
                    hit.material.col *= 13.0*hit.material.col;
                }
                missed = false;
            }
        }
    }
    
    if (missed){
        hit.dist = -1.0;
    }
    
    if (dot(hit.norm,-r.dir)<0.0){
        hit.norm*=-1.0;
    }
    
    return hit;
}

vec3 sky(vec3 dir,float seed){
    vec3 t = texture(iChannel0,dir).rgb;
    return t*t*mod(seed*1.72,1.0)*2.0;
}

vec3 randDir(vec3 seed){
    for (int i=0;i<100;i++){
        vec3 rand = hash33(seed)-0.5;
        float l = length(rand);
        if (l>0.0001 && 1.0>l){
            return normalize(rand);
        }
        seed += vec3(1.0);
    }
    return vec3(0.0);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    vec4 data = texelFetch(iChannel1,ivec2(0,0),0);
    if (ivec2(fragCoord)==ivec2(0,0)){
        data.y += 1.0;
        if (texelFetch(iChannel2,ivec2(32,0),0).r>0.5){
            if (data.z<0.5){
                data.x = iTime + iTimeDelta + float(iFrame);
                data.y=0.0;
            }
            data.z = 1.0;
        }else{
            data.z = 0.0;
        }
        if (iMouse.z>0.0 || texelFetch(iChannel2,ivec2(82,0),0).r>0.5){
            data.y=0.0;
        }
        fragColor = data;
    }else{
        vec2 angle = iMouse.xy/iResolution.xy*vec2(6.2831853,8.0);
        if (angle==vec2(0,0)){
            angle = vec2(6.0,4.0);
        }
        vec3 camPos = vec3(5.0*sin(angle.x),angle.y,5.0*cos(angle.x));
        vec3 camTarg = vec3(0.0,0.0,0.0);
        mat4 camera = createCamMatrix(camPos,normalize(camTarg-camPos),vec3(0,1,0));
        
        float sceneSeed = data.x+25.0;
        vec2 UV = (fragCoord-0.5*iResolution.xy+hash21(iTime)-0.5)/iResolution.y;
        vec3 col = vec3(1.0);
        float IOR = 1.0;
        
        ray r = getCamRay(camera,UV);
        
        for (int i=0;i<8;i++){
            hitInfo info = trace(r,sceneSeed);
            if (info.dist<0.0){
                col *= sky(r.dir,sceneSeed);
                break;
            }else if (i==7){
                col = vec3(0.0);
            }

            vec3 seed = info.pos*140.0+vec3(iTime);
            vec3 rand = randDir(seed);
            if (dot(rand,info.norm)<0.0){
                rand*=-1.0;
            }
            if (info.material.type == 0){ // Metal
                r.pos = info.pos + info.norm*0.0001;
                r.dir = mix(reflect(r.dir,info.norm),rand,info.material.roughness);
                col *= info.material.col;
            }else if (info.material.type == 1){ // Specular
                refInfo gloss = getRefInfo(r.dir,mix(info.norm,rand,info.material.roughness),IOR,info.material.IOR);
                if (hash13(seed)<gloss.refFac){ // Reflected off of specular coating
                    r.pos = info.pos + info.norm*0.0001;
                    r.dir = gloss.reflected;
                }else{ // Passed through specular coating
                    r.pos = info.pos + info.norm*0.0001;
                    r.dir = rand;
                    col *= info.material.col;
                }
            }else if (info.material.type == 2){ // Glass
                refInfo glass = getRefInfo(r.dir,mix(info.norm,rand,info.material.roughness),IOR,info.material.IOR);
                if (hash13(seed)<glass.refFac){ // Reflected off of glass
                    r.pos = info.pos + info.norm*0.0001;
                    r.dir = glass.reflected;
                }else{ // Refracted into glass
                    r.pos = info.pos - info.norm*0.0001;
                    r.dir = glass.refracted;
                    IOR = info.material.IOR;
                    col *= info.material.col;
                }
            }else if (info.material.type == 3){ // Emissive
                col *= info.material.col;
                break;
            }
        }

        fragColor = vec4(mix(texture(iChannel1,fragCoord/iResolution.xy).rgb,col,1.0/(data.y+1.0)),1.0);
    }
}
