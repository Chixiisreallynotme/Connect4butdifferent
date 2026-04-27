extern float time;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 texcolor = Texel(texture, texture_coords) * color;
    if (texcolor.a == 0.0) {
        return vec4(0.0);
    }
    
    float frame = floor(time * 8.0);
    float frameMod = mod(frame, 4.0);
    
    // step function on a noise pattern
    float n = fract(sin(dot(texture_coords, vec2(127.1, 311.7))) * 43758.5);
    float threshold = 0.5 + 0.1 * frameMod;
    
    if (n > threshold) {
        vec3 p0 = vec3(1.0, 0.0, 0.2);
        vec3 p1 = vec3(1.0, 1.0, 0.0);
        vec3 p2 = vec3(0.0, 0.2, 1.0);
        vec3 p3 = vec3(1.0, 0.1, 0.6);
        vec3 p4 = vec3(0.2, 1.0, 0.0);
        vec3 p5 = vec3(1.0, 0.5, 0.0);
        vec3 p6 = vec3(1.0, 1.0, 1.0);
        
        float colorIdx = mod(floor(n * 100.0 + frame), 7.0);
        vec3 sparkleColor = p0;
        
        if (colorIdx < 1.0) sparkleColor = p0;
        else if (colorIdx < 2.0) sparkleColor = p1;
        else if (colorIdx < 3.0) sparkleColor = p2;
        else if (colorIdx < 4.0) sparkleColor = p3;
        else if (colorIdx < 5.0) sparkleColor = p4;
        else if (colorIdx < 6.0) sparkleColor = p5;
        else sparkleColor = p6;
        
        return vec4(sparkleColor, texcolor.a);
    }
    
    return texcolor;
}
