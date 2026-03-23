//Forked from https://www.shadertoy.com/view/Xds3zN
//This Inigo Quilez's raymarching demo is used to test my lens effect  

// This work's aim is modelling of the lens focusing behaviour with real parameters. 
// In this scope performance is not important for now.
// If you interest with this work, feel free to contact me if you need any further information
// I am pretty new on GLSL. Thus, I had to fork IQ's work to test the lens. 
// Please visit the original one too. 
// yuempek 


//"
// Copyright Yunus Emre Pektas, 2022 - https://yuempek.github.com/
// I am the sole copyright owner of this work.
// You cannot host, display, distribute or share this work in any form,
// including physical and digital. You cannot use this work in any
// commercial or non-commercial product, website or project. You cannot
// sell this work and you cannot mint an NFTs of it.
// I share this work for educational purposes, and you can link to it,
// through an URL, proper attribution and unmodified screenshot, as part
// of your educational material. If these conditions are too restrictive
// please contact me and we'll definitely work it out.
//"
// I copied this copyright from Inigo Quilez's copyright. Because the copyright had not own copyright. =)


//https://www.japanistry.com/depth-of-focus/
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 mo = iMouse.xy/iResolution.xy;
	     mo = iMouse.x < 1.0 ? vec2(0.5, 0.15) : mo;
    float time = iTime;

    // set the camera position
    vec3 target = vec3( 0.0, 1.0, 0.0 );
    float angle = 0.1*time + 7.0*mo.x;
    float cameraaltitudeangle = 3.14159265/2.0*mo.y;
    float cameraaltitude = sin(cameraaltitudeangle)*10.0+0.5;
    float cameradistance = cos(cameraaltitudeangle)*10.0;
    float cameraroll = 0.0;
    vec3 cameraposition = vec3(cameradistance*cos(angle), cameraaltitude, cameradistance*sin(angle));
    mat3 rotation = setCamera(cameraposition, target, cameraroll);

    
    // initialize
    float sw = 0.035;    //sensor width (full frame 35mm x 24mm) https://www.wikiwand.com/en/Image_sensor_format
    float sd = 0.085;   //sensor distance (meter) (or focal length)
    float fd = 10.0;   //focal(focused) distance (meter)
    float lr = 0.100; //lens radius (meter)
    
    vec2 uv = (fragCoord - 0.5)/iResolution.x; // 0 < x < 1
         uv = uv * 2.0 - 1.0;                 // -1 < x < 1
         uv = uv * sw / 2.0;                 // -sw/2 < x < +sw/2
    

// This is a typical camera model (sensor + lens + object)
// I modelled the lens with discrete points centered on origin.
//
//
////                  points on lens                                          
////                         .                                        ooo    
////                                                                 o\o/o   
////   sensor                .                                        o\o    
////      |                    (0,0)                                   H     
////      |___sensor dist ___./____________focal distance______________H     
////      |                                                                  
////      |                  .                                               
////                                                                         
////                         .                                               
////  
    

// For each sensor point calculated from pixels, 
// we find the focused point of the sensor point 
// with triangle similarity on lens origin 
// with using focused distance and sensor distance.  
//
//    
////                       pl(i)                                             
////                         .                                 ________. fp 
////                                                __________/        |    
////   sensor                .           __________/                   |    
////      |                    _________/                              |    
////      |________sd________./__________________fd____________________|    
////      |         ________/                                               
////   ps !________/         .                                              
////                                                                        
////                         .                                              
////

// Then we throw ray from each point on lens to this point. 
// Because all rays should be focused on the same point. 
//
////                       pl(i)                                             
////                       __._________________________________________. fp 
////                    __/                                            |    
////   sensor        __/     .                                         |    
////      |       __/                                                  |    
////      |______/_sd________. __________________fd____________________|    
////      | __/                                                             
////   ps !/                 .                                              
////                                                                        
////                         .                                              
////

// But some rays hits obstacles between lens and object.
// This creates realistic blur effect. 
// The quality is directly proportional to the number of points on lens.


    vec3 ps = vec3(uv, sd); //point on sensor
    vec3 fp = ps * fd/sd;  //focal point of sensor point  
    
    
    vec3 color = vec3(0);
    float w = 0.0;
    vec3 pl; //point on lens 
    
    // render with lens
    for (int i = 0; i < plArray.length(); i++) {
        pl = plArray[i];    //get next point on lens (-1 < pl < +1)
        vec3 ro = pl*lr;    //get position of point on lens (-lr < pl < +lr)
        vec3 ray = fp - ro; //ray from lens point to focal point
        vec3 nr = normalize(ray);
        //color += render_low(rotation*ro + cameraposition , rotation*nr);
        color += render(rotation*ro + cameraposition , rotation*nr);
        w++;
    }
    vec3 col = color/w;
    
    
    
    // gamma
    col = pow(col, vec3(0.5));

    fragColor = vec4(col, 1.0);
}
