
void fetchAndSortClosest3D(
    inout vec4 distances, 
    inout uvec4 indices,
    in vec3 samplePoint,
    in vec3 voxelCenter
) {
    uvec4 ids = fetchClosest3D(samplePoint, iChannel1);
    
    for (int i = 0; i < 4; i++) {
        sortClosest(distances, indices, ids[i], voxelCenter, iChannel0);
    }
}


float randomFloat(inout uint state) {
    state ^= state >> 16;
    state *= 0x7feb352dU;
    state ^= state >> 15;
    state *= 0x846ca68bU;
    state ^= state >> 16;
    return float(state) / 4294967296.0;
}

vec3 randomDir3D(inout uint state) {
    float z  = randomFloat(state) * 2.0 - 1.0;  // range [-1,1]
    float az = randomFloat(state) * PI2;
    float r  = sqrt(1.0 - z * z);
    float x  = r * cos(az);
    float y  = r * sin(az);
    return vec3(x, y, z);
}

uint rngSeed = 314159265u;
uint xorshift(in uint value) {
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value;
}
uint nextUint() {
    rngSeed = xorshift(rngSeed);
    return rngSeed;
}
float nextFloat() {
    return float(nextUint()) / float(uint(-1));
}

uint murmur3( in uint u )
{
  u ^= ( u >> 16 ); u *= 0x85EBCA6Bu;
  u ^= ( u >> 13 ); u *= 0xC2B2AE35u;
  u ^= ( u >> 16 );

  return u;
}


void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 fc = ivec2(fragCoord);
    ivec2 maxSize = ivec2(slicesPerRow * iResolution3D.x);
    if (any(greaterThanEqual(fc, maxSize))) {fragColor = vec4(0.0); return; }
  
    ivec3 cellCoord = from2D(fc, iResolution3D); 
    vec3 voxelCenter = vec3(cellCoord) + 0.5; 
    
    vec4 bestDistances = vec4(FLOAT_INF);
    uvec4 closestIndices = uvec4(uint(-1));
    
    if (iFrame == 0) {
        closestIndices = uvec4(nextUint(), nextUint(), nextUint(), nextUint()) % 63u;
    }
    
    uint seed = uint(iFrame) + uint(fragCoord.x) + uint(fragCoord.y);
    float rad = 3.0;

    fetchAndSortClosest3D(bestDistances, closestIndices, voxelCenter, voxelCenter);
    fetchAndSortClosest3D(bestDistances, closestIndices, voxelCenter + randomDir3D(seed) * rad, voxelCenter);
    fetchAndSortClosest3D(bestDistances, closestIndices, voxelCenter + randomDir3D(seed) * rad, voxelCenter);
    fetchAndSortClosest3D(bestDistances, closestIndices, voxelCenter + randomDir3D(seed) * rad, voxelCenter);
    fetchAndSortClosest3D(bestDistances, closestIndices, voxelCenter + randomDir3D(seed) * rad, voxelCenter);

    rngSeed = murmur3(uint(fragCoord.x)) ^ murmur3(floatBitsToUint(fragCoord.y)) ^ murmur3(floatBitsToUint(iTime));

    for (int i = 0; i < 16; i++) {
        sortClosest(bestDistances, closestIndices, nextUint() % PARTICLE_COUNT, voxelCenter, iChannel0);
    }
    

    fragColor = uintBitsToFloat(closestIndices);
}

