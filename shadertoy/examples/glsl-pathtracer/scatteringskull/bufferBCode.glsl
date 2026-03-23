#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (8 + MESH_DATA_OFFSET)
#define lightsTex (12 + MESH_DATA_OFFSET)
#define BVH (12 + MESH_DATA_OFFSET)
#define vertexIndicesTex (504027 + MESH_DATA_OFFSET)
#define verticesTex (692898 + MESH_DATA_OFFSET)
#define normalsTex (1259511 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 0;
int maxDepth = 2;
int topBVHIndex = 168003;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);