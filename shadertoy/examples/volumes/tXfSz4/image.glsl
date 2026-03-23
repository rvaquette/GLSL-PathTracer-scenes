
vec3 rotate(vec3 p, vec3 axis, float angle) {
    return mix(dot(p, axis) * axis, p, cos(angle)) + sin(angle) * cross(axis, p);
}

float getSpheresSDFUnique(vec3 p) {
    vec3 voxelPos = worldToVoxel(p.xyzz).xyz;
    ivec3 basePos = ivec3(floor(voxelPos));
    
    vec4 distances = vec4(FLOAT_INF);
    uvec4 indices = uvec4(uint(-1));

    float shapeD = 9999.0;
    for(int z = -1; z <= 1; z++) {     
        for(int y = -1; y <= 1; y++) {   
            for(int x = -1; x <= 1; x++) {
                ivec3 sampleCoord = basePos + ivec3(x, y, z);

                uvec4 fetchedClosest = fetchClosest3D(vec3(sampleCoord), iChannel1);
                for (int j = 0; j < 2; j++) {
                    uint index = fetchedClosest[j];
                    if(index == uint(-1)) { continue; }
                    if (index == uint(-1) || any(equal(indices, uvec4(index)))) {
                        continue;
                    } 

                    vec4 e = texelFetch(iChannel0, ivec2(index, 0), 0);
                    float dist = length(e.xyz - p) - e.w;

                    if (dist < distances[0]) {
                        distances = vec4(dist, distances.xyz);
                        indices = uvec4(index, indices.xyz);
                    } else if (dist < distances[1]) {
                        distances = vec4(distances.x, dist, distances.yz); 
                        indices = uvec4(indices.x, index, indices.yz);
                    } else if (dist < distances[2]) {
                        distances = vec4(distances.xy, dist, distances.z); 
                    } else if (dist < distances[3]) {
                        distances = vec4(distances.xyz, dist);             
                    }
              }
            }
        }
    }

    for(int i = 0; i < 4; i++) {
    shapeD = smin(distances[i], shapeD, 0.05 - smoothstep(0.0, 1.0, sin((iTime + 1.0) * 0.5)) * 0.009);
    }

    return shapeD;
}


float getSpheresSDF(vec3 p) {
    vec3 voxelPos = worldToVoxel(p.xyzz).xyz;
    ivec3 basePos = ivec3(floor(voxelPos));

    float shapeD = 9999.0;
    for(int z = -1; z <= 1; z++) {     
        for(int y = -1; y <= 1; y++) {   
            for(int x = -1; x <= 1; x++) {
                ivec3 sampleCoord = basePos + ivec3(x, y, z);

                uvec4 fetchedClosest = fetchClosest3D(vec3(sampleCoord), iChannel1);
                for (int j = 0; j < 2; j++) {
                    uint sphereIdx = fetchedClosest[j];
                    if(sphereIdx == uint(-1)) { continue; }

                    vec4 e = texelFetch(iChannel0, ivec2(sphereIdx, 0), 0);
                    e.w += pow(1.0 - e.w, 8.0) * 0.005;
                    float nd = length(e.xyz - p) - e.w;
                    shapeD = smin(nd, shapeD, 0.0125 - smoothstep(0.0, 1.0, sin((iTime + 1.0) * 0.5)) * 0.009);
              }
            }
        }
    }



    return shapeD;
}


float raymarchMap(vec3 ro, vec3 rd, bool groundTruth) {
    float t = 0.0;
    for(int i = 0; i < 32; i++) {
        vec3 p = ro + rd * t;
        
        float shapeD = !groundTruth ? 1e4 : scene(p) + 0.015;
        
        if(!groundTruth) {
            shapeD = min(getSpheresSDF(p), shapeD);
        }
        
        if(shapeD < 0.005) 
            return t;
        
        t += shapeD;
        
        if(t > 6.0) 
            break;  
    }
    return t;
}

vec3 getNormal(vec3 p) {
	float d = scene(p);
    vec2 e = vec2(.01, 0);
    
    vec3 n = d - vec3(
        scene(p-e.xyy),
        scene(p-e.yxy),
        scene(p-e.yyx));
    
    return normalize(n);
}

vec3 getSpheresNormal(vec3 p) {
	float d = getSpheresSDF(p);
    vec2 e = vec2(.01, 0);
    
    vec3 n = d - vec3(
        getSpheresSDF(p-e.xyy),
        getSpheresSDF(p-e.yxy),
        getSpheresSDF(p-e.yyx));
    
    return normalize(n);
}

vec3 shade( in vec3 p, in vec3 n, in vec3 ro, in vec3 rd, vec3 lp) {		
	float latt = pow(length(lp - p) * 2.0, 2.5) * 2.25;
    vec3 ld = normalize(vec3(2.0));
	vec3 diff = vec3(0.2,.5,1.) * (max(dot(n, ld),0.) ) ;
    vec3 col =  diff * 0.5;
	float trans =  pow( clamp( dot(-rd, -ld+n), 0., 1.), 1.) + 1.0;
	col += vec3(1.0,.2,.35) * (trans / latt );
    col += vec3(specular(p, rd, n, lp)) * 0.1;
    col += smoothstep(1., 0.6, dot(-rd, n)) * 0.1;

	return col;
}



void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy * 2.0 - 1.0;


    vec2 center   = vec2(0.5, 0.0);
    vec2 uvLeft   = uv + center;
    vec2 uvRight  = uv - center;

    float aspect = iResolution.x / iResolution.y;
    uvLeft.x  *= aspect;
    uvRight.x *= aspect;

    bool isLeftSide = (fragCoord.x < 0.5 * iResolution.x);

    bool groundTruth = isLeftSide;

    vec2 uvCam = isLeftSide ? uvLeft : uvRight;
    vec2 mouse = (iMouse.xy - 0.5 * iResolution.xy) / iResolution.y;

    vec3 rd = normalize(vec3(uvCam, -1.5));
    vec3 ro = vec3(0.0, 0.0, 2.0);

    float yrot = 0.0;
    float zrot =  sin(iTime * 2.0) * 0.25;
    if (iMouse.z > 0.0) {
        yrot += -4.0 * mouse.y;
        zrot = 4.0 * mouse.x;
    }
    rd = rotate(rd, vec3(1, 0, 0), yrot);
    ro = rotate(ro, vec3(1, 0, 0), yrot);
    rd = rotate(rd, vec3(0, 1, 0), zrot);
    ro = rotate(ro, vec3(0, 1, 0), zrot);
    

    float t = raymarchMap(ro, rd, groundTruth);

    if(t > 6.0) {
        fragColor = vec4(0.5, 0.5, 1.0, 1.0) * pow(length(uvCam), 0.33) * 0.5 * (hash(uvCam) * 0.1 + 0.9);
        return;
    }

    vec3 p   = ro + rd * t;    
    //vec3 nor =  isLeftSide ? getNormal(p) : getSpheresNormal(p);  
    vec3 nor =   getNormal(p);
    vec3 lp =  vec3(0.0, 0.095, 0.125);

    vec3 col = shade(p, nor, vec3(0.0), normalize(vec3(-1.5, uvCam)), lp);
    
    float rim = pow(clamp(1.0 - dot(nor, -rd), 0.0, 1.0), 3.0);
    col += vec3(0.5, 0.7, 1.0)*rim*0.25;

    fragColor = vec4(col, 1.0);
}

