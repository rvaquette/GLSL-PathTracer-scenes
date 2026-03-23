#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (24 + MESH_DATA_OFFSET)
#define lightsTex (32 + MESH_DATA_OFFSET)
#define BVH (37 + MESH_DATA_OFFSET)
#define vertexIndicesTex (85 + MESH_DATA_OFFSET)
#define verticesTex (99 + MESH_DATA_OFFSET)
#define normalsTex (141 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 1;
int maxDepth = 5;
int topBVHIndex = 12;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);