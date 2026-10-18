#include "opentune/partial_analyzer.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <numeric>
#include <stdexcept>

namespace opentune {
namespace {
constexpr double pi=3.14159265358979323846;
int power2(int n){int p=1;while(p<n)p*=2;return p;}
int checkedRate(int rate){if(rate<16000||rate>96000)throw std::invalid_argument("partial_sample_rate");return rate;}
double predicted(double ideal,double b,int n){return n*ideal*std::sqrt(1+b*n*n);}

PartialResult regress(PartialResult result) {
    double sw=0,sx=0,sy=0,sxx=0,sxy=0;
    for(int i=0;i<result.count;i++){
        const auto& p=result.partials[i];const double x=p.order*p.order,y=std::pow(p.hz/p.order,2);
        const double w=std::clamp(std::sqrt(p.power),.1,1.);
        sw+=w;sx+=w*x;sy+=w*y;sxx+=w*x*x;sxy+=w*x*y;
    }
    const double den=sw*sxx-sx*sx;
    if(result.count<4||den<=0){result.reason=PartialReason::few;return result;}
    const double slope=(sw*sxy-sx*sy)/den,a=(sy-slope*sx)/sw;
    if(a<=0||slope/a<-.000002||slope/a>.01){result.reason=PartialReason::mismatch;return result;}
    result.idealHz=std::sqrt(a);result.b=std::max(0.,slope/a);
    if(slope<0){
        double logHz=0;for(int i=0;i<result.count;i++)logHz+=std::log(result.partials[i].hz/result.partials[i].order);
        result.idealHz=std::exp(logHz/result.count);
    }
    result.firstHz=result.idealHz*std::sqrt(1+result.b);
    double sum=0,meanDerivative=0,derivativeVariance=0;
    for(int i=0;i<result.count;i++){
        auto& p=result.partials[i];p.residual=centsBetween(p.hz,predicted(result.idealHz,result.b,p.order));
        sum+=p.residual*p.residual;
        meanDerivative+=(600/std::log(2.))*p.order*p.order/(1+result.b*p.order*p.order);
    }
    result.residual=std::sqrt(sum/result.count);meanDerivative/=result.count;
    for(int i=0;i<result.count;i++){
        const double n=result.partials[i].order;
        const double d=(600/std::log(2.))*n*n/(1+result.b*n*n)-meanDerivative;
        derivativeVariance+=d*d;
    }
    // Sensitivity proxy using a 0.2-cent floor, NOT a calibrated confidence interval.
    result.sensitivity=std::max(.2,result.residual)/std::sqrt(std::max(1.,derivativeVariance));
    result.reason=PartialReason::ready;return result;
}
PartialResult associate(const SpectralFeatures& peaks,double ideal,double b,double tolerance) {
    PartialResult r;double maximum=0;for(int i=0;i<peaks.count;i++)maximum=std::max(maximum,peaks.peaks[i].power);
    std::array<bool,64> used{};
    for(int n=1;n<=16;n++){
        const double hz=predicted(ideal,b,n);int best=-1;double distance=tolerance;
        for(int i=0;i<peaks.count;i++){
            if(used[i])continue;
            const double d=std::abs(centsBetween(peaks.peaks[i].hz,hz));
            if(d<distance){distance=d;best=i;}
        }
        if(best>=0){used[best]=true;r.partials[r.count++]={n,peaks.peaks[best].hz,peaks.peaks[best].power/maximum,0};}
    }
    return r;
}
}

PartialResult fitStiffString(const SpectralFeatures& peaks,double expected) {
    if(!std::isfinite(expected)||expected<20||expected>5000||peaks.count<0||peaks.count>64)
        throw std::invalid_argument("partial input");
    PartialResult best;best.peaks=peaks.count;best.reason=PartialReason::few;
    if(peaks.count<4)return best;
    double bestRank=-1;bool plausible=false,ambiguous=false;
    for(int seed=0;seed<=80;seed++){
        const double b=seed==0?0:std::pow(10.,-6.+4.*(seed-1)/79.);
        auto r=associate(peaks,expected/std::sqrt(1+b),b,60);
        if(r.count<4)continue;
        r=regress(r);if(r.reason!=PartialReason::ready)continue;plausible=true;
        // Reassociate using the measured regression, not the selected target.
        r=regress(associate(peaks,r.idealHz,r.b,5));
        if(r.reason!=PartialReason::ready||std::abs(centsBetween(r.firstHz,expected))>60||r.residual>1.5)continue;
        int gcd=0;double explained=0,total=0;bool largeResidual=false;
        for(int i=0;i<r.count;i++){gcd=std::gcd(gcd,r.partials[i].order);largeResidual|=std::abs(r.partials[i].residual)>3;}
        if(gcd!=1||largeResidual)continue;
        for(int i=0;i<peaks.count;i++){
            total+=peaks.peaks[i].power;
            bool assigned=false;
            for(int j=0;j<r.count;j++)if(std::abs(centsBetween(peaks.peaks[i].hz,r.partials[j].hz))<.01)assigned=true;
            if(assigned)explained+=peaks.peaks[i].power;
        }
        r.explained=total>0?explained/total:0;
        if(r.explained<.8)continue;
        const double rank=r.count+2*r.explained-.2*r.residual;
        if(bestRank>=0&&rank>=bestRank-.15&&std::abs(centsBetween(r.firstHz,best.firstHz))>2&&std::abs(r.b-best.b)>std::max(.000005,best.b*.4))ambiguous=true;
        if(rank>bestRank){best=r;bestRank=rank;}
    }
    best.peaks=peaks.count;
    if(bestRank<0){best.reason=plausible?PartialReason::ambiguous:PartialReason::mismatch;return best;}
    if(ambiguous){best.reason=PartialReason::ambiguous;return best;}
    if(best.sensitivity>std::max(.000002,best.b*.4)){best.reason=PartialReason::unidentifiable;return best;}
    // A second strong resolved peak around any model partial is not a single string.
    double maximum=0;for(int i=0;i<peaks.count;i++)maximum=std::max(maximum,peaks.peaks[i].power);
    for(int j=0;j<best.count;j++){
        int close=0;
        for(int i=0;i<peaks.count;i++)if(peaks.peaks[i].power>maximum*.01&&std::abs(centsBetween(peaks.peaks[i].hz,best.partials[j].hz))<35)++close;
        if(close>1){best.reason=PartialReason::doublePeak;return best;}
    }
    best.score=std::clamp(best.explained*std::exp(-best.residual/2),0.,1.);
    best.reason=PartialReason::ready;return best;
}

PartialAnalyzer::PartialAnalyzer(int rate,double reference,int midi,double association):rate_(checkedRate(rate)),
    n_(static_cast<int>(std::round(rate*.75))),hop_(static_cast<int>(std::round(rate*.1))),size_(power2(n_*4)),midi_(midi),
    expected_(reference*std::pow(2.,(midi-69)/12.)),x_(n_),energy_(n_+1),noise_(size_/2),spectrum_(size_) {
    if(!std::isfinite(reference)||reference<400||reference>480||midi<21||midi>108)throw std::invalid_argument("partial target");
    if(!std::isfinite(association)||association<0||association>0&&(association<20||association>5000||std::abs(centsBetween(association,expected_))>150.001))throw std::invalid_argument("partial association");
    if(association>0)expected_=association;
}
Analysis partialPitch(const PartialResult& p,double reference) {
    Analysis r;r.timeSeconds=p.time;r.rawHz=p.firstHz;r.score=p.score;r.rmsDb=p.rmsDb;r.clipFraction=p.clip;r.computeMs=p.computeMs;
    r.validity=p.reason==PartialReason::ready?Validity::valid:p.reason==PartialReason::silent?Validity::silent:p.reason==PartialReason::clipped?Validity::clipped:Validity::uncertain;
    r.frameQualified=p.reason==PartialReason::ready;r.consistency=std::min(1.,p.stable/4.);
    r.trackState=r.frameQualified?TrackState::tracking:TrackState::candidate;
    if(r.frameQualified){
        r.trackedHz=p.firstHz;for(int i=0;i<p.count;i++)if(p.partials[i].order==1)r.trackedHz=p.partials[i].hz;
        const double pitch=1200*std::log2(r.trackedHz/reference);r.midi=static_cast<int>(std::round(69+pitch/100));r.cents=pitch-100*(r.midi-69);
    }
    return r;
}
void appendPartialPayload(std::vector<double>& values,const PartialResult& p,int midi){
    if(values.size()!=48||p.count<0||p.count>16||midi<21||midi>108)throw std::invalid_argument("partial wire boundary");
    values.resize(64+p.count*4,0);values[0]=4;
    values[48]=static_cast<int>(p.reason);values[49]=p.idealHz;values[50]=p.firstHz;values[51]=p.b;
    values[52]=p.residual;values[53]=p.sensitivity;values[54]=p.explained;values[55]=p.stable;
    values[56]=p.peaks;values[57]=p.count;values[58]=.75;values[59]=midi;values[61]=1;
    for(int i=0;i<p.count;i++){
        const auto& q=p.partials[i];values[64+4*i]=q.order;values[65+4*i]=q.hz;values[66+4*i]=q.power;values[67+4*i]=q.residual;
        if(q.order==1)values[60]=q.hz;
    }
}
void PartialAnalyzer::reset(){stable_=0;previous_={};previousTime_=0;}
PartialResult PartialAnalyzer::analyze(const float* pcm,int count,double end) {
    if(!pcm||count!=n_||!std::isfinite(end)||end<0)throw std::invalid_argument("partial frame");
    const auto begin=std::chrono::steady_clock::now();
    auto features=preprocess(pcm,n_,x_,energy_);PartialResult r;
    r.reason=features.rmsDb< -105?PartialReason::silent:features.clipFraction>.02?PartialReason::clipped:PartialReason::few;
    if(r.reason==PartialReason::few){
        std::fill(spectrum_.begin(),spectrum_.end(),0);
        for(int i=0;i<n_;i++)spectrum_[i]=x_[i]*(.5-.5*std::cos(2*pi*i/(n_-1)));
        fft(spectrum_,false);
        const int limit=std::min(static_cast<int>(18000.*size_/rate_),static_cast<int>(size_*.42));
        double maximum=0;
        for(int k=1;k<limit;k++){noise_[k]=std::abs(spectrum_[k]);maximum=std::max(maximum,noise_[k]);}
        std::nth_element(noise_.begin()+1,noise_.begin()+limit/2,noise_.begin()+limit);
        const double threshold=std::max(maximum*.025,noise_[limit/2]*4);
        SpectralFeatures peaks;
        for(int k=2;k<limit;k++){
            const double amplitude=std::abs(spectrum_[k]);
            if(amplitude<threshold||amplitude<=std::abs(spectrum_[k-1])||amplitude<std::abs(spectrum_[k+1]))continue;
            const double a=std::log(std::max(std::abs(spectrum_[k-1]),1e-15)),b=std::log(amplitude),c=std::log(std::max(std::abs(spectrum_[k+1]),1e-15)),den=a-2*b+c;
            const double offset=std::abs(den)>1e-12?std::clamp(.5*(a-c)/den,-.5,.5):0;
            SpectralFeatures::Peak p{(k+offset)*rate_/size_,amplitude*amplitude};
            if(p.hz<20)continue;
            if(peaks.count<64)peaks.peaks[peaks.count++]=p;
            else{auto weak=std::min_element(peaks.peaks.begin(),peaks.peaks.end(),[](auto a,auto b){return a.power<b.power;});if(p.power>weak->power)*weak=p;}
        }
        r=fitStiffString(peaks,expected_);
        if(r.reason==PartialReason::few&&expected_*4>std::min(18000.,rate_*.42))r.reason=PartialReason::bandwidth;
    }
    if(r.reason==PartialReason::ready){
        const bool continuous=previousTime_>0&&end-previousTime_>.05&&end-previousTime_<.2;
        const bool consistent=previous_.firstHz>0&&std::abs(centsBetween(r.firstHz,previous_.firstHz))<=2&&std::abs(r.b-previous_.b)<=std::max(.000002,std::max(r.b,previous_.b)*.2);
        stable_=continuous&&consistent?stable_+1:1;r.stable=stable_;
        previous_=r;
        if(stable_<4)r.reason=stable_==1?PartialReason::unstable:PartialReason::warming;
    }else{stable_=0;previous_={};}
    previousTime_=end;r.sequence=++sequence_;r.time=end;r.rmsDb=features.rmsDb;r.clip=features.clipFraction;
    r.computeMs=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();return r;
}
} // namespace opentune
