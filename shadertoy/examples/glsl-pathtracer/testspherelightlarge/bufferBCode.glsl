#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (16 + MESH_DATA_OFFSET)
#define lightsTex (20 + MESH_DATA_OFFSET)
#define BVH (25 + MESH_DATA_OFFSET)
#define vertexIndicesTex (34 + MESH_DATA_OFFSET)
#define verticesTex (36 + MESH_DATA_OFFSET)
#define normalsTex (42 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 1;
int maxDepth = 2;
int topBVHIndex = 1;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);