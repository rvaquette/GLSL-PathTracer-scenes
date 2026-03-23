#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (16 + MESH_DATA_OFFSET)
#define lightsTex (20 + MESH_DATA_OFFSET)
#define BVH (20 + MESH_DATA_OFFSET)
#define vertexIndicesTex (2235905 + MESH_DATA_OFFSET)
#define verticesTex (3067717 + MESH_DATA_OFFSET)
#define normalsTex (5563153 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 8;
int topBVHIndex = 745293;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 5.000000;

int textureMapsArrayIndices[1] = int[](0);