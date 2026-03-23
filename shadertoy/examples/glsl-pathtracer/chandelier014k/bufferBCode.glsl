#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (16 + MESH_DATA_OFFSET)
#define lightsTex (24 + MESH_DATA_OFFSET)
#define BVH (24 + MESH_DATA_OFFSET)
#define vertexIndicesTex (74928 + MESH_DATA_OFFSET)
#define verticesTex (101788 + MESH_DATA_OFFSET)
#define normalsTex (182368 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 24964;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[3] = int[](0, 1, 2);