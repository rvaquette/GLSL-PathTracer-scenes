#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (232 + MESH_DATA_OFFSET)
#define lightsTex (408 + MESH_DATA_OFFSET)
#define BVH (438 + MESH_DATA_OFFSET)
#define vertexIndicesTex (13731636 + MESH_DATA_OFFSET)
#define verticesTex (18979676 + MESH_DATA_OFFSET)
#define normalsTex (34723796 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 6;
int maxDepth = 3;
int topBVHIndex = 4576978;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[20] = int[](0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19);