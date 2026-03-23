#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (104 + MESH_DATA_OFFSET)
#define lightsTex (448 + MESH_DATA_OFFSET)
#define BVH (458 + MESH_DATA_OFFSET)
#define vertexIndicesTex (1252148 + MESH_DATA_OFFSET)
#define verticesTex (1707304 + MESH_DATA_OFFSET)
#define normalsTex (3072772 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 2;
int maxDepth = 6;
int topBVHIndex = 417058;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);