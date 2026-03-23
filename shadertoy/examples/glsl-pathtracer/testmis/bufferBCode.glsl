#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (16 + MESH_DATA_OFFSET)
#define lightsTex (24 + MESH_DATA_OFFSET)
#define BVH (29 + MESH_DATA_OFFSET)
#define vertexIndicesTex (77 + MESH_DATA_OFFSET)
#define verticesTex (91 + MESH_DATA_OFFSET)
#define normalsTex (133 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 1;
int maxDepth = 10;
int topBVHIndex = 12;
float roughnessMollificationAmt = 0.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);