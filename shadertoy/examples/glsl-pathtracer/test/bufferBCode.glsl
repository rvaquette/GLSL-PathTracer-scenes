#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (88 + MESH_DATA_OFFSET)
#define lightsTex (132 + MESH_DATA_OFFSET)
#define BVH (217 + MESH_DATA_OFFSET)
#define vertexIndicesTex (301396 + MESH_DATA_OFFSET)
#define verticesTex (408930 + MESH_DATA_OFFSET)
#define normalsTex (731532 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 17;
int maxDepth = 3;
int topBVHIndex = 100371;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);