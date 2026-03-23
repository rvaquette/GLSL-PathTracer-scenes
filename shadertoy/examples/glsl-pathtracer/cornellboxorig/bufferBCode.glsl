#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (64 + MESH_DATA_OFFSET)
#define lightsTex (92 + MESH_DATA_OFFSET)
#define BVH (97 + MESH_DATA_OFFSET)
#define vertexIndicesTex (220 + MESH_DATA_OFFSET)
#define verticesTex (254 + MESH_DATA_OFFSET)
#define normalsTex (356 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 1;
int maxDepth = 2;
int topBVHIndex = 27;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 2.000000;

int textureMapsArrayIndices[1] = int[](0);