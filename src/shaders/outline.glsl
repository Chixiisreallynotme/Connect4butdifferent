extern vec3 outlineColor;
extern vec2 textureSize;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 texcolor = Texel(texture, texture_coords);
    
    if (texcolor.a < 0.5) {
        return texcolor * color;
    }
    
    vec2 offset = 1.0 / textureSize;
    
    float a = 4.0;
    a -= Texel(texture, texture_coords + vec2(offset.x, 0.0)).a;
    a -= Texel(texture, texture_coords + vec2(-offset.x, 0.0)).a;
    a -= Texel(texture, texture_coords + vec2(0.0, offset.y)).a;
    a -= Texel(texture, texture_coords + vec2(0.0, -offset.y)).a;
    
    if (a > 0.5) {
        return vec4(outlineColor, texcolor.a);
    }
    
    return texcolor * color;
}
