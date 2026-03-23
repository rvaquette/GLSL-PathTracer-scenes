#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (48 + MESH_DATA_OFFSET)
#define lightsTex (128 + MESH_DATA_OFFSET)
#define BVH (143 + MESH_DATA_OFFSET)
#define vertexIndicesTex (670451 + MESH_DATA_OFFSET)
#define verticesTex (905716 + MESH_DATA_OFFSET)
#define normalsTex (1611511 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 3;
int maxDepth = 5;
int topBVHIndex = 223396;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);