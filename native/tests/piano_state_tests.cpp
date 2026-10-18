#include "opentune/piano_analyzer.h"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <vector>
using namespace opentune;
namespace{constexpr double pi=3.14159265358979323846;void require(bool v,const char*m){if(!v)throw std::runtime_error(m);}}
int main(int argc,char**argv){try{
 const std::filesystem::path dir=argc>1?argv[1]:"piano-state";std::filesystem::create_directories(dir);std::ofstream out(dir/"states.csv");out<<std::setprecision(15)<<"rate,case,time,truth_hz,valid,raw_hz,tracked_hz,error_cents,score\n";
 int weak=0,weakValid=0,falseValid=0;double maxWeak=0;
 for(int rate:{44100,48000})for(double hz:{25.,27.5,110.,440.,2093.004522,4566.546307}){
  PianoAnalyzer a(rate);std::vector<float> p(rate);for(int i=0;i<rate;i++)p[i]=static_cast<float>(.07+.003*std::sin(2*pi*hz*i/rate));
  for(int end=a.windowSize();end<=rate;end+=a.hopSize()){
   const auto r=a.analyze(p.data()+end-a.windowSize(),a.windowSize(),end/static_cast<double>(rate),false);if(end<rate*.4)continue;++weak;const bool valid=r.validity==Validity::valid;double error=0;if(valid){++weakValid;error=centsBetween(r.trackedHz,hz);maxWeak=std::max(maxWeak,std::abs(error));}
   out<<rate<<",weak_dc,"<<end/static_cast<double>(rate)<<','<<hz<<','<<valid<<','<<r.rawHz<<','<<r.trackedHz<<','<<error<<','<<r.score<<'\n';
  }
 }
 std::ofstream response(dir/"response.csv");response<<"rate,first_valid_ms,step_settled_ms,silence_invalid_ms,return_valid_ms,glide_accepted,glide_frames,glide_end_error_mean_cents\n";
 for(int rate:{44100,48000}){
  PianoAnalyzer a(rate);std::vector<float> p(rate*3);double phase=0;
  for(int i=0;i<static_cast<int>(p.size());i++){const double t=i/static_cast<double>(rate);const double hz=t<.8?27.5:55;phase+=2*pi*hz/rate;p[i]=t>=1.6&&t<2.2?0:static_cast<float>(.2*std::sin(phase));}
  double first=-1,switched=-1,lost=-1,returned=-1;int consistent=0;
  for(int end=a.windowSize();end<=static_cast<int>(p.size());end+=a.hopSize()){
   const double t=end/static_cast<double>(rate),truth=t<.8?27.5:55;const auto r=a.analyze(p.data()+end-a.windowSize(),a.windowSize(),t,false);const bool valid=r.validity==Validity::valid;const double error=valid?centsBetween(r.trackedHz,truth):0;
   if(valid&&first<0)first=t*1000;
   if(t>=.8&&t<1.6){consistent=valid&&std::abs(error)<5?consistent+1:0;if(consistent>=3&&switched<0)switched=(t-.8)*1000;}
   if(t>=1.6&&t<2.2&&!valid&&lost<0)lost=(t-1.6)*1000;
   if(t>=2.2&&valid&&returned<0)returned=(t-2.2)*1000;
   out<<rate<<",step_silence_return,"<<t<<','<<truth<<','<<valid<<','<<r.rawHz<<','<<r.trackedHz<<','<<error<<','<<r.score<<'\n';
  }
  require(first>0&&first<=260&&switched>0&&switched<=350&&lost>=0&&lost<=250&&returned>=0&&returned<=260,"piano dynamic response exceeds registered bounds");
  a.reset();int glide=0,count=0;double sum=0;phase=0;p.resize(rate*2);
  for(int i=0;i<static_cast<int>(p.size());i++){const double t=i/static_cast<double>(rate),hz=220*std::pow(2.,t*.25);phase+=2*pi*hz/rate;p[i]=static_cast<float>(.2*std::sin(phase));}
  for(int end=a.windowSize();end<=static_cast<int>(p.size());end+=a.hopSize()){
   const double t=end/static_cast<double>(rate),truth=220*std::pow(2.,t*.25);const auto r=a.analyze(p.data()+end-a.windowSize(),a.windowSize(),t,false);if(t<.4)continue;++count;if(r.validity==Validity::valid){++glide;sum+=std::abs(centsBetween(r.trackedHz,truth));}
  }
  response<<rate<<','<<first<<','<<switched<<','<<lost<<','<<returned<<','<<glide<<','<<count<<','<<(glide?sum/glide:-1)<<'\n';
  for(int kind:{0,1,2}){
   a.reset();p.resize(rate);for(int i=0;i<rate;i++){const double t=i/static_cast<double>(rate);p[i]=kind==0?static_cast<float>(.2*std::sin(2*pi*220*t)+.2*std::sin(2*pi*337.13*t)):kind==1?static_cast<float>(std::clamp(4*std::sin(2*pi*440*t),-1.,1.)):static_cast<float>(.2*std::sin(2*pi*6000*t));}
   for(int end=a.windowSize();end<=rate;end+=a.hopSize()){const auto r=a.analyze(p.data()+end-a.windowSize(),a.windowSize(),end/static_cast<double>(rate),false);if(r.validity==Validity::valid)++falseValid;}
  }
 }
 require(weakValid>=weak*.95&&maxWeak<=5&&falseValid==0,"weak/DC, mixture/clipping/outside piano rejection failed");std::cout<<weakValid<<'/'<<weak<<" weak/DC frames accepted, max "<<maxWeak<<"c; mixture/clipping/6k false valid "<<falseValid<<"; step/silence/glide report written (glide end error not steady accuracy)\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
