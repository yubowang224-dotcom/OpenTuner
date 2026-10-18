#include "opentune/waveform.h"
#include "opentune/analyzer.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>
using namespace opentune;
namespace {
constexpr double pi=3.14159265358979323846;
void require(bool v,const char* s){if(!v)throw std::runtime_error(s);}
std::vector<float> tone(int rate,double hz,double amplitude,double phase=0,double dc=0){
  std::vector<float> p(static_cast<int>(std::round(rate*.08)));
  for(size_t i=0;i<p.size();++i)p[i]=static_cast<float>(dc+amplitude*std::sin(2*pi*hz*i/rate+phase));return p;
}
double rms(const DisplayWave& w){double e=0;for(int i=0;i<w.count;i++)e+=w.samples[i]*w.samples[i];return std::sqrt(e/w.count);}
void fixture(const std::filesystem::path& dir,const char* name,const DisplayWave& w,const std::vector<float>& pcm){
 std::ofstream f(dir/(std::string(name)+".json"));f<<std::setprecision(15)<<"{\"sample_rate\":48000,\"step_seconds\":"<<w.stepSeconds<<",\"start_seconds\":"<<w.startSeconds<<",\"duration_seconds\":"<<w.duration()<<",\"triggered\":"<<(w.triggered?"true":"false")<<",\"samples\":[";
 for(int i=0;i<w.count;++i)f<<(i?",":"")<<w.samples[i];
 Analyzer analyzer(48000);const auto result=analyzer.analyze(pcm.data(),static_cast<int>(pcm.size()),.08,true);
 f<<"],\"bin_hz\":"<<result.spectrumBinHz<<",\"spectrum\":[";
 for(int i=0;i<result.spectrumCount;i++)f<<(i?",":"")<<result.spectrum[i];f<<"]}\n";
}
}
int main(int argc,char**argv){try{
 const std::filesystem::path dir=argc>1?argv[1]:"waveform-results";std::filesystem::create_directories(dir);
 std::ofstream csv(dir/"waveform.csv");csv<<std::setprecision(15)<<"rate,hz,amplitude,phase,points,step_seconds,duration_seconds,start_seconds,triggered,rising_crossings,max_sample_error,compute_ms\n";
 std::vector<double> timings;int cases=0,triggered=0;
 for(int rate:{8000,44100,48000,96000,192000})for(double hz:{50.,82.406889,220.,440.,880.,2000.})for(double amp:{.005,.4})for(double phase:{0.,.7,2.9}){
   const auto pcm=tone(rate,hz,amp,phase,.13);WaveformDisplay display(rate);
   const auto w=display.extract(pcm.data(),static_cast<int>(pcm.size()),.08,true);
   require(w.count>=2&&w.count<=512,"bounded sample count");require(std::abs(w.stepSeconds-w.decimation/static_cast<double>(rate))<1e-12,"actual sample spacing");
   require(w.duration()<=.020000001&&w.duration()>=.0198,"declared approximately 20ms window");
   require(w.startSeconds>=0&&w.startSeconds+w.duration()<.080000001,"sample clock boundaries");
   double maximum=0;int crossings=0;
   for(int i=0;i<w.count;i++){
     const double truth=.13+amp*std::sin(2*pi*hz*(w.startSeconds+i*w.stepSeconds)+phase);
     maximum=std::max(maximum,std::abs(w.samples[i]-truth));
     require(std::isfinite(w.samples[i]),"finite samples");
     if(i&&w.samples[i-1]<=.13&&w.samples[i]>.13)++crossings;
   }
   require(maximum<amp*.01+1e-6,"passband amplitude/time error exceeds preregistered 1 percent target");
   require(std::abs(crossings-hz*w.duration())<=1.1,"period count disagrees with real time axis");
   const auto free=display.extract(pcm.data(),static_cast<int>(pcm.size()),.08,false);require(!free.triggered,"trigger false must remain false");
   timings.push_back(w.computeMs);++cases;triggered+=w.triggered;
   csv<<rate<<','<<hz<<','<<amp<<','<<phase<<','<<w.count<<','<<w.stepSeconds<<','<<w.duration()<<','<<w.startSeconds<<','<<w.triggered<<','<<crossings<<','<<maximum<<','<<w.computeMs<<'\n';
 }
 std::ofstream alias(dir/"antialias.csv");alias<<"rate,hz,decimation,attenuation_db\n";int aliasCases=0;
 for(int rate:{44100,48000,96000,192000})for(double fraction:{.52,.8}){
   WaveformDisplay display(rate);auto pcm=tone(rate,440,.4);const auto base=display.extract(pcm.data(),static_cast<int>(pcm.size()),.08,false);
   const double hz=fraction/base.stepSeconds;pcm=tone(rate,hz,.4);
   const auto w=display.extract(pcm.data(),static_cast<int>(pcm.size()),.08,false);
   const double db=20*std::log10(std::max(rms(w)/(.4/std::sqrt(2.)),1e-15));
   require(db<-50,"display anti-alias rejection below 50dB target");++aliasCases;
   alias<<rate<<','<<hz<<','<<w.decimation<<','<<db<<'\n';
 }
 WaveformDisplay display(48000);auto p=tone(48000,440,.4);
 fixture(dir,"sine440",display.extract(p.data(),static_cast<int>(p.size()),.08,true),p);
 for(size_t i=0;i<p.size();i++)p[i]=static_cast<float>(.25*std::sin(2*pi*220*i/48000)+.15*std::sin(2*pi*880*i/48000));
 const auto dual=display.extract(p.data(),static_cast<int>(p.size()),.08,false);fixture(dir,"dual",dual,p);
 require(rms(dual)>.15,"dual signal must not become silence");
 std::fill(p.begin(),p.end(),0);auto silence=display.extract(p.data(),static_cast<int>(p.size()),.08,true);fixture(dir,"silence",silence,p);
 require(!silence.triggered&&rms(silence)==0,"silence fabricated waveform or trigger");
 std::fill(p.begin(),p.end(),.2f);auto dc=display.extract(p.data(),static_cast<int>(p.size()),.08,true);require(!dc.triggered,"DC falsely triggered");
 for(int i=0;i<dc.count;i++)require(std::abs(dc.samples[i]-.2)<1e-6,"DC amplitude not preserved");
 uint32_t seed=48121;for(auto& sample:p){seed=seed*1664525u+1013904223u;sample=static_cast<float>((static_cast<double>(seed)/4294967296.-.5)*.4);}
 const auto noise=display.extract(p.data(),static_cast<int>(p.size()),.08,false);fixture(dir,"noise",noise,p);require(!noise.triggered&&rms(noise)>.01,"noise incorrectly replaced");
 p[20]=std::numeric_limits<float>::quiet_NaN();bool rejected=false;try{display.extract(p.data(),static_cast<int>(p.size()),.08,false);}catch(const std::invalid_argument&){rejected=true;}require(rejected,"nonfinite input not rejected");
 std::sort(timings.begin(),timings.end());std::cout<<cases<<" tone conditions, "<<aliasCases<<" alias conditions; trigger found "<<triggered<<'/'<<cases<<"; median "<<timings[timings.size()/2]<<"ms P95 "<<timings[static_cast<size_t>(std::ceil(timings.size()*.95))-1]<<"ms; dual/silence/DC/noise/NaN passed\n";
 return 0;
}catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}}
