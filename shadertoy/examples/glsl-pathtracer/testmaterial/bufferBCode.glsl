#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (24 + MESH_DATA_OFFSET)
#define lightsTex (36 + MESH_DATA_OFFSET)
#define BVH (46 + MESH_DATA_OFFSET)
#define vertexIndicesTex (2833 + MESH_DATA_OFFSET)
#define verticesTex (3807 + MESH_DATA_OFFSET)
#define normalsTex (6729 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 2;
int maxDepth = 8;
int topBVHIndex = 923;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);