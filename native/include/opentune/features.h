#pragma once
#include <array>
#include <complex>
#include <vector>

namespace opentune {
struct SignalFeatures {
    double mean = 0, rmsDb = -120, clipFraction = 0;
};
// Caller supplies preallocated output and prefix-energy buffers.
SignalFeatures preprocess(const float* pcm, int n, std::vector<double>& centered,
                          std::vector<double>& prefixEnergy);
struct SpectralFeatures {
    struct Peak { double hz = 0, power = 0; };
    std::array<Peak, 64> peaks{};
    int count = 0;
    double centroidHz = 0;
    double harmonicRatio(double f0) const;
};
SpectralFeatures extractSpectrum(const std::vector<std::complex<double>>& fft, int rate);
class NoiseFloor {
public:
    void reset() { known_ = false; db_ = -120; }
    void observe(double rmsDb, bool unvoiced, double dt);
    bool known() const { return known_; }
    double db() const { return db_; }
private:
    bool known_ = false;
    double db_ = -120;
};
} // namespace opentune
