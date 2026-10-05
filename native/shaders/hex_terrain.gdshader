shader_type spatial;

uniform int terrain_id = 0;
uniform sampler2D woodland_albedo : source_color, repeat_enable;
uniform float woodland_texture_scale = 0.42;
varying vec3 world_position;
varying float tile_local_y;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float total = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        total += noise2(p) * amplitude;
        p *= 2.03;
        amplitude *= 0.5;
    }
    return total;
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    tile_local_y = VERTEX.y;
}

void fragment() {
    vec2 p = world_position.xz;
    float broad = fbm(p * 1.4);
    float grain = fbm(p * 9.0 + broad * 3.0);
    float fine = noise2(p * 38.0);
    float micro_height = fbm(p * 24.0) * 0.025 + noise2(p * 72.0) * 0.009;

    vec3 base = vec3(0.20, 0.37, 0.16);
    float rough = 0.92;

    if (terrain_id == 1) {
        vec2 forest_uv = (tile_local_y < -0.01 ? world_position.xy : world_position.xz) * woodland_texture_scale;
        vec3 forest = texture(woodland_albedo, forest_uv).rgb;
        base = forest;
        rough = 0.82 + grain * 0.10;
        micro_height += dot(forest, vec3(0.299, 0.587, 0.114)) * 0.12;
    } else if (terrain_id == 2) {
        base = mix(vec3(0.27, 0.20, 0.12), vec3(0.62, 0.46, 0.27), grain);
        float pebbles = smoothstep(0.78, 0.92, fine);
        base = mix(base, vec3(0.69, 0.61, 0.48), pebbles * 0.34);
        rough = 0.94;
    } else if (terrain_id == 3) {
        base = mix(vec3(0.29, 0.32, 0.31), vec3(0.64, 0.67, 0.63), grain);
        base *= 0.78 + 0.35 * fine;
        rough = 0.98;
    } else if (terrain_id == 4) {
        base = mix(vec3(0.54, 0.41, 0.23), vec3(0.85, 0.72, 0.44), grain);
        base *= 0.82 + 0.28 * fine;
        rough = 0.88;
    } else if (terrain_id == 5) {
        base = mix(vec3(0.13, 0.28, 0.23), vec3(0.36, 0.53, 0.41), grain);
        float wet = smoothstep(0.54, 0.72, fine);
        base = mix(base, vec3(0.13, 0.25, 0.27), wet * 0.48);
        rough = mix(0.88, 0.58, wet);
    } else {
        base = mix(vec3(0.17, 0.34, 0.13), vec3(0.42, 0.58, 0.25), grain);
        float blades = smoothstep(0.70, 0.93, fine);
        base = mix(base, vec3(0.50, 0.57, 0.23), blades * 0.22);
        rough = 0.92;
    }

    float face_light = mix(0.68, 1.0, smoothstep(-0.075, -0.01, tile_local_y));
    float color_variation = 0.91 + broad * 0.14 + fine * 0.04;

    // Add a restrained screen-space bump so fine surface variation responds to the scene lights.
    vec2 bump_gradient = vec2(dFdx(micro_height), dFdy(micro_height));
    NORMAL = normalize(NORMAL - vec3(bump_gradient * 1.25, 0.0));

    ALBEDO = base * color_variation * face_light;
    ROUGHNESS = rough;
    SPECULAR = 0.18;
}
