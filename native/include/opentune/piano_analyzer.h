#pragma once
#include "analyzer.h"
namespace opentune {
// Worker-only, no Android/Flutter dependency. No resampling.
class PianoAnalyzer {
public:
    explicit PianoAnalyzer(int sampleRate, double referenceHz = 440);
    int windowSize() const { return n_; }
    int hopSize() const { return hop_; }
    int sampleRate() const { return rate_; }
    void reset();
    // count MUST equal windowSize; invalid input is rejected, not partially read.
    Analysis analyze(const float* pcm, int count, double endSeconds, bool visuals);
private:
    int rate_, n_, hop_, maxLag_, fftSize_, spectrumFftSize_;
    double reference_;
    std::vector<double> x_, energy_, difference_, cmndf_;
    std::vector<std::complex<double>> full_, head_, spectrum_;
    uint64_t sequence_ = 0;
    PitchTracker tracker_;
    NoiseFloor noise_;
    double previousTime_ = 0;
};
}
