#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (48 + MESH_DATA_OFFSET)
#define lightsTex (84 + MESH_DATA_OFFSET)
#define BVH (84 + MESH_DATA_OFFSET)
#define vertexIndicesTex (291 + MESH_DATA_OFFSET)
#define verticesTex (352 + MESH_DATA_OFFSET)
#define normalsTex (535 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 51;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[4] = int[](0, 1, 2, 3);