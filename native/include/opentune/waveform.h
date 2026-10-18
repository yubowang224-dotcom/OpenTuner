#pragma once
#include <array>
#include <cstddef>
namespace opentune {
constexpr int kDisplaySamples=512;
struct DisplayWave {
    std::array<float,kDisplaySamples> samples{};
    int count=0,decimation=1;
    bool triggered=false;
    double stepSeconds=0,startSeconds=0,computeMs=0;
    double duration() const {return count>1?(count-1)*stepSeconds:0;}
};
// Display-only centered FIR, run on the worker's existing PCM window. Never
// changes samples supplied to Analyzer/Tracker, never runs in the callback.
class WaveformDisplay {
public:
    explicit WaveformDisplay(int sampleRate);
    DisplayWave extract(const float* pcm,int count,double endSeconds,bool trigger) const;
private:
    double filtered(const float* pcm,int center) const;
    int rate_,decimation_,points_,half_;
    std::array<double,257> coefficients_{};
};
}
