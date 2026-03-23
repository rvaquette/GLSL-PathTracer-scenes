void mainImage( out vec4 fragColor, in vec2 fragCoord ){
	vec2 uv = fragCoord.xy / iResolution.xy;
    vec3 col = vec3(0.0);
    
    if( iFrame>0 ) {
        col = texture( iChannel0, uv ).xyz;
        col = pow( col, vec3(0.4545) );
    }
    fragColor = vec4( col, 1.0 );
}
