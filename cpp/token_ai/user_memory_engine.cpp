// cpp/token_ai/user_memory_engine.cpp
// Token-AI User Tracking and Persistent Memory Engine
//
// Scrubbed and refactored from a game-specific "grime" integration system
// into a Token-AI–centric C++17 engine that:
//
//   - Tracks per-user interaction exposure (tokens, latency, errors, etc.).
//   - Integrates those exposures over time into a persistent UserMemoryState.
//   - Provides clean update and finalization APIs for AI-chat tools to
//     "end responses correctly" (e.g., update memory after each turn).
//
// No game context remains; this is suitable for GitHub-hosted AI/chat services.

#include <algorithm>
#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

namespace token_ai {

inline float clamp01(float v) noexcept {
    if (v < 0.0f) return 0.0f;
    if (v > 1.0f) return 1.0f;
    return v;
}

// ---------------------------------------------------------------------
// Core structures
// ---------------------------------------------------------------------

// Invariants governing how aggressively memory integrates exposure.
struct MemoryInvariants {
    float coherenceWeight;  // weight for coherence-related signals (0-1)
    float safetyWeight;     // weight for safety-related signals (0-1)
    float retentionWeight;  // weight for retention/engagement (0-1)

    MemoryInvariants(float coherence = 0.5f,
                     float safety = 0.5f,
                     float retention = 0.5f)
        : coherenceWeight(clamp01(coherence)),
          safetyWeight(clamp01(safety)),
          retentionWeight(clamp01(retention)) {}
};

// Per-turn exposure metrics for a user.
struct InteractionExposure {
    float tokensUsed;        // tokens used in this interaction (normalized 0-1)
    float latencyScore;      // latency score (higher = slower, 0-1)
    float errorScore;        // error/failure score (0-1)
    float satisfactionScore; // user satisfaction estimate (0-1)
    float noveltyScore;      // how novel the content was (0-1)

    InteractionExposure(float tokensUsed_ = 0.0f,
                        float latencyScore_ = 0.0f,
                        float errorScore_ = 0.0f,
                        float satisfactionScore_ = 0.0f,
                        float noveltyScore_ = 0.0f)
        : tokensUsed(clamp01(tokensUsed_)),
          latencyScore(clamp01(latencyScore_)),
          errorScore(clamp01(errorScore_)),
          satisfactionScore(clamp01(satisfactionScore_)),
          noveltyScore(clamp01(noveltyScore_)) {}
};

// Persistent memory state per user.
struct UserMemoryState {
    std::string userId;

    // Accumulated metrics (normalized where possible).
    float cumulativeTokenUsage;   // aggregated normalized token usage
    float avgLatencyScore;        // running average latency
    float avgErrorScore;          // running average error
    float avgSatisfactionScore;   // running average satisfaction
    float preferenceNoveltyBias;  // bias toward novelty vs stability (0-1)

    // Derived flags.
    bool prefersConcise;          // true if high token usage + low satisfaction
    bool prefersDeep;             // true if high satisfaction with higher tokens
    bool atRiskOfChurn;           // true if low satisfaction + high error

    std::uint64_t interactionCount;

    MemoryInvariants invariants;

    UserMemoryState(const std::string& id = "",
                    const MemoryInvariants& inv = MemoryInvariants())
        : userId(id),
          cumulativeTokenUsage(0.0f),
          avgLatencyScore(0.0f),
          avgErrorScore(0.0f),
          avgSatisfactionScore(0.0f),
          preferenceNoveltyBias(0.5f),
          prefersConcise(false),
          prefersDeep(false),
          atRiskOfChurn(false),
          interactionCount(0),
          invariants(inv) {}
};

// ---------------------------------------------------------------------
// Integration logic
// ---------------------------------------------------------------------

// Integrate a single interaction exposure into the user's memory state.
// dt is a time step in seconds or normalized time (>= 0).
inline void integrateExposure(UserMemoryState& state,
                              const InteractionExposure& exposure,
                              float dt) noexcept {
    if (dt <= 0.0f) {
        // Treat non-positive dt as a unit step to avoid division issues.
        dt = 1.0f;
    }

    // Weighted running average helper.
    auto update_avg = [](float current, float sample, float weight) -> float {
        // weight in (0,1]; small weight = slow adaptation
        float w = std::max(0.01f, std::min(weight, 1.0f));
        return current * (1.0f - w) + sample * w;
    };

    state.interactionCount += 1;

    // Normalize token usage contribution using invariants.retentionWeight as a scale.
    float tokenContribution = exposure.tokensUsed * dt * state.invariants.retentionWeight;
    state.cumulativeTokenUsage += tokenContribution;

    // Update averages using coherence and safety weights.
    state.avgLatencyScore =
        update_avg(state.avgLatencyScore,
                   exposure.latencyScore,
                   0.2f * state.invariants.coherenceWeight);

    state.avgErrorScore =
        update_avg(state.avgErrorScore,
                   exposure.errorScore,
                   0.3f * state.invariants.safetyWeight);

    state.avgSatisfactionScore =
        update_avg(state.avgSatisfactionScore,
                   exposure.satisfactionScore,
                   0.3f * state.invariants.retentionWeight);

    // Preference novelty bias trends toward higher novelty when satisfaction
    // is good and errors are low; toward stability otherwise.
    float noveltyTarget =
        clamp01(exposure.noveltyScore * (1.0f - state.avgErrorScore))
        * clamp01(exposure.satisfactionScore + 0.3f);
    state.preferenceNoveltyBias =
        update_avg(state.preferenceNoveltyBias, noveltyTarget, 0.15f);

    // Derived flags used by Token-AI to choose response strategies.
    float highTokenUsage   = state.cumulativeTokenUsage > 0.6f;
    float lowSatisfaction  = state.avgSatisfactionScore < 0.4f;
    float highSatisfaction = state.avgSatisfactionScore > 0.7f;
    float highError        = state.avgErrorScore > 0.5f;

    state.prefersConcise = highTokenUsage && lowSatisfaction;
    state.prefersDeep    = !state.prefersConcise && highSatisfaction && !highError;
    state.atRiskOfChurn  = lowSatisfaction && highError;
}

// Finalization logic to be called at the end of a response.
// This can adjust flags based on the latest exposure and optionally
// perform end-of-turn normalization.
inline void finalizeResponse(UserMemoryState& state,
                             const InteractionExposure& exposure) noexcept {
    // Ensure invariants are respected: clamp averages and bias.
    state.avgLatencyScore        = clamp01(state.avgLatencyScore);
    state.avgErrorScore          = clamp01(state.avgErrorScore);
    state.avgSatisfactionScore   = clamp01(state.avgSatisfactionScore);
    state.preferenceNoveltyBias  = clamp01(state.preferenceNoveltyBias);
    state.cumulativeTokenUsage   = clamp01(state.cumulativeTokenUsage);

    // Lightweight end-of-response check: if latency is high but satisfaction is
    // still good, encourage deeper responses; otherwise lean concise.
    bool highLatency   = state.avgLatencyScore > 0.6f;
    bool goodSatisfaction = state.avgSatisfactionScore > 0.6f;

    if (highLatency && goodSatisfaction) {
        state.prefersDeep = true;
        state.prefersConcise = false;
    }

    // If the latest exposure had poor satisfaction, nudge toward concise and
    // update churn risk.
    if (exposure.satisfactionScore < 0.3f) {
        state.prefersConcise = true;
        state.atRiskOfChurn  = true;
    }

    // Optional: reduce novelty bias slightly if errors are high.
    if (state.avgErrorScore > 0.6f) {
        state.preferenceNoveltyBias =
            clamp01(state.preferenceNoveltyBias * 0.8f);
    }
}

// ---------------------------------------------------------------------
// Engine wrapper: manages multiple users in memory.
// ---------------------------------------------------------------------

class UserMemoryEngine {
public:
    UserMemoryEngine() = default;

    // Get or create a user memory state.
    UserMemoryState& getOrCreateUser(const std::string& userId,
                                     const MemoryInvariants& defaults = MemoryInvariants()) {
        auto it = states_.find(userId);
        if (it != states_.end()) {
            return it->second;
        }
        UserMemoryState state(userId, defaults);
        auto inserted = states_.emplace(userId, state);
        return inserted.first->second;
    }

    // Update memory for a user given an exposure and time step.
    void updateUser(const std::string& userId,
                    const InteractionExposure& exposure,
                    float deltaSeconds,
                    const MemoryInvariants& defaults = MemoryInvariants()) {
        UserMemoryState& state = getOrCreateUser(userId, defaults);
        integrateExposure(state, exposure, deltaSeconds);
    }

    // Finalize a response for a user; typically called after an AI reply
    // is generated and its metrics are known.
    void endResponse(const std::string& userId,
                     const InteractionExposure& exposure) {
        auto it = states_.find(userId);
        if (it == states_.end()) {
            // No state yet; create and finalize.
            UserMemoryState state(userId);
            finalizeResponse(state, exposure);
            states_.emplace(userId, state);
            return;
        }
        finalizeResponse(it->second, exposure);
    }

    // Read-only access to a user's memory state; returns nullptr if absent.
    const UserMemoryState* getUserState(const std::string& userId) const noexcept {
        auto it = states_.find(userId);
        if (it == states_.end()) return nullptr;
        return &it->second;
    }

    // List all known user IDs (e.g., for persistence or inspection).
    std::vector<std::string> listUserIds() const {
        std::vector<std::string> ids;
        ids.reserve(states_.size());
        for (const auto& kv : states_) {
            ids.push_back(kv.first);
        }
        return ids;
    }

private:
    std::unordered_map<std::string, UserMemoryState> states_;
};

} // namespace token_ai
