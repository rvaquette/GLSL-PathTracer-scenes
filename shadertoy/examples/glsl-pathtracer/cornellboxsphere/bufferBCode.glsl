#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (72 + MESH_DATA_OFFSET)
#define lightsTex (100 + MESH_DATA_OFFSET)
#define BVH (105 + MESH_DATA_OFFSET)
#define vertexIndicesTex (44448 + MESH_DATA_OFFSET)
#define verticesTex (60342 + MESH_DATA_OFFSET)
#define normalsTex (108024 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 1;
int maxDepth = 3;
int topBVHIndex = 14767;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);