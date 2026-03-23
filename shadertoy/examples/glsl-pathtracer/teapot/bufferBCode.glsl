#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (24 + MESH_DATA_OFFSET)
#define lightsTex (36 + MESH_DATA_OFFSET)
#define BVH (36 + MESH_DATA_OFFSET)
#define vertexIndicesTex (344847 + MESH_DATA_OFFSET)
#define verticesTex (470897 + MESH_DATA_OFFSET)
#define normalsTex (849047 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 114931;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 5.000000;

int textureMapsArrayIndices[1] = int[](0);