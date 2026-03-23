#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (32 + MESH_DATA_OFFSET)
#define lightsTex (48 + MESH_DATA_OFFSET)
#define BVH (48 + MESH_DATA_OFFSET)
#define vertexIndicesTex (222780 + MESH_DATA_OFFSET)
#define verticesTex (303550 + MESH_DATA_OFFSET)
#define normalsTex (545860 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 74236;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);