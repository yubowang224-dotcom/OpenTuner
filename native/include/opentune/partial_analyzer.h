#pragma once
#include "analyzer.h"
namespace opentune {
enum class PartialReason : int {
    ready=0, warming=1, silent=2, clipped=3, few=4, mismatch=5,
    ambiguous=6, doublePeak=7, unstable=8, bandwidth=9, unidentifiable=10
};
struct ObservedPartial { int order=0; double hz=0, power=0, residual=0; };
struct PartialResult {
    uint64_t sequence=0;
    double time=0, idealHz=0, firstHz=0, b=0, residual=0, sensitivity=0;
    double explained=0, score=0, rmsDb=-120, clip=0, computeMs=0;
    int count=0, peaks=0, stable=0;
    PartialReason reason=PartialReason::warming;
    std::array<ObservedPartial,16> partials{};
};
// Explicit known-key association, not an imposed measured frequency. No Android.
PartialResult fitStiffString(const SpectralFeatures& peaks,double expectedFirstHz);
Analysis partialPitch(const PartialResult& result,double referenceHz);
// Append ABI4 fields to the same 48-scalar audio metadata header used by Android.
void appendPartialPayload(std::vector<double>& header,const PartialResult& result,int midi);
class PartialAnalyzer {
public:
    PartialAnalyzer(int sampleRate,double referenceHz,int midi,double associationHz=0);
    int windowSize()const{return n_;}
    int hopSize()const{return hop_;}
    void reset();
    PartialResult analyze(const float* pcm,int count,double endSeconds);
private:
    int rate_,n_,hop_,size_,midi_;
    double expected_,previousTime_=0;
    int stable_=0;
    PartialResult previous_;
    uint64_t sequence_=0;
    std::vector<double> x_,energy_,noise_;
    std::vector<std::complex<double>> spectrum_;
};
} // namespace opentune
