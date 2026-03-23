#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (56 + MESH_DATA_OFFSET)
#define lightsTex (60 + MESH_DATA_OFFSET)
#define BVH (60 + MESH_DATA_OFFSET)
#define vertexIndicesTex (1395489 + MESH_DATA_OFFSET)
#define verticesTex (1940055 + MESH_DATA_OFFSET)
#define normalsTex (3573753 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 465141;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 5.000000;

int textureMapsArrayIndices[1] = int[](0);