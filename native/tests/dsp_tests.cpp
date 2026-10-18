#include "opentune/analyzer.h"
#include "opentune/c_api.h"
#include "opentune/spsc_ring.h"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <random>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#include <limits>
#include <chrono>
#include <ctime>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#else
#include <sys/resource.h>
#endif
using namespace opentune;
constexpr double pi = 3.14159265358979323846;
void require(bool condition, const char* message) { if (!condition) throw std::runtime_error(message); }
double percentile(std::vector<double> v, double q) {
    if (v.empty()) return -1;
    std::sort(v.begin(), v.end()); return v[static_cast<size_t>(std::round(q * (v.size() - 1)))];
}
struct Case { std::string group, name; int rate; double hz, amp; std::vector<double> harmonics; double snr = 999, dc = 0; bool clip = false; };
struct Stats {
    int frames = 0, valid = 0, octave = 0, highScore = 0;
    double first = -1;
    std::vector<double> errors, rawErrors, signedErrors, times;
};
std::vector<float> signal(const Case& c, double seconds) {
    std::vector<float> out(static_cast<size_t>(c.rate * seconds));
    std::mt19937 rng(20261018); std::normal_distribution<double> noise;
    const double noiseAmp = c.amp / std::sqrt(2.0) * std::pow(10, -c.snr / 20);
    double phase = 0;
    for (size_t i = 0; i < out.size(); ++i) {
        const double t = static_cast<double>(i) / c.rate;
        double hz = c.hz, amplitude = c.amp;
        if (c.name == "step") hz = t < .6 ? 220 : 440;
        if (c.name == "glide") hz = 220 + 110 * t / seconds;
        if (c.name == "silence_return" && t >= .6 && t < 1) amplitude = 0;
        if (c.name == "decay") amplitude *= std::exp(-6 * t);
        phase += 2 * pi * hz / c.rate;
        double x = 0;
        for (size_t h = 0; h < c.harmonics.size(); ++h) x += amplitude * c.harmonics[h] * std::sin((h + 1) * phase);
        if (c.name == "noise") x = .2 * noise(rng);
        else if (c.snr != 999) x += noiseAmp * noise(rng);
        if (c.name == "impulses") x = i % (c.rate / 7) == 0 ? .8 : 0;
        if (c.name == "dual") x = .3 * std::sin(phase) + .3 * std::sin(2 * pi * 337.13 * t);
        x += c.dc;
        if (c.clip) x = std::clamp(x * 8, -1.0, 1.0);
        out[i] = static_cast<float>(x);
    }
    return out;
}
void boundaryTests() {
    require(ot_abi_version() == 1, "C ABI version");
    require(!ot_create(0, 440) && !ot_create(48000, 0), "invalid constructor");
    auto* handle = ot_create(48000, 442); require(handle != nullptr, "C ABI create");
    ot_result out{}; out.size = sizeof(out);
    std::vector<float> tone(ot_window_size(handle));
    for (size_t i = 0; i < tone.size(); ++i) tone[i] = static_cast<float>(.3 * std::sin(2 * pi * 442 * i / 48000));
    require(ot_analyze(nullptr, tone.data(), static_cast<int>(tone.size()), .08, &out) == OT_INVALID, "null handle");
    require(ot_analyze(handle, nullptr, static_cast<int>(tone.size()), .08, &out) == OT_INVALID, "null PCM");
    require(ot_analyze(handle, tone.data(), 1, .08, &out) == OT_INVALID, "short buffer");
    out.size = 1; require(ot_analyze(handle, tone.data(), static_cast<int>(tone.size()), .08, &out) == OT_INVALID, "ABI size");
    out.size = sizeof(out);
    for (int i = 0; i < 3; ++i) require(ot_analyze(handle, tone.data(), static_cast<int>(tone.size()), .08 + i * .02, &out) == OT_OK, "C ABI analysis");
    require(out.validity == 2 && out.midi == 69 && std::abs(out.cents) < 2, "reference 442 mapping");
    tone[0] = std::numeric_limits<float>::quiet_NaN();
    require(ot_analyze(handle, tone.data(), static_cast<int>(tone.size()), .2, &out) == OT_INVALID, "NaN rejected");
    require(out.validity == 0 && out.tracked_hz == 0, "invalid ABI result clears old pitch");
    ot_destroy(handle); ot_destroy(nullptr);
    bool rejected = false; try { centsBetween(0, 440); } catch (...) { rejected = true; }
    require(rejected, "zero logarithm guard");
    // FFT independent round-trip and spectral units, DC rejection.
    std::vector<std::complex<double>> fftInput(8), expected(8);
    for (int i=0;i<8;++i) fftInput[i]=i*.1;
    for (int k=0;k<8;++k) for (int i=0;i<8;++i) expected[k]+=fftInput[i]*std::polar(1.0,-2*pi*k*i/8);
    fft(fftInput,false);
    for (int i=0;i<8;++i) require(std::abs(fftInput[i]-expected[i])<1e-10,"FFT vs independent DFT");
    fft(fftInput,true);
    for (int i=0;i<8;++i) require(std::abs(fftInput[i]-std::complex<double>(i*.1,0))<1e-10,"FFT round trip");
    Analyzer a(48000); auto clean = signal({"test", "sine", 48000, 375, .5, {1}}, .08);
    const auto r = a.analyze(clean.data(), a.windowSize(), .08, true);
    const auto peak = std::max_element(r.spectrum.begin(), r.spectrum.begin() + r.spectrumCount);
    const int bin = static_cast<int>(peak - r.spectrum.begin());
    require(std::abs(bin * r.spectrumBinHz - 375) <= r.spectrumBinHz, "spectrum Hz grid");
    require(std::abs(*peak - 20 * std::log10(.5)) < 1.5, "Hann peak dBFS scale");
    require(std::abs(r.waveDuration - .08) < 1e-9, "wave time units");
    for (double outside : {27.5,4000.}) {
        Analyzer limited(48000); const auto source=signal({"test","outside",48000,outside,.3,{1}},.12);
        for (int end=limited.windowSize();end<=static_cast<int>(source.size());end+=limited.hopSize())
            require(limited.analyze(source.data()+end-limited.windowSize(),limited.windowSize(),end/48000.,false).validity!=Validity::valid,"out-of-range pure tone aliases into supported octave");
    }
}
void ringTests() {
    SpscRing<8> tiny; float input[12]; std::iota(input, input + 12, 0.f); float output[12]{};
    require(tiny.push(input, 12) == 8 && tiny.size() == 8, "bounded overflow");
    require(tiny.pop(output, 3) == 3 && output[2] == 2, "ordered copy");
    require(tiny.push(input + 8, 4) == 3, "producer cannot overwrite read slots");
    require(tiny.pop(output, 12) == 8 && output[0] == 3 && output[7] == 10, "ring wrap");
    require(tiny.push(input, 8) == 8 && tiny.discard() == 8 && tiny.size() == 0, "consumer discard");
    SpscRing<1024> ring; std::atomic<bool> failure{false};
    std::thread producer([&] { for (int i = 0; i < 100000; ) { float v = static_cast<float>(i); if (ring.push(&v, 1)) ++i; } });
    for (int i = 0; i < 100000;) { float v; if (ring.pop(&v, 1)) { if (v != i) failure = true; ++i; } }
    producer.join(); require(!failure, "SPSC concurrent ownership/order");
    for (int restart = 0; restart < 50; ++restart) { Analyzer a(44100); a.reset(); require(a.windowSize() == 3528, "repeat resources"); }
}
int main(int argc, char** argv) {
    try {
        const auto wallStart=std::chrono::steady_clock::now();
        boundaryTests(); ringTests();
        const std::filesystem::path directory = argc > 1 ? argv[1] : "results";
        std::filesystem::create_directories(directory);
        std::ofstream frames(directory / "frames.csv"), summary(directory / "cases.csv"), dynamics(directory / "dynamic.csv");
        frames << std::setprecision(17); summary << std::setprecision(17); dynamics << std::setprecision(17);
        frames << "group,case,sample_rate,amplitude,truth_hz,end_seconds,validity,raw_hz,tracked_hz,cents,score,rms_db,clip_fraction,compute_ms\n";
        summary << "group,case,sample_rate,hz,amplitude,frames,valid,coverage,median_abs_cents,p95_abs_cents,p95_raw_abs_cents,octave_errors,high_score_valid,jitter_sd_cents,first_ms,p50_compute_ms,p95_compute_ms\n";
        dynamics << "case,sample_rate,first_ms,switch_ms,invalidation_ms,return_ms\n";
        std::vector<Case> cases;
        for (int rate : {44100, 48000}) {
            for (double hz : {50.,55.,65.406,82.407,110.,146.832,220.,337.13,440.,659.255,880.,997.31,1000.,1567.98,1990.,2000.})
                for (double amp : {.03,.3,.8}) cases.push_back({"primary", "sine", rate, hz, amp, {1}});
            for (double hz : {82.407,220.,440.}) {
                cases.push_back({"harmonic", "weak_fundamental", rate, hz, .8, {.05,.6,.3}});
                cases.push_back({"harmonic", "missing_fundamental", rate, hz, .7, {0,.6,.3,.2}});
            }
            cases.push_back({"invalid", "silence", rate, 0, 0, {}});
            cases.push_back({"invalid", "dc", rate, 0, 0, {}, 999, .4});
            cases.push_back({"invalid", "noise", rate, 0, 0, {}});
            cases.push_back({"invalid", "impulses", rate, 0, 0, {}});
            cases.push_back({"ambiguous", "dual", rate, 220, .3, {1}});
            cases.push_back({"interference", "dc_sine", rate, 440, .3, {1}, 999, .35});
            cases.push_back({"interference", "clipped", rate, 440, .3, {1}, 999, 0, true});
            for (double snr : {40.,20.,10.,0.}) cases.push_back({"noise", "snr" + std::to_string(static_cast<int>(snr)), rate, 440, .3, {1}, snr});
            for (auto name : {"step","glide","decay","silence_return"}) cases.push_back({"dynamic", name, rate, 220, .3, {1}});
        }
        Stats primary, core;
        for (const auto& c : cases) {
            Analyzer analyzer(c.rate); const auto samples = signal(c, 1.5); Stats s;
            double switchMs = -1, invalidMs = -1, returnMs = -1; int consistent = 0; double firstNew = -1;
            for (int end = analyzer.windowSize(); end <= static_cast<int>(samples.size()); end += analyzer.hopSize()) {
                const double time = static_cast<double>(end) / c.rate;
                const auto r = analyzer.analyze(samples.data() + end - analyzer.windowSize(), analyzer.windowSize(), time, true);
                double truth = c.group == "ambiguous" ? 0 : c.hz;
                if (c.name == "step") truth = time < .6 ? 220 : 440;
                if (c.name == "glide") truth = 220 + 110 * time / 1.5;
                if (c.name == "silence_return" && time >= .6 && time < 1) truth = 0;
                const bool valid = r.validity == Validity::valid;
                frames << c.group << ',' << c.name << ',' << c.rate << ',' << c.amp << ',' << truth << ',' << time << ',' << static_cast<int>(r.validity) << ',' << r.rawHz << ',' << r.trackedHz << ',' << r.cents << ',' << r.score << ',' << r.rmsDb << ',' << r.clipFraction << ',' << r.computeMs << '\n';
                if (valid && s.first < 0) s.first = time * 1000;
                if (c.name == "step" && time >= .6) {
                    if (valid && std::abs(centsBetween(r.trackedHz, 440)) < 10) { if (!consistent) firstNew = time; ++consistent; if (consistent == 3) switchMs = (firstNew - .6) * 1000; }
                    else consistent = 0;
                }
                if (c.name == "silence_return" && time >= .6 && !valid && invalidMs < 0) invalidMs = (time - .6) * 1000;
                if (c.name == "silence_return" && time >= 1 && valid && returnMs < 0) returnMs = (time - 1) * 1000;
                if (time < .3) continue;
                ++s.frames; s.times.push_back(r.computeMs);
                if (valid) {
                    ++s.valid; if (r.score >= .9) ++s.highScore;
                    if (truth > 0) {
                        const double err = centsBetween(r.trackedHz, truth);
                        s.errors.push_back(std::abs(err)); s.signedErrors.push_back(err);
                        s.rawErrors.push_back(std::abs(centsBetween(r.rawHz, truth)));
                        if (std::abs(std::abs(err) - 1200) < 100) ++s.octave;
                    }
                }
            }
            double sd = -1;
            if (!s.signedErrors.empty()) {
                double mean = std::accumulate(s.signedErrors.begin(), s.signedErrors.end(), 0.0) / s.signedErrors.size();
                double variance = 0; for (double e : s.signedErrors) variance += (e - mean) * (e - mean);
                sd = std::sqrt(variance / s.signedErrors.size());
            }
            summary << c.group << ',' << c.name << ',' << c.rate << ',' << c.hz << ',' << c.amp << ',' << s.frames << ',' << s.valid << ',' << static_cast<double>(s.valid)/s.frames << ',' << percentile(s.errors,.5) << ',' << percentile(s.errors,.95) << ',' << percentile(s.rawErrors,.95) << ',' << s.octave << ',' << s.highScore << ',' << sd << ',' << s.first << ',' << percentile(s.times,.5) << ',' << percentile(s.times,.95) << '\n';
            if (c.group == "dynamic") dynamics << c.name << ',' << c.rate << ',' << s.first << ',' << switchMs << ',' << invalidMs << ',' << returnMs << '\n';
            if (c.group == "primary") {
                primary.frames += s.frames; primary.valid += s.valid;
                primary.errors.insert(primary.errors.end(), s.errors.begin(), s.errors.end());
                if (c.hz >= 65 && c.hz <= 1000) { core.errors.insert(core.errors.end(), s.errors.begin(), s.errors.end()); core.frames += s.frames; core.valid += s.valid; }
            }
            if (c.group == "invalid") require(s.valid == 0, "invalid input false pitch");
            if (c.group == "ambiguous") require(s.valid == 0, "non-harmonic dual tone false lock");
            if (c.group == "harmonic") require(s.valid >= .95*s.frames && percentile(s.errors,.95)<=5, "harmonic regression");
        }
        std::cout << std::setprecision(8) << "Primary frames=" << primary.frames << " valid=" << primary.valid
            << " median=" << percentile(primary.errors,.5) << " P95=" << percentile(primary.errors,.95)
            << " cents; core P95=" << percentile(core.errors,.95) << "\n";
        require(primary.valid >= .99 * primary.frames, "primary coverage < 99%");
        require(percentile(primary.errors,.5) <= 2 && percentile(primary.errors,.95) <= 5, "primary cents target failed");
        uint64_t peakBytes=0;
        double cpuSeconds=-1;
#ifdef _WIN32
        PROCESS_MEMORY_COUNTERS memory{};
        if (GetProcessMemoryInfo(GetCurrentProcess(),&memory,sizeof(memory))) peakBytes=memory.PeakWorkingSetSize;
        FILETIME creation{},exit{},kernel{},user{};
        if (GetProcessTimes(GetCurrentProcess(),&creation,&exit,&kernel,&user)) {
            ULARGE_INTEGER k{},u{}; k.LowPart=kernel.dwLowDateTime; k.HighPart=kernel.dwHighDateTime;
            u.LowPart=user.dwLowDateTime; u.HighPart=user.dwHighDateTime;
            cpuSeconds=(k.QuadPart+u.QuadPart)/1e7;
        }
#else
        rusage usage{};
        if (getrusage(RUSAGE_SELF,&usage)==0) {
            peakBytes=static_cast<uint64_t>(usage.ru_maxrss)*1024;
            cpuSeconds=usage.ru_utime.tv_sec+usage.ru_stime.tv_sec+(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1e6;
        }
#endif
        std::ofstream profile(directory / "host_process.json");
        profile << "{\"peak_resident_bytes\":" << peakBytes << ",\"process_cpu_seconds\":" << cpuSeconds
            << ",\"wall_seconds\":" << std::chrono::duration<double>(std::chrono::steady_clock::now()-wallStart).count() << "}\n";
        std::cout << "Production DSP, ABI, FFT units, ring overflow/concurrency and repeat resources passed\n";
        return 0;
    } catch (const std::exception& e) { std::cerr << "FAIL: " << e.what() << '\n'; return 1; }
}
