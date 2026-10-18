#include "opentune/analyzer.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <stdexcept>

namespace opentune {
namespace {
constexpr double pi = 3.14159265358979323846;
int power2(int n) { int p = 1; while (p < n) p *= 2; return p; }
int checkedRate(int rate) { if (rate<8000 || rate>192000) throw std::invalid_argument("unsupported sample rate"); return rate; }
}
double centsBetween(double hz, double target) {
    if (!(hz > 0 && target > 0 && std::isfinite(hz) && std::isfinite(target)))
        throw std::invalid_argument("positive finite frequencies required");
    return 1200 * std::log2(hz / target);
}
void fft(std::vector<std::complex<double>>& a, bool inverse) {
    const size_t n = a.size();
    for (size_t i = 1, j = 0; i < n; ++i) {
        size_t bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(a[i], a[j]);
    }
    for (size_t len = 2; len <= n; len <<= 1) {
        const double angle = (inverse ? 2 : -2) * pi / static_cast<double>(len);
        const std::complex<double> step(std::cos(angle), std::sin(angle));
        for (size_t i = 0; i < n; i += len) {
            std::complex<double> w(1, 0);
            for (size_t j = 0; j < len / 2; ++j) {
                const auto u = a[i + j], v = a[i + j + len / 2] * w;
                a[i + j] = u + v; a[i + j + len / 2] = u - v; w *= step;
            }
        }
    }
    if (inverse) for (auto& v : a) v /= static_cast<double>(n);
}
Analyzer::Analyzer(int rate, double reference) : rate_(checkedRate(rate)),
    n_(static_cast<int>(std::round(rate * .080))), hop_(static_cast<int>(std::round(rate * .020))),
    maxLag_(static_cast<int>(std::ceil(rate / 50.0)) + 2), fftSize_(power2(n_ * 2)),
    spectrumFftSize_(power2(n_)), reference_(reference), x_(n_), energy_(n_ + 1),
    difference_(maxLag_ + 1), cmndf_(maxLag_ + 1), full_(fftSize_), head_(fftSize_), spectrum_(spectrumFftSize_) {
    if (rate < 8000 || rate > 192000 || !std::isfinite(reference) || reference < 400 || reference > 480)
        throw std::invalid_argument("unsupported sample rate or reference");
}
void Analyzer::reset() {
    tracker_.reset(); noise_.reset(); previousTime_ = 0;
}
Analysis Analyzer::analyze(const float* pcm, int count, double endSeconds, bool visuals) {
    if (!pcm || count != n_ || !std::isfinite(endSeconds) || endSeconds < 0)
        throw std::invalid_argument("invalid frame boundary");
    const auto start = std::chrono::steady_clock::now();
    Analysis result; result.sequence = ++sequence_; result.timeSeconds = endSeconds;
    const auto features = preprocess(pcm, n_, x_, energy_);
    result.rmsDb = features.rmsDb; result.clipFraction = features.clipFraction;
    // Numerical floor, not a loudness gate: weak periodic tones remain eligible.
    result.validity = result.rmsDb < -105 ? Validity::silent : Validity::uncertain;
    if (result.clipFraction > .02) result.validity = Validity::clipped;
    bool qualifiedCandidate=false;
    double windowSum = 0;
    if (visuals || result.validity == Validity::uncertain) {
        std::fill(spectrum_.begin(), spectrum_.end(), 0);
        for (int i = 0; i < n_; ++i) {
            const double hann = .5 - .5 * std::cos(2 * pi * i / (n_ - 1));
            spectrum_[i] = x_[i] * hann; windowSum += hann;
        }
        fft(spectrum_, false);
    }
    if (result.validity == Validity::uncertain) {
        // Exact fixed-integration-window YIN difference, using FFT correlation
        // to reduce cost. W is constant for every lag; this is NOT FFT peak F0.
        const int w = n_ - maxLag_;
        std::fill(full_.begin(), full_.end(), 0);
        std::fill(head_.begin(), head_.end(), 0);
        for (int i = 0; i < n_; ++i) full_[i] = x_[i];
        for (int i = 0; i < w; ++i) head_[i] = x_[i];
        fft(full_, false); fft(head_, false);
        for (int i = 0; i < fftSize_; ++i) full_[i] *= std::conj(head_[i]);
        fft(full_, true);
        double sum = 0; cmndf_[0] = 1;
        for (int lag = 1; lag <= maxLag_; ++lag) {
            const double d = std::max(0.0, energy_[w] + energy_[lag + w] - energy_[lag] - 2 * full_[lag].real());
            difference_[lag] = d; sum += d;
            cmndf_[lag] = sum > 1e-20 ? d * lag / sum : 1;
        }
        // Search short periods too, then reject out-of-range F0. Starting at
        // rate/2000 would incorrectly accept an octave of a pure 4kHz signal.
        const int minLag = 2;
        int candidate = -1;
        for (int lag = minLag; lag < maxLag_; ++lag) {
            if (cmndf_[lag] < .12) {
                while (lag + 1 < maxLag_ && cmndf_[lag + 1] < cmndf_[lag]) ++lag;
                candidate = lag; break;
            }
        }
        const auto spectral = extractSpectrum(spectrum_, rate_);
        result.centroidHz = spectral.centroidHz;
        // Up to six local YIN minima. The first reliable short period protects
        // against accepting subharmonics of out-of-range pure tones.
        const bool outside = candidate > 0 && (static_cast<double>(rate_)/candidate > 2100);
        double best = -1;
        if (!outside) for (int lag=2; lag<maxLag_ && result.candidateCount<6; ++lag) {
            if (cmndf_[lag] > .25 || cmndf_[lag] > cmndf_[lag-1] || cmndf_[lag] >= cmndf_[lag+1]) continue;
            // A longer period can explain a noisy single spectral peak as an
            // octave below. Do not rescue a rejected first reliable YIN period
            // using its multiples; ambiguity is preferable to a confident octave.
            if (candidate > 0 && lag > candidate*1.35) break;
            const int candidate = lag;
            ++result.candidateCount;
            const double a = cmndf_[candidate - 1], b = cmndf_[candidate], c = cmndf_[candidate + 1];
            const double denom = a - 2 * b + c;
            const double delta = std::abs(denom) > 1e-12 ? std::clamp(.5 * (a - c) / denom, -.5, .5) : 0;
            // Parabolic interpolation of squared differences has a small
            // high-frequency bias (notably 44.1k/2k). Use interpolated YIN lag
            // for candidate selection, then a cosine curvature correction for
            // local minima. Derived for d(t)=A(1-cos wt); approximate for complex
            // harmonics, which are measured separately in the regression set.
            double refinedLag = candidate + delta;
            if (candidate > 2 && std::abs(denom) > 1e-12) {
                const double da=difference_[candidate-1], db=difference_[candidate], dc=difference_[candidate+1];
                const double curvature=da-2*db+dc;
                const double omega=2*pi/refinedLag;
                const double ratio=omega > 1e-8 ? std::tan(omega/2)/(omega/2) : 1;
                if (curvature > 1e-12) refinedLag=candidate+std::clamp(.5*(da-dc)/curvature*ratio,-.5,.5);
            }
            const double hz = rate_ / refinedLag;
            const double periodicity = std::clamp(1-b, 0.0, 1.0);
            const double harmonic = spectral.harmonicRatio(hz);
            if (best < 0 && result.rawHz == 0) {
                result.rawHz=hz; result.score=periodicity;
                result.harmonicRatio=harmonic; result.cmndfMinimum=b;
            }
            // No continuity bonus: it could trap a true octave change at its old
            // subharmonic. Prefer the shortest similarly reliable YIN period.
            const double rank = .75*periodicity + .25*harmonic - .025*std::log2(static_cast<double>(candidate)/std::max(2, minLag));
            if (hz >= 49.95 && hz <= 2002 && periodicity >= .88 && harmonic >= .85 && rank > best) {
                best = rank; result.rawHz = hz; result.score = periodicity;
                result.harmonicRatio = harmonic; result.cmndfMinimum = b;
                qualifiedCandidate = true;
            }
        }
    }
    const double dt = previousTime_ > 0 ? std::clamp(endSeconds-previousTime_, .001, .1) : .02;
    noise_.observe(result.rmsDb, !qualifiedCandidate && result.validity != Validity::clipped, dt);
    result.noiseKnown = noise_.known(); result.noiseFloorDb = noise_.db();
    result.levelMarginDb = result.noiseKnown ? result.rmsDb-noise_.db() : 0;
    result.frameQualified = qualifiedCandidate;
    const auto tracked = tracker_.update(result.rawHz, qualifiedCandidate, result.score, endSeconds);
    result.trackState = tracked.state; result.pitchRate = tracked.rateCentsPerSecond;
    result.consistency = tracked.consistency;
    if (tracked.valid) {
        result.validity = Validity::valid; result.trackedHz = tracked.hz;
        const double logPitch = 1200*std::log2(tracked.hz/reference_);
        result.midi = static_cast<int>(std::round(69+logPitch/100));
        result.cents = logPitch-100*(result.midi-69);
    }
    previousTime_ = endSeconds;
    if (visuals) {
        result.waveDuration = static_cast<double>(n_) / rate_;
        for (int bin = 0; bin < kWavePoints; ++bin) {
            float lo = 1, hi = -1;
            for (int i = bin * n_ / kWavePoints; i < (bin + 1) * n_ / kWavePoints; ++i) {
                lo = std::min(lo, pcm[i]); hi = std::max(hi, pcm[i]);
            }
            result.wave[2 * bin] = lo; result.wave[2 * bin + 1] = hi;
        }
        // First 512 actual FFT bins; never invent a frequency grid. DC is not doubled.
        result.spectrumCount = std::min(kSpectrumBins, spectrumFftSize_ / 2 + 1);
        result.spectrumBinHz = static_cast<double>(rate_) / spectrumFftSize_;
        for (int i = 0; i < result.spectrumCount; ++i) {
            const double amplitude = std::abs(spectrum_[i]) * (i == 0 ? 1 : 2) / windowSum;
            result.spectrum[i] = static_cast<float>(20 * std::log10(std::max(amplitude, 1e-6)));
        }
    }
    result.computeMs = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
    return result;
}
}
