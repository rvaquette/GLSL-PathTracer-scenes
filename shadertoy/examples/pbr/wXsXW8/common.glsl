struct Material{
    float roughness;
    float metallic;
    vec3 albedo;
};

struct Object{
    Material material;
    int id;
};

struct Hit{
    float dist;
    Object obj;
};

struct Light{
    vec3 color;
    vec3 p;
};

Object[16] getObjects(){
    Object objects[16];
    Material matteRed = Material(0.4, 0., vec3(1., 0., 0.));
    Object sphere1 = Object(matteRed, 0);
    for (int i = 0; i < 4; ++i){
        for (int j = 0; j < 4; ++j){
            objects[i * 4 + j] = Object(Material(float(i) / 4., float(j) / 4., vec3(1., 0., 0.)), i * 4 + j);
        }
    }
    return objects;
}

Light[4] getLights(){
    Light main = Light(vec3(10.), vec3(0., 1., 4.));
    Light light2 = Light(vec3(100.), vec3(-10.));
    Light light3 = Light(vec3(30), vec3(-4., -4., 0.));
    Light light4 = Light(vec3(10), vec3(3., 3., 0.));
    //Light light5 = Light(vec3(20), vec3(-3., 4., 0.));
    
    Light lights[4];
    lights[0] = main;
    lights[1] = light2;
    lights[2] = light3;
    lights[3] = light4;
    //lights[4] = light5;
    return lights;
}

mat2 rot2d(float angle){
    float s = sin(angle);
    float c = cos(angle);
    return mat2(c, -s, s, c);
}

