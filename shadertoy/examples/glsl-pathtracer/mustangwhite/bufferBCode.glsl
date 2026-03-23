#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (88 + MESH_DATA_OFFSET)
#define lightsTex (128 + MESH_DATA_OFFSET)
#define BVH (128 + MESH_DATA_OFFSET)
#define vertexIndicesTex (5082308 + MESH_DATA_OFFSET)
#define verticesTex (6921311 + MESH_DATA_OFFSET)
#define normalsTex (12438320 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 7;
int topBVHIndex = 1694040;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.411000;

int textureMapsArrayIndices[1] = int[](0);