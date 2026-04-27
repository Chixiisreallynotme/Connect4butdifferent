extern vec3 targetColor;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 texcolor = Texel(texture, texture_coords) * color;
    if (texcolor.a == 0.0) {
        return vec4(0.0);
    }
    
    vec3 c = texcolor.rgb * targetColor;
    
    vec3 p0 = vec3(1.0, 0.0, 0.2); // neon red
    vec3 p1 = vec3(1.0, 1.0, 0.0); // neon yellow
    vec3 p2 = vec3(0.0, 0.2, 1.0); // electric blue
    vec3 p3 = vec3(1.0, 0.1, 0.6); // hot pink
    vec3 p4 = vec3(0.2, 1.0, 0.0); // lime green
    vec3 p5 = vec3(1.0, 0.5, 0.0); // bright orange
    vec3 p6 = vec3(1.0, 1.0, 1.0); // white
    vec3 p7 = vec3(0.0, 0.0, 0.0); // black
    
    float minDist = 10.0;
    vec3 closest = p0;
    
    float d = distance(c, p0); if (d < minDist) { minDist = d; closest = p0; }
    d = distance(c, p1); if (d < minDist) { minDist = d; closest = p1; }
    d = distance(c, p2); if (d < minDist) { minDist = d; closest = p2; }
    d = distance(c, p3); if (d < minDist) { minDist = d; closest = p3; }
    d = distance(c, p4); if (d < minDist) { minDist = d; closest = p4; }
    d = distance(c, p5); if (d < minDist) { minDist = d; closest = p5; }
    d = distance(c, p6); if (d < minDist) { minDist = d; closest = p6; }
    d = distance(c, p7); if (d < minDist) { minDist = d; closest = p7; }
    
    return vec4(closest, texcolor.a);
}
