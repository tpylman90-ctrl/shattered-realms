shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform int terrain_id = 0;
varying vec3 world_position;

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
}

void fragment() {
    vec2 p = world_position.xz;
    float broad = fbm(p * 1.7);
    float grain = fbm(p * 12.0 + broad * 3.0);
    float fine = noise2(p * 42.0);
    vec3 base = vec3(0.20, 0.37, 0.16);
    float rough = 0.93;

    if (terrain_id == 1) {
        base = mix(vec3(0.18, 0.31, 0.13), vec3(0.40, 0.49, 0.23), grain);
        float litter = smoothstep(0.66, 0.82, fine);
        base = mix(base, vec3(0.43, 0.31, 0.17), litter * 0.32);
    } else if (terrain_id == 2) {
        base = mix(vec3(0.36, 0.24, 0.13), vec3(0.70, 0.49, 0.28), grain);
        float pebbles = smoothstep(0.78, 0.92, fine);
        base = mix(base, vec3(0.66, 0.58, 0.43), pebbles * 0.34);
    } else if (terrain_id == 3) {
        base = mix(vec3(0.36, 0.39, 0.38), vec3(0.68, 0.69, 0.63), grain);
        base *= 0.78 + 0.35 * fine;
        rough = 0.98;
    } else if (terrain_id == 4) {
        base = mix(vec3(0.62, 0.48, 0.27), vec3(0.92, 0.77, 0.47), grain);
        base *= 0.82 + 0.28 * fine;
    } else if (terrain_id == 5) {
        base = mix(vec3(0.15, 0.34, 0.29), vec3(0.40, 0.60, 0.47), grain);
        float wet = smoothstep(0.54, 0.72, fine);
        base = mix(base, vec3(0.17, 0.31, 0.32), wet * 0.55);
        rough = 0.72;
    } else {
        base = mix(vec3(0.20, 0.38, 0.15), vec3(0.44, 0.59, 0.25), grain);
        float blades = smoothstep(0.70, 0.93, fine);
        base = mix(base, vec3(0.53, 0.58, 0.24), blades * 0.22);
    }

    float value = 0.86 + broad * 0.42 + fine * 0.12;
    ALBEDO = base * value;
    EMISSION = base * 0.12;
    ROUGHNESS = rough;
}
