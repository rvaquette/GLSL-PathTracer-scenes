#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (64 + MESH_DATA_OFFSET)
#define lightsTex (312 + MESH_DATA_OFFSET)
#define BVH (312 + MESH_DATA_OFFSET)
#define vertexIndicesTex (825078 + MESH_DATA_OFFSET)
#define verticesTex (1103664 + MESH_DATA_OFFSET)
#define normalsTex (1939422 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 4;
int topBVHIndex = 274798;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);