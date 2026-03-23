#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (72 + MESH_DATA_OFFSET)
#define lightsTex (116 + MESH_DATA_OFFSET)
#define BVH (121 + MESH_DATA_OFFSET)
#define vertexIndicesTex (301300 + MESH_DATA_OFFSET)
#define verticesTex (408834 + MESH_DATA_OFFSET)
#define normalsTex (731436 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 1;
int maxDepth = 3;
int topBVHIndex = 100371;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);