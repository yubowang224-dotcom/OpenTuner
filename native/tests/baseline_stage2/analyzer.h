#pragma once
#include <array>
#include <complex>
#include <cstdint>
#include <vector>

namespace stage2baseline {
constexpr int kWavePoints = 128;
constexpr int kSpectrumBins = 512;
enum class Validity : int { silent = 0, uncertain = 1, valid = 2, clipped = 3 };
struct Analysis {
    bool frameQualified = false; // observation adapter only, no algorithm change
    uint64_t sequence = 0;
    double timeSeconds = 0; // exclusive end of analysis window on sample clock
    Validity validity = Validity::silent;
    double rawHz = 0, trackedHz = 0, cents = 0, score = 0;
    double rmsDb = -120, clipFraction = 0, computeMs = 0;
    int midi = -1;
    double waveDuration = 0, spectrumBinHz = 0;
    int spectrumCount = 0;
    std::array<float, kWavePoints * 2> wave{}; // min,max pairs, full input scale
    std::array<float, kSpectrumBins> spectrum{}; // Hann one-sided peak dBFS/bin
};

// Worker-only, no Android/Flutter dependency. No resampling.
class Analyzer {
public:
    explicit Analyzer(int sampleRate, double referenceHz = 440);
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
    double trackedLog_ = 0, pendingLog_ = 0, previousTime_ = 0;
    int pendingCount_ = 0, acceptedMidi_ = -1;
    bool tracking_ = false;
};
double centsBetween(double hz, double target);
void fft(std::vector<std::complex<double>>& a, bool inverse);
} // namespace opentune
