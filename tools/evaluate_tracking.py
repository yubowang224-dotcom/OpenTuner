"""Measured-data-only stage 2.5 figures and joint coverage/error report."""
import argparse, csv, json, platform
from collections import defaultdict
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

parser=argparse.ArgumentParser();parser.add_argument('--input',default='build/dsp/evaluation');parser.add_argument('--output',default='artifacts/stage25-evaluation');args=parser.parse_args()
source=Path(args.input);out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
rows=list(csv.DictReader((source/'frames.csv').open()))
for r in rows:
    for k in r:
        if k not in ('case','method'):r[k]=float(r[k])
groups=defaultdict(list)
for r in rows:groups[(r['case'],r['rate'],r['amplitude'],r['base_hz'],r['method'])].append(r)
assert len(groups)==390, 'Expected all 78 conditions x 5 methods, including frequency in the condition key'
summary=[]
def quant(v,q):return float(np.quantile(v,q)) if len(v) else None
for (case,rate,amp,base_hz,method),rs in groups.items():
    stat=[r for r in rs if r['time']>=.3];voiced=[r for r in stat if r['truth_hz']>0];valid=[r for r in voiced if r['valid']]
    errors=[1200*np.log2(r['hz']/r['truth_hz']) for r in valid]
    invalid=[r for r in stat if r['truth_hz']==0]
    first=next((r['time']*1000 for r in rs if r['valid'] and r['truth_hz']>0),None)
    switch_first=switch_confirm=None
    consecutive=0
    if case=='step':
        for r in rs:
            if r['time']<1:continue
            okay=r['valid'] and abs(1200*np.log2(r['hz']/440))<=10
            consecutive=consecutive+1 if okay else 0
            if consecutive==1:start=(r['time']-1)*1000
            if consecutive==3:switch_first=start;switch_confirm=(r['time']-1)*1000;break
    loss=next(((r['time']-1)*1000 for r in rs if r['time']>=1 and not r['valid']),None) if case=='silence_return' else None
    summary.append(dict(case=case,rate=rate,amplitude=amp,base_hz=base_hz,method=method,voiced_frames=len(voiced),valid_frames=len(valid),coverage=len(valid)/len(voiced) if voiced else None,rejection=1-len(valid)/len(voiced) if voiced else None,median_abs_cents=quant(np.abs(errors),.5),p95_abs_cents=quant(np.abs(errors),.95),max_abs_cents=quant(np.abs(errors),1),octave_errors=sum(abs(abs(e)-1200)<100 for e in errors),jitter_sd_cents=float(np.std(errors)) if errors and case not in ('step','glide','vibrato','silence_return','interference','decay') else None,invalid_truth_frames=len(invalid),false_valid=sum(bool(r['valid']) for r in invalid),first_ms=first,switch_first_ms=switch_first,switch_confirm_ms=switch_confirm,loss_ms=loss,p50_compute_ms=quant([r['compute_ms'] for r in stat],.5),p95_compute_ms=quant([r['compute_ms'] for r in stat],.95)))
with (out/'summary.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=summary[0]);w.writeheader();w.writerows(summary)
(out/'summary.json').write_text(json.dumps(summary,indent=2,default=lambda x: x.item()),encoding='utf-8')
(out/'profile.json').write_text((source/'profile.json').read_text())
(out/'environment.json').write_text(json.dumps(dict(platform=platform.platform(),processor=platform.processor(),python=platform.python_version(),numpy=np.__version__,matplotlib=matplotlib.__version__),indent=2))
# Preserve the complete input, not only accepted frames.
import shutil
shutil.copyfile(source/'frames.csv',out/'frames.csv')
methods=['A_raw','B_fixed','C_adaptive','C_shared','Stage2'];colors=['#a8aeb5','#d29248','#148278','#875fc0','#5187b5']
def samples(case,method,rate=48000,amp=.3):return groups[(case,float(rate),float(amp),440.0,method)]
fig,axes=plt.subplots(2,1,figsize=(10,6),layout='constrained')
for ax,case in zip(axes,['phase_noise','interference']):
    for m,c in zip(methods[:3],colors[:3]):
        rs=samples(case,m);ax.plot([r['time'] for r in rs],[r['hz'] if r['valid'] else np.nan for r in rs],label=m,color=c,lw=1.1)
    ax.set(xlabel='Window end (s)',ylabel='Frequency (Hz)',title=f'Synthetic {case}; gaps = invalid, 48 kHz');ax.legend();ax.grid(alpha=.2)
fig.savefig(out/'time-series.png',dpi=160);plt.close(fig)
fig,ax=plt.subplots(figsize=(10,4),layout='constrained')
for m,c in zip(methods,colors):
    rs=samples('step',m);ax.plot([r['time'] for r in rs],[r['hz'] if r['valid'] else np.nan for r in rs],label=m,color=c)
ax.plot([.5,1,1,2],[220,220,440,440],'k--',lw=.9,label='Truth');ax.set(xlim=(.85,1.65),xlabel='Window end (s)',ylabel='Hz',title='Synthetic octave step; no time alignment correction');ax.legend(ncol=3);ax.grid(alpha=.2)
fig.savefig(out/'step-response.png',dpi=160);plt.close(fig)
fig,axes=plt.subplots(1,2,figsize=(10,4),layout='constrained')
for m,c in zip(methods[:3],colors[:3]):
    data=[next(x for x in summary if x['case']==f'snr{n}' and x['rate']==48000 and x['method']==m) for n in [0,10,20,40]]
    axes[0].plot([0,10,20,40],[100*x['coverage'] for x in data],'o-',label=m,color=c)
    axes[1].plot([0,10,20,40],[x['p95_abs_cents'] if x['p95_abs_cents'] is not None else np.nan for x in data],'o-',label=m,color=c)
axes[0].set(ylabel='Valid / all voiced frames (%)',ylim=(-3,103));axes[1].set(ylabel='P95 absolute error of valid frames (cents)')
for ax in axes:ax.set(xlabel='Synthetic input SNR (dB)',xticks=[0,10,20,40]);ax.grid(alpha=.2);ax.legend()
fig.suptitle('Same noisy PCM; missing error points mean no detections, not zero error')
fig.savefig(out/'noise-comparison.png',dpi=160);plt.close(fig)
# A compact, auditable Markdown table; both rates remain in CSV.
lines=['# Stage 2.5 measured synthetic comparison (48 kHz)','','Each cell: coverage % / P95 cents / jitter SD cents; dynamic jitter is omitted.','', '| Case | A raw | B fixed | C adaptive | C shared | Stage2 |','|---|---|---|---|---|---|']
for case in ['sine','weak','harmonic','missing','snr40','snr20','snr10','snr0','phase_noise','step','glide','vibrato','interference','silence_return']:
    entries=[]
    for m in methods:
        ss=[s for s in summary if s['case']==case and s['rate']==48000 and s['method']==m]
        # Representative condition for table; all frequencies/amplitudes in CSV.
        if case=='sine':ss=[s for s in ss if s['amplitude']==.3]  # aggregate separately below
        cov=sum(s['valid_frames'] for s in ss)/sum(s['voiced_frames'] for s in ss) if sum(s['voiced_frames'] for s in ss) else 0
        # Avoid pooling percentiles: this table labels worst per-condition P95/SD.
        p=[s['p95_abs_cents'] for s in ss if s['p95_abs_cents'] is not None];j=[s['jitter_sd_cents'] for s in ss if s['jitter_sd_cents'] is not None]
        entries.append(f'{cov*100:.1f} / {max(p):.3f} / '+(f'{max(j):.3f}' if j else '—') if p else f'{cov*100:.1f} / — / —')
    lines.append('| '+case+' | '+' | '.join(entries)+' |')
lines+=['','P95 and SD above are the **worst individual condition** in each row, not pooled percentiles. No successful frames are silently removed.','', '| Method | Step first / third confirmation ms | First valid ms | Loss first invalid ms |','|---|---|---|---|']
for m in methods:
    st=next(s for s in summary if s['case']=='step' and s['rate']==48000 and s['method']==m);loss=next(s for s in summary if s['case']=='silence_return' and s['rate']==48000 and s['method']==m)
    fmt=lambda x:'—' if x is None else f'{x:.0f}'
    lines.append(f"| {m} | {fmt(st['switch_first_ms'])} / {fmt(st['switch_confirm_ms'])} | {fmt(st['first_ms'])} | {fmt(loss['loss_ms'])} |")
lines+=['','All inputs here are synthetic. Loss timing includes partial windows after silence; internal tracker expiry is 200 ms. Phone latency and CPU are unmeasured.']
profile=json.loads((source/'profile.json').read_text())
lines+=['', '| Full host pipeline | CPU seconds / 234 s PCM | One-core audio-time equivalent % | Frame compute P50 / P95 ms |','|---|---|---|---|']
for method,key in [('A_raw','baseline_cpu_seconds'),('B_fixed','fixed_cpu_seconds'),('C_adaptive','production_cpu_seconds')]:
    times=[r['compute_ms'] for r in rows if r['method']==method]
    lines.append(f"| {method} | {profile[key]:.6f} | {100*profile[key]/234:.3f} | {quant(times,.5):.3f} / {quant(times,.95):.3f} |")
lines+=['', 'A/B include the unchanged frozen Analyzer (its old tracker still executes, although A/B use frame observations). B reruns that frontend independently and includes fixed EMA cost. C uses production features/tracking. This is one sequential host run, not phone CPU or statistical performance certification. Shared-tracker/CSV overhead is recorded separately.']
(out/'results.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
# Joint gates: no dropping rejected frames or weakening existing DSP criteria.
for s in summary:
    if s['method'] != 'C_adaptive': continue
    if s['case'] in ('sine','harmonic','missing','weak'):
        assert s['coverage'] >= .99 and s['p95_abs_cents'] <= 5, s
    if s['case'] in ('silence','noise','impulses','dual'): assert s['false_valid'] == 0, s
    if s['case']=='snr10': assert s['octave_errors'] == 0, s
print('Joint coverage/error and invalid-input gates passed')
print('\n'.join(lines));print((out/'profile.json').read_text())
