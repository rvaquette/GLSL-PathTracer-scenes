#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (48 + MESH_DATA_OFFSET)
#define lightsTex (72 + MESH_DATA_OFFSET)
#define BVH (92 + MESH_DATA_OFFSET)
#define vertexIndicesTex (146 + MESH_DATA_OFFSET)
#define verticesTex (158 + MESH_DATA_OFFSET)
#define normalsTex (194 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 4;
int maxDepth = 4;
int topBVHIndex = 6;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);