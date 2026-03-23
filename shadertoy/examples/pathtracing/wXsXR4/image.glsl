// Raytracing Boilerplate V2 by Bingle
/* Axis orientation (local to camera):

       ^ +Y
       |
       |
       |
       +-------> +X
      /
 +Z |/ 
     ‾‾
*/


void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    fragColor = sqrt(texture(iChannel0,fragCoord/iResolution.xy));
}

// Press SPACE to generate a new scene
// Press R to restart rendering the current scene
// Pan the camera with the mouse
