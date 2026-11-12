#language slang 2026

import kitty_custom_shader_types;

static const float MARGIN_PX = 12.0;
static const int MARKER_OFFSETS[4] = { 0, 32, 48, 64 };

// Match these sRGB values (0–255) to sliding-tabs.conf.
static const float3 ACTIVE_BACKGROUND = float3(203, 166, 247);
static const float3 ACTIVE_TITLE = float3(30, 30, 46);
static const float3 ACTIVE_INDEX = float3(88, 91, 112);
static const float3 INACTIVE_TITLE = float3(205, 214, 244);
static const float3 INACTIVE_INDEX = float3(147, 153, 178);

float linear_channel(float srgb) {
    float value = srgb / 255.0;
    return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}

float3 linear_rgb(float3 srgb) {
    return float3(linear_channel(srgb.r), linear_channel(srgb.g), linear_channel(srgb.b));
}

int read_marker(KittyTexture texture, float2 pixel, float x, float y, int signature) {
    float3 sample_color = texture.Sample(float2(x * pixel.x, y)).rgb;
    if (any(sample_color < 0.10)) return -1;
    float3 srgb = 1.055 * pow(sample_color, float3(1.0 / 2.4)) - 0.055;
    int3 levels = int3(round((srgb * 255.0 - 96.0) / 5.0));
    if (any(levels < 0) || any(levels > 31)) return -1;
    int value = (levels.x << 10) | (levels.y << 5) | levels.z;
    return (value >> 13) == signature ? value & 8191 : -1;
}

float coverage_of(float3 color, float3 background, float3 ink) {
    float3 delta = ink - background;
    return saturate(dot(color - background, delta) / max(dot(delta, delta), 0.00001));
}

// The left glyph's advance can be fractional while Kitty's cell width is
// rounded up. Extend its last fully rendered part into the join with the body.
float left_cap_fill(KittyTexture texture, float2 pixel, float y, float left, float offset,
                    float cell_width, float3 background, float3 highlight) {
    float3 cap = texture.Sample(float2((left + offset) * pixel.x, y)).rgb;
    float fill = coverage_of(cap, background, highlight);
    if (offset < cell_width - 2.0) return fill;
    float3 inner_cap = texture.Sample(float2((left + cell_width - 2.5) * pixel.x, y)).rgb;
    return max(fill, coverage_of(inner_cap, background, highlight));
}

float4 paint_slide(float4 color, KittyTextures t, KittyCustomShaderData d,
                   float2 pixel, float cell_width, float2 visible, float2 target) {
    float x = t.pos.x / pixel.x;
    bool under_target = x >= target.x && x < target.y;
    bool under_slide = x >= visible.x && x < visible.y;
    if (!under_target && !under_slide) return color;

    // Carry the current cap pixels with the moving pill, including their antialiasing.
    float3 background = d.background.rgb;
    float3 highlight = linear_rgb(ACTIVE_BACKGROUND);
    float fill = 0.0;
    if (under_slide) {
        float left_offset = x - visible.x;
        float right_offset = visible.y - x;
        if (left_offset < cell_width) {
            fill = left_cap_fill(t.backbuffer, pixel, t.pos.y, target.x, left_offset,
                                 cell_width, background, highlight);
        } else if (right_offset <= cell_width) {
            float3 cap = t.backbuffer.Sample(float2((target.y - right_offset) * pixel.x, t.pos.y)).rgb;
            fill = coverage_of(cap, background, highlight);
        } else {
            fill = 1.0;
        }
    }
    float3 new_background = lerp(background, highlight, fill);
    if (under_target && (x < target.x + cell_width || x >= target.y - cell_width))
        return float4(new_background, color.a);

    // Recover text coverage from the title and index colors and composite it
    // in place over the moving fill. The labels never translate.
    float3 inactive_title = linear_rgb(INACTIVE_TITLE);
    float3 inactive_number = linear_rgb(INACTIVE_INDEX);
    float3 active_title = linear_rgb(ACTIVE_TITLE);
    float3 active_number = linear_rgb(ACTIVE_INDEX);
    float3 original_background = under_target ? highlight : background;
    float3 old_title = under_target ? active_title : inactive_title;
    float3 old_number = under_target ? active_number : inactive_number;
    float title_alpha = coverage_of(color.rgb, original_background, old_title);
    float number_alpha = coverage_of(color.rgb, original_background, old_number);
    bool number = distance(color.rgb, lerp(original_background, old_number, number_alpha))
                < distance(color.rgb, lerp(original_background, old_title, title_alpha));
    float3 title = lerp(inactive_title, active_title, fill);
    float3 index = lerp(inactive_number, active_number, fill);
    return float4(lerp(new_background, number ? index : title, number ? number_alpha : title_alpha), color.a);
}


float4 repair_static_join(float4 color, KittyTextures t, KittyCustomShaderData d,
                          float2 pixel, float sample_y, float cell_width) {
    float x = t.pos.x / pixel.x;
    float left = MARGIN_PX + floor((x - MARGIN_PX) / cell_width) * cell_width;
    float offset = x - left;
    if (left < MARGIN_PX || offset < cell_width - 2.0 || cell_width < 4.0) return color;
    float3 inside = t.backbuffer.Sample(float2((left + cell_width * 0.5) * pixel.x, sample_y)).rgb;
    float3 before = t.backbuffer.Sample(float2((left - 0.5) * pixel.x, sample_y)).rgb;
    float3 highlight = linear_rgb(ACTIVE_BACKGROUND);
    if (distance(inside, highlight) >= 0.035 || distance(before, highlight) < 0.035) return color;
    float3 background = d.background.rgb;
    float fill = left_cap_fill(t.backbuffer, pixel, t.pos.y, left, offset, cell_width, background, highlight);
    return float4(lerp(background, highlight, fill), color.a);
}

public float4 fragment_main(float4 color, KittyTextures t, uniform KittyCustomShaderData d) {
    float2 pixel = 1.0 / float2(d.viewport_size_pixels);
    float bottom = d.central_area.y + d.central_area.w;
    float top = 1.0 - MARGIN_PX * pixel.y;
    if (t.pos.y < bottom || t.pos.y >= top) return color;

    float row_height = round((top - bottom) / pixel.y);
    float cell_width = max(1.0, ceil(row_height * (24.0 / 53.0)));
    int columns = int(floor((float(d.viewport_size_pixels.x) - 2.0 * MARGIN_PX) / cell_width));
    float sample_y = (top + bottom) * 0.5;

    // The Python renderer supplies one small record in four unused cells.
    // Erase those cells from the final frame after reading the coordinates.
    for (int i = 0; i < 4; ++i) {
        int column = columns - 4 - MARKER_OFFSETS[i];
        if (column < 0) continue;
        float start = MARGIN_PX + float(column) * cell_width;
        float x = start + 0.5 * cell_width;
        int left = read_marker(t.backbuffer, pixel, x, sample_y, 1);
        if (left < int(MARGIN_PX)) continue;
        int right = read_marker(t.backbuffer, pixel, x + cell_width, sample_y, 2);
        int target_left = read_marker(t.backbuffer, pixel, x + 2.0 * cell_width, sample_y, 3);
        int target_right = read_marker(t.backbuffer, pixel, x + 3.0 * cell_width, sample_y, 2);
        if (right <= left || target_left < int(MARGIN_PX) || target_right <= target_left
            || float(right) > start || float(target_right) > start) continue;
        float position = t.pos.x / pixel.x;
        if (position >= start && position < start + 4.0 * cell_width)
            return float4(d.background.rgb, color.a);
        return paint_slide(color, t, d, pixel, cell_width,
                           float2(float(left), float(right)), float2(float(target_left), float(target_right)));
    }
    return repair_static_join(color, t, d, pixel, sample_y, cell_width);
}
