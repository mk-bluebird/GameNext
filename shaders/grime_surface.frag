#version 450

layout(location = 0) in vec2 vUV;
layout(location = 1) in vec3 vWorldPos;
layout(location = 2) in vec3 vNormal;

layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0) uniform GrimeUniforms {
    float uWetness;
    float uMud;
    float uSoot;
    float uDust;
    float uTearIntensity;
    float uRoughness;
    vec2 uFlowDir;
    vec2 uStretchDir;
};

layout(set = 1, binding = 0) uniform sampler2D uBaseAlbedo;
layout(set = 1, binding = 1) uniform sampler2D uBaseNormal;
layout(set = 1, binding = 2) uniform sampler2D uGrimeMask;
layout(set = 1, binding = 3) uniform sampler2D uMudTex;
layout(set = 1, binding = 4) uniform sampler2D uSootTex;

vec3 applyWetSpecular(vec3 baseColor, float wet) {
    float luma = dot(baseColor, vec3(0.299, 0.587, 0.114));
    vec3 desatColor = mix(baseColor, vec3(luma), wet * 0.6);
    float darken = wet * 0.3;
    return desatColor * (1.0 - darken);
}

void main() {
    vec3 baseColor = texture(uBaseAlbedo, vUV).rgb;
    float grimeMask = texture(uGrimeMask, vUV).r;
    
    vec2 flowUV = vUV + uFlowDir * grimeMask * 0.02;
    vec2 stretchUV = vUV + uStretchDir * uTearIntensity * 0.015;
    
    vec3 mudColor = texture(uMudTex, flowUV).rgb;
    vec3 sootColor = texture(uSootTex, stretchUV).rgb;
    
    float mudFactor = uMud * grimeMask;
    float sootFactor = uSoot * grimeMask * (1.0 - mudFactor);
    float dustFactor = uDust * grimeMask * 0.5;
    
    vec3 color = baseColor;
    color = mix(color, mudColor, mudFactor);
    color = mix(color, sootColor, sootFactor);
    color = mix(color, color * 0.85, dustFactor);
    color = applyWetSpecular(color, uWetness);
    
    fragColor = vec4(color, 1.0);
}
