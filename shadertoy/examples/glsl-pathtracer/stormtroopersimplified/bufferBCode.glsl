#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (32 + MESH_DATA_OFFSET)
#define lightsTex (44 + MESH_DATA_OFFSET)
#define BVH (59 + MESH_DATA_OFFSET)
#define vertexIndicesTex (1863020 + MESH_DATA_OFFSET)
#define verticesTex (2775294 + MESH_DATA_OFFSET)
#define normalsTex (5512116 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 3;
int maxDepth = 2;
int topBVHIndex = 620981;
float roughnessMollificationAmt = 0.000000;

int textureMapsArrayIndices[1] = int[](0);