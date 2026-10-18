#include "opentune/waveform.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <stdexcept>
namespace opentune {
namespace {constexpr double pi=3.14159265358979323846;}
WaveformDisplay::WaveformDisplay(int rate):rate_(rate) {
    if(rate<8000||rate>192000)throw std::invalid_argument("waveform sample rate");
    const int window=static_cast<int>(std::round(rate*.020));
    decimation_=std::max(1,(window+kDisplaySamples-1)/kDisplaySamples);
    points_=std::min(kDisplaySamples,window/decimation_+1);
    half_=decimation_==1?0:16*decimation_;
    double sum=0;const double cutoff=.4/decimation_;
    for(int j=-half_;j<=half_;++j){
        const double sinc=j==0?2*cutoff:std::sin(2*pi*cutoff*j)/(pi*j);
        const double window=half_==0?1:.42+.5*std::cos(pi*j/half_)+.08*std::cos(2*pi*j/half_);
        coefficients_[j+half_]=sinc*window;sum+=sinc*window;
    }
    for(int j=0;j<=2*half_;++j)coefficients_[j]/=sum;
}
double WaveformDisplay::filtered(const float* pcm,int center) const {
    double sum=0;for(int j=-half_;j<=half_;++j)sum+=pcm[center+j]*coefficients_[j+half_];return sum;
}
DisplayWave WaveformDisplay::extract(const float* pcm,int n,double end,bool trigger) const {
    if(!pcm||n<points_*decimation_+2*half_||!std::isfinite(end)||end<static_cast<double>(n)/rate_)throw std::invalid_argument("waveform PCM boundary");
    const auto begin=std::chrono::steady_clock::now();
    for(int i=0;i<n;++i)if(!std::isfinite(pcm[i]))throw std::invalid_argument("nonfinite waveform PCM");
    DisplayWave r;r.count=points_;r.decimation=decimation_;r.stepSeconds=static_cast<double>(decimation_)/rate_;
    int start=n-1-half_-(points_-1)*decimation_;
    int triggerIndex=start;
    if(trigger){
        // Only actual filtered samples choose the trigger; pitch is never used
        // to synthesize a shape. Search up to 20ms back for the LAST rising DC
        // crossing. A noise frame can simply remain untriggered.
        double dc=0;for(int i=0;i<n;++i)dc+=pcm[i];dc/=n;
        const int first=std::max(half_,start-rate_/50);
        double previous=filtered(pcm,first)-dc;
        for(int i=first+decimation_;i<=start;i+=decimation_){
            const double value=filtered(pcm,i)-dc;
            if(previous<=0&&value>0){r.triggered=true;triggerIndex=i;}
            previous=value;
        }
        if(r.triggered)start=triggerIndex;
    }
    r.startSeconds=end+static_cast<double>(start-n)/rate_;
    for(int i=0;i<points_;++i)r.samples[i]=static_cast<float>(filtered(pcm,start+i*decimation_));
    r.computeMs=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();return r;
}
}
