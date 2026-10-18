#include "opentune/partial_analyzer.h"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <vector>
using namespace opentune;
namespace {
constexpr double pi=3.14159265358979323846;
struct Test {const char* name;int midi;double b,detune;int mode;bool mustReject;double association=0;};
void require(bool value,const char* text){if(!value)throw std::runtime_error(text);}
std::vector<float> signal(int rate,const Test& c){
 std::vector<float> pcm(rate*3/2);std::vector<double> phases(17,0);
 const double first=440*std::pow(2.,(c.midi-69)/12.+c.detune/1200),ideal=first/std::sqrt(1+c.b);
 for(int i=0;i<static_cast<int>(pcm.size());i++){
  const double t=i/static_cast<double>(rate);double x=0;
  for(int n=1;n<=16;n++){
   if(c.mode==1&&n>2||c.mode==2&&(n>8||n%2==1))continue;
   double hz=n*ideal*std::sqrt(1+c.b*n*n);
   if(c.mode==3)hz*=std::pow(2.,((n%3)-1)*8./1200);
   if(c.mode==9)hz*=2;
   if(c.mode==10)hz*=std::pow(2.,t*200/1200);
   if(hz>=std::min(18000.,rate*.42))continue;
   phases[n]+=2*pi*hz/rate;
   x+=.12/std::pow(n,.7)*std::sin(phases[n]+.17*n);
   if(c.mode==4||c.mode==5)x+=.12/std::pow(n,.7)*std::sin(phases[n]*std::pow(2.,(c.mode==4?24.:3.)/1200)+.13*n);
  }
  if(c.mode==6)x=0;
  if(c.mode==7)x=std::clamp(x*20,-1.,1.);
  pcm[i]=static_cast<float>(x);
 }
 uint32_t seed=20261019;
 if(c.mode==8||c.mode==11||c.mode==12){
  double sum=0;for(auto x:pcm)sum+=x*x;const double rms=std::sqrt(sum/pcm.size());
  const double amplitude=c.mode==8?.2:rms*std::sqrt(12.)/std::pow(10.,(c.mode==11?20.:10.)/20);
  for(auto& x:pcm){seed=seed*1664525u+1013904223u;const double noise=(seed/4294967296.-.5)*amplitude;x=static_cast<float>((c.mode==8?0:x)+noise);}
 }
 return pcm;
}
}
int main(int argc,char**argv){try{
 const std::filesystem::path dir=argc>1?argv[1]:"partial-edges";std::filesystem::create_directories(dir);std::ofstream out(dir/"frames.csv"),cases(dir/"cases.csv");
 out<<std::setprecision(15)<<"case,rate,midi,detune,time,ready,reason,b,model_first,observed_first,measured_cents,truth_cents,score,compute_ms\n";
 cases<<"case,rate,midi,b_truth,detune,steady,ready,must_reject,max_first_error_cents\n";
 std::vector<Test> tests;
 for(int midi:{45,69,93})for(double detune:{-30.,-17.,17.,30.})tests.push_back({"detuned",midi,.0004,detune,0,false});
 for(double center:{-90.,90.})for(double delta:{-17.,17.})tests.push_back({"curve_scope",45,.006,center+delta,0,false,110*std::pow(2.,center/1200)});
 tests.push_back({"stale_curve_center",45,.006,0,0,true,110*std::pow(2.,90./1200)});
 for(int midi:{45,69,93})for(int mode:{11,12})tests.push_back({mode==11?"snr20":"snr10",midi,.0004,0,mode,false});
 for(const auto& c:std::vector<Test>{{"two_peaks",69,.0004,0,1,true},{"even_only",45,.0004,0,2,true},{"irregular",69,.0004,0,3,true},{"resolved_dual24c",69,.0004,0,4,true},{"unresolved_dual3c",69,.0004,0,5,false},{"silence",69,.0004,0,6,true},{"clipped",69,.0004,0,7,true},{"noise",69,.0004,0,8,true},{"wrong_octave",69,.0004,0,9,true},{"glide200cps",69,.0004,0,10,true},{"wrong_key",69,.0004,100,0,true}})tests.push_back(c);
 for(int midi:{21,108})for(double b:{.00003,.006})tests.push_back({"boundary",midi,b,0,0,false});
 int total=0,readyCount=0,falseReady=0,detunedFrames=0,detunedReady=0;double maximumDetuned=0;
 for(int rate:{44100,48000})for(const auto& c:tests){
  auto pcm=signal(rate,c);PartialAnalyzer analyzer(rate,440,c.midi,c.association);int count=0,valid=0;double maxError=0;
  for(int end=analyzer.windowSize();end<=static_cast<int>(pcm.size());end+=analyzer.hopSize()){
   const double time=end/static_cast<double>(rate);const auto r=analyzer.analyze(pcm.data()+end-analyzer.windowSize(),analyzer.windowSize(),time);const bool ready=r.reason==PartialReason::ready;const auto pitch=partialPitch(r,440);
   double observed=0;for(int i=0;i<r.count;i++)if(r.partials[i].order==1)observed=r.partials[i].hz;
   out<<c.name<<','<<rate<<','<<c.midi<<','<<c.detune<<','<<time<<','<<ready<<','<<static_cast<int>(r.reason)<<','<<r.b<<','<<r.firstHz<<','<<observed<<','<<(ready?centsBetween(pitch.trackedHz,440*std::pow(2.,(c.midi-69)/12.)):0)<<','<<c.detune<<','<<r.score<<','<<r.computeMs<<'\n';
   if(ready&&c.mustReject)++falseReady;
   if(time<1.1)continue;++total;++count;
   if(ready){++readyCount;++valid;const double truth=440*std::pow(2.,(c.midi-69)/12.+c.detune/1200);const double error=std::abs(centsBetween(pitch.trackedHz,truth));maxError=std::max(maxError,error);}
  }
  if(std::string(c.name)=="detuned"||std::string(c.name)=="curve_scope"){require(valid>=count*.95&&maxError<=2,"per-condition association accuracy");detunedFrames+=count;detunedReady+=valid;maximumDetuned=std::max(maximumDetuned,maxError);}
  cases<<c.name<<','<<rate<<','<<c.midi<<','<<c.b<<','<<c.detune<<','<<count<<','<<valid<<','<<c.mustReject<<',';if(valid)cases<<maxError;cases<<'\n';
 }
 // Existing streams: stop must become invalid and a reappearing signal must requalify.
 std::ofstream dynamic(dir/"response.csv");dynamic<<"rate,first_ready_ms,stop_invalid_ms,return_ready_ms\n";
 for(int rate:{44100,48000}){
  Test c{"dynamic",69,.0004,0,0,false};auto base=signal(rate,c);std::vector<float> pcm(rate*4);for(int i=0;i<static_cast<int>(pcm.size());i++)pcm[i]=i>=rate*3/2&&i<rate*5/2?0:base[i%base.size()];
  PartialAnalyzer a(rate,440,69);double first=-1,lost=-1,returned=-1;
  for(int end=a.windowSize();end<=static_cast<int>(pcm.size());end+=a.hopSize()){
   const double t=end/static_cast<double>(rate);const auto r=a.analyze(pcm.data()+end-a.windowSize(),a.windowSize(),t);const bool ready=r.reason==PartialReason::ready;
   if(ready&&first<0)first=t*1000;if(t>=1.5&&t<2.5&&!ready&&lost<0)lost=(t-1.5)*1000;if(t>=2.5&&ready&&returned<0)returned=(t-2.5)*1000;
  }
  dynamic<<rate<<','<<first<<','<<lost<<','<<returned<<'\n';require(first>0&&first<=1200&&lost>=0&&lost<=850&&returned>=0&&returned<=1300,"partial stop/return boundary");
 }
 for(int rate:{8000,192000}){bool rejected=false;try{PartialAnalyzer a(rate,440,69);}catch(const std::invalid_argument&){rejected=true;}require(rejected,"partial unsupported rate must reject");}
 for(double hz:{-1.,1.,5001.,440*std::pow(2.,151./1200)}){bool rejected=false;try{PartialAnalyzer a(48000,440,69,hz);}catch(const std::invalid_argument&){rejected=true;}require(rejected,"invalid association must reject");}
 bool rejected=false;try{PartialAnalyzer a(48000,440,69);a.analyze(nullptr,a.windowSize(),1);}catch(const std::invalid_argument&){rejected=true;}require(rejected,"null partial frame");
 std::cout<<tests.size()*2<<" extra conditions; detuned "<<detunedReady<<'/'<<detunedFrames<<" accepted, max true f1 error "<<maximumDetuned<<"c; rejected-input false ready "<<falseReady<<"; all exploratory rows retained\n";
 require(detunedReady>=detunedFrames*.9&&maximumDetuned<=2&&falseReady==0,"extra partial conditions failed");return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
