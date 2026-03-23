#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (32 + MESH_DATA_OFFSET)
#define lightsTex (44 + MESH_DATA_OFFSET)
#define BVH (59 + MESH_DATA_OFFSET)
#define vertexIndicesTex (16563356 + MESH_DATA_OFFSET)
#define verticesTex (24825798 + MESH_DATA_OFFSET)
#define normalsTex (49613124 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 3;
int maxDepth = 2;
int topBVHIndex = 5521093;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);