#pragma once
#include <cmath>

namespace opentune {
enum class TrackState { idle, candidate, tracking, switching, uncertain, lost };
struct TrackedPitch {
    bool valid = false;
    double hz = 0, rateCentsPerSecond = 0, consistency = 0;
    TrackState state = TrackState::idle;
};
// One worker owns each tracker. Time is the exclusive frame end on the sample clock.
// Unqualified observations NEVER produce valid held-over frequencies.
class PitchTracker {
public:
    void reset();
    TrackedPitch update(double hz, bool qualified, double quality, double time);
private:
    bool tracking_ = false;
    int pending_ = 0, directionCount_ = 0;
    double log_ = 0, pendingLog_ = 0, previous_ = 0, lastGood_ = -1;
    double previousRaw_ = 0, direction_ = 0;
};
} // namespace opentune
