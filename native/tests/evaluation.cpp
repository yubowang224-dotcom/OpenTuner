#include "opentune/analyzer.h"
#include "opentune/tone_synth.h"
#include "baseline_stage2/analyzer.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <random>
#include <string>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#include <psapi.h>
#else
#include <sys/resource.h>
#endif
namespace {
constexpr double pi=3.14159265358979323846;
struct Case { std::string name; double hz,amp; std::vector<double> partials; double snr=999; };
void require(bool value,const char* message) { if(!value) throw std::runtime_error(message); }
double cpuTime() {
#ifdef _WIN32
 FILETIME c{},e{},k{},u{}; GetProcessTimes(GetCurrentProcess(),&c,&e,&k,&u);
 ULARGE_INTEGER a{},b{}; a.LowPart=k.dwLowDateTime;a.HighPart=k.dwHighDateTime;b.LowPart=u.dwLowDateTime;b.HighPart=u.dwHighDateTime;return (a.QuadPart+b.QuadPart)/1e7;
#else
 rusage u{};getrusage(RUSAGE_SELF,&u);return u.ru_utime.tv_sec+u.ru_stime.tv_sec+(u.ru_utime.tv_usec+u.ru_stime.tv_usec)/1e6;
#endif
}
void trackerTests() {
 opentune::PitchTracker t;
 require(!t.update(440,true,1,.08).valid,"startup confirmation");
 require(t.update(440,true,1,.10).valid,"startup lock");
 require(!t.update(880,true,1,.12).valid,"single octave outlier invalid");
 require(t.update(440,true,1,.14).valid,"outlier does not reset lock");
 require(!t.update(0,false,0,.16).valid,"invalid cannot hold valid pitch");
 require(t.update(440,true,1,.18).valid,"short dropout keeps internal track");
 auto lost=t.update(0,false,0,.40); require(lost.state==opentune::TrackState::lost,"200ms loss reset");
 require(!t.update(440,true,1,.42).valid,"return reconfirms");
 require(t.update(440,true,1,.44).valid,"return lock");
 require(!t.update(440,true,1,.8).valid,"discontinuous clock reconfirms");
}
void toneTests() {
 for(int rate:{44100,48000}) for(double hz:{82.406889,220.,440.,880.,523.25113}) {
   opentune::ToneSynth tone(rate,hz); std::vector<float> pcm(rate*4);tone.render(pcm.data(),static_cast<int>(pcm.size()));
   require(tone.finished(),"tone automatic release"); require(pcm.front()==0&&pcm.back()==0,"tone endpoints");
   int crosses=0,first=-1,last=-1;
   for(int i=rate/10;i<rate*2;++i) {
    require(std::abs(pcm[i])<=.150001,"tone amplitude");
    if(pcm[i-1]<0&&pcm[i]>=0) {if(first<0) first=i;last=i;++crosses;}
   }
   const double measured=(crosses-1)*static_cast<double>(rate)/(last-first);
   require(std::abs(1200*std::log2(measured/hz))<1,"independent crossing tone frequency");
   for(int i=1;i<static_cast<int>(pcm.size());++i) require(std::abs(pcm[i]-pcm[i-1])<.03,"tone continuity");
   opentune::ToneSynth early(rate,hz);early.render(pcm.data(),100);early.release();early.render(pcm.data(),rate/10);
   require(early.finished()&&pcm[rate/10-1]==0,"early release");
 }
}
}
int main(int argc,char**argv) {
 try {
 trackerTests();toneTests();
 const std::filesystem::path dir=argc>1?argv[1]:"evaluation";std::filesystem::create_directories(dir);
 std::ofstream out(dir/"frames.csv");out<<std::setprecision(14);
 out<<"case,rate,amplitude,base_hz,time,truth_hz,method,valid,hz,raw_hz,quality,compute_ms,production_cmndf,production_harmonic,production_centroid,production_noise_known,production_noise_floor,production_tracker_state\n";
 std::vector<Case> cases;
 for(double hz:{55.,82.407,220.,337.13,440.,997.31,1990.})for(double amp:{.03,.3})cases.push_back({"sine",hz,amp,{1}});
 for(double amp:{.0002,.001})cases.push_back({"weak",220,amp,{1}});
 for(double hz:{82.407,220.,440.}) {cases.push_back({"harmonic",hz,.8,{.05,.6,.3}});cases.push_back({"missing",hz,.7,{0,.6,.3,.2}});}
 for(double snr:{40.,20.,10.,0.})cases.push_back({"snr"+std::to_string(static_cast<int>(snr)),440,.3,{1},snr});
 for(auto name:{"silence","noise","impulses","dual","step","glide","vibrato","phase_noise","interference","silence_return","decay","dc","clipped"})cases.push_back({name,440,.3,{1}});
 double cpuA=0,cpuB=0,cpuC=0,wallA=0,wallB=0,wallC=0,trackerCpu=0;uint64_t frameCount=0;
 for(int rate:{44100,48000})for(const auto&c:cases) {
  std::mt19937 rng(20261025);std::normal_distribution<double> noise(0,1);
  std::vector<float> pcm(rate*3);double phase=0,phaseWander=0;
  for(int i=0;i<rate*3;++i) {
   const double time=static_cast<double>(i)/rate;
   double hz=c.hz;
   if(c.name=="step"||c.name=="silence_return")hz=time<1?220:440;
   if(c.name=="silence_return")hz=220;
   if(c.name=="glide")hz=220+110*time/3;
   if(c.name=="vibrato")hz=440*std::exp2(15*std::sin(2*pi*5*time)/1200);
   phase+=2*pi*hz/rate;
   // Band-limited random phase perturbation: carrier truth remains 440 Hz;
   // this is a stability stress stimulus, not instantaneous-pitch accuracy data.
   if(c.name=="phase_noise" && i%(rate/50)==0)phaseWander=.015*noise(rng);
   double value=0;for(size_t k=0;k<c.partials.size();++k)value+=c.amp*c.partials[k]*std::sin((k+1)*phase+phaseWander);
   if(c.snr<900)value+=c.amp/std::sqrt(2.)*std::pow(10.,-c.snr/20)*noise(rng);
   if(c.name=="silence")value=0;
   if(c.name=="noise")value=.1*noise(rng);
   if(c.name=="impulses")value=i%(rate/10)==0?.9:0;
   if(c.name=="dual")value=.3*(std::sin(2*pi*220*time)+std::sin(2*pi*337.13*time));
   if(c.name=="interference"&&time>=1&&time<1.06)value+=.5*noise(rng);
   if(c.name=="silence_return"&&time>=1&&time<1.6)value=0;
   if(c.name=="decay")value*=std::exp(-time*2);
   if(c.name=="dc")value+=.35;
   if(c.name=="clipped")value=std::clamp(value*8.,-1.,1.);
   pcm[i]=static_cast<float>(value);
  }
  stage2baseline::Analyzer old(rate);opentune::Analyzer production(rate);
  std::vector<stage2baseline::Analysis> a;std::vector<opentune::Analysis> p;
  auto before=std::chrono::steady_clock::now();double cpu=cpuTime();
  for(int end=old.windowSize();end<=static_cast<int>(pcm.size());end+=old.hopSize())a.push_back(old.analyze(pcm.data()+end-old.windowSize(),old.windowSize(),static_cast<double>(end)/rate,true));
  cpuA+=cpuTime()-cpu;wallA+=std::chrono::duration<double>(std::chrono::steady_clock::now()-before).count();
  before=std::chrono::steady_clock::now();cpu=cpuTime();
  for(int end=production.windowSize();end<=static_cast<int>(pcm.size());end+=production.hopSize())p.push_back(production.analyze(pcm.data()+end-production.windowSize(),production.windowSize(),static_cast<double>(end)/rate,true));
  cpuC+=cpuTime()-cpu;wallC+=std::chrono::duration<double>(std::chrono::steady_clock::now()-before).count();
  // Independent complete B pass: include the same frozen front-end work plus
  // fixed smoothing, rather than mistaking an EMA-only timing for pipeline CPU.
  stage2baseline::Analyzer fixedFrontend(rate);
  std::vector<double> fixedHz(a.size()), fixedMs(a.size());
  double fixed=0,last=0;bool locked=false;size_t fixedIndex=0;
  before=std::chrono::steady_clock::now();cpu=cpuTime();
  for(int end=fixedFrontend.windowSize();end<=static_cast<int>(pcm.size());end+=fixedFrontend.hopSize()) {
   const auto frameStart=std::chrono::steady_clock::now();
   const double time=static_cast<double>(end)/rate;
   const auto r=fixedFrontend.analyze(pcm.data()+end-fixedFrontend.windowSize(),fixedFrontend.windowSize(),time,true);
   require(r.frameQualified==a[fixedIndex].frameQualified,"identical fixed frontend qualification");
   if(r.frameQualified) {const double raw=std::log2(r.rawHz);if(!locked){fixed=raw;locked=true;}else fixed+=(1-std::exp(-(time-last)/.15))*(raw-fixed);}
   else locked=false;
   last=time;fixedHz[fixedIndex]=locked?std::exp2(fixed):0;
   fixedMs[fixedIndex++]=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-frameStart).count();
  }
  cpuB+=cpuTime()-cpu;wallB+=std::chrono::duration<double>(std::chrono::steady_clock::now()-before).count();
  opentune::PitchTracker shared;

  cpu=cpuTime();
  for(size_t i=0;i<a.size();++i) {
   const auto&r=a[i];const auto&n=p[i];double truth=c.hz;
   const double time=r.timeSeconds;
   if(c.name=="step")truth=time<1?220:440;
   if(c.name=="silence_return")truth=time>=1&&time<1.6?0:220;
   if(c.name=="glide")truth=220+110*time/3;
   if(c.name=="vibrato")truth=440*std::exp2(15*std::sin(2*pi*5*time)/1200);
   if(c.name=="silence"||c.name=="noise"||c.name=="impulses"||c.name=="dual")truth=0;
   auto sh=shared.update(r.rawHz,r.frameQualified,r.score,time);
   if (c.name=="snr10" && n.validity==opentune::Validity::valid)
       require(std::abs(1200*std::log2(n.trackedHz/440))<100,"noisy octave rescue regression");
   const auto emit=[&](const char*method,bool valid,double hz,double raw,double quality,double ms) {
    out<<c.name<<','<<rate<<','<<c.amp<<','<<c.hz<<','<<time<<','<<truth<<','<<method<<','<<valid<<','<<(valid?hz:0)<<','<<raw<<','<<quality<<','<<ms<<','<<n.cmndfMinimum<<','<<n.harmonicRatio<<','<<n.centroidHz<<','<<n.noiseKnown<<','<<n.noiseFloorDb<<','<<static_cast<int>(n.trackState)<<'\n';
   };
   emit("A_raw",r.frameQualified,r.rawHz,r.rawHz,r.score,r.computeMs);
   emit("B_fixed",r.frameQualified,fixedHz[i],r.rawHz,r.score,fixedMs[i]);
   emit("C_adaptive",n.validity==opentune::Validity::valid,n.trackedHz,n.rawHz,n.score,n.computeMs);
   emit("C_shared",sh.valid,sh.hz,r.rawHz,r.score,r.computeMs);
   emit("Stage2",r.validity==stage2baseline::Validity::valid,r.trackedHz,r.rawHz,r.score,r.computeMs);
  }
  trackerCpu+=cpuTime()-cpu;frameCount+=a.size();
 }
 std::ofstream profile(dir/"profile.json");profile<<std::setprecision(12)<<"{\"frames_per_frontend\":"<<frameCount<<",\"baseline_cpu_seconds\":"<<cpuA<<",\"production_cpu_seconds\":"<<cpuC<<",\"fixed_cpu_seconds\":"<<cpuB<<",\"fixed_wall_seconds\":"<<wallB<<",\"baseline_wall_seconds\":"<<wallA<<",\"production_wall_seconds\":"<<wallC<<",\"postprocessing_and_csv_cpu_seconds\":"<<trackerCpu<<"}\n";
 std::cout<<"Evaluation wrote "<<frameCount<<" frames per frontend; tracker and sine synthesis tests passed\n";
 return 0;
 }catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}
}
