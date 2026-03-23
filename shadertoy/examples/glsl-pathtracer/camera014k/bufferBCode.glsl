#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (32 + MESH_DATA_OFFSET)
#define lightsTex (52 + MESH_DATA_OFFSET)
#define BVH (52 + MESH_DATA_OFFSET)
#define vertexIndicesTex (75661 + MESH_DATA_OFFSET)
#define verticesTex (102648 + MESH_DATA_OFFSET)
#define normalsTex (183609 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 25193;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[9] = int[](0, 1, 2, 3, 4, 5, 6, 7, 8);