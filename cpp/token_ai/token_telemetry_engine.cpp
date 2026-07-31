// cpp/token_ai/token_telemetry_engine.cpp
// Token-AI Telemetry Engine
//
// Scrubbed and converted from a GameNext/BCI-oriented Rust module into a
// Token-AI–centric C++17 implementation. This engine computes visual/audio
// telemetry parameters from normalized interaction metrics (stress, latency,
// overload, signal quality) and invariant gates.
//
// The code is self-contained, uses only the C++ standard library, and is
// suitable for GitHub-hosted projects and AI-agent integrations.

#include <algorithm>
#include <cstdint>
#include <string>
#include <vector>

namespace token_ai {

// Utility clamp in [0, 1].
inline float clamp01(float v) noexcept {
    if (v < 0.0f) return 0.0f;
    if (v > 1.0f) return 1.0f;
    return v;
}

// Stress band: abstracted from BCI, now generic interaction load bands.
enum class StressBand {
    Low,
    Mid,
    High
};

// Attention band: how focused the interaction is.
enum class AttentionBand {
    Drifting,
    Focused,
    Locked
};

// Summary of interaction state used by Token-AI.
// All values are normalized floats in [0, 1].
struct InteractionSummary {
    float stressScore;          // perceived difficulty/load
    StressBand stressBand;
    AttentionBand attentionBand;
    float overloadIndex;        // visual/context overload
    float surpriseSpike;        // transient spike (errors, unexpected events)
    float signalQuality;        // quality/confidence of underlying signals/models
};

// Invariant gates controlling safety and stability.
struct Invariants {
    float cic;  // Coherence Integrity Coefficient
    float aos;  // Attention Orientation Score (unused here but retained)
    float det;  // Detection reliability
    float lsg;  // Latency Safety Guard
    float uec;  // User Experience Comfort (optional metric; default 0)
    float cdl;  // Churn/Dropout Likelihood (optional metric; default 0)
    float arr;  // Attention Retention Rate (optional metric; default 0)

    Invariants(float cic_,
               float aos_,
               float det_,
               float lsg_,
               float uec_ = 0.0f,
               float cdl_ = 0.0f,
               float arr_ = 0.0f)
        : cic(clamp01(cic_)),
          aos(clamp01(aos_)),
          det(clamp01(det_)),
          lsg(clamp01(lsg_)),
          uec(clamp01(uec_)),
          cdl(clamp01(cdl_)),
          arr(clamp01(arr_)) {}
};

// Visual telemetry parameters for Token-AI dashboards or UI bindings.
struct VisualParams {
    float maskRadius;    // how tight the focus region is
    float maskFeather;   // softness of the focus boundary
    float decayGrain;    // high-frequency detail for noise/decay visualization
    float colorDesat;    // desaturation / tonal simplification
    float emphasisOverlay; // emphasis overlay intensity
    float motionSmear;   // motion/blur intensity for dynamic visuals
    std::vector<std::string> paletteHex; // optional color palette

    VisualParams()
        : maskRadius(0.95f),
          maskFeather(0.6f),
          decayGrain(0.0f),
          colorDesat(0.0f),
          emphasisOverlay(0.0f),
          motionSmear(0.0f),
          paletteHex() {}
};

// Audio telemetry parameters for Token-AI (alerts, heartbeat, etc.).
struct AudioParams {
    float alertChannelGain; // alerts/critical notifications
    float backgroundMuffle; // muffle for less important channels
    float heartbeatGain;    // heartbeat-like feedback (load/stress)
    float breathGain;       // breathing/effort feedback
    float ringingLevel;     // high-frequency emphasis (warnings)
    float direct;           // clarity of main channel

    AudioParams()
        : alertChannelGain(0.0f),
          backgroundMuffle(0.0f),
          heartbeatGain(0.0f),
          breathGain(0.0f),
          ringingLevel(0.0f),
          direct(1.0f) {}
};

// A single telemetry binding for a logical UI/interaction region.
struct TelemetryBinding {
    std::string id;           // stable binding identifier, e.g., "token-ai-main-panel"
    std::string region;       // logical region, e.g., "primary", "sidebar"
    Invariants gates;
    VisualParams visual;
    AudioParams audio;

    TelemetryBinding(const std::string& id_,
                     const std::string& region_,
                     const Invariants& inv,
                     const VisualParams& vis,
                     const AudioParams& aud)
        : id(id_), region(region_), gates(inv), visual(vis), audio(aud) {}
};

// Telemetry request envelope (scrubbed variant of AiBciGeometryRequestV1).
struct TelemetryRequestV1 {
    std::string version;           // protocol version, e.g., "v1"
    std::string experienceType;    // e.g., "nano-mode", "analysis-mode"
    std::string style;             // style hint, e.g., "Minimal-Metrics"
    std::string locale;            // optional locale, e.g., "en-US"
    std::string platform;          // optional platform hint, e.g., "server"
    InteractionSummary summary;
    Invariants invariants;

    TelemetryRequestV1(const std::string& ver,
                       const std::string& expType,
                       const std::string& style_,
                       const std::string& locale_,
                       const std::string& platform_,
                       const InteractionSummary& sum,
                       const Invariants& inv)
        : version(ver),
          experienceType(expType),
          style(style_),
          locale(locale_),
          platform(platform_),
          summary(sum),
          invariants(inv) {}
};

// Telemetry response envelope (scrubbed variant of AiBciGeometryResponseV1).
struct TelemetryResponseV1 {
    std::string version;
    std::string experienceType;
    std::vector<TelemetryBinding> bindings;

    TelemetryResponseV1(const std::string& ver,
                        const std::string& expType,
                        std::vector<TelemetryBinding> b)
        : version(ver),
          experienceType(expType),
          bindings(std::move(b)) {}
};

// Internal helpers ------------------------------------------------------

inline float stressBandWeight(StressBand band) noexcept {
    switch (band) {
        case StressBand::Low:  return 0.15f;
        case StressBand::Mid:  return 0.55f;
        case StressBand::High: return 0.90f;
    }
    return 0.55f; // safe default
}

inline float attentionFocusWeight(AttentionBand band) noexcept {
    switch (band) {
        case AttentionBand::Drifting: return 0.20f;
        case AttentionBand::Focused:  return 0.60f;
        case AttentionBand::Locked:   return 0.90f;
    }
    return 0.60f; // safe default
}

// Guard based on signal quality: low quality scales down effects.
inline float computeQualityGuard(float signalQuality, float threshold) noexcept {
    float sq = clamp01(signalQuality);
    if (sq >= threshold) {
        return 1.0f;
    }
    return clamp01(sq / threshold);
}

inline void applyQualityGuardVisual(VisualParams& v, float guard) noexcept {
    const float neutralMaskRadius  = 0.95f;
    const float neutralMaskFeather = 0.60f;

    v.maskRadius  = neutralMaskRadius  + (v.maskRadius  - neutralMaskRadius)  * guard;
    v.maskFeather = neutralMaskFeather + (v.maskFeather - neutralMaskFeather) * guard;

    v.decayGrain     *= guard;
    v.colorDesat     *= guard;
    v.emphasisOverlay *= guard;
    v.motionSmear    *= guard;

    v.maskRadius = std::max(0.02f, std::min(v.maskRadius, 1.0f));
    (void)neutralMaskRadius;
    (void)neutralMaskFeather;
}

inline void applyQualityGuardAudio(AudioParams& a, float guard) noexcept {
    a.alertChannelGain *= guard;
    a.backgroundMuffle *= guard;
    a.heartbeatGain    *= guard;
    a.breathGain       *= guard;
    a.ringingLevel     *= guard;

    // Ensure main clarity channel does not collapse; bias toward at least 0.5.
    float minDirect = 0.5f;
    float adjusted  = a.direct + (1.0f - guard) * 0.1f;
    if (adjusted < minDirect) adjusted = minDirect;
    if (adjusted > 1.0f) adjusted = 1.0f;
    a.direct = adjusted;
}

// System health gate combines cic and det.
inline float computeSystemHealthGate(const Invariants& inv) noexcept {
    float cic = clamp01(inv.cic);
    float det = clamp01(inv.det);
    float health = clamp01(0.5f * cic + 0.5f * det);
    return 0.6f + 0.4f * health;
}

inline void applySystemHealthGate(VisualParams& v,
                                  AudioParams& a,
                                  const Invariants& inv) noexcept {
    float gate = computeSystemHealthGate(inv);

    v.decayGrain     *= gate;
    v.motionSmear    *= gate;
    a.alertChannelGain *= gate;
    a.heartbeatGain    *= gate;
    a.ringingLevel     *= gate;
}

// Public computation APIs -----------------------------------------------

// Compute visual telemetry parameters from interaction summary and invariants.
VisualParams computeVisualParams(const InteractionSummary& sum,
                                 const Invariants& inv) {
    const float sbw = stressBandWeight(sum.stressBand);
    const float afw = attentionFocusWeight(sum.attentionBand);

    VisualParams v;
    v.maskRadius = clamp01(
        0.95f
        - 0.55f * sum.stressScore
        - 0.35f * sum.overloadIndex
    );
    v.maskFeather = clamp01(
        0.60f
        - 0.35f * sum.stressScore
        + 0.20f * (1.0f - sum.overloadIndex)
    );
    v.decayGrain = clamp01(
        0.20f
        + 0.70f * sum.stressScore
        + 0.30f * sbw
    );
    v.colorDesat = clamp01(
        0.25f
        + 0.55f * sum.stressScore
        + 0.20f * sum.overloadIndex
    );
    v.emphasisOverlay = clamp01(
        0.30f
        + 0.50f * sum.stressScore
        + 0.40f * clamp01(sum.surpriseSpike)
    );
    v.motionSmear = clamp01(
        0.15f
        + 0.40f * sum.overloadIndex
        + 0.25f * (1.0f - afw)
        + 0.15f * sum.surpriseSpike
    );

    float guard = computeQualityGuard(sum.signalQuality, 0.30f);
    applyQualityGuardVisual(v, guard);

    AudioParams audioDummy;
    applySystemHealthGate(v, audioDummy, inv);

    return v;
}

// Compute audio telemetry parameters from interaction summary and invariants.
AudioParams computeAudioParams(const InteractionSummary& sum,
                               const Invariants& inv) {
    const float afw = attentionFocusWeight(sum.attentionBand);

    AudioParams a;
    a.alertChannelGain = clamp01(
        0.30f
        + 0.70f * sum.stressScore
        + 0.30f * sum.surpriseSpike
    );
    a.backgroundMuffle = clamp01(
        0.20f
        + 0.60f * sum.overloadIndex
        + 0.20f * sum.stressScore
    );
    a.heartbeatGain = clamp01(
        0.25f
        + 0.60f * sum.stressScore
        + 0.30f * sum.surpriseSpike
    );
    {
        float base = clamp01(
            0.20f
            + 0.50f * sum.stressScore
            + 0.30f * (1.0f - afw)
        );
        a.breathGain = base * clamp01(sum.signalQuality);
    }
    a.ringingLevel = clamp01(
        0.10f
        + 0.70f * sum.overloadIndex
        + 0.20f * (1.0f - sum.signalQuality)
    );
    a.direct = clamp01(
        0.90f
        - 0.50f * sum.stressScore
        - 0.30f * sum.overloadIndex
    );

    float guard = computeQualityGuard(sum.signalQuality, 0.30f);
    applyQualityGuardAudio(a, guard);

    VisualParams visualDummy;
    applySystemHealthGate(visualDummy, a, inv);

    return a;
}

// High-level engine entry point: handle a telemetry request and produce a
// response with one binding for the main region. This mirrors the Rust
// handle_ai_bci_geometry_request but is scrubbed for Token-AI.
TelemetryResponseV1 handleTelemetryRequest(const TelemetryRequestV1& req) {
    VisualParams visual = computeVisualParams(req.summary, req.invariants);
    AudioParams audio   = computeAudioParams(req.summary, req.invariants);

    TelemetryBinding binding(
        "token-ai-default-region",
        "primary",
        req.invariants,
        visual,
        audio
    );

    std::vector<TelemetryBinding> bindings;
    bindings.emplace_back(binding);

    return TelemetryResponseV1("v1", req.experienceType, std::move(bindings));
}

} // namespace token_ai
