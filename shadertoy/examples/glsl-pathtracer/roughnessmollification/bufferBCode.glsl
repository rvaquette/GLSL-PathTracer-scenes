#define materialsTex (0 + MESH_DATA_OFFSET)
#define transformsTex (24 + MESH_DATA_OFFSET)
#define lightsTex (32 + MESH_DATA_OFFSET)
#define BVH (47 + MESH_DATA_OFFSET)
#define vertexIndicesTex (209015 + MESH_DATA_OFFSET)
#define verticesTex (310427 + MESH_DATA_OFFSET)
#define normalsTex (614663 + MESH_DATA_OFFSET)

//-------------------------- Uniforms ---------------------------

vec3 uniformLightCol = vec3(0.300000, 0.300000, 0.300000);
int numOfLights = 3;
int maxDepth = 8;
int topBVHIndex = 69652;
float roughnessMollificationAmt = 1.000000;
float envMapIntensity = 1.000000;

int textureMapsArrayIndices[1] = int[](0);