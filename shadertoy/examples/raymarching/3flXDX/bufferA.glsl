//Track mouse movement and resolution change between frames and set camera position.

#define PI 3.14159
#define EPS 1e-4
#define CAMERA_DIST 3.5

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    
    //Work with just the first four pixels.
    if((fragCoord.x == 0.5) && (fragCoord.y < 4.0)){
        
        vec4 oldMouse = texelFetch(iChannel0, ivec2(0.5), 0).xyzw;
        vec4 mouse = (iMouse / iResolution.xyxy); 
        vec4 newMouse = vec4(0);

        float mouseDownLastFrame = texelFetch(iChannel0, ivec2(0.5, 3.5), 0).x;
        
        //If mouse button is down and was down last frame
        if(iMouse.z > 0.0 && mouseDownLastFrame > 0.0){
            
            //Difference between mouse position last frame and now.
            vec2 mouseMove = mouse.xy-oldMouse.zw;
            newMouse = vec4(oldMouse.xy + vec2(5.0, 3.0)*mouseMove, mouse.xy);
        }else{
            newMouse = vec4(oldMouse.xy, mouse.xy);
        }
        newMouse.x = mod(newMouse.x, 2.0*PI);
        newMouse.y = min(0.99, max(-0.99, newMouse.y));

        //Store mouse data in the first pixel of Buffer B.
        if(fragCoord == vec2(0.5, 0.5)){
            //Set value at first frames
            if(iFrame < 5){
                newMouse = vec4(-2.0, -0.2, 0.0, 0.0);
            }
            fragColor = vec4(newMouse);
        }

        //Store camera position in the second pixel of Buffer B.
        if(fragCoord == vec2(0.5, 1.5)){
            //Set camera position from mouse information.
            vec3 cameraPos = CAMERA_DIST * vec3(sin(newMouse.x), -sin(newMouse.y), -cos(newMouse.x));
            fragColor = vec4(cameraPos, 1.0);
        }
        
        //Store resolution change data in the third pixel of Buffer B.
        if(fragCoord == vec2(0.5, 2.5)){
            float resolutionChangeFlag = 0.0;
            //The resolution last frame.
            vec2 oldResolution = texelFetch(iChannel0, ivec2(0.5, 2.5), 0).yz;
            
            if(iResolution.xy != oldResolution){
            	resolutionChangeFlag = 1.0;
            }
            
        	fragColor = vec4(resolutionChangeFlag, iResolution.xy, 1.0);
        }
           
        //Store whether the mouse button is down in the fourth pixel of Buffer A
        if(fragCoord == vec2(0.5, 3.5)){
            if(iMouse.z > 0.0){
            	fragColor = vec4(vec3(1.0), 1.0);
            }else{
            	fragColor = vec4(vec3(0.0), 1.0);
            }
        }
        
    }
}