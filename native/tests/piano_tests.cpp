#include "opentune/piano_analyzer.h"
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
namespace {constexpr double pi=3.14159265358979323846;
double pct(std::vector<double>v,double q){if(v.empty())return -1;std::sort(v.begin(),v.end());return v[static_cast<size_t>(std::ceil(q*v.size()))-1];}
void require(bool ok,const char*m){if(!ok)throw std::runtime_error(m);}
}
int main(int argc,char**argv){try{
 const std::filesystem::path dir=argc>1?argv[1]:"piano-results";std::filesystem::create_directories(dir);const bool quick=argc>2;
 std::ofstream cases(dir/"cases.csv"),frames(dir/"frames.csv");
 cases<<std::setprecision(15)<<"midi,rate,a4,signal,truth_hz,frames,valid,median_cents,p95_cents,octave_errors,jitter_sd,first_ms,p95_compute_ms,goal\n";
 frames<<std::setprecision(15)<<"midi,rate,a4,signal,time,truth_hz,steady,valid,raw_hz,tracked_hz,error_cents,score,compute_ms\n";
 int conditions=0,failures=0,total=0,accepted=0,octaves=0;std::vector<double> allErrors,allTiming;
 const std::vector<std::vector<double>> spectra={{1},{1},{.08,1,.65,.2},{0,1,.65,.3}};
 const char* names[]={"pure","detuned17","strong_partials","missing_fundamental"};
 for(int midi=21;midi<=108;midi++)for(int rate:{44100,48000})for(double a4:{440.,442.})for(int kind=0;kind<4;kind++){
  if(quick&&midi!=21&&midi!=33&&midi!=60&&midi!=84&&midi!=108)continue;
  const double hz=a4*std::pow(2.,(midi-69)/12.+(kind==1?17./1200:0));std::vector<float> pcm(rate);
  for(int i=0;i<rate;i++){double x=0;for(size_t n=0;n<spectra[kind].size();n++)x+=.18*spectra[kind][n]*std::sin(2*pi*(n+1)*hz*i/rate+.3);pcm[i]=static_cast<float>(x);}
  PianoAnalyzer a(rate,a4);int count=0,valid=0,octave=0;double first=-1;std::vector<double> errors,signedError,timing;
  for(int end=a.windowSize();end<=rate;end+=a.hopSize()){
   const double time=end/static_cast<double>(rate);const auto r=a.analyze(pcm.data()+end-a.windowSize(),a.windowSize(),time,false);const bool ok=r.validity==Validity::valid,steady=time>=.4-1e-9;const double err=ok?centsBetween(r.trackedHz,hz):0;
   if(ok&&first<0)first=time*1000;
   frames<<midi<<','<<rate<<','<<a4<<','<<names[kind]<<','<<time<<','<<hz<<','<<steady<<','<<ok<<','<<r.rawHz<<','<<r.trackedHz<<','<<err<<','<<r.score<<','<<r.computeMs<<'\n';
   if(!steady)continue;++count;++total;timing.push_back(r.computeMs);allTiming.push_back(r.computeMs);
   if(ok){++valid;++accepted;errors.push_back(std::abs(err));signedError.push_back(err);allErrors.push_back(std::abs(err));if(std::abs(std::abs(err)-1200)<50){++octave;++octaves;}}
  }
  const double mean=signedError.empty()?0:std::accumulate(signedError.begin(),signedError.end(),0.)/signedError.size();double variance=0;for(double e:signedError)variance+=(e-mean)*(e-mean);
  const bool goal=valid>=count*.95&&!errors.empty()&&pct(errors,.5)<=2&&pct(errors,.95)<=5&&octave==0;if(!goal)++failures;
  cases<<midi<<','<<rate<<','<<a4<<','<<names[kind]<<','<<hz<<','<<count<<','<<valid<<','<<pct(errors,.5)<<','<<pct(errors,.95)<<','<<octave<<','<<(signedError.empty()?-1:std::sqrt(variance/signedError.size()))<<','<<first<<','<<pct(timing,.95)<<','<<goal<<'\n';++conditions;
 }
 int boundary=0;for(int rate:{16000,44100,48000})for(double a4:{400.,480.})for(int midi:{21,108}){
  const double hz=a4*std::pow(2.,(midi-69)/12.);PianoAnalyzer a(rate,a4);std::vector<float> pcm(rate);for(int i=0;i<rate;i++)pcm[i]=static_cast<float>(.2*std::sin(2*pi*hz*i/rate));
  int valid=0,count=0;double maximum=0;for(int end=a.windowSize();end<=rate;end+=a.hopSize()){const auto r=a.analyze(pcm.data()+end-a.windowSize(),a.windowSize(),end/static_cast<double>(rate),false);if(end<rate*.4)continue;++count;if(r.validity==Validity::valid){++valid;maximum=std::max(maximum,std::abs(centsBetween(r.trackedHz,hz)));}}
  if(valid<count*.95||maximum>5)++failures;++boundary;
 }
 int invalid=0,falseValid=0;for(int rate:{44100,48000})for(int noise:{0,1}){
  PianoAnalyzer a(rate);std::vector<float> p(rate);uint32_t seed=20261019;for(auto& x:p){seed=seed*1664525u+1013904223u;x=noise?static_cast<float>((seed/4294967296.-.5)*.4):0;}
  for(int end=a.windowSize();end<=rate;end+=a.hopSize()){const auto r=a.analyze(p.data()+end-a.windowSize(),a.windowSize(),end/static_cast<double>(rate),false);++invalid;if(r.validity==Validity::valid)++falseValid;}
 }
 bool rejected=false;try{PianoAnalyzer unsupported(8000);}catch(const std::invalid_argument&){rejected=true;}require(rejected,"8k piano input must reject rather than alias C8");
 std::ofstream summary(dir/"summary.json");summary<<std::setprecision(15)<<"{\"quick\":"<<quick<<",\"conditions\":"<<conditions<<",\"goal_failures\":"<<failures<<",\"steady_frames\":"<<total<<",\"valid\":"<<accepted<<",\"median_cents\":"<<pct(allErrors,.5)<<",\"p95_cents\":"<<pct(allErrors,.95)<<",\"octave_errors\":"<<octaves<<",\"p95_compute_ms\":"<<pct(allTiming,.95)<<",\"a4_boundary_cases\":"<<boundary<<",\"invalid_frames\":"<<invalid<<",\"false_valid\":"<<falseValid<<"}\n";
 std::cout<<conditions<<" piano conditions: "<<accepted<<'/'<<total<<" accepted; median "<<pct(allErrors,.5)<<"c P95 "<<pct(allErrors,.95)<<"c; goal failures "<<failures<<", octave "<<octaves<<"; invalid "<<falseValid<<'/'<<invalid<<"; host P95 "<<pct(allTiming,.95)<<"ms\n";
 require(failures==0&&falseValid==0,"piano matrix goals failed (all conditions retained)");return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
