"""M3 host-only stiff-string experiments from the production analyzer and curve solver."""
import argparse,csv,hashlib,json,platform
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--build',type=Path,default=root/'build/m3-dsp');p.add_argument('--output',type=Path,default=root/'artifacts/m3/results');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
def rows(path):
 with (a.build/path).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def pct(x,q):return float(np.percentile(x,q,method='inverted_cdf')) if x else None
s=json.loads((a.build/'partial-results/summary.json').read_text(encoding='utf-8'));assert s['conditions']==240 and s['ready']==s['steady']==960 and not s['quick']
f=rows('partial-results/frames.csv');steady=[r for r in f if r['steady']=='1'];valid=[r for r in steady if r['ready']=='1']
s.update(evidence='Original synthetic host PCM only; NOT a phone, recording or professional piano validation',all_frames=len(f),all_ready=sum(r['ready']=='1' for r in f),steady_denominator=len(steady),steady_rejected=len(steady)-len(valid),python=platform.python_version())
s['per_signal']={}
for kind,name in enumerate(['full','weak_first','missing_first_fourth','perturbed_partials']):
 data=[r for r in steady if int(r['condition'])==kind];ok=[r for r in data if r['ready']=='1'];s['per_signal'][name]=dict(frames=len(data),ready=len(ok),first_cents_p95=pct([abs(1200*np.log2(float(r['first_hz'])/float(r['first_truth']))) for r in ok],95),b_relative_p95=pct([abs(float(r['b'])/float(r['b_truth'])-1) for r in ok],95))
edges=rows('partial-edges/cases.csv');s['extensions']={}
for name in sorted({r['case'] for r in edges}):
 data=[r for r in edges if r['case']==name];err=[float(r['max_first_error_cents']) for r in data if r['max_first_error_cents']];s['extensions'][name]=dict(conditions=len(data),frames=sum(int(r['steady']) for r in data),ready=sum(int(r['ready']) for r in data),max_cents_error=max(err) if err else None,must_reject=any(r['must_reject']=='1' for r in data))
assert all(not x['ready'] for x in s['extensions'].values() if x['must_reject'])
s['response']=rows('partial-edges/response.csv');s['curves']=json.loads((a.build/'stretch-targets/summary.json').read_text(encoding='utf-8'))
loop=rows('curve-loop/cases.csv');s['curve_loop']=dict(conditions=len(loop),steady=sum(int(r['steady']) for r in loop),ready=sum(int(r['ready']) for r in loop),max_cents_error=max(float(r['max_error_cents']) for r in loop))
s['jitter_max_case_sd_cents']=max(float(np.std([1200*np.log2(float(r['first_hz'])/float(r['first_truth'])) for r in valid if r['case']==case])) for case in {r['case'] for r in valid})
if (a.output.parent/'host-resource.json').exists():s['host_resource']=json.loads((a.output.parent/'host-resource.json').read_text(encoding='utf-8-sig'))
s['source_sha256_lf']={str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [root/'native/src/partial_analyzer.cpp',root/'native/include/opentune/partial_analyzer.h',root/'lib/model/piano_calibration.dart',root/'native/tests/partial_tests.cpp',root/'native/tests/partial_edges.cpp',root/'native/tests/partial_curve_loop.cpp']}
s['raw_sha256']={path:hashlib.sha256((a.build/path).read_bytes()).hexdigest() for path in ['partial-results/frames.csv','partial-results/cases.csv','partial-edges/frames.csv','partial-edges/cases.csv','partial-edges/response.csv','stretch-targets/curve-guide.csv','stretch-targets/curve-strong.csv','curve-loop/frames.csv','curve-loop/cases.csv']}
fig,axes=plt.subplots(1,2,figsize=(10,4));labels=list(s['per_signal']);values=list(s['per_signal'].values());axes[0].bar(range(4),[100*x['ready']/x['frames'] for x in values]);axes[0].set(ylabel='All steady frame acceptance (%)',ylim=(0,105));axes[1].bar(range(4),[100*x['b_relative_p95'] for x in values]);axes[1].set(ylabel='B relative error P95 (%)')
for ax in axes:ax.set_xticks(range(4),['Full','Weak first','Missing 1/4','Perturbed']);ax.grid(axis='y',alpha=.2)
fig.suptitle('240 synthetic stiff-string conditions; host only');fig.tight_layout();fig.savefig(a.output/'partial-coverage-error.png',dpi=160);plt.close(fig)
fig,axes=plt.subplots(2,1,figsize=(9,7))
for label in ['guide','strong']:
 data=json.loads((a.build/f'stretch-targets/curve-{label}.json').read_text(encoding='utf-8'));points=data['curve']['points'];axes[0].plot([r['midi'] for r in points],[1200*np.log2(r['first']/(440*2**((r['midi']-69)/12))) for r in points],label=label)
 samples=data['samples'];axes[1].semilogy([r['midi'] for r in samples],[r['frame']['b'] for r in samples],'o-',label=label)
axes[0].set(ylabel='Modeled first-partial target offset (cents)',title='Production curve solver: all targets modeled; no extrapolation');axes[0].axhline(0,color='gray',lw=.6);axes[1].set(xlabel='MIDI (A1=33, A4=69, A6=93)',ylabel='Measured synthetic B')
for ax in axes:ax.legend();ax.grid(alpha=.2)
fig.tight_layout();fig.savefig(a.output/'stretch-curves.png',dpi=160);plt.close(fig)
lf=rows('curve-loop/frames.csv');fig,axes=plt.subplots(2,1,figsize=(9,6))
for missing in ['0','1']:
 data=[r for r in lf if r['midi']=='33' and r['rate']=='48000' and r['delta']=='17' and r['missing']==missing];axes[0].plot([float(r['time']) for r in data],[float(r['measured_hz']) if r['ready']=='1' else np.nan for r in data],'.-',label='Observed first' if missing=='0' else 'Missing first (model)');axes[1].plot([float(r['time']) for r in data],[float(r['cents']) if r['ready']=='1' else np.nan for r in data],'.-',label='Observed first' if missing=='0' else 'Missing first (model)')
axes[0].axhline(float(data[0]['target_hz']),ls='--',color='gray',label='Modeled target');axes[0].set(ylabel='Hz',title='A1 target -78.88c from ET; independently synthesized source +17c from target');axes[1].axhline(17,ls='--',color='gray',label='True +17c');axes[1].set(xlabel='PCM end time (seconds)',ylabel='Measured relative to target (cents)')
axes[1].ticklabel_format(axis='y',style='plain',useOffset=False)
for ax in axes:ax.legend(fontsize=8);ax.grid(alpha=.2)
fig.tight_layout();fig.savefig(a.output/'curve-measurement-loop.png',dpi=160);plt.close(fig)
(a.output/'summary.json').write_text(json.dumps(s,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in s.items() if k not in ['raw_sha256','source_sha256_lf','curves']},indent=2))
