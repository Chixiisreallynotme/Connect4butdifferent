extern float intensity;
extern vec2 textureSize;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 offset = vec2(1.0 / textureSize.x, 0.0);
    
    float r = Texel(texture, texture_coords - offset).r;
    float g = Texel(texture, texture_coords).g;
    float b = Texel(texture, texture_coords + offset).b;
    
    vec4 baseColor = Texel(texture, texture_coords);
    vec3 chromColor = mix(baseColor.rgb, vec3(r, g, b), intensity);
    
    vec4 finalColor = vec4(chromColor, baseColor.a) * color;
    
    // Every even pixel row darkened by 30% to simulate a CRT scanline grid
    if (mod(floor(screen_coords.y), 2.0) == 0.0) {
        finalColor.rgb *= 0.7;
    }
    
    return finalColor;
}
