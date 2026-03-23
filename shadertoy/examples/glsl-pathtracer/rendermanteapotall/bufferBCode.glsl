#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (104 + MESH_DATA_OFFSET)
#define lightsTex (160 + MESH_DATA_OFFSET)
#define BVH (175 + MESH_DATA_OFFSET)
#define vertexIndicesTex (1304665 + MESH_DATA_OFFSET)
#define verticesTex (1788585 + MESH_DATA_OFFSET)
#define normalsTex (3240345 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 3;
int maxDepth = 10;
int topBVHIndex = 434802;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[15] = int[](0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14);