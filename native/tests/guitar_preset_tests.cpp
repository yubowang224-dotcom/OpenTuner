#include "opentune/analyzer.h"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <stdexcept>
#include <vector>
using namespace opentune;
namespace {
constexpr double pi=3.14159265358979323846;
struct Preset {const char* id; int midi[6];};
constexpr Preset presets[]={
 {"standard",{40,45,50,55,59,64}}, {"dropD",{38,45,50,55,59,64}},
 {"dStandard",{38,43,48,53,57,62}}, {"halfDown",{39,44,49,54,58,63}},
 {"dadgad",{38,45,50,55,57,62}}, {"openD",{38,45,50,54,57,62}},
 {"openG",{38,43,50,55,59,62}}};
double pct(std::vector<double> v,double q){std::sort(v.begin(),v.end());return v.empty()?-1:v[static_cast<size_t>(std::ceil(q*v.size()))-1];}
void require(bool b,const char* m){if(!b)throw std::runtime_error(m);}
}
int main(int argc,char**argv){try{
 const std::filesystem::path dir=argc>1?argv[1]:"guitar-results";std::filesystem::create_directories(dir);
 std::ofstream frames(dir/"frames.csv"),cases(dir/"cases.csv");
 frames<<std::setprecision(15)<<"preset,string,rate,signal,truth_hz,time_seconds,steady,valid,raw_hz,tracked_hz,error_cents,score,compute_ms\n";
 cases<<std::setprecision(15)<<"preset,string,midi,hz,rate,signal,frames,valid,median_cents,p95_cents,octave_errors,jitter_sd_cents,first_ms,p95_compute_ms\n";
 int conditions=0,total=0,accepted=0,octaves=0;std::vector<double> errors,timings;
 const std::vector<std::vector<double>> spectra={{1},{.12,1,.45,.2},{.04,1,.65,.2},{0,1,.65,.3}};
 const char* names[]={"pure","strong_second","weak_fundamental","missing_fundamental"};
 for(const auto& preset:presets)for(int string=0;string<6;++string)for(int rate:{44100,48000})for(int kind=0;kind<4;++kind){
  const double hz=440*std::pow(2.,(preset.midi[string]-69)/12.);std::vector<float> pcm(static_cast<size_t>(rate*1.2));
  for(size_t i=0;i<pcm.size();++i){double x=0;for(size_t h=0;h<spectra[kind].size();++h)x+=.18*spectra[kind][h]*std::sin(2*pi*(h+1)*hz*i/rate+.3);pcm[i]=static_cast<float>(x);}
  Analyzer a(rate);int n=0,valid=0,octave=0;double first=-1;std::vector<double> e,signedError,t;
  for(int end=a.windowSize();end<=static_cast<int>(pcm.size());end+=a.hopSize()){
   const double time=end/static_cast<double>(rate);const auto r=a.analyze(pcm.data()+end-a.windowSize(),a.windowSize(),time,false);
   const bool ok=r.validity==Validity::valid,steady=time>=.3-1e-9;const double err=ok?centsBetween(r.trackedHz,hz):0;
   if(ok&&first<0)first=time*1000;
   frames<<preset.id<<','<<6-string<<','<<rate<<','<<names[kind]<<','<<hz<<','<<time<<','<<steady<<','<<ok<<','<<r.rawHz<<','<<r.trackedHz<<','<<err<<','<<r.score<<','<<r.computeMs<<'\n';
   if(!steady)continue;++n;++total;t.push_back(r.computeMs);timings.push_back(r.computeMs);
   if(ok){++valid;++accepted;e.push_back(std::abs(err));signedError.push_back(err);errors.push_back(std::abs(err));if(std::abs(std::abs(err)-1200)<50){++octave;++octaves;}}
  }
  const double mean=signedError.empty()?0:std::accumulate(signedError.begin(),signedError.end(),0.)/signedError.size();double variance=0;for(double x:signedError)variance+=(x-mean)*(x-mean);
  const double jitter=signedError.empty()?-1:std::sqrt(variance/signedError.size());
  cases<<preset.id<<','<<6-string<<','<<preset.midi[string]<<','<<hz<<','<<rate<<','<<names[kind]<<','<<n<<','<<valid<<','<<pct(e,.5)<<','<<pct(e,.95)<<','<<octave<<','<<jitter<<','<<first<<','<<pct(t,.95)<<'\n';++conditions;
  require(valid>=n*.95,"preset case coverage below 95 percent");require(pct(e,.5)<=2&&pct(e,.95)<=5&&octave==0,"preset steady accuracy goal failed");
 }
 // Independent invalid inputs: retain every frame, do not count empty error as
 // success. Fixed LCG uniform noise and all-zero silence, both sample rates.
 int invalidFrames=0,falseValid=0;
 for(int rate:{44100,48000})for(int noise:{0,1}){
  Analyzer a(rate);uint32_t seed=20261019;std::vector<float> pcm(static_cast<size_t>(rate*1.2));
  for(auto& v:pcm){seed=1664525u*seed+1013904223u;v=noise?static_cast<float>((seed/4294967296.-.5)*.4):0;}
  for(int end=a.windowSize();end<=static_cast<int>(pcm.size());end+=a.hopSize()){
   const auto r=a.analyze(pcm.data()+end-a.windowSize(),a.windowSize(),end/static_cast<double>(rate),false);++invalidFrames;if(r.validity==Validity::valid)++falseValid;
  }
 }
 std::ofstream summary(dir/"summary.json");summary<<std::setprecision(15)<<"{\"conditions\":"<<conditions<<",\"steady_frames\":"<<total<<",\"valid\":"<<accepted<<",\"median_cents\":"<<pct(errors,.5)<<",\"p95_cents\":"<<pct(errors,.95)<<",\"octave_errors\":"<<octaves<<",\"p95_compute_ms\":"<<pct(timings,.95)<<",\"invalid_frames\":"<<invalidFrames<<",\"false_valid\":"<<falseValid<<"}\n";
 require(falseValid==0,"silence or noise false accepted pitch");std::cout<<conditions<<" preset/signal/rate cases, "<<accepted<<'/'<<total<<" steady accepted, median "<<pct(errors,.5)<<"c P95 "<<pct(errors,.95)<<"c, octaves "<<octaves<<", invalid "<<falseValid<<'/'<<invalidFrames<<"; host compute P95 "<<pct(timings,.95)<<"ms\n";
 return 0;
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
