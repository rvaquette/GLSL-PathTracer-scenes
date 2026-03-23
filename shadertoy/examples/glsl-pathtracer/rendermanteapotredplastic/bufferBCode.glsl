#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (32 + MESH_DATA_OFFSET)
#define lightsTex (44 + MESH_DATA_OFFSET)
#define BVH (54 + MESH_DATA_OFFSET)
#define vertexIndicesTex (752151 + MESH_DATA_OFFSET)
#define verticesTex (1020903 + MESH_DATA_OFFSET)
#define normalsTex (1827159 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 2;
int maxDepth = 3;
int topBVHIndex = 250693;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);