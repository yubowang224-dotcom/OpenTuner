#include "opentune/features.h"
#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace opentune {
SignalFeatures preprocess(const float* pcm, int n, std::vector<double>& x, std::vector<double>& energy) {
    SignalFeatures f; int clips = 0;
    for (int i = 0; i < n; ++i) {
        if (!std::isfinite(pcm[i])) throw std::invalid_argument("nonfinite PCM");
        f.mean += pcm[i]; if (std::abs(pcm[i]) >= .999f) ++clips;
    }
    f.mean /= n; energy[0] = 0;
    for (int i = 0; i < n; ++i) { x[i] = pcm[i] - f.mean; energy[i+1] = energy[i] + x[i]*x[i]; }
    f.rmsDb = 10 * std::log10(std::max(energy[n]/n, 1e-12));
    f.clipFraction = static_cast<double>(clips) / n;
    return f;
}
SpectralFeatures extractSpectrum(const std::vector<std::complex<double>>& spectrum, int rate) {
    SpectralFeatures f; double maximum = 0, power = 0, weighted = 0;
    const int size = static_cast<int>(spectrum.size());
    const int limit = std::min(size/2-1, static_cast<int>(8000.0*size/rate));
    for (int k = 1; k < limit; ++k) {
        const double p = std::norm(spectrum[k]);
        power += p; weighted += p*k*rate/size; maximum = std::max(maximum, std::abs(spectrum[k]));
    }
    f.centroidHz = power > 0 ? weighted/power : 0;
    for (int k = 2; k < limit; ++k) {
        const double amplitude = std::abs(spectrum[k]);
        if (amplitude < maximum*.18 || amplitude <= std::abs(spectrum[k-1]) || amplitude < std::abs(spectrum[k+1])) continue;
        const double a = std::log(std::max(std::abs(spectrum[k-1]), 1e-15));
        const double b = std::log(std::max(amplitude, 1e-15));
        const double c = std::log(std::max(std::abs(spectrum[k+1]), 1e-15));
        const double den = a-2*b+c;
        const double offset = std::abs(den)>1e-12 ? std::clamp(.5*(a-c)/den, -.5, .5) : 0;
        SpectralFeatures::Peak peak{(k+offset)*rate/size, amplitude*amplitude};
        if (f.count < static_cast<int>(f.peaks.size())) f.peaks[f.count++] = peak;
        else {
            auto weakest = std::min_element(f.peaks.begin(), f.peaks.end(), [](auto x, auto y) { return x.power < y.power; });
            if (peak.power > weakest->power) *weakest = peak;
        }
    }
    return f;
}
double SpectralFeatures::harmonicRatio(double f0) const {
    double good = 0, total = 0;
    for (int i = 0; i < count; ++i) {
        const auto& p = peaks[i]; const double order = std::round(p.hz/f0);
        total += p.power;
        if (order >= 1 && std::abs(p.hz-order*f0) <= std::max(1.5, p.hz*.004)) good += p.power;
    }
    return total > 0 ? good/total : 0;
}
void NoiseFloor::observe(double level, bool unvoiced, double dt) {
    // Only unvoiced windows inform the floor; no claim of calibrated SNR.
    if (!unvoiced) return;
    if (!known_) { db_ = level; known_ = true; return; }
    const double tau = level < db_ ? .2 : 3.0;
    db_ += (1-std::exp(-dt/tau))*(level-db_);
}
} // namespace opentune
