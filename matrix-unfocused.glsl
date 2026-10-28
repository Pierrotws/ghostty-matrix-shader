// Matrix rain behind the text of unfocused Ghostty splits.
//
// Ghostty runs one copy of this shader per split. The focused split is left
// untouched; the others get green glyph rain wherever they show the default
// background, so their text stays readable on top.
//
// Needs Ghostty 1.3+ (iFocus, iBackgroundColor) and
// `custom-shader-animation = always`: by default unfocused splits never redraw.

// Glyph cell size, in pixels.
const vec2 CELL = vec2(14.0, 22.0);
// Fall speed range, in cells per second.
const float SPEED_MIN = 4.0;
const float SPEED_MAX = 14.0;
// Trail length, in cells.
const float TRAIL = 16.0;
// Drops falling down each column at the same time.
const int DROPS = 2;
// Glyphs mostly hold still; the most restless change this often per second.
const float GLYPH_RATE = 8.0;
// Share of a glyph's 12 strokes that are lit.
const float DENSITY = 0.45;
// Stroke half-width, in pixels.
const float STROKE = 0.9;
// Colors in sRGB, as a hex code gives them.
const vec3 RAIN_COLOR = vec3(0.10, 0.95, 0.35);
const vec3 HEAD_COLOR = vec3(0.80, 1.00, 0.85);
// How strongly the rain covers the background, from 0 to 1.
const float OPACITY = 0.6;

float hash(vec2 p) {
    vec3 p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 linearize(vec3 c) {
    return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThanEqual(c, vec3(0.04045)));
}

vec3 unlinearize(vec3 c) {
    return mix(pow(c, vec3(1.0 / 2.4)) * 1.055 - 0.055, c * 12.92, lessThanEqual(c, vec3(0.0031308)));
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Coverage of a glyph at p, in pixels from the top-left corner of its cell.
// A glyph lights a random subset of the 12 strokes joining a 3x3 grid of points.
float glyph(vec2 p, float seed) {
    vec2 origin = CELL * vec2(0.2, 0.15);
    vec2 step = CELL * vec2(0.3, 0.35);
    float d = 1e9;
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            vec2 a = origin + step * vec2(i, j);
            float k = float(i * 3 + j);
            if (i < 2 && hash(vec2(seed, k)) < DENSITY) d = min(d, segment(p, a, a + vec2(step.x, 0.0)));
            if (j < 2 && hash(vec2(seed, k + 9.0)) < DENSITY) d = min(d, segment(p, a, a + vec2(0.0, step.y)));
        }
    }
    return 1.0 - smoothstep(STROKE - 0.5, STROKE + 0.5, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 term = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = term;
    if (iFocus > 0) return;

    // Shaders get linear colors unless `alpha-blending = native`, while
    // iBackgroundColor is always sRGB. The window padding in the corner shows
    // the background, which tells the two apart.
    vec3 corner = texture(iChannel0, 0.5 / iResolution.xy).rgb;
    vec3 bg = iBackgroundColor;
    bool linear = distance(corner, linearize(bg)) <= distance(corner, bg);
    vec3 shown = linear ? unlinearize(term.rgb) : term.rgb;

    // Rain shows through the default background only, fading out over the
    // anti-aliased edges of text.
    float through = 1.0 - smoothstep(0.02, 0.12, distance(shown, bg));
    if (through <= 0.0) return;

    // Cells count from the top, while on OpenGL fragCoord starts at the bottom.
    // Time wraps hourly: float precision would make the rain stutter in splits
    // left open for days.
    vec2 pos = vec2(fragCoord.x, iResolution.y - fragCoord.y);
    vec2 cell = floor(pos / CELL);
    float rows = ceil(iResolution.y / CELL.y);
    float time = mod(iTime, 3600.0);

    float glow = 0.0;
    float head = 0.0;
    for (int k = 0; k < DROPS; k++) {
        vec2 column = vec2(cell.x, float(k) * 101.0);
        float speed = mix(SPEED_MIN, SPEED_MAX, hash(column));
        // A drop loops over the column, its trail and a random gap, so the
        // columns do not all empty and refill together.
        float span = rows + TRAIL + hash(column + 17.0) * rows;
        float y = floor(mod(time * speed + hash(column + 31.0) * span, span));
        float behind = y - cell.y;
        if (behind >= 0.0 && behind < TRAIL) {
            glow = max(glow, pow(1.0 - behind / TRAIL, 2.0));
            if (behind == 0.0) head = 1.0;
        }
    }
    if (glow <= 0.0) return;

    float rate = GLYPH_RATE * pow(hash(cell + 53.0), 4.0);
    float tick = floor(time * rate + hash(cell + 71.0));
    float seed = floor(hash(cell + tick * vec2(1.37, 2.71)) * 4096.0);
    float ink = glyph(pos - cell * CELL, seed);

    vec3 rain = mix(RAIN_COLOR, HEAD_COLOR, head);
    vec3 color = mix(shown, rain, ink * glow * OPACITY * through);
    fragColor.rgb = linear ? linearize(color) : color;
}
