#include <metal_stdlib>
using namespace metal;

float3 liquidMetalPermute(float3 value) {
    return fmod(((value * 34.0) + 1.0) * value, 289.0);
}

float liquidMetalNoise(float2 value) {
    constexpr float4 c = float4(
        0.211324865405187,
        0.366025403784439,
        -0.577350269189626,
        0.024390243902439
    );
    float2 cell = floor(value + dot(value, c.yy));
    float2 x0 = value - cell + dot(cell, c.xx);
    float2 offset = x0.x > x0.y ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + c.xxzz;
    x12.xy -= offset;
    cell = fmod(cell, 289.0);
    float3 permutation = liquidMetalPermute(
        liquidMetalPermute(cell.y + float3(0.0, offset.y, 1.0))
            + cell.x + float3(0.0, offset.x, 1.0)
    );
    float3 attenuation = max(
        0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)),
        0.0
    );
    attenuation *= attenuation;
    attenuation *= attenuation;
    float3 x = 2.0 * fract(permutation * c.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    attenuation *= 1.79284291400159
        - 0.85373472095314 * (a0 * a0 + h * h);
    float3 gradient;
    gradient.x = a0.x * x0.x + h.x * x0.y;
    gradient.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(attenuation, gradient);
}

float liquidMetalChannel(
    float light,
    float dark,
    float stripe,
    float3 widths,
    float blur,
    float bump
) {
    float channel = mix(dark, light, smoothstep(0.0, 2.0 * blur, stripe));
    float border = widths.x;
    channel = mix(channel, dark, smoothstep(border, border + 2.0 * blur, stripe));
    border = widths.x + 0.4 * (1.0 - bump) * widths.y;
    channel = mix(channel, light, smoothstep(border, border + 2.0 * blur, stripe));
    border = widths.x + 0.5 * (1.0 - bump) * widths.y;
    channel = mix(channel, dark, smoothstep(border, border + 2.0 * blur, stripe));
    border = widths.x + widths.y;
    channel = mix(channel, light, smoothstep(border, border + 2.0 * blur, stripe));
    float gradientPosition = (stripe - widths.x - widths.y) / widths.z;
    float gradient = mix(light, dark, smoothstep(0.0, 1.0, gradientPosition));
    return mix(channel, gradient, smoothstep(border, border + 0.5 * blur, stripe));
}

float3 rainbowHSV(float hue, float saturation, float value) {
    float3 shifted = abs(fract(hue + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    float3 rgb = clamp(shifted - 1.0, 0.0, 1.0);
    rgb = rgb * rgb * (3.0 - 2.0 * rgb);
    return value * mix(float3(1.0), rgb, saturation);
}

[[ stitchable ]] half4 rainbowWaveField(
    float2 position,
    half4 source,
    float2 size,
    float time,
    float rise,
    float intensity,
    float darkMode
) {
    float2 uv = position / size;
    float aspect = size.x / max(size.y, 1.0);
    float2 center = float2(0.5, 1.16 + (1.0 - rise) * 0.48);
    float2 delta = uv - center;
    delta.x *= aspect;
    float radius = length(delta);
    float phase = radius * 26.0 - time * 0.72;
    float wave = 0.5 + 0.5 * cos(phase);
    wave = smoothstep(0.04, 0.96, wave);

    // The surface remains continuous and nearly white. Only saturation rises
    // and falls with the concentric wave, growing gradually toward the bottom.
    float depth = smoothstep(0.30, 0.98, uv.y);
    float saturation = depth * (0.025 + 0.38 * wave) * intensity;
    float hue = fract(0.90 + radius * 1.28 - time * 0.026);
    float topFade = smoothstep(0.24, 0.48, uv.y + (rise - 1.0) * 0.18);
    float3 lightColor = rainbowHSV(hue, saturation, 1.0);
    lightColor = mix(float3(1.0), lightColor, topFade);

    float3 darkBase = float3(0.018, 0.021, 0.032);
    float darkWave = depth * (0.12 + 0.88 * wave) * intensity;
    float3 darkGlow = rainbowHSV(
        hue,
        0.34 + 0.34 * wave,
        0.12 + 0.34 * darkWave
    );
    float3 darkColor = mix(darkBase, darkGlow, topFade * darkWave);
    float3 color = mix(lightColor, darkColor, darkMode);
    return half4(half3(color), source.a);
}

[[ stitchable ]] half4 liquidMetalBubble(
    float2 position,
    half4 source,
    float2 size,
    float2 center,
    float radius,
    float time,
    float intensity
) {
    // These are the values from the Paper reference. The equations below keep
    // Paper's circle coordinate system, contour compression, and RGB phase shift.
    constexpr float repetition = 2.0;
    constexpr float softness = 0.10;
    constexpr float shiftRed = 0.30;
    constexpr float shiftBlue = 0.30;
    constexpr float distortion = 0.07;
    constexpr float contourStrength = 0.40;
    constexpr float angleDegrees = 70.0;
    constexpr float speed = 1.0;

    float2 point = (position - center) / max(radius, 1.0);
    float radial = length(point);
    if (radial > 1.01) {
        return half4(0.0);
    }

    float2 uv = point * 0.5 + 0.5;
    float t = 0.3 * (time * speed + 2.8);

    float angle = (-angleDegrees + 70.0) * M_PI_F / 180.0;
    float cosine = cos(angle);
    float sine = sin(angle);
    float2 rotatedUV = uv - 0.5;
    rotatedUV = float2(
        rotatedUV.x * cosine - rotatedUV.y * sine,
        rotatedUV.x * sine + rotatedUV.y * cosine
    ) + 0.5;

    float2 shapeUV = (uv - 0.5) * 0.67;
    float edge = pow(clamp(3.0 * length(shapeUV), 0.0, 1.0), 18.0);
    float edgeMask = smoothstep(0.88, 0.90, edge);
    edge = mix(edgeMask, edge, smoothstep(0.0, 0.4, contourStrength));
    float opacity = 1.0 - smoothstep(0.886, 0.90, edge);
    edge *= 1.2;

    float diagonalUp = rotatedUV.x - rotatedUV.y;
    float diagonalDown = rotatedUV.x + rotatedUV.y;
    float3 light = float3(0.98, 0.98, 1.0);
    float3 dark = float3(0.10, 0.10, 0.10 + 0.10 * smoothstep(0.7, 1.3, diagonalDown));

    float2 gradientUV = uv - 0.5;
    float distanceFromCenter = length(gradientUV + float2(0.0, 0.2 * diagonalUp));
    float gradientAngle = (0.25 - 0.2 * diagonalUp) * M_PI_F;
    float2 turned = float2(
        gradientUV.x * cos(gradientAngle) - gradientUV.y * sin(gradientAngle),
        gradientUV.x * sin(gradientAngle) + gradientUV.y * cos(gradientAngle)
    );
    float direction = turned.x;

    float bump = 1.0 - pow(1.8 * distanceFromCenter, 1.2);
    bump *= pow(max(uv.y, 0.0001), 0.3);
    float thinOneRatio = 0.12 / repetition * (1.0 - 0.4 * bump);
    float thinTwoRatio = 0.07 / repetition * (1.0 + 0.4 * bump);
    float wideRatio = 1.0 - thinOneRatio - thinTwoRatio;
    float3 widths = float3(
        repetition * thinOneRatio,
        repetition * thinTwoRatio,
        wideRatio
    );

    float noise = liquidMetalNoise(uv - t);
    edge += (1.0 - edge) * distortion * noise * intensity;
    direction += diagonalUp;
    direction -= 2.0 * noise * diagonalUp
        * (smoothstep(0.0, 1.0, edge) * (1.0 - smoothstep(0.0, 1.0, edge)));
    direction *= mix(1.0, 1.0 - edge, smoothstep(0.5, 1.0, contourStrength));
    direction -= 1.7 * edge * smoothstep(0.5, 1.0, contourStrength);
    direction += 0.2 * pow(contourStrength, 4.0) * (1.0 - smoothstep(0.0, 1.0, edge));

    bump *= clamp(pow(max(uv.y, 0.0001), 0.1), 0.3, 1.0);
    direction *= 0.1 + (1.1 - edge) * bump;
    direction *= 0.4 + 0.6 * (1.0 - smoothstep(0.5, 1.0, edge));
    direction += 0.18 * smoothstep(0.1, 0.2, uv.y)
        * (1.0 - smoothstep(0.2, 0.4, uv.y));
    direction += 0.03 * smoothstep(0.1, 0.2, 1.0 - uv.y)
        * (1.0 - smoothstep(0.2, 0.4, 1.0 - uv.y));
    direction *= 0.5 + 0.5 * pow(uv.y, 2.0);
    direction = direction * repetition - t;

    float dispersion = clamp(1.0 - bump, 0.0, 1.0);
    float redDispersion = dispersion + 0.03 * bump * noise;
    redDispersion += 5.0
        * smoothstep(-0.1, 0.2, uv.y)
        * (1.0 - smoothstep(0.1, 0.5, uv.y))
        * smoothstep(0.4, 0.6, bump)
        * (1.0 - smoothstep(0.4, 1.0, bump));
    redDispersion -= diagonalUp;
    float blueDispersion = dispersion * 1.3;
    blueDispersion += smoothstep(0.0, 0.4, uv.y)
        * (1.0 - smoothstep(0.1, 0.8, uv.y))
        * smoothstep(0.4, 0.6, bump)
        * (1.0 - smoothstep(0.4, 0.8, bump));
    blueDispersion -= 0.2 * edge;
    redDispersion *= shiftRed / 20.0;
    blueDispersion *= shiftBlue / 20.0;

    float blur = softness / 15.0;
    widths.y -= 0.02 * smoothstep(0.0, 1.0, edge + bump);
    float red = liquidMetalChannel(
        light.r, dark.r, fract(direction + redDispersion), widths, blur, bump
    );
    float green = liquidMetalChannel(
        light.g, dark.g, fract(direction), widths, blur, bump
    );
    float blue = liquidMetalChannel(
        light.b, dark.b, fract(direction - blueDispersion), widths, blur, bump
    );
    float3 color = float3(red, green, blue);

    // Paper composites the circle over colorBack (#aaa). The extension keeps
    // its white canvas, so only the circle is emitted and its antialiased edge
    // naturally blends into the surrounding UI.
    float circleAlpha = smoothstep(1.01, 0.99, radial) * opacity;
    return half4(half3(clamp(color, 0.0, 1.0)), half(circleAlpha * source.a));
}
