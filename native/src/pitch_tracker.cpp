#include "opentune/pitch_tracker.h"
#include <algorithm>

namespace opentune {
void PitchTracker::reset() { *this = PitchTracker{}; }
TrackedPitch PitchTracker::update(double hz, bool qualified, double quality, double time) {
    TrackedPitch out;
    const double dt = previous_ > 0 ? std::clamp(time - previous_, .001, .1) : .02;
    if (previous_ > 0 && (time <= previous_ || time - previous_ > .2)) reset();
    previous_ = time;
    if (!qualified || !std::isfinite(hz) || hz <= 0) {
        pending_ = 0; directionCount_ = 0;
        const bool expired = lastGood_ < 0 || time - lastGood_ >= .2;
        if (expired) { tracking_ = false; previousRaw_ = 0; }
        out.state = expired ? TrackState::lost : TrackState::uncertain;
        return out;
    }
    const double p = std::log2(hz);
    const double innovation = (p - log_) * 1200;
    out.rateCentsPerSecond = previousRaw_ > 0 ? 1200 * (p - previousRaw_) / dt : 0;
    previousRaw_ = p;
    if (!tracking_ || std::abs(innovation) > 80) {
        if (pending_ && std::abs(p - pendingLog_) * 1200 < 35) ++pending_;
        else { pending_ = 1; pendingLog_ = p; }
        out.state = tracking_ ? TrackState::switching : TrackState::candidate;
        const int required = quality >= .97 ? 2 : 3;
        out.consistency = std::min(1.0, static_cast<double>(pending_) / required);
        if (pending_ < required) return out;
        // Confirmed discontinuity: adopt the new pitch, do not slide through
        // unrelated intermediate notes. The UI owns its separate short animation.
        log_ = p; tracking_ = true; pending_ = 0; directionCount_ = 0;
    } else {
        pending_ = 0;
        const double sign = innovation > 0 ? 1 : -1;
        if (std::abs(innovation) > 12 && sign == direction_) ++directionCount_;
        else directionCount_ = std::abs(innovation) > 12 ? 1 : 0;
        direction_ = sign;
        // Three persistent innovations distinguish drift/glide from one noisy
        // frame. Stable tones use 140ms; sustained changes use 50ms.
        const double tau = directionCount_ >= 3 ? .050 : .140;
        const double alpha = 1 - std::exp(-dt / tau);
        log_ += alpha * (p - log_);
        out.consistency = std::exp(-std::abs(innovation) / 80);
    }
    lastGood_ = time; out.valid = true; out.hz = std::exp2(log_);
    out.state = TrackState::tracking;
    return out;
}
} // namespace opentune
