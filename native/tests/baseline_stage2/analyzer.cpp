#include "analyzer.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <stdexcept>

namespace stage2baseline {
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
    tracking_ = false; pendingCount_ = 0; acceptedMidi_ = -1; previousTime_ = 0;
}
Analysis Analyzer::analyze(const float* pcm, int count, double endSeconds, bool visuals) {
    if (!pcm || count != n_ || !std::isfinite(endSeconds) || endSeconds < 0)
        throw std::invalid_argument("invalid frame boundary");
    const auto start = std::chrono::steady_clock::now();
    Analysis result; result.sequence = ++sequence_; result.timeSeconds = endSeconds;
    double mean = 0; int clips = 0;
    for (int i = 0; i < n_; ++i) {
        if (!std::isfinite(pcm[i])) throw std::invalid_argument("nonfinite PCM");
        mean += pcm[i]; if (std::abs(pcm[i]) >= .999f) ++clips;
    }
    mean /= n_; energy_[0] = 0;
    for (int i = 0; i < n_; ++i) { x_[i] = pcm[i] - mean; energy_[i + 1] = energy_[i] + x_[i] * x_[i]; }
    result.rmsDb = 10 * std::log10(std::max(energy_[n_] / n_, 1e-12));
    result.clipFraction = static_cast<double>(clips) / n_;
    result.validity = result.rmsDb < -60 ? Validity::silent : Validity::uncertain;
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
        if (candidate > 0 && candidate < maxLag_) {
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
            result.rawHz = hz; // diagnostic candidate, never valid by itself
            result.score = std::clamp(1 - b, 0.0, 1.0);
            // Evidence-driven gate: YIN alone falsely locked near-commensurate
            // 220+337.13Hz onto ~111Hz with high periodicity. Check strong Hann
            // peaks against integer partials of the period candidate. This does
            // not separate voices or certify monophony (harmonic mixtures remain
            // intrinsically ambiguous). FFT is NOT used to choose the F0.
            double peakMaximum = 0, consistentPower = 0, inconsistentPower = 0;
            const int peakLimit = std::min(spectrumFftSize_/2-1, static_cast<int>(8000.0*spectrumFftSize_/rate_));
            for (int k=2; k<peakLimit; ++k) peakMaximum=std::max(peakMaximum,std::abs(spectrum_[k]));
            for (int k=2; k<peakLimit; ++k) {
                const double amplitude=std::abs(spectrum_[k]);
                if (amplitude < peakMaximum*.18 || amplitude <= std::abs(spectrum_[k-1]) || amplitude < std::abs(spectrum_[k+1])) continue;
                const double pa=std::log(std::max(std::abs(spectrum_[k-1]),1e-15));
                const double pb=std::log(std::max(amplitude,1e-15));
                const double pc=std::log(std::max(std::abs(spectrum_[k+1]),1e-15));
                const double den=pa-2*pb+pc;
                const double offset=std::abs(den)>1e-12 ? std::clamp(.5*(pa-pc)/den,-.5,.5) : 0;
                const double peakHz=(k+offset)*rate_/spectrumFftSize_;
                const double partial=std::round(peakHz/hz);
                if (partial>=1 && std::abs(peakHz-partial*hz)<=std::max(1.5,peakHz*.004)) consistentPower+=amplitude*amplitude;
                else inconsistentPower+=amplitude*amplitude;
            }
            const bool harmonic = inconsistentPower <= .15*(consistentPower+inconsistentPower) && consistentPower>0;
            if (hz >= 49.95 && hz <= 2002 && result.score >= .88 && harmonic) {
                qualifiedCandidate=true;
                const double logHz = std::log2(hz);
                bool accept = true;
                const int midi = static_cast<int>(std::round(69 + 12 * (logHz - std::log2(reference_))));
                if (!tracking_) {
                    if (pendingCount_ && std::abs(logHz - pendingLog_) * 1200 < 40) ++pendingCount_;
                    else { pendingCount_ = 1; pendingLog_ = logHz; }
                    accept = pendingCount_ >= 2;
                    if (accept) { trackedLog_ = logHz; tracking_ = true; pendingCount_ = 0; }
                } else {
                    const double distance = std::abs(logHz - trackedLog_) * 1200;
                    // A large jump or a candidate name change requires two
                    // consistent frames. Rejected frames are visibly invalid.
                    if (distance > 80 || midi != acceptedMidi_) {
                        if (pendingCount_ && std::abs(logHz - pendingLog_) * 1200 < 40) ++pendingCount_;
                        else { pendingCount_ = 1; pendingLog_ = logHz; }
                        accept = pendingCount_ >= 2;
                        if (accept) { trackedLog_ = logHz; pendingCount_ = 0; }
                    } else {
                        pendingCount_ = 0;
                        const double dt = std::clamp(endSeconds - previousTime_, .001, .1);
                        const double tau = distance > 12 ? .012 : .025;
                        trackedLog_ += (1 - std::exp(-dt / tau)) * (logHz - trackedLog_);
                    }
                }
                if (accept) {
                    result.validity = Validity::valid;
                    result.trackedHz = std::exp2(trackedLog_);
                    result.midi = static_cast<int>(std::round(69 + 12 * (trackedLog_ - std::log2(reference_))));
                    acceptedMidi_ = result.midi;
                    result.cents = 1200 * (trackedLog_ - std::log2(reference_)) - 100 * (result.midi - 69);
                }
            }
        }
    }
    result.frameQualified=qualifiedCandidate;
    if (!qualifiedCandidate) reset();
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
