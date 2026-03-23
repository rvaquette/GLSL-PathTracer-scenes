#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (248 + MESH_DATA_OFFSET)
#define lightsTex (520 + MESH_DATA_OFFSET)
#define BVH (530 + MESH_DATA_OFFSET)
#define vertexIndicesTex (4018880 + MESH_DATA_OFFSET)
#define verticesTex (5510630 + MESH_DATA_OFFSET)
#define normalsTex (9985880 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 2;
int maxDepth = 3;
int topBVHIndex = 1339314;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[4] = int[](0, 1, 2, 3);