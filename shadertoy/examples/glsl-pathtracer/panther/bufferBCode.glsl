#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (16 + MESH_DATA_OFFSET)
#define lightsTex (24 + MESH_DATA_OFFSET)
#define BVH (39 + MESH_DATA_OFFSET)
#define vertexIndicesTex (5184093 + MESH_DATA_OFFSET)
#define verticesTex (7188935 + MESH_DATA_OFFSET)
#define normalsTex (13203461 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 3;
int maxDepth = 3;
int topBVHIndex = 1728014;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);