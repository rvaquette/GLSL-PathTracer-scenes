#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (56 + MESH_DATA_OFFSET)
#define lightsTex (92 + MESH_DATA_OFFSET)
#define BVH (92 + MESH_DATA_OFFSET)
#define vertexIndicesTex (126467 + MESH_DATA_OFFSET)
#define verticesTex (173056 + MESH_DATA_OFFSET)
#define normalsTex (312823 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 42107;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[7] = int[](0, 1, 2, 3, 4, 5, 6);