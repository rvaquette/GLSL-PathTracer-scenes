float getAvailableSpaceSDF(vec3 p, int currentIndex) {
    float shapeSDF = scene(p);
    
    uvec4 fetchedClosest = fetchClosest3D(worldToVoxel(p.xyzz).xyz, iChannel1);

    for(int i = 0; i < 4; i++) {
        uint sphereIdx = fetchedClosest[i];
        if(sphereIdx == uint(-1)) { continue; }
        vec4 circle = texelFetch(iChannel0, ivec2(sphereIdx, 0), 0);
        if(circle.w <= 0.0) continue;

        float currentCircleSDF = length(p - circle.xyz) - circle.w * 1.0;
        shapeSDF = max(-currentCircleSDF, shapeSDF);
    }
    
    
    for(int i = 0; i < (currentIndex % 4); i++) {
        vec4 circle = texelFetch(iChannel0, ivec2(i, 0), 0);
        if(circle.w <= 0.0) continue;
        
        float currentCircleSDF = length(p - circle.xyz) - circle.w * 1.0;
        
        shapeSDF = max(-currentCircleSDF, shapeSDF);
    }
    
    return shapeSDF;
}

vec4 gtSDG(vec3 pos) {
    float eps = 0.02;
    vec3 n;
    float d = scene(pos);
    n.x = scene(vec3(pos.x + eps, pos.y, pos.z)) - d;
    n.y = scene(vec3(pos.x, pos.y + eps, pos.z)) - d;
    n.z = scene(vec3(pos.x, pos.y, pos.z + eps)) - d;

    return vec4(n, d);
}

vec3 availableSpaceSDG(vec3 pos, int currentIndex) {
    float eps = 0.02;
    vec3 n;
    float d = getAvailableSpaceSDF(pos, currentIndex);
    n.x = getAvailableSpaceSDF(vec3(pos.x + eps, pos.y, pos.z), currentIndex) - d;
    n.y = getAvailableSpaceSDF(vec3(pos.x, pos.y + eps, pos.z), currentIndex) - d;
    n.z = getAvailableSpaceSDF(vec3(pos.x, pos.y, pos.z + eps), currentIndex) - d;

    return n;
}

vec3 snapToMedialAxis(vec3 candidate, int currentIndex) {
    vec3 pos = candidate;
    float s = 0.1;   
    float alpha = 0.1;  
    float beta = 0.5;    

    for(int iter = 0; iter < 32; iter++) {
        vec3 g = gtSDG(pos).xyz; //availableSpaceSDG(pos, currentIndex).xyz;
        float mg = length(g);        
        if(mg < 1e-4) break; 
        
        vec3 dir = g / mg;
        
        float currentSDF = getAvailableSpaceSDF(pos, currentIndex);        
        float stepSize = s;
        bool stepAccepted = false;

        while(stepSize > 1e-4) {
            vec3 newPos = pos - stepSize * dir;            
            float newSDF = getAvailableSpaceSDF(newPos, currentIndex);
            
            if(newSDF <= currentSDF - alpha * stepSize * mg) {
                pos = newPos;
                stepAccepted = true;
                break;
            }
            
            stepSize *= beta;
        }
        
        if(!stepAccepted) {
            break;
        }
        
        s = stepSize;
    }
    
    return pos;
}


void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord.xy / iResolution.xy) * 2.0 - 1.0;
    
    if(fragCoord.y > 0.5) {
        fragColor = vec4(0.0);
        return;
    }
    
    
    int circleIndex = int(fragCoord.x);
    
    if(circleIndex >= N_SPHERES) {
        fragColor = vec4(0.0);
        return;
    }
    
    vec4 oldData = texelFetch(iChannel0, ivec2(circleIndex, 0), 0);
    vec3 center = oldData.xyz;
    float radius = oldData.w;
    
    if(circleIndex > iFrame) {
        fragColor = oldData;
        return;
    }
    
    srand(ivec2(fragCoord), iFrame);
    if(circleIndex == iFrame && iFrame < N_SPHERES) {
        float bestScore = -1.0;
        vec3 bestPos = randomOnSphere() * frand();
        
        for(int c = 0; c < 16; c++) {
            vec3 candidate;
            float spaceSDF = 0.0;
            
            candidate = bestPos + randomOnSphere() * frand() * frand() * mix(0.05, 1.0, float(c) / 7.0);
            spaceSDF = getAvailableSpaceSDF(candidate, circleIndex);

            if(spaceSDF > 0.1) {
                vec3 g = availableSpaceSDG(candidate, circleIndex);
                candidate -= g * spaceSDF * 1.001;
            }
                        
            float score = -spaceSDF;
            
            vec3 snapped = snapToMedialAxis(candidate, circleIndex);
            float snappedSpaceSDF = getAvailableSpaceSDF(snapped, circleIndex);
            float snappedScore = -snappedSpaceSDF;
            
            if(snappedSpaceSDF < 0.0 && snappedScore > score) {
                candidate = snapped;
                score = snappedScore;
            }
            
            
            if(score > bestScore) {
                bestScore = score;
                bestPos = candidate;
            }
        }
        
        if(bestScore > MIN_RADIUS) {
            center = bestPos;
            radius = max(bestScore, MIN_RADIUS);
        } else {
            center = vec3(0.0);
            radius = 0.0;
        }
    }
    fragColor = vec4(center, radius);
}

