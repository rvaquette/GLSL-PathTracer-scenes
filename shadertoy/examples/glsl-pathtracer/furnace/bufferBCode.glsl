#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (16 + MESH_DATA_OFFSET)
#define lightsTex (20 + MESH_DATA_OFFSET)
#define BVH (20 + MESH_DATA_OFFSET)
#define vertexIndicesTex (11279 + MESH_DATA_OFFSET)
#define verticesTex (15247 + MESH_DATA_OFFSET)
#define normalsTex (27151 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 3;
int topBVHIndex = 3751;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);