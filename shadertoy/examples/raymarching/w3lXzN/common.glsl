/*

    '3D' Texture Utils
    ------------------

	These allow reading and writing to a cubemap texture that's
    repurposed as a 3D texture.

*/


//#define fTime mod(iTime / 3., 1.)
#define fTime (0.)

vec2 texSubdivisions = vec2(8,2);

#define MIRROR
#define SCALE (vec3(4.1,1.73,1.75)/1.1)
#define OFFSET vec3(.95, .094, -.088)

// #define SCALE vec3(1)
// #define OFFSET vec3(0)

// Cube face ID from direction
// 0 x
// 1 y
// 2 z
// 3 -x
// 4 -y
// 5 -z
int faceIdFromDir(vec3 v) {
    vec3 va = abs(v);
    int id = 0;
    float m = va.x;
    if (va.y > m) id = 1, m = va.y;
    if (va.z > m) id = 2;
    if (v[id] < 0.) id += 3;
    return id;
}


// Direction from uv and cube face ID
// uv: vec2(0,0) to vec2(1,1)
// id: 0 to 5
vec3 dirFromFaceId(vec2 uv, int id) {
    vec3 dir = vec3(.5, .5 - uv.yx);
    dir = normalize(dir);
    if (id == 4) dir.yz *= -1.;
    if (id > 2) dir.xz *= -1., id -= 3;
    if (id == 1) return (dir * vec3(1,-1,-1)).zxy;
    if (id == 2) return (dir * vec3(1,1,-1)).zyx;    
    return dir;
}


// Divide texture into 3d space coordinates
// uv = 2d texture coordinates 0:1
// c = channel 0:3
// id = face id 0:6

// xy is split for each z
// z is split across channels and cube map faces (4 * 6 = 24)

// Returns matrix representing four positions in space
// vec3 p0 = mat4[0].xyz;
// vec3 p1 = mat4[1].xyz;
// vec3 p2 = mat4[2].xyz;
// vec3 p3 = mat4[4].xyz;

vec3 texToSpace(vec2 coord, int c, int id, vec2 size) {
    vec2 sub = texSubdivisions;
    vec2 subSize = floor(size / sub);
    vec2 subCoord = floor(coord / subSize);
    float z = 0.;
    z += float(id) * 4. * sub.y * sub.x; // face offset
    z += float(c) * sub.y * sub.x; // channel offset
    z += subCoord.y * sub.x; // y offset
    z += subCoord.x; // x offset
    float zRange = sub.x * sub.y * 4. * 6. - 1.;
    z /= zRange;
    vec2 subUv = mod(coord / subSize, 1.);
    vec3 p = vec3(subUv, z);
    p = p * 2. - 1.; // range -1:1
    return p;
}

mat4 texToSpace(vec2 coord, int id, vec2 size) {
    return mat4(
        vec4(texToSpace(coord, 0, id, size), 0),
        vec4(texToSpace(coord, 1, id, size), 0),
        vec4(texToSpace(coord, 2, id, size), 0),
        vec4(texToSpace(coord, 3, id, size), 0)
    );
}


// Transform xyz coordinate in range -1,-1,-1 to 1,1,1
// to texture rayDir and channel
vec4 spaceToTex(vec3 p, vec2 size) {
    p = clamp(p, -1., 1.);
    p = p * .5 + .5; // range 0:1

    vec2 sub = texSubdivisions;
    vec2 subSize = floor(size / sub);

    // Work out the z index
    float zRange = sub.x * sub.y * 4. * 6. - 1.;
    float i = round(p.z * zRange);

    // return vec3(mod(i, sub.x)/sub.x);
    // translate uv into the micro offset in the z block
    vec2 coord = p.xy * subSize;

    int faceId = int(floor(i / (4. * sub.y * sub.x)));
    float channel = mod(floor(i / (sub.x * sub.y)), 4.);
    float y = mod(floor(i / sub.x), sub.y);
    float x = mod(i, sub.x);
    
    // Work out the macro offset for the xy block from the z block
    coord += vec2(x,y) * subSize;
	coord /= size;
    
    vec3 dir = dirFromFaceId(coord, faceId);

    return vec4(dir, channel);
}

float range(float vmin, float vmax, float value) {
  return clamp((value - vmin) / (vmax - vmin), 0., 1.);
}

float mapTex(samplerCube tex, vec3 p, vec2 size) {
    // stop x bleeding into the next cell as it's the mirror cut
    #ifdef MIRROR
        p.x = clamp(p.x, -.95, .95);
    #endif
    vec2 sub = texSubdivisions;
    float zRange = sub.x * sub.y * 4. * 6. - 1.;
    float z = p.z * .5 + .5; // range 0:1
    float zFloor = (floor(z * zRange) / zRange) * 2. - 1.;
    float zCeil = (ceil(z * zRange) / zRange) * 2. - 1.;
    vec4 uvcA = spaceToTex(vec3(p.xy, zFloor), size);
    vec4 uvcB = spaceToTex(vec3(p.xy, zCeil), size);
    float a = texture(tex, uvcA.xyz)[int(uvcA.w)];
    float b = texture(tex, uvcB.xyz)[int(uvcB.w)];
    return mix(a, b, range(zFloor, zCeil, p.z));
}

