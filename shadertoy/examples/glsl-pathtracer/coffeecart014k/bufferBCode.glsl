#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (24 + MESH_DATA_OFFSET)
#define lightsTex (36 + MESH_DATA_OFFSET)
#define BVH (36 + MESH_DATA_OFFSET)
#define vertexIndicesTex (75747 + MESH_DATA_OFFSET)
#define verticesTex (103406 + MESH_DATA_OFFSET)
#define normalsTex (186383 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 25231;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[6] = int[](0, 1, 2, 3, 4, 5);