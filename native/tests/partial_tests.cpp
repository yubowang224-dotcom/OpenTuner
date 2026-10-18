#include "opentune/partial_analyzer.h"
#include "partial_fixture.h"
#include <algorithm>
#include <cmath>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <vector>
using namespace opentune;
namespace {
constexpr double pi=3.14159265358979323846;
double pct(std::vector<double> x,double q){if(x.empty())return -1;std::sort(x.begin(),x.end());return x[static_cast<size_t>(std::ceil(q*x.size()))-1];}
void require(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
}
int main(int argc,char**argv){try{
 const std::filesystem::path output=argc>1?argv[1]:"partial-results";std::filesystem::create_directories(output);const bool quick=argc>2;
 std::ofstream csv(output/"frames.csv"),cases(output/"cases.csv");csv<<std::setprecision(15)<<"case,midi,rate,b_truth,first_truth,condition,time,steady,ready,reason,b,ideal_hz,first_hz,residual,sensitivity,partials,stable,compute_ms\n";
 cases<<"case,midi,rate,b_truth,condition,frames,ready,b_relative_p95,first_cents_p95\n";
 int id=0,total=0,accepted=0;bool fixture=false;std::array<bool,6> wrote{},wroteStrong{};std::vector<double> bErrors,absB,firstErrors,timing;const auto cpuStart=std::clock();
 for(int midi:{33,45,57,69,81,93})for(int rate:{44100,48000})for(double b:{.00003,.0001,.0004,.0015,.006})for(int kind=0;kind<4;kind++){
  if(quick&&(midi!=45&&midi!=93||rate!=48000||b!=.0001&&b!=.006))continue;
  const double first=440*std::pow(2.,(midi-69)/12.),ideal=first/std::sqrt(1+b);std::vector<float> pcm(rate*3/2);
  for(int i=0;i<static_cast<int>(pcm.size());i++){
   const double t=i/static_cast<double>(rate);double x=.01;
   for(int n=1;n<=16;n++){
    if(kind==2&&(n==1||n==4))continue;
    double hz=n*ideal*std::sqrt(1+b*n*n);if(kind==3)hz*=std::pow(2.,((n%3)-1)*.15/1200);
    if(hz>=std::min(18000.,rate*.42))continue;
    const double amplitude=.12/std::pow(n,.7)*(kind==1&&n==1?.02:1);
    x+=amplitude*std::exp(-t*(.15+.025*n))*std::sin(2*pi*hz*t+.17*n);
   }
   pcm[i]=static_cast<float>(x);
  }
  PartialAnalyzer analyzer(rate,440,midi);int denominator=0,valid=0;std::vector<double> localB,localF;
  for(int end=analyzer.windowSize();end<=static_cast<int>(pcm.size());end+=analyzer.hopSize()){
   const double time=end/static_cast<double>(rate);const auto r=analyzer.analyze(pcm.data()+end-analyzer.windowSize(),analyzer.windowSize(),time);const bool steady=time>=1.1,ready=r.reason==PartialReason::ready;
   csv<<id<<','<<midi<<','<<rate<<','<<b<<','<<first<<','<<kind<<','<<time<<','<<steady<<','<<ready<<','<<static_cast<int>(r.reason)<<','<<r.b<<','<<r.idealHz<<','<<r.firstHz<<','<<r.residual<<','<<r.sensitivity<<','<<r.count<<','<<r.stable<<','<<r.computeMs<<'\n';
   const int group=(midi-33)/12;const double pattern[]={.0015,.0004,.0001,.0001,.0004,.0015};
   const bool original=!fixture&&midi==69&&rate==48000&&b==.0004&&kind==2&&ready;
   const bool guide=!wrote[group]&&rate==48000&&b==pattern[group]&&kind==2&&ready;
   const bool strong=!wroteStrong[group]&&rate==48000&&b==.006&&kind==0&&ready;
   if(original||guide||strong){
    writePartialFixture(output/(strong?"fixture-strong-"+std::to_string(midi)+".json":guide?"fixture-"+std::to_string(midi)+".json":"fixture.json"),r,rate,440,midi);
    if(original)fixture=true;if(guide)wrote[group]=true;if(strong)wroteStrong[group]=true;
   }
   if(!steady)continue;++denominator;++total;timing.push_back(r.computeMs);
   if(ready){++valid;++accepted;const double error=std::abs(r.b-b)/b,ferror=std::abs(centsBetween(r.firstHz,first));localB.push_back(error);localF.push_back(ferror);bErrors.push_back(error);firstErrors.push_back(ferror);absB.push_back(std::abs(r.b-b));}
  }
  cases<<id<<','<<midi<<','<<rate<<','<<b<<','<<kind<<','<<denominator<<','<<valid<<','<<pct(localB,.95)<<','<<pct(localF,.95)<<'\n';++id;
 }
 std::ofstream summary(output/"summary.json");summary<<std::setprecision(15)<<"{\"quick\":"<<quick<<",\"conditions\":"<<id<<",\"steady\":"<<total<<",\"ready\":"<<accepted<<",\"b_relative_median\":"<<pct(bErrors,.5)<<",\"b_relative_p95\":"<<pct(bErrors,.95)<<",\"b_absolute_p95\":"<<pct(absB,.95)<<",\"first_cents_p95\":"<<pct(firstErrors,.95)<<",\"compute_p95_ms\":"<<pct(timing,.95)<<",\"cpu_seconds\":"<<static_cast<double>(std::clock()-cpuStart)/CLOCKS_PER_SEC<<"}\n";
 std::cout<<id<<" partial conditions: "<<accepted<<'/'<<total<<" ready, B median relative "<<pct(bErrors,.5)<<" P95 "<<pct(bErrors,.95)<<"; f1 P95 "<<pct(firstErrors,.95)<<"c; compute P95 "<<pct(timing,.95)<<"ms\n";
 require(accepted>=total*.9&&pct(bErrors,.5)<=.1&&pct(bErrors,.95)<=.25&&pct(firstErrors,.95)<=2,"registered partial goals failed; all rows retained");
 return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
