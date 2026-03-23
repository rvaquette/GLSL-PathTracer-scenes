#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (112 + MESH_DATA_OFFSET)
#define lightsTex (168 + MESH_DATA_OFFSET)
#define BVH (168 + MESH_DATA_OFFSET)
#define vertexIndicesTex (211164 + MESH_DATA_OFFSET)
#define verticesTex (293381 + MESH_DATA_OFFSET)
#define normalsTex (540032 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 70304;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[28] = int[](0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27);