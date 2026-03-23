#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (24 + MESH_DATA_OFFSET)
#define lightsTex (3040 + MESH_DATA_OFFSET)
#define BVH (3040 + MESH_DATA_OFFSET)
#define vertexIndicesTex (369436 + MESH_DATA_OFFSET)
#define verticesTex (497282 + MESH_DATA_OFFSET)
#define normalsTex (880820 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 120624;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[10] = int[](0, 1, 2, 3, 4, 5, 6, 7, 8, 9);