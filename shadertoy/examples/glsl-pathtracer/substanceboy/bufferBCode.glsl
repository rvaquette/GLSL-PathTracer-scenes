#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (40 + MESH_DATA_OFFSET)
#define lightsTex (68 + MESH_DATA_OFFSET)
#define BVH (78 + MESH_DATA_OFFSET)
#define vertexIndicesTex (240906 + MESH_DATA_OFFSET)
#define verticesTex (326132 + MESH_DATA_OFFSET)
#define normalsTex (581810 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 2;
int maxDepth = 2;
int topBVHIndex = 80262;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[10] = int[](0, 1, 2, 3, 4, 5, 6, 7, 8, 9);