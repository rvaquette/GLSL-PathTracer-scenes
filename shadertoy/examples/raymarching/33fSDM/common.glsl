#define getIOR ior_copper
#define f0_     f0_copper
#define f82_   f82_copper

// renormalize the values for energy conservation with RGB rendering (for gold/copper)
//#define RENORMALIZE_REFLECTANCE
// alternatively, clamp the values instead, to achieve the same goal (idk which one is preferable)
//#define CLAMP_REFLECTANCE 

//// Metals characteristics
// spctral data taken from refractiveindex.info

// sadly can't have arbitrary size arrays as function parameter
vec2 resampleIor_49(float data_wl[49], vec2 data[49], float wl){
    int lastIndex = 48;
    wl /= 1000.;
    int lowerbound = 0;
    int higherbound = lastIndex;
    float i = 0.;
    int index = 0;
    for(int j = 0; j < lastIndex + 1; j ++) {
        float i0=i;
        i = float(lowerbound) + float(higherbound-lowerbound) * (wl - data_wl[lowerbound]) / (data_wl[higherbound] - data_wl[lowerbound]);
        if(int(i)==index)
            i+=sign(i-i0);
        index = int(i);
        if(higherbound == lowerbound + 1) break;
        if(data_wl[index] > wl) {
            higherbound = index;
        }
        if(index < lastIndex) if(data_wl[index + 1] < wl) {
            lowerbound = index + 1;
        }
    }
    if(index < 0) return data[0];
    if(index >= lastIndex) return data[lastIndex];

    return mix(data[index], data[index + 1], fract(i));
} 

    // Iron
//Johnson and Christy 1974:
float iron_data_wl[49] = float[](0.188, 0.192, 0.195, 0.199, 0.203, 0.207, 0.212, 0.216, 0.221, 0.226, 0.231, 0.237, 0.243, 0.249, 0.255, 0.262, 0.269, 0.276, 0.284, 0.292, 0.301, 0.311, 0.32, 0.332, 0.342, 0.354, 0.368, 0.381, 0.397, 0.413, 0.431, 0.451, 0.471, 0.496, 0.521, 0.549, 0.582, 0.617, 0.659, 0.704, 0.756, 0.821, 0.892, 0.984, 1.088, 1.216, 1.393, 1.61, 1.937);    
vec2 iron_data[49] = vec2[](vec2(1.29, 1.35), vec2(1.35, 1.37), vec2(1.42, 1.39), vec2(1.45, 1.4), vec2(1.47, 1.4), vec2(1.49, 1.41), vec2(1.47, 1.43), vec2(1.47, 1.44), vec2(1.47, 1.47), vec2(1.47, 1.49), vec2(1.48, 1.53), vec2(1.48, 1.57), vec2(1.5, 1.61), vec2(1.51, 1.66), vec2(1.53, 1.7), vec2(1.56, 1.75), vec2(1.59, 1.79), vec2(1.62, 1.84), vec2(1.64, 1.88), vec2(1.65, 1.94), vec2(1.67, 2), vec2(1.69, 2.06), vec2(1.74, 2.12), vec2(1.78, 2.19), vec2(1.85, 2.27), vec2(1.93, 2.35), vec2(2.02, 2.43), vec2(2.12, 2.5), vec2(2.24, 2.58), vec2(2.35, 2.65), vec2(2.48, 2.71), vec2(2.59, 2.77), vec2(2.67, 2.82), vec2(2.74, 2.88), vec2(2.86, 2.91), vec2(2.95, 2.93), vec2(2.94, 2.99), vec2(2.88, 3.05), vec2(2.92, 3.1), vec2(2.86, 3.19), vec2(2.87, 3.28), vec2(2.94, 3.39), vec2(2.96, 3.56), vec2(2.92, 3.79), vec2(2.97, 4.06), vec2(3.03, 4.39), vec2(3.09, 4.83), vec2(3.11, 5.39), vec2(3.17, 6.12));
vec2 ior_iron(float wl){
    return resampleIor_49(iron_data_wl,iron_data,wl);
}
vec3 f0_iron = vec3(134,131,125)/255.;
vec3 f82_iron = vec3(147,147,152)/255.;

    // Gold (needs renormalization or clamping for energy conservation)
    
//McPeak et al. 2015, samples are uniformly distributed with wavelength
//0:380nm->42:800nm
vec2 gold_data[43] = vec2[](vec2(1.678059067,    1.948381952), vec2(1.672504217,    1.966512231), vec2(1.665616091,    1.973924254), vec2(1.653911114,    1.975227068), vec2(1.63743714,    1.970304643), vec2(1.612343317,    1.959477219), vec2(1.581523054,    1.940313163), vec2(1.538326354,    1.910745397), vec2(1.475285274,    1.872315849), vec2(1.386263242,    1.827683172), vec2(1.252905499,    1.782097694), vec2(1.064360219,    1.76786953), vec2(0.848474841,    1.828280492), vec2(0.661635502,    1.964525779), vec2(0.52912664,    2.129735899), vec2(0.438041087,    2.294990195), vec2(0.372502061,    2.451664289), vec2(0.323930966,    2.597158307), vec2(0.284960267,    2.738978341), vec2(0.254069233,    2.871855006), vec2(0.228936734,    2.999518633), vec2(0.207122197,    3.1213458), vec2(0.188789629,    3.241703491), vec2(0.172726107,    3.356759495), vec2(0.160071695,    3.465634566), vec2(0.14636792,    3.577628204), vec2(0.135417727,    3.685964997), vec2(0.125499436,    3.792327795), vec2(0.117832095,    3.896137113), vec2(0.111117685,    3.999543366), vec2(0.105744888,    4.102704228), vec2(0.101509306,    4.205033191), vec2(0.098607898,    4.305081128), vec2(0.097790271,    4.403812319), vec2(0.098623269,    4.499191766), vec2(0.096903666,    4.59580138), vec2(0.099463321,    4.687205239), vec2(0.098537395,    4.78107829), vec2(0.099206649,    4.872354868), vec2(0.101706737,    4.958865219), vec2(0.101315225,    5.051560628), vec2(0.103067755,    5.148069829), vec2(0.10422723,    5.223682926));
vec2 ior_gold(float wl){
    float i = 42.*(wl-380.)/(800.-380.);
    int index = int(i);
    if(index<0) return gold_data[0];
    if(index>=42) return gold_data[42];
    return mix(gold_data[index],gold_data[index+1],fract(i));
}
vec3 f0_gold =  vec3(268., 200,  87)/255.;
vec3 f82_gold = vec3(255., 227, 162)/255.;
/*//Johnson and Christy 1972 (looks too orange)
float gold_data_wl[49] = float[](0.1879, 0.1916, 0.1953, 0.1993, 0.2033, 0.2073, 0.2119, 0.2164, 0.2214, 0.2262, 0.2313, 0.2371, 0.2426, 0.249, 0.2551, 0.2616, 0.2689, 0.2761, 0.2844, 0.2924, 0.3009, 0.3107, 0.3204, 0.3315, 0.3425, 0.3542, 0.3679, 0.3815, 0.3974, 0.4133, 0.4305, 0.4509, 0.4714, 0.4959, 0.5209, 0.5486, 0.5821, 0.6168, 0.6595, 0.7045, 0.7560, 0.8211, 0.892, 0.984, 1.088, 1.216, 1.393, 1.61, 1.937);
vec2 gold_data[49] = vec2[](vec2(1.28,	1.188), vec2(1.32,	1.203), vec2(1.34,	1.226), vec2(1.33,	1.251), vec2(1.33,	1.277), vec2(1.30,	1.304), vec2(1.30,	1.350), vec2(1.30,	1.387), vec2(1.30,	1.427), vec2(1.31,	1.460), vec2(1.30,	1.497), vec2(1.32,	1.536), vec2(1.32,	1.577), vec2(1.33,	1.631), vec2(1.33,	1.688), vec2(1.35,	1.749), vec2(1.38,	1.803), vec2(1.43,	1.847), vec2(1.47,	1.869), vec2(1.49,	1.878), vec2(1.53,	1.889), vec2(1.53,	1.893), vec2(1.54,	1.898), vec2(1.48,	1.883), vec2(1.48,	1.871), vec2(1.50,	1.866), vec2(1.48,	1.895), vec2(1.46,	1.933), vec2(1.47,	1.952), vec2(1.46,	1.958), vec2(1.45,	1.948), vec2(1.38,	1.914), vec2(1.31,	1.849), vec2(1.04,	1.833), vec2(0.62,	2.081), vec2(0.43,	2.455), vec2(0.29,	2.863), vec2(0.21,	3.272), vec2(0.14,	3.697), vec2(0.13,	4.103), vec2(0.14,	4.542), vec2(0.16,	5.083), vec2(0.17,	5.663), vec2(0.22,	6.350), vec2(0.27,	7.150), vec2(0.35,	8.145), vec2(0.43,	9.519), vec2(0.56,	11.21), vec2(0.92,	13.78));
vec2 ior_gold(float wl){
    return resampleIor_49(gold_data_wl,gold_data,wl);
}
vec3 f0_gold = vec3(263.5625,173,93)/255.;
vec3 f82_gold = vec3(253,214,167)/255.;
*/

    // Aluminium
//Cheng et al. 2016
float aluminium_data_wl[49] = float[](0.38032, 0.38267, 0.38745, 0.38989, 0.39485, 0.39739, 0.40518, 0.41054, 0.41887, 0.42171, 0.42753, 0.4305, 0.43656, 0.44599, 0.44922, 0.45582, 0.4592, 0.46611, 0.46964, 0.47686, 0.48056, 0.492, 0.49994, 0.504, 0.51233, 0.5166, 0.52536, 0.52985, 0.53906, 0.5535, 0.55849, 0.56873, 0.58483, 0.5904, 0.60187, 0.60777, 0.62618, 0.63909, 0.64575, 0.65949, 0.66658, 0.68123, 0.6888, 0.70446, 0.72932, 0.738, 0.756, 0.76533, 0.78471	);
vec2 aluminium_data[49] = vec2[](vec2(0.2878, 3.60372), vec2(0.2909, 3.62721), vec2(0.29729, 3.67524), vec2(0.30058, 3.69951), vec2(0.30735, 3.74919), vec2(0.31085, 3.77447), vec2(0.32176, 3.85221), vec2(0.32944, 3.90558), vec2(0.34161, 3.98845), vec2(0.34587, 4.01679), vec2(0.35464, 4.07453), vec2(0.35918, 4.1039), vec2(0.3686, 4.164), vec2(0.38364, 4.25725), vec2(0.3889, 4.2892), vec2(0.39984, 4.35441), vec2(0.40554, 4.38776), vec2(0.41739, 4.45569), vec2(0.42359, 4.49059), vec2(0.43647, 4.56163), vec2(0.44322, 4.59798), vec2(0.46467, 4.7103), vec2(0.48011, 4.78806), vec2(0.48824, 4.82787), vec2(0.5053, 4.90941), vec2(0.51427, 4.95111), vec2(0.53318, 5.03659), vec2(0.54318, 5.08036), vec2(0.56435, 5.17015), vec2(0.59929, 5.3101), vec2(0.61196, 5.3584), vec2(0.63899, 5.4575), vec2(0.68435, 5.61207), vec2(0.70096, 5.66536), vec2(0.73677, 5.7745), vec2(0.75612, 5.83024), vec2(0.82099, 6.00308), vec2(0.87086, 6.12212), vec2(0.89815, 6.18269), vec2(0.95827, 6.30565), vec2(0.99142, 6.36765), vec2(1.06475, 6.49213), vec2(1.10544, 6.55393), vec2(1.19586, 6.67511), vec2(1.35763, 6.84172), vec2(1.41881, 6.88956), vec2(1.55061, 6.96595), vec2(1.61955, 6.99085), vec2(1.75427, 7.00432));
vec2 ior_aluminium(float wl){
    return resampleIor_49(aluminium_data_wl,aluminium_data,wl);
}
vec3 f0_aluminium = vec3(233,235,235)/255.;
vec3 f82_aluminium = vec3(222,229,235)/255.;

    // Chrome
//Johnson and Christy 1974
float chrome_data_wl[49] = float[](0.188, 0.192, 0.195, 0.199, 0.203, 0.207, 0.212, 0.216, 0.221, 0.226, 0.231, 0.237, 0.243, 0.249, 0.255, 0.262, 0.269, 0.276, 0.284, 0.292, 0.301, 0.311, 0.32, 0.332, 0.342, 0.354, 0.368, 0.381, 0.397, 0.413, 0.431, 0.451, 0.471, 0.496, 0.521, 0.549, 0.582, 0.617, 0.659, 0.704, 0.756, 0.821, 0.892, 0.984, 1.088, 1.216, 1.393, 1.61, 1.937);
vec2 chrome_data[49] = vec2[](vec2(1.28, 1.64), vec2(1.31, 1.65), vec2(1.35, 1.68), vec2(1.39, 1.7), vec2(1.43, 1.7), vec2(1.46, 1.71), vec2(1.46, 1.72), vec2(1.47, 1.72), vec2(1.45, 1.73), vec2(1.43, 1.74), vec2(1.4, 1.77), vec2(1.38, 1.8), vec2(1.36, 1.85), vec2(1.36, 1.91), vec2(1.37, 1.97), vec2(1.38, 2.03), vec2(1.39, 2.08), vec2(1.43, 2.15), vec2(1.45, 2.21), vec2(1.48, 2.28), vec2(1.53, 2.34), vec2(1.58, 2.4), vec2(1.65, 2.47), vec2(1.69, 2.53), vec2(1.76, 2.58), vec2(1.84, 2.64), vec2(1.87, 2.69), vec2(1.92, 2.74), vec2(2, 2.83), vec2(2.08, 2.93), vec2(2.19, 3.04), vec2(2.33, 3.14), vec2(2.51, 3.24), vec2(2.75, 3.3), vec2(2.94, 3.33), vec2(3.18, 3.33), vec2(3.22, 3.3), vec2(3.17, 3.3), vec2(3.09, 3.34), vec2(3.05, 3.39), vec2(3.08, 3.42), vec2(3.2, 3.48), vec2(3.3, 3.52), vec2(3.41, 3.57), vec2(3.58, 3.58), vec2(3.67, 3.6), vec2(3.69, 3.84), vec2(3.66, 4.31), vec2(3.71, 5.04));
vec2 ior_chrome(float wl){
    return resampleIor_49(chrome_data_wl,chrome_data,wl);
}
vec3 f0_chrome = vec3(140,142,141)/255.;
vec3 f82_chrome = vec3(144,148,161)/255.;

    // Copper
//McPeak et al. 2015, samples are uniformly distributed with wavelength, needs renormalization or clamping to be energy conservative
//0:380nm->42:800nm
vec2 copper_data[42] = vec2[](vec2(1.16577487,	2.046321345), vec2(1.139929606,	2.090129064), vec2(1.119339006,	2.14224644), vec2(1.097661459,	2.193481406), vec2(1.082884327,	2.251163803), vec2(1.067185209,	2.306769228), vec2(1.056310845,	2.361946782), vec2(1.048210496,	2.413637347), vec2(1.044058354,	2.464134299), vec2(1.040826414,	2.50896784), vec2(1.040383818,	2.549587906), vec2(1.035622719,	2.577676166), vec2(1.0292166,	2.600958825), vec2(1.01596237,	2.610628188), vec2(0.995463808, 2.613856957), vec2(0.957525814, 2.60358516), vec2(0.896412084, 2.584135179), vec2(0.79745994, 2.56420404), vec2(0.649913539, 2.566649101), vec2(0.467667795, 2.633707115), vec2(0.308052581, 2.774526337), vec2(0.206477543, 2.953105649), vec2(0.15342929, 3.124794481), vec2(0.129738592, 3.28082796), vec2(0.116677068, 3.422223479), vec2(0.110069919, 3.546563885), vec2(0.107194012, 3.666809315), vec2(0.104232496, 3.775693898), vec2(0.102539467, 3.879628119), vec2(0.102449402, 3.981770445), vec2(0.101216009, 4.082308744), vec2(0.101603953, 4.175083635), vec2(0.101236908, 4.27062629), vec2(0.101557633, 4.365353818), vec2(0.101132194, 4.453675754), vec2(0.100848965, 4.541494304), vec2(0.100919789, 4.632837662), vec2(0.101173963, 4.718605321), vec2(0.101837799, 4.806908667), vec2(0.101672055, 4.890330992), vec2(0.104166566, 4.985764803), vec2(0.10154611, 5.05878558));
vec2 ior_copper(float wl){
    float i = 41.*(wl-380.)/(800.-380.);
    int index = int(i);
    if(index<0) return copper_data[0];
    if(index>=41) return copper_data[41];
    return mix(copper_data[index],copper_data[index+1],fract(i));
}
vec3 f0_copper =vec3(262, 172, 143)/255.;
vec3 f82_copper = vec3(258.5 , 203, 189)/255.;
/*//Johnson and Christy 1972 (looks desaturated, but at least is energy conservative in RGB)
float copper_data_wl[49] = float[](0.1879, 0.1916, 0.1953, 0.1993, 0.2033, 0.2073, 0.2119, 0.2164, 0.2214, 0.2262, 0.2313, 0.2371, 0.2426, 0.249, 0.2551, 0.2616, 0.2689, 0.2761, 0.2844, 0.2924, 0.3009, 0.3107, 0.3204, 0.3315, 0.3425, 0.3542, 0.3679, 0.3815, 0.3974, 0.4133, 0.4305, 0.4509, 0.4714, 0.4959, 0.5209, 0.5486, 0.5821, 0.6168, 0.6595, 0.7045, 0.756, 0.8211, 0.892, 0.984, 1.088, 1.216, 1.393, 1.61, 1.937);
vec2 copper_data[49] = vec2[](vec2(0.94, 1.337), vec2(0.95, 1.388), vec2(0.97, 1.44), vec2(0.98, 1.493), vec2(0.99, 1.55), vec2(1.01, 1.599), vec2(1.04, 1.651), vec2(1.08, 1.699), vec2(1.13, 1.737), vec2(1.18, 1.768), vec2(1.23, 1.792), vec2(1.28, 1.802), vec2(1.34, 1.799), vec2(1.37, 1.783), vec2(1.41, 1.741), vec2(1.41, 1.691), vec2(1.45, 1.668), vec2(1.46, 1.646), vec2(1.45, 1.633), vec2(1.42, 1.633), vec2(1.4, 1.679), vec2(1.38, 1.729), vec2(1.38, 1.783), vec2(1.34, 1.821), vec2(1.36, 1.864), vec2(1.37, 1.916), vec2(1.36, 1.975), vec2(1.33, 2.045), vec2(1.32, 2.116), vec2(1.28, 2.207), vec2(1.25, 2.305), vec2(1.24, 2.397), vec2(1.25, 2.483), vec2(1.22, 2.564), vec2(1.18, 2.608), vec2(1.02, 2.577), vec2(0.7, 2.704), vec2(0.3, 3.205), vec2(0.22, 3.747), vec2(0.21, 4.205), vec2(0.24, 4.665), vec2(0.26, 5.18), vec2(0.3, 5.768), vec2(0.32, 6.421), vec2(0.36, 7.217), vec2(0.48, 8.245), vec2(0.6, 9.439), vec2(0.76, 11.12), vec2(1.09, 13.43));
vec2 ior_copper(float wl){
    return resampleIor_49(copper_data_wl,copper_data,wl);
}
vec3 f0_copper = vec3(222, 155, 132)/255.;
vec3 f82_copper = vec3(234, 192, 182)/255.;
*/
    // Lead
// Mathewson and Myers 1971
float lead_data_wl[59] = float[](0.3444,  0.34925,  0.35424,  0.35937,  0.36466,  0.3701,  0.37571,  0.38149,  0.38745,  0.3936,  0.39995,  0.40651,  0.41328,  0.42029,  0.42753,  0.43503,  0.4428,  0.45085,  0.4592,  0.46786,  0.47686,  0.48621,  0.49594,  0.50606,  0.5166,  0.52759,  0.53906,  0.55104,  0.56356,  0.57667,  0.5904,  0.6048,  0.61992,  0.63582,  0.65255,  0.67018,  0.6888,  0.70848,  0.72932,  0.75142,  0.7749,  0.7999,  0.82656,  0.85506,  0.8856,  0.9184,  0.95372,  0.99187,  1.0332,  1.07812,  1.12713,  1.1808,  1.23984,  1.3051,  1.3776,  1.45864,  1.5498,  1.65312,  1.7712);
vec2 lead_data[59] = vec2[](vec2(1.17059, 3.45981), vec2(1.19607, 3.51149), vec2(1.21679, 3.57499), vec2(1.24136, 3.62505), vec2(1.27765, 3.67864), vec2(1.32504, 3.73574), vec2(1.37126, 3.79214), vec2(1.41637, 3.84787), vec2(1.47166, 3.90715), vec2(1.52979, 3.95478), vec2(1.58664, 4.00218), vec2(1.65717, 4.04304), vec2(1.71581, 4.07971), vec2(1.79827, 4.11507), vec2(1.86905, 4.14649), vec2(1.95301, 4.17304), vec2(2.03525, 4.17639), vec2(2.11192, 4.19049), vec2(2.18315, 4.1912), vec2(2.25385, 4.19283), vec2(2.30983, 4.19944), vec2(2.36141, 4.19241), vec2(2.40388, 4.18074), vec2(2.44112, 4.17841), vec2(2.47301, 4.18518), vec2(2.49592, 4.18684), vec2(2.51876, 4.18857), vec2(2.54683, 4.18167), vec2(2.56955, 4.18361), vec2(2.58356, 4.18028), vec2(2.59756, 4.177), vec2(2.60618, 4.18237), vec2(2.60294, 4.16837), vec2(2.5943, 4.16298), vec2(2.57157, 4.16088), vec2(2.52934, 4.17104), vec2(2.45892, 4.18883), vec2(2.37327, 4.23467), vec2(2.27887, 4.30038), vec2(2.1818, 4.40003), vec2(2.09878, 4.55026), vec2(2.01129, 4.74819), vec2(1.9583, 4.95328), vec2(1.91905, 5.18486), vec2(1.88041, 5.39777), vec2(1.85222, 5.64187), vec2(1.84405, 5.85667), vec2(1.81906, 6.15703), vec2(1.80417, 6.48498), vec2(1.80918, 6.74338), vec2(1.79546, 7.12907), vec2(1.82482, 7.39797), vec2(1.80484, 7.97856), vec2(1.84979, 8.43337), vec2(1.88333, 8.9469), vec2(1.94706, 9.47581), vec2(2.04976, 10.04995), vec2(2.17508, 10.80421), vec2(2.26234, 11.58094));
vec2 ior_lead(float wl){
    float data_wl[] = lead_data_wl;
    vec2 data[] = lead_data; 
    int lastIndex = 58;
    wl /= 1000.;
    int lowerbound = 0;
    int higherbound = lastIndex;
    float i = 0.;
    int index = 0;
    for(int j = 0; j < lastIndex + 1; j ++) {
        float i0=i;
        i = float(lowerbound) + float(higherbound-lowerbound) * (wl - data_wl[lowerbound]) / (data_wl[higherbound] - data_wl[lowerbound]);
        if(int(i)==index)
            i+=sign(i-i0);
        index = int(i);
        if(higherbound == lowerbound + 1) break;
        if(data_wl[index] > wl) {
            higherbound = index;
        }
        if(index < lastIndex) if(data_wl[index + 1] < wl) {
            lowerbound = index + 1;
        }
    }
    if(index < 0) return data[0];
    if(index >= lastIndex) return data[lastIndex];

    return mix(data[index], data[index + 1], fract(i));
} 
vec3 f0_lead = vec3(167,169,177)/255.;
vec3 f82_lead = vec3(163,164,176)/255.;

    // Plat
//Werner et al. 2009
float platinum_data_wl[11] = float[](0.30996, 0.330625, 0.354241, 0.38149, 0.413281, 0.450852, 0.495937, 0.551041, 0.619921, 0.708481, 0.826561);
vec2 platinum_data[11] = vec2[](vec2(1.1505, 2.8379), vec2(1.304, 3.1046), vec2(1.5367, 3.0624), vec2(1.2882, 2.908), vec2(0.8675, 3.2129), vec2(0.6273, 3.7605), vec2(0.5124, 4.3965), vec2(0.4643, 5.121), vec2(0.4611, 5.9757), vec2(0.5013, 7.0273), vec2(0.5979, 8.3824));
vec2 ior_platinum(float wl){
    float data_wl[] = platinum_data_wl;
    vec2 data[] = platinum_data; 
    int lastIndex = 10;
    wl /= 1000.;
    int lowerbound = 0;
    int higherbound = lastIndex;
    float i = 0.;
    int index = 0;
    for(int j = 0; j < lastIndex + 1; j ++) {
        float i0=i;
        i = float(lowerbound) + float(higherbound-lowerbound) * (wl - data_wl[lowerbound]) / (data_wl[higherbound] - data_wl[lowerbound]);
        if(int(i)==index)
            i+=sign(i-i0);
        index = int(i);
        if(higherbound == lowerbound + 1) break;
        if(data_wl[index] > wl) {
            higherbound = index;
        }
        if(index < lastIndex) if(data_wl[index + 1] < wl) {
            lowerbound = index + 1;
        }
    }
    if(index < 0) return data[0];
    if(index >= lastIndex) return data[lastIndex];

    return mix(data[index], data[index + 1], fract(i));
} 
vec3 f0_platinum = vec3(243,236,206)/255.;
vec3 f82_platinum = vec3(236,232,215)/255.;

    // Silver
//Johnson and Christy 1972
float silver_data_wl[49] = float[](0.1879, 0.1916, 0.1953, 0.1993, 0.2033, 0.2073, 0.2119, 0.2164, 0.2214, 0.2262, 0.2313, 0.2371, 0.2426, 0.249, 0.2551, 0.2616, 0.2689, 0.2761, 0.2844, 0.2924, 0.3009, 0.3107, 0.3204, 0.3315, 0.3425, 0.3542, 0.3679, 0.3815, 0.3974, 0.4133, 0.4305, 0.4509, 0.4714, 0.4959, 0.5209, 0.5486, 0.5821, 0.6168, 0.6595, 0.7045, 0.756, 0.8211, 0.892, 0.984, 1.088, 1.216, 1.393, 1.61, 1.937);
vec2 silver_data[49] = vec2[](vec2(1.07, 1.212), vec2(1.1, 1.232), vec2(1.12, 1.255), vec2(1.14, 1.277), vec2(1.15, 1.296), vec2(1.18, 1.312), vec2(1.2, 1.325), vec2(1.22, 1.336), vec2(1.25, 1.342), vec2(1.26, 1.344), vec2(1.28, 1.357), vec2(1.28, 1.367), vec2(1.3, 1.378), vec2(1.31, 1.389), vec2(1.33, 1.393), vec2(1.35, 1.387), vec2(1.38, 1.372), vec2(1.41, 1.331), vec2(1.41, 1.264), vec2(1.39, 1.161), vec2(1.34, 0.964), vec2(1.13, 0.616), vec2(0.81, 0.392), vec2(0.17, 0.829), vec2(0.14, 1.142), vec2(0.1, 1.419), vec2(0.07, 1.657), vec2(0.05, 1.864), vec2(0.05, 2.07), vec2(0.05, 2.275), vec2(0.04, 2.462), vec2(0.04, 2.657), vec2(0.05, 2.869), vec2(0.05, 3.093), vec2(0.05, 3.324), vec2(0.06, 3.586), vec2(0.05, 3.858), vec2(0.06, 4.152), vec2(0.05, 4.483), vec2(0.04, 4.838), vec2(0.03, 5.242), vec2(0.04, 5.727), vec2(0.04, 6.312), vec2(0.04, 6.992), vec2(0.04, 7.795), vec2(0.09, 8.828), vec2(0.13, 10.1), vec2(0.15, 11.85), vec2(0.24, 14.08));
vec2 ior_silver(float wl){
    return resampleIor_49(silver_data_wl,silver_data,wl);
}
vec3 f0_silver = vec3(252,251,249)/255.;
vec3 f82_silver = vec3(252,252,252)/255.;


//// Fresnel
    // Exact
float conductiveFresnel(float ior,float k, float NdotI){
    float s2 = ior*ior+k*k;
    float rp2 = (s2*NdotI*NdotI-2.*ior*NdotI+1.)/(s2*NdotI*NdotI+2.*ior*NdotI+1.);
    float ro2 = (s2-2.*ior*NdotI+NdotI*NdotI)/(s2+2.*ior*NdotI+NdotI*NdotI);
    return clamp(mix(rp2,ro2,.5),0.,1.);
}

float dielectricFresnel(vec3 N, vec3 I, float ior){
    vec3 T = refract(-I,N,ior); 
    if(dot(T,T)<.5)return 1.;
    float NdotI = dot(I,N),NdotTs = dot(T,-N)/ior;
    float fresnel = (NdotI-NdotTs)/(NdotI+NdotTs);
    fresnel*=fresnel;
    float fresnel2 = (NdotTs-NdotI)/(NdotI+NdotTs);
    fresnel2*=fresnel2;
    return clamp(mix(fresnel,fresnel2,.5),0.,1.);
}

    // Approx
vec3 Lazanyi2019(vec3 f0, vec3 f82, float cosTheta) {
    #ifdef RENORMALZE_REFLECTANCE
    f0 = f0/max(max(1.,f0.r),max(f0.g,f0.b));
    f82 = f82/max(max(1.,f82.r),max(f82.g,f82.b));
    #elifdef CLAMP_REFLECTANCE
    f0 = clamp(f0,0.,1.);
    f82 = clamp(f82,0.,1.);
    #endif

    // vec3 a = (f0 + (1.-f0)*pow(1.-(1./7.),5.)-f82)/((1./7.)*pow(1.-(1./7.),6.));
    // vec3 a = 7.*(pow(7./6.,6.) * (f0 - f82) + (7./6.) * (1.0 - f0));
    vec3 a = (823543./46656.) * (f0 - f82) + (49./6.) * (1.0 - f0);

    float p1 = 1.0 - cosTheta;
    float p2 = p1*p1;
    float p4 = p2*p2;

    return clamp(f0 + ((1.0 - f0) * p1 - a * cosTheta * p2) * p4, 0., 1. );
    //return clamp(f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0) - a * cosTheta * pow(1.0 - cosTheta, 6.0),0.,1.);
}

vec3 Schlick(vec3 f0, float cosTheta){
    #ifdef RENORMALZE_REFLECTANCE
    f0 = f0/max(max(1.,f0.r),max(f0.g,f0.b));
    #elifdef CLAMP_REFLECTANCE
    f0 = clamp(f0,0.,1.);
    #endif
    return f0+(1.-f0)*pow(1.-cosTheta,5.);
}


//// CONSTANTS

const float PI = acos(-1.);
const float TAU = PI+PI;

//// Misc

float hash(float p)
{
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

mat3 getBasis(vec3 nor){
    bool t = 1.-abs(nor.z)>.00001;
    if(!t)
        nor=nor.zxy;
    vec3 tc = vec3( 1.0+nor.z-nor.xy*nor.xy, -nor.x*nor.y)/(1.0+nor.z);
    vec3 uu = vec3( tc.x, tc.z, -nor.x );
    vec3 vv = vec3( tc.z, tc.y, -nor.y );
    
    return t?mat3(uu,vv,nor):mat3(uu.yzx,vv.yzx,nor.yzx);
}

float getRoughness(vec3 p, sampler2D t){
    return .15+.25*texture(t,(p.xz)).r;
}

//// Raytracing

vec4 iSphere(vec3 sp, float sr,vec3 ro, vec3 rd) //intersection entre une sphere et un rayon
{
    vec3 p = sp-ro;
    float d = dot(-rd,p);
    float i = d*d- dot(p,p)+sr*sr;
    d = i>0.?-sqrt(i)-d:-1000.;
    if(d<0.)
        i=-abs(i);
	return vec4(normalize(rd*d-p),i>0.?d:1e6); //renvoie le vecteur normal au point d'intersection et la distance
}									//1e6 est un nombre tres grand

//// Smith masking

/* // unused
float ggxMaskingShadowing(vec3 n, vec3 d, vec3 l, float a){
    a*=a;
    float dotNL = dot(n,l);
    float dotND = dot(n,d);
    float denomA = dotNL * sqrt(a + (1.0f - a) * dotND * dotND);
    float denomB = dotND * sqrt(a + (1.0f - a) * dotNL * dotNL);

    return 2.0f * dotND * dotNL / (denomA + denomB);
}
*/
float ggxMasking(vec3 n, vec3 l, float a){
    a*=a;
    float dotNL = dot(n,l);
    float denom = sqrt((1.-a) + a/(dotNL*dotNL));

    return 2.0f / (1.+denom);
}

//// GGX BRDF (unused)

/*
float D_GGX_A(vec3 n, const vec3 h, float at, float ab) { //anisotropic
    vec3 hh = inverse(getBasis(n))*h; //should probably be precomputed
    float d = hh.z;
    float ToH = hh.x;
    float BoH = hh.y;
    float a2 = at * ab;
    vec3 v = vec3(ab * ToH, at * BoH, a2 * d);
    float v2 = dot(v, v);
    float w2 = a2 / v2;
    return a2 * w2 * w2 * (1.0 / PI);
}


float ggx(vec3 n, vec3 h, float a){
    float d = dot(n,h);
    a = a*a;
    float w = (d*d*(a-1.)+1.);
    return a/(PI*w*w);
}
*/


//// GGX importance sampling

// https://hal.archives-ouvertes.fr/hal-01509746/document
vec3 sampleGGXVNDF(vec3 V_, float at, float ab, float U1, float U2)
{
    // stretch view
    vec3 V = normalize(vec3(at * V_.x, ab * V_.y, V_.z));
    // orthonormal basis
    vec3 T1 = (V.z < 0.9999) ? normalize(cross(V, vec3(0,0,1))) : vec3(1,0,0);
    vec3 T2 = cross(T1, V);
    // sample point with polar coordinates (r, phi)
    float a = 1.0 / (1.0 + V.z);
    float r = sqrt(U1);
    float phi = (U2<a) ? U2/a * PI : PI + (U2-a)/(1.0-a) * PI;
    float P1 = r*cos(phi);
    float P2 = r*sin(phi)*((U2<a) ? 1.0 : V.z);
    // compute normal
    vec3 N = P1*T1 + P2*T2 + sqrt(max(0.0, 1.0 - P1*P1 - P2*P2))*V;
    // unstretch
    N = normalize(vec3(at*N.x, ab*N.y, max(0.0, N.z)));
    return N;
}

vec3 h_sampleGGXVNDF(vec3 n,vec3 v, float a, vec2 seed, int iFrame){
    const float phi2=1.32471795724474602596090885447809734; //root of X^3-X-1=0.
	const float phi2sq=phi2*phi2;
    vec2 hash = fract(seed + fract(.5+float(iFrame)/vec2(phi2sq,phi2)));
    
    mat3 b =  getBasis(n);
    return getBasis(n)*sampleGGXVNDF(inverse(b)*v,a,a,hash.x,hash.y);
}

/*  //VNDF is better
//I forgot where I fond the formulas for this one, sorry
vec3 ggxSample(vec3 n,float r, vec2 seed, int iFrame){
    const float phi2=1.32471795724474602596090885447809734; //root of X^3-X-1=0.
	const float phi2sq=phi2*phi2;
    vec2 hash = fract(seed + fract(.5+float(iFrame)/vec2(phi2sq,phi2)));
    
    float e0 = hash.x;
    float t = acos(sqrt((1.-e0)/((r*r-1.)*e0+1.))); //acos makes this pretty slow
    float p = hash.y*TAU;
    
    vec3 h = getBasis(n)*vec3(sin(t)*vec2(cos(p),sin(p)),cos(t));    

    return h;
}
*/


//// Dynamic range and tonemap
const float HLG_MAX = 2.; // peak brightness (>=1). Due to float precision issues, values above 5.4 can lead to invalid nubers 
// increasing past 3. will affect significantly only pixels with luninance exceeding 254./255.
// HLG_MAX = sqrt(-log(1-HLG_SCALER*HLG_SCALER))/HLG_SCALER
//this is an empirical fitting approximation of the solution, not the actual solution to this equation (I don't think there is a simple real solution)
const float HLG_SCALER = sqrt(1.-exp((1.-HLG_MAX)*3.92)); 

vec3 HLG(vec3 lin){ //increased dinamic range from image (assusmes color to be already in linear space)
    if(HLG_SCALER<=0. || HLG_MAX <=1.)
        return lin;
    lin*=HLG_SCALER;
    //luminance-based version(could also maybe work per channel, but it would mess with chromacity; so I perfer this way)
    float lum = dot(lin,vec3(0.2126,.7152,.0722));
    float l = lum;
    if(l<=0.) return lin/HLG_SCALER;
    l = (sqrt(-log(1.-l*l)));
    if(isnan(l))l=lum;
    return (lin*l/lum)/HLG_SCALER;
}


vec3 HLG_tm(vec3 o){ //how the HLG function assumes the HDR colors are encoded, can be used as bad tonemapping (still needs gamma correction after)
    if(HLG_SCALER<=0. || HLG_MAX <=1.)
        return o;
    o=o*HLG_SCALER;
    float l = dot(o,vec3(0.2126,.7152,.0722));
    if(l<=0.)return vec3(0.);
    float lum = sqrt(1.-exp(-l*l)); 
    vec3 lin = lum*o/l;
    return lin/HLG_SCALER;
}

//// Spectrum locus (cie1931 numerical approximation)

float gaussian(float x,float al, float mu, float s1, float s2){
    float y = x-mu;
    y/=y<0.?s1:s2;
    return al*exp(-y*y*.5);
}

vec3 lambdatoXYZ(float wl){
    return .27*vec3( gaussian(wl, 1.056, 599.8, 37.9, 31.0)+gaussian(wl, 0.362, 442.0, 16.0, 26.7)+ gaussian(wl, -0.065, 501.1, 20.4, 26.2)
                ,gaussian(wl, 0.821, 568.8, 46.9, 40.5)+gaussian(wl,0.286, 530.9, 16.3, 31.1)
                ,gaussian(wl, 1.217, 437.0, 11.8, 36.0)+gaussian(wl, 0.681, 459.0, 26.0, 13.8));
}

#define SPECTRUM_SAMPLES 89

#define MIN_WL 390.0
#define WL_STEP 5.0
#define MAX_WL 830.0
const vec3 cie2006[] = vec3[SPECTRUM_SAMPLES](
    vec3(0.003769647, 0.0004146161, 0.0184726), vec3(0.009382967, 0.001059646, 0.04609784), vec3(0.02214302, 0.002452194, 0.109609),
    vec3(0.04742986, 0.004971717, 0.2369246),   vec3(0.08953803, 0.00907986, 0.4508369),    vec3(0.1446214, 0.01429377, 0.7378822),
    vec3(0.2035729, 0.02027369, 1.051821),      vec3(0.2488523, 0.02612106, 1.305008),      vec3(0.2918246, 0.03319038, 1.552826),
    vec3(0.3227087, 0.0415794, 1.74828),        vec3(0.3482554, 0.05033657, 1.917479),      vec3(0.3418483, 0.05743393, 1.918437),
    vec3(0.3224637, 0.06472352, 1.848545),      vec3(0.2826646, 0.07238339, 1.664439),      vec3(0.2485254, 0.08514816, 1.522157),
    vec3(0.2219781, 0.1060145, 1.42844),        vec3(0.1806905, 0.1298957, 1.25061),        vec3(0.129192, 0.1535066, 0.9991789),
    vec3(0.08182895, 0.1788048, 0.7552379),     vec3(0.04600865, 0.2064828, 0.5617313),     vec3(0.02083981, 0.237916, 0.4099313),
    vec3(0.007097731, 0.285068, 0.3105939),     vec3(0.002461588, 0.3483536, 0.2376753),    vec3(0.003649178, 0.4277595, 0.1720018),
    vec3(0.01556989, 0.5204972, 0.1176796),     vec3(0.04315171, 0.6206256, 0.08283548),    vec3(0.07962917, 0.718089, 0.05650407),
    vec3(0.1268468, 0.7946448, 0.03751912),     vec3(0.1818026, 0.8575799, 0.02438164),     vec3(0.2405015, 0.9071347, 0.01566174), 
    vec3(0.3098117, 0.9544675, 0.00984647),     vec3(0.3804244, 0.9814106, 0.006131421),    vec3(0.4494206, 0.9890228, 0.003790291),
    vec3(0.5280233, 0.9994608, 0.002327186),    vec3(0.6133784, 0.9967737, 0.001432128),    vec3(0.7016774, 0.9902549, 0.0008822531),
    vec3(0.796775, 0.9732611, 0.0005452416),    vec3(0.8853376, 0.9424569, 0.0003386739),   vec3(0.9638388, 0.8963613, 0.0002117772),
    vec3(1.051011, 0.8587203, 0.0001335031),    vec3(1.109767, 0.8115868, 8.494468e-05),    vec3(1.14362, 0.7544785, 5.460706e-05), 
    vec3(1.151033, 0.6918553, 3.549661e-05),    vec3(1.134757, 0.6270066, 2.334738e-05),    vec3(1.083928, 0.5583746, 1.554631e-05),
    vec3(1.007344, 0.489595, 1.048387e-05),     vec3(0.9142877, 0.4229897, 0.0),            vec3(0.8135565, 0.3609245, 0.0), 
    vec3(0.6924717, 0.2980865, 0.0),            vec3(0.575541, 0.2416902, 0.0),             vec3(0.4731224, 0.1943124, 0.0),
    vec3(0.3844986, 0.1547397, 0.0),            vec3(0.2997374, 0.119312, 0.0),             vec3(0.2277792, 0.08979594, 0.0), 
    vec3(0.1707914, 0.06671045, 0.0),           vec3(0.1263808, 0.04899699, 0.0),           vec3(0.09224597, 0.03559982, 0.0),
    vec3(0.0663996, 0.02554223, 0.0),           vec3(0.04710606, 0.01807939, 0.0),          vec3(0.03292138, 0.01261573, 0.0),
    vec3(0.02262306, 0.008661284, 0.0),         vec3(0.01575417, 0.006027677, 0.0),         vec3(0.01096778, 0.004195941, 0.0),
    vec3(0.00760875, 0.002910864, 0.0),         vec3(0.005214608, 0.001995557, 0.0),        vec3(0.003569452, 0.001367022, 0.0),
    vec3(0.002464821, 0.0009447269, 0.0),       vec3(0.001703876, 0.000653705, 0.0),        vec3(0.001186238, 0.000455597, 0.0),
    vec3(0.0008269535, 0.0003179738, 0.0),      vec3(0.0005758303, 0.0002217445, 0.0),      vec3(0.0004058303, 0.0001565566, 0.0),
    vec3(0.0002856577, 0.0001103928, 0.0),      vec3(0.0002021853, 7.827442e-05, 0.0),      vec3(0.000143827, 5.578862e-05, 0.0),
    vec3(0.0001024685, 3.981884e-05, 0.0),      vec3(7.347551e-05, 2.860175e-05, 0.0),      vec3(5.25987e-05, 2.051259e-05, 0.0),
    vec3(3.806114e-05, 1.487243e-05, 0.0),      vec3(2.758222e-05, 1.080001e-05, 0.0),      vec3(2.004122e-05, 7.86392e-06, 0.0),
    vec3(1.458792e-05, 5.736935e-06, 0.0),      vec3(1.068141e-05, 4.211597e-06, 0.0),      vec3(7.857521e-06, 3.106561e-06, 0.0),
    vec3(5.768284e-06, 2.286786e-06, 0.0),      vec3(4.259166e-06, 1.693147e-06, 0.0),      vec3(3.167765e-06, 1.262556e-06, 0.0),
    vec3(2.358723e-06, 9.422514e-07, 0.0),      vec3(1.762465e-06, 7.05386e-07, 0.0));

#define cie cie2006 
vec3 spectrum_to_xyz(in float w)
{
    w = clamp(w, MIN_WL, MAX_WL) - MIN_WL;
    float n = floor(w / WL_STEP);
    int n0 = min(SPECTRUM_SAMPLES - 1, int(n));
    int n1 = min(SPECTRUM_SAMPLES - 1, n0 + 1);
    float t = w - (n * WL_STEP);
    return mix(cie[n0], cie[n1], t / WL_STEP);
}

const mat3 xyz = mat3(
	3.240479, -1.537150, -0.498535,
    -0.969256, 1.875992, 0.041556,
    0.055648, -0.204043, 1.057311);

vec3 spectrum_to_rgb(in float wl){
    return spectrum_to_xyz(wl)*xyz*.25;
    //return lambdatoXYZ(wl)*xyz;
}


//// RGB to reflectance Spectrum (assumes true D65 lighting) 

//http://scottburns.us/wp-content/uploads/2018/09/RGB-components-comma-separated.txt
//0:380->35:730
const float[] rho_R = float[36](0.021592459, 0.020293111, 0.021807906, 0.023803297, 0.025208132, 0.025414957, 0.024621282, 0.020973705, 0.015752802, 0.01116804, 0.008578277, 0.006581877, 0.005171723, 0.004545205, 0.00414512, 0.004343112, 0.005238155, 0.007251939, 0.012543656, 0.028067132, 0.091342277, 0.484081092, 0.870378324, 0.939513128, 0.960926994, 0.968623763, 0.971263883, 0.972285819, 0.971898742, 0.972691859, 0.971734812, 0.97234454, 0.97150339, 0.970857997, 0.970553866, 0.969671404);
const float[] rho_G = float[36](0.010542406, 0.010878976, 0.011063512, 0.010736566, 0.011681813, 0.012434719, 0.014986907, 0.020100392, 0.030356263, 0.063388962, 0.173423837, 0.568321142, 0.827791998, 0.916560468, 0.952002841, 0.964096452, 0.970590861, 0.972502542, 0.969148203, 0.955344651, 0.892637233, 0.5003641, 0.116236717, 0.047951391, 0.027873526, 0.020057963, 0.017382174, 0.015429109, 0.01543808, 0.014546826, 0.015197773, 0.014285896, 0.015069123, 0.015506263, 0.015545797, 0.016302839);
const float[] rho_B = float[36](0.967865135, 0.968827912, 0.967128582, 0.965460137, 0.963110055, 0.962150324, 0.960391811, 0.958925903, 0.953890935, 0.925442998, 0.817997886, 0.42509696, 0.167036273, 0.078894327, 0.043852038, 0.031560435, 0.024170984, 0.020245519, 0.01830814, 0.016588218, 0.01602049, 0.015554808, 0.013384959, 0.012535491, 0.011199484, 0.011318274, 0.011353953, 0.012285073, 0.012663188, 0.012761325, 0.013067426, 0.013369566, 0.013427487, 0.01363574, 0.013893597, 0.014025757);

float RGBtoSPD(vec3 col, float wl){ //linear color input, obiously
    float i = 35.*(wl-380.)/(730.-380.);
    int index = int(i);
    if(index<0) return col.b;
    if(index>=35) return col.r;
    float m = min(col.r,min(col.g,col.b));
    return m+dot(col-m,mix(vec3(rho_R[index],rho_G[index],rho_B[index]),vec3(rho_R[index+1],rho_G[index+1],rho_B[index+1]),fract(i)));
}


//// D65 spectrum

float blackbody(float wl, float T){
    const float h = 6.62607015e-34; // Planck constant
    const float k = 1.380649e-23; // Boltzmann constant
    const float c = 2.99792458e8; // Speed of light
   	wl*=1e-9; // convert nm to m

    const float normalization_constant = 3.12245e-13; //such as 6500K lightsource is almost pure sRGB white, with luminance == 1.

    return  2.*h*(c*c)/(wl*wl*wl*wl*wl*(exp(h*c/(T*wl*k))-1.))*normalization_constant;
}


//https://www.mtheiss.com/help/final/html/code/bk_d65_spectrum.htm
//0:380->80:780
const float[] D65 = float[81](50.,  52.,  54.,  68.,  82.,  87.,  91.,  92.,  93.,  90.,  86.,  95., 104., 110., 117., 117., 117., 116., 114., 115., 115., 112., 108., 109., 109., 108., 107., 106., 104., 106., 107., 106., 104., 104., 104., 102., 100.,  98.,  96.,  96.,  95.,  92.,  88.,  89.,  90.,  89.,  89.,  88.,  87.,  85.,  83.,  83.,  83.,  81.,  80.,  80.,  80.,  81.,  82.,  80.,  78.,  74.,  69.,  70.,  71.,  73.,  74.,  68.,  61.,  65.,  69.,  72.,  75.,  69.,  63.,  55.,  46.,  56.,  66.,  65.,  63.) ;

float get_D65(float wl){
    float i = 80.*(wl-380.)/(780.-380.);
    int index = int(i);
    if(index<0) return blackbody(wl,6500.);
    if(index>=80) return blackbody(wl,6500.);
    
    const float normalization_constant = .142358; // such as integration over the wole spectum gives vec3(1)

    return mix(D65[index],D65[index+1],fract(i))*normalization_constant;
}
