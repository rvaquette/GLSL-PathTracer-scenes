#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (168 + MESH_DATA_OFFSET)
#define lightsTex (248 + MESH_DATA_OFFSET)
#define BVH (253 + MESH_DATA_OFFSET)
#define vertexIndicesTex (703705 + MESH_DATA_OFFSET)
#define verticesTex (958204 + MESH_DATA_OFFSET)
#define normalsTex (1721701 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 1;
int maxDepth = 3;
int topBVHIndex = 234444;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[9] = int[](0, 1, 2, 3, 4, 5, 6, 7, 8);