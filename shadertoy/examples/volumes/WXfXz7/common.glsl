const float Y_OFFSET = -10.;
const float PAW_SPACING = 7.;
const float PAW_HEIGHT = 12.;
const float HEAD_Y = 22.;
const float HEAD_Z = 2.;
const vec3  EYE_POS = vec3(-2.5, 12.5, -4.1);
const vec3  EAR_POS = vec3(6.0, 16., 1.);
const float DETAIL_K = 3.0;
const float MASS_K = 1.0;
 
mat3 rotX(float angle) { float cosa = cos(angle); float sina = sin(angle); return mat3(vec3(1., 0., 0.), vec3(0., cosa, sina), vec3(0., -sina, cosa));}
mat3 rotY(float angle) { float cosa = cos(angle); float sina = sin(angle); return mat3(vec3(cosa, 0., sina), vec3(0., 1., 0.), vec3(-sina, 0., cosa));}
mat3 rotZ(float angle) { float cosa = cos(angle); float sina = sin(angle); return mat3(vec3(cosa, sina, 0.), vec3(-sina, cosa, 0.), vec3(0., 0., 1.));}
 
vec3 transfo(vec3 m, float rx, float ry, float rz, float x, float y, float z) {
    
    mat3 rotation = rotX(rx) * rotY(ry) * rotZ(rz);
    vec3 translation = vec3(x, y, z);
    
    return transpose(rotation) * (m - translation);
}

// iq made it
float smin( float a, float b, float k) {
    //k = k*2.;
    return min(a, b);
    //float res = exp2( -k*a ) + exp2( -k*b );
    //return -log2( res)/k  ;
}

float sdEllipsoid(vec3 m, vec3 r) {
    float k = length(m/r);
    return (k-1.0)*min(min(r.x,r.y),r.z);
}

float sdGoldBear(vec3 m) {

    m.y += 3.;

    float paw1 = sdEllipsoid(transfo(m, 0., 0., 0., -PAW_SPACING, Y_OFFSET+3., -5.), vec3(4., 4., 4.));  
    float paw2 = sdEllipsoid(transfo(m, 0., 0., 0.,  PAW_SPACING, Y_OFFSET+3., -5.), vec3(4., 4., 4.));    
    float paw3 = sdEllipsoid(transfo(m, 0., 0., 0., -PAW_SPACING, Y_OFFSET+PAW_HEIGHT, -5.), vec3(3., 3., 3.));  
    float paw4 = sdEllipsoid(transfo(m, 0., 0., 0.,  PAW_SPACING, Y_OFFSET+PAW_HEIGHT, -5.), vec3(3., 3., 3.));   

    float paws = smin(smin(paw1, paw2, MASS_K), smin(paw3, paw4, MASS_K), MASS_K*0.8);

    vec3 headm = transfo(m, 0.0, 0.0, 0., 0., HEAD_Y+Y_OFFSET, HEAD_Z);
    float head = sdEllipsoid(headm, vec3(8.5, 8., 6.));
    
    float eye1 = sdEllipsoid(transfo(headm, 0., 0., 0., -EYE_POS.x, EYE_POS.y + Y_OFFSET, EYE_POS.z), 0.9*vec3(1.3, 1.3, 0.6));     
    float eye2 = sdEllipsoid(transfo(headm, 0., 0., 0., +EYE_POS.x, EYE_POS.y + Y_OFFSET, EYE_POS.z), 0.9*vec3(1.3, 1.3, 0.6));         
    float nose = sdEllipsoid(transfo(headm, 0., 0., 0., 0., EYE_POS.y - 2.2 + Y_OFFSET, EYE_POS.z), vec3(1., 1., 0.6));             

    float headDetails = min(eye1, eye2);//min(min(eye1, eye2), nose);

    head = smin(head, headDetails, 10.);    

    float ear1 = sdEllipsoid(transfo(headm, 0., 0., 0., -EAR_POS.x, EAR_POS.y + Y_OFFSET, EAR_POS.z), vec3(2., 1.8, 1.)*1.2);     
    float ear2 = sdEllipsoid(transfo(headm, 0., 0., 0., +EAR_POS.x, EAR_POS.y + Y_OFFSET, EAR_POS.z), vec3(2., 1.8, 1.)*1.2);         

    float body = smin(head, paws, MASS_K);
    float body_and_ears = min(smin(body, ear1, DETAIL_K), smin(body, ear2, DETAIL_K));
    
    float body1 = sdEllipsoid(transfo(m, 0., 0., 0., 0., -2., 0.), vec3(10., 10., 8.));     


    return min(body_and_ears, body1);
}
