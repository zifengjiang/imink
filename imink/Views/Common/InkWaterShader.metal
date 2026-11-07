#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// 墨水液面：整条由一个片元着色器绘制。
//
// 全部使用归一化坐标（0~1），避免 colorEffect 里 position 的单位（像素/点）歧义。
// 参数取自游戏内逐帧实测：波幅约 0.41 容器高、波长约 0.31 条宽、周期 6s/4s、
// 高光带厚度 0.06~0.26 容器高。

static inline float inkSurface(float u, float t) {
    float v = 0.80;
    v += 0.12 * sin(6.2831853 * 3.2 * u + 6.2831853 / 6.0 * t);
    v += 0.05 * sin(6.2831853 * 2.0 * u - 6.2831853 / 4.0 * t + 1.7);
    return clamp(v, 0.35, 1.0);
}

static inline float inkBandThickness(float u, float t) {
    float th = 0.16 + 0.075 * sin(6.2831853 * 3.2 * u - 6.2831853 / 4.8 * t + 2.4);
    return clamp(th, 0.06, 0.26);
}

static inline float inkHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static inline float inkNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = inkHash(i);
    float b = inkHash(i + float2(1.0, 0.0));
    float c = inkHash(i + float2(0.0, 1.0));
    float d = inkHash(i + float2(1.0, 1.0));
    float2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

/// - Parameters:
///   - bounds: 两处颜色分界的归一化 x（0 表示没有该分界）
[[stitchable]] half4 inkWater(float2 pos, half4 color,
                              float time, float level, float2 pixelSize,
                              half4 c1, half4 c2, half4 c3, float2 bounds)
{
    // pos 与 size 同为「点」，统一换算成 0~1
    float2 uv = pos / max(pixelSize, float2(1.0, 1.0));
    uv = clamp(uv, 0.0, 1.0);

    // 液面位置（0 = 顶部，1 = 底部）
    float surface = 1.0 - inkSurface(uv.x, time) * level;
    if (uv.y < surface) {
        return half4(0.0);
    }

    // 颜色交界：缓慢摆动 + 逐像素毛刺，像两团墨自然相接
    float slowRipple = 0.0045 * sin(uv.y * 3.4 + time * 1.1)
                     + 0.0027 * sin(uv.y * 7.1 - time * 0.7);
    float grain = (inkNoise(float2(uv.y * 26.0, time * 0.35)) - 0.5) * 0.009;
    float x = uv.x - slowRipple - grain;

    // 交界处轻微渗透，但保持边界清晰
    float blend = 0.004;
    half3 col = c1.rgb;
    if (bounds.x > 0.0) {
        col = mix(col, c2.rgb, smoothstep(-blend, blend, x - bounds.x));
    }
    if (bounds.y > 0.0) {
        col = mix(col, c3.rgb, smoothstep(-blend, blend, x - bounds.y));
    }

    // 水面高光带：上边缘贴液面，下边缘是另一条波
    float thickness = inkBandThickness(uv.x, time) * level;
    float bandEdge = surface + thickness;
    float inBand = smoothstep(bandEdge + 0.008, bandEdge - 0.008, uv.y);
    half3 bandColor = mix(col, half3(1.0, 1.0, 1.0), 0.42);
    col = mix(col, bandColor, inBand);

    // 越靠近容器底部越深，制造体积感
    float depth = clamp((uv.y - surface) / max(1.0 - surface, 0.001), 0.0, 1.0);
    col *= half(1.0 - 0.16 * depth);

    return half4(col, 1.0);
}
