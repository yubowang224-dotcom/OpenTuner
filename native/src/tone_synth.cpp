#include "opentune/tone_synth.h"
#include <algorithm>
#include <cmath>
#include <stdexcept>
namespace opentune {
namespace { constexpr double pi = 3.14159265358979323846; }
ToneSynth::ToneSynth(int rate, double hz, ToneVoice voice, double level) : rate_(rate), attack_(std::max(1, rate/100)),
    releaseLength_(std::max(1, rate*3/100)), step_(2*pi*hz/rate), voice_(voice), level_(level) {
    if (rate < 8000 || rate > 192000 || !std::isfinite(hz) || hz <= 0 || hz >= rate*.45 || !std::isfinite(level) || level<0 || level>1 || (voice!=ToneVoice::sine&&voice!=ToneVoice::guitar))
        throw std::invalid_argument("unsupported tone");
    if(voice_==ToneVoice::guitar){
        constexpr double weights[]={.8,.55,.32,.20,.12,.08,.05,.03};
        double sum=0;
        for(int i=0;i<8&&hz*(i+1)<rate*.45;i++){partials_[i]=weights[i];sum+=weights[i];decay_[i]=std::exp(-(.35+.17*(i+1))/rate);++partialCount_;}
        for(int i=0;i<partialCount_;i++)partials_[i]/=sum;
    }
}
void ToneSynth::release() {
    if (releaseAt_ >= 0) return;
    releaseAt_ = 0;
    releaseGain_ = std::min(1.0, static_cast<double>(frame_)/attack_);
}
void ToneSynth::render(float* output, int count) {
    for (int i=0; i<count; ++i) {
        if (frame_ >= static_cast<int64_t>(rate_)*3) release();
        double gain = std::min(1.0, static_cast<double>(frame_)/attack_);
        if (releaseAt_ >= 0) {
            gain = releaseGain_*.5*(1+std::cos(pi*std::min(releaseAt_,releaseLength_)/releaseLength_));
            if (++releaseAt_ > releaseLength_) finished_ = true;
        }
        double wave=std::sin(phase_)*.15;
        if(voice_==ToneVoice::guitar){
            wave=0;for(int h=0;h<partialCount_;++h){wave+=partials_[h]*std::sin((h+1)*phase_);partials_[h]*=decay_[h];}
            wave*=.65;
        }
        output[i] = finished_ ? 0 : static_cast<float>(level_*gain*wave);
        phase_ += step_; if (phase_ >= 2*pi) phase_ -= 2*pi; ++frame_;
    }
}
}
