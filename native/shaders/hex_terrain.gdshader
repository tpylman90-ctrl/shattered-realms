shader_type spatial;

uniform int terrain_id = 0;
uniform sampler2D grass_albedo : source_color, repeat_enable;
uniform sampler2D woodland_albedo : source_color, repeat_enable;
uniform sampler2D dirt_albedo : source_color, repeat_enable;
uniform sampler2D stone_albedo : source_color, repeat_enable;
uniform sampler2D sand_albedo : source_color, repeat_enable;
uniform sampler2D marsh_albedo : source_color, repeat_enable;
uniform float terrain_texture_scale = 0.42;
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
    float broad = fbm(p * 1.3);
    float fine = noise2(p * 38.0);
    float micro_height = fbm(p * 24.0) * 0.025 + noise2(p * 72.0) * 0.009;
    vec2 terrain_uv = (tile_local_y < -0.01 ? world_position.xy : world_position.xz) * terrain_texture_scale;
    vec3 base = vec3(0.20, 0.37, 0.16);
    float rough = 0.91;

    if (terrain_id == 0) {
        base = texture(grass_albedo, terrain_uv).rgb;
        rough = 0.91;
    } else if (terrain_id == 1) {
        base = texture(woodland_albedo, terrain_uv).rgb;
        rough = 0.88;
    } else if (terrain_id == 2) {
        base = texture(dirt_albedo, terrain_uv).rgb;
        rough = 0.94;
    } else if (terrain_id == 3) {
        base = texture(stone_albedo, terrain_uv).rgb;
        rough = 0.98;
    } else if (terrain_id == 4) {
        base = texture(sand_albedo, terrain_uv).rgb;
        rough = 0.89;
    } else {
        base = texture(marsh_albedo, terrain_uv).rgb;
        float wet = smoothstep(0.56, 0.74, fine);
        base = mix(base, vec3(0.14, 0.25, 0.23), wet * 0.18);
        rough = mix(0.92, 0.60, wet);
    }

    float face_light = mix(0.68, 1.0, smoothstep(-0.075, -0.01, tile_local_y));
    float color_variation = 0.93 + broad * 0.10 + fine * 0.035;
    vec2 bump_gradient = vec2(dFdx(micro_height), dFdy(micro_height));
    NORMAL = normalize(NORMAL - vec3(bump_gradient * 1.1, 0.0));

    ALBEDO = base * color_variation * face_light;
    ROUGHNESS = rough;
    SPECULAR = 0.18;
}
