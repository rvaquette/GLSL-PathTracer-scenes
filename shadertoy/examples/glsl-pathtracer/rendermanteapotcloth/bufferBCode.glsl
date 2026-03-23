#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (40 + MESH_DATA_OFFSET)
#define lightsTex (56 + MESH_DATA_OFFSET)
#define BVH (71 + MESH_DATA_OFFSET)
#define vertexIndicesTex (1304501 + MESH_DATA_OFFSET)
#define verticesTex (1788421 + MESH_DATA_OFFSET)
#define normalsTex (3240181 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 3;
int maxDepth = 3;
int topBVHIndex = 434802;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[3] = int[](0, 1, 2);