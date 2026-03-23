// I thought it could be a fun exercise to make skeletal animation in shadertoy.
// It's supposed to be a wireframe of a fish or something like that.
// 2D animation only, though extending to 3d should be quite similar.

// Yellow lines are the bones, blue ones vertices and green ones rendered wireframe.
// Only one bone / vertex, so the weight of each vertex/bone is always 1.

#define PI 3.14159265358

#define BONE_H .07
#define BONE_W .017
#define BONES 5
#define VERTICES 9
#define INDICES 21

vec2 g_uv;


struct Vertex
{
    vec3 pos;
    int boneIndex; // index of bone this vertex belongs to. The weight is always 1.
};



struct Bone
{
    mat3 localMatrix; // local coordinates, rotation + position
    float h;
    float w;
};

    
    
Vertex vertices[VERTICES];
Bone bones[BONES];
mat3 bonesWorld[BONES];
mat3 boneInversesWorld[BONES];


// https://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
float line(in vec2 from, in vec2 to, float w)
{
    float l2 = dot(to-from, to-from);
    float t = max(0., min(1.0, dot(g_uv-from, to-from) / l2));
    vec2 projection = from + t * (to - from);
    w *= dFdx(g_uv.x);
    return smoothstep(0.0025, 0.0025 - w * 4., length(g_uv - projection));
}

float bone(in vec2 from, in vec2 to, float w)
{
    float l2 = dot(to-from, to-from);
    float t = max(0., min(1.0, dot(g_uv-from, to-from) / l2));
    vec2 projection = from + t * (to - from);
    w *= dFdx(g_uv.x);
    float f = length(g_uv-from) * .04;
    return smoothstep(0.002 + f, 0.002 - w + f, length(g_uv - projection));
}

float circle(in vec2 pos, float r)
{
    return length(g_uv - pos) - r;
}

mat3 rotation(float angle)
{
    mat3 rm;
    rm[0][0] = cos(angle);
    rm[0][1] = -sin(angle);
    rm[1][0] = sin(angle);
    rm[1][1] = cos(angle);
    rm[2] = vec3(0.0, 0.0, 1.0);
    return rm;
}


Bone getBone(in Bone parent, float h)
{
	Bone b;
    b.w = BONE_W;
    b.h = h;
    
    mat3 r;
    r[0] = vec3(1.0, 0.0, 0.0);
    r[1] = vec3(0.0, 1.0, 0.0);
    r[2] = vec3(0.0, h, 1.0); // h = offset from the parent bone vertically
    b.localMatrix = r;

    return b;
}

void calculateWorldMatrices()
{
 
    for (int i = 0; i < BONES; ++i)
    {
        bonesWorld[i] = bones[i].localMatrix;
    }
    
    for (int i = 1; i < BONES; ++i)
    {
        bonesWorld[i] = bonesWorld[i - 1] * bonesWorld[i];
    }
    
}

void calculateWorldMatriceInverses()
{
    for (int i = 0; i < BONES; ++i)
    {
        boneInversesWorld[i] = inverse(bonesWorld[i]);
    }    
}



void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor=vec4(.95, .95, 1., .0);
	g_uv = ((fragCoord.xy - iResolution.xy*.5) / iResolution.xy) * vec2(1.0, iResolution.y / iResolution.x);
    vec2 _uv = g_uv;
    g_uv *= .5 + sin(iTime * .5) * .05;
    g_uv.y += 0.1;
    
    Bone root;
    root.localMatrix[0] = vec3(1.0, 0.0, 0.0);
    root.localMatrix[1] = vec3(0.0, 1.0, 0.0);
    root.localMatrix[2] = vec3(0.0, 0.0, 1.0);
    
    root.w = 0.;
    root.h = 0.;

    /////// Creating the "Bind pose"
    bones[0] = root;

    bones[1] = getBone(root, BONE_H);
    bones[2] = getBone(bones[1],BONE_H);
    bones[3] = getBone(bones[2],BONE_H);
    bones[4] = getBone(bones[3],BONE_H * .2);
    
    // this step is for 
    // calculating the world matrice inverses
    calculateWorldMatrices();
	calculateWorldMatriceInverses();
    
    //////////////////////////////////////////////////
    ///// Animation //////////////////////////////////
    //////////////////////////////////////////////////
    
    // This is the "animation data", which is some translation or rotation applied to the bones
    bones[0].localMatrix = rotation(cos(iTime * 2.) * .2) * bones[0].localMatrix;
    bones[0].localMatrix[2] += vec3(sin(-PI*.5+iTime * 2.)* .008, sin(iTime)*.01, 0.0);
    bones[2].localMatrix = rotation(sin(iTime * 2.)*.15) * bones[2].localMatrix;
    
    // moving the middle bone a little, just to see that the animation will work with that.
    bones[2].localMatrix[2] += vec3(0.0, sin(iTime)*.01, 0.0);
    
    // last bone rotations
    bones[3].localMatrix = rotation(sin(iTime * 2.)*.2) * bones[3].localMatrix;
    bones[4].localMatrix = rotation(sin(iTime * 2.)*.4) * bones[4].localMatrix;
    
    // calculate world matrices at the animated pose.
    calculateWorldMatrices();
	
	// render bones    
    for (int i = 1; i < BONES; ++i)
    {
        vec4 color = bone(bonesWorld[i][2].xy, bonesWorld[i-1][2].xy, 3.) * vec4(1.0, 1.0, 0.0, 1.);
        fragColor = mix(fragColor, color, color.a);
    }
    
    float W = 1.5;
    float H = 1.;
    
    // build vertices
    vertices[0].pos = vec3(0., 0., 1.);
    vertices[0].boneIndex = 0;
    
    vertices[1].pos = vec3(0.027 * W, 0.05 * H, 1.);
    vertices[1].boneIndex = 1;

    vertices[2].pos = vec3(-vertices[1].pos.x, vertices[1].pos.y, 1.);
    vertices[2].boneIndex = vertices[1].boneIndex;

    vertices[3].pos = vec3(0.005 * W, 0.14 * H, 1.);
    vertices[3].boneIndex = 2;

    vertices[4].pos = vec3(-vertices[3].pos.x, vertices[3].pos.y, 1.);
    vertices[4].boneIndex = 2;
    
    vertices[5].pos = vec3(0.0015 * W, 0.2 * H, 1.);
    vertices[5].boneIndex = 3;
    
    vertices[6].pos = vec3(-vertices[5].pos.x, vertices[5].pos.y, 1.);
    vertices[6].boneIndex = vertices[5].boneIndex;

    vertices[7].pos = vec3(0.015 * W, 0.22 * H, 1.);
    vertices[7].boneIndex = 4;

    vertices[8].pos = vec3(-vertices[7].pos.x, vertices[7].pos.y, 1.);
    vertices[8].boneIndex = vertices[7].boneIndex;
    
    // render vertices at their new transformed positions
    for (int i = 0; i < VERTICES; ++i)
    {
        // offset matrix contains a delta from the bind pose to the animated pose
        // you get this delta by multiplying the current pose by the inverse of the bind pose.
        // it's what you want to transform the vertices with.
        mat3 offsetMatrix = (bonesWorld[vertices[i].boneIndex] * boneInversesWorld[vertices[i].boneIndex]);
        vec3 p = offsetMatrix * vertices[i].pos;
        vec4 color = vec4(0., 0., 1.,1.) * smoothstep(dFdx(g_uv.x) * 2.5, 0.0, circle(p.xy, .002));
	    fragColor = mix(fragColor, color, color.a);
        vertices[i].pos = p;
    }
    
    
    // rendering the wireframe
    int indices[INDICES];
    
    indices[0] = 0;
    indices[1] = 1;
    indices[2] = 2;

    indices[3] = 2;
    indices[4] = 3;
    indices[5] = 1;

    indices[6] = 4;
    indices[7] = 2;
    indices[8] = 3;

    indices[9]  = 4;
    indices[10] = 5;
    indices[11] = 6;

    indices[12] = 3;
    indices[13] = 5;
    indices[14] = 4;

    indices[15] = 6;
    indices[16] = 7;
    indices[17] = 8;

    indices[18] = 5;
    indices[19] = 6;
    indices[20] = 7;
    
    
    
    for (int i = 0; i < INDICES; i = i + 3)
    {
       vec4 color = line(vertices[indices[i]].pos.xy, vertices[indices[i + 1]].pos.xy, .5) * vec4(0., 1., 0., 1.);
       fragColor = mix(fragColor, color, color.a);
        
       color = line(vertices[indices[i + 1]].pos.xy, vertices[indices[i + 2]].pos.xy, .5) * vec4(0., 1., 0., 1.);
       fragColor = mix(fragColor, color, color.a);

       color = line(vertices[indices[i + 0]].pos.xy, vertices[indices[i + 2]].pos.xy, .5) * vec4(0., 1., 0., 1.);
       fragColor = mix(fragColor, color, color.a);
    }
    
    //wignetting
    fragColor = mix(fragColor, vec4(0.1,  0.1, 0.15, 0.), smoothstep(0.2,0.8, length(_uv*vec2(1.1, 1.9))));
}
