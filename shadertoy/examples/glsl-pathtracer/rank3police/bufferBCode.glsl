#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (328 + MESH_DATA_OFFSET)
#define lightsTex (560 + MESH_DATA_OFFSET)
#define BVH (560 + MESH_DATA_OFFSET)
#define vertexIndicesTex (3468452 + MESH_DATA_OFFSET)
#define verticesTex (4760560 + MESH_DATA_OFFSET)
#define normalsTex (8636884 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 1155848;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[69] = int[](0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68);