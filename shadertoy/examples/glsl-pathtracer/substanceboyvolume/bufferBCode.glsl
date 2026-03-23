#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (16 + MESH_DATA_OFFSET)
#define lightsTex (28 + MESH_DATA_OFFSET)
#define BVH (38 + MESH_DATA_OFFSET)
#define vertexIndicesTex (222413 + MESH_DATA_OFFSET)
#define verticesTex (301495 + MESH_DATA_OFFSET)
#define normalsTex (538741 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 2;
int maxDepth = 4;
int topBVHIndex = 74119;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);