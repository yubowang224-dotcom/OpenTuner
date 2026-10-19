"""Summarize ALL fixed-interval production frames; never filters error outliers."""
import csv
import json
import math
import platform
import statistics
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/dsp'
def read(name):
    with (OUT / name).open(encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))
def pct(values, fraction):
    if not values:
        return None
    v = sorted(values)
    return v[math.floor(fraction * (len(v) - 1) + .5)]

def main():
    frames = read('frames.csv')
    cases = read('cases.csv')
    groups = {}
    for name in sorted({f['group'] for f in frames}):
        selected = [f for f in frames if f['group'] == name and float(f['end_seconds']) >= .3]
        valid = [f for f in selected if f['validity'] == '2']
        errors = [abs(1200 * math.log2(float(f['tracked_hz']) / float(f['truth_hz']))) for f in valid if float(f['truth_hz']) > 0]
        raw_errors = [abs(1200 * math.log2(float(f['raw_hz']) / float(f['truth_hz']))) for f in valid if float(f['truth_hz']) > 0]
        times = [float(f['compute_ms']) for f in selected]
        group_cases = [c for c in cases if c['group'] == name]
        jitter = [float(c['jitter_sd_cents']) for c in group_cases if float(c['jitter_sd_cents']) >= 0]
        raw_by_condition = {}
        for f in valid:
            if float(f['truth_hz']) <= 0: continue
            key=(f['case'],f['sample_rate'],f['amplitude'],f['truth_hz'])
            raw_by_condition.setdefault(key,[]).append(1200*math.log2(float(f['raw_hz'])/float(f['truth_hz'])))
        raw_jitter=[statistics.pstdev(v) for v in raw_by_condition.values()]
        groups[name] = dict(frames=len(selected), valid=len(valid), coverage=len(valid)/len(selected),
            median_abs_cents=pct(errors,.5), p95_abs_cents=pct(errors,.95), max_abs_cents=max(errors,default=None),
            p95_raw_abs_cents=pct(raw_errors,.95), octave_errors=sum(int(c['octave_errors']) for c in group_cases),
            high_score_valid=sum(float(f['score']) >= .9 for f in valid), max_case_jitter_sd_cents=max(jitter,default=None),
            max_case_raw_jitter_sd_cents=max(raw_jitter,default=None),
            p50_compute_ms=pct(times,.5), p95_compute_ms=pct(times,.95), max_compute_ms=max(times,default=None))
    core = [f for f in frames if f['group']=='primary' and 65 <= float(f['truth_hz']) <= 1000 and float(f['end_seconds'])>=.3]
    core_valid = [f for f in core if f['validity']=='2']
    core_p95 = pct([abs(1200*math.log2(float(f['tracked_hz'])/float(f['truth_hz']))) for f in core_valid],.95)
    all_compute = [float(f['compute_ms']) for f in frames]
    env = dict(platform=platform.platform(), python=platform.python_version(), compiler='MSVC 19.35 /O2, CMake Release',
        cpu=json.loads((OUT/'cpu.json').read_text(encoding='utf-8-sig')) if (OUT/'cpu.json').exists() else 'record with OS tool')
    profile=json.loads((OUT/'host_process.json').read_text(encoding='utf-8'))
    dynamic=read('dynamic.csv')
    for row in dynamic:
        row['switch_confirmation_ms']=-1
        if row['case']!='step': continue
        consecutive=0
        for f in frames:
            if f['case']!='step' or f['sample_rate']!=row['sample_rate'] or float(f['end_seconds'])<.6: continue
            if f['validity']=='2' and abs(1200*math.log2(float(f['tracked_hz'])/440))<10:
                consecutive+=1
                if consecutive==3:
                    row['switch_confirmation_ms']=(float(f['end_seconds'])-.6)*1000
                    break
            else: consecutive=0
    result = dict(protocol='docs/stage-2-test-protocol.md', algorithm='YIN fixed-window FFT correlation + strong-partial gate v1',
        window_ms=80,hop_ms=20,statistics_interval_seconds=[.3,1.5], sample_rates=[44100,48000], cases=len(cases), total_frames=len(frames),
        groups=groups, dynamic=dynamic, core_65_1000_p95=core_p95,core_coverage=len(core_valid)/len(core),
        overall_compute_p95_ms=pct(all_compute,.95),environment=env,host_test_process_profile=profile,
        boundary_tests=['C ABI argument/size/nonfinite guards and reference 442','Hann dBFS/bin and actual Hz axis','bounded ring overflow/wrap/discard','100000 concurrent SPSC samples','50 analyzer allocations/resets'],
        evidence_sha256={name:hashlib.sha256((OUT/name).read_bytes()).hexdigest() for name in ['frames.csv','cases.csv','dynamic.csv']},
        device_status='Not tested: no adb device connected; host timing excludes capture/hardware/UI and is not phone CPU/PSS')
    (OUT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['# 阶段2生产DSP合成测量结果','',f"共 {len(cases)} 组条件、{len(frames)} 帧（含启动帧）；统计区间固定为 0.3–1.5 s，拒检保留在分母。算法 v1；80 ms / 20 ms；44.1/48 kHz。",'',
        '| 组 | 有效/全部帧 | 绝对误差median / P95(cents) | 八度错误 | 最大单条件raw / tracked抖动SD(cents) | 单帧P95(ms) |','|---|---|---|---|---|---|']
    def fmt(v): return '—' if v is None else f'{v:.6g}'
    for name,g in groups.items():
        lines.append(f"| {name} | {g['valid']}/{g['frames']} ({g['coverage']:.2%}) | {fmt(g['median_abs_cents'])} / {fmt(g['p95_abs_cents'])} | {g['octave_errors']} | {fmt(g['max_case_raw_jitter_sd_cents'])} / {fmt(g['max_case_jitter_sd_cents'])} | {fmt(g['p95_compute_ms'])} |")
    lines += ['',f'原阶段0的65–1000 Hz目标单列：P95={core_p95:.6g} cents，覆盖={len(core_valid)/len(core):.2%}。',
        '', '| 动态 | 采样率 | 首次(ms) | 阶跃首帧/连续3帧确认(ms) | 停声失效(ms) | 再现(ms) |','|---|---|---|---|---|---|']
    for d in result['dynamic']:
        cells=[d[k] if k=='case' else fmt(float(d[k])) if float(d[k])>=0 else '—' for k in ['case','sample_rate','first_ms','switch_ms','invalidation_ms','return_ms']]
        if d['case']=='step': cells[3]+=' / '+fmt(d['switch_confirmation_ms'])
        lines.append('| '+' | '.join(cells)+' |')
    lines += ['', '动态误差相对窗口末端的瞬时真值，包含80ms观察窗的滑音滞后与阶跃混合窗。阶跃中的旧八度帧如实统计，不能理解为稳态八度误判。非谐双音无唯一真值，不计算其频率误差。decay/silence_return覆盖率含真静音及低于门限的部分。',
        '', 'noise汇总混合不同SNR，必须结合逐条件表阅读；10dB精度不等同于纯音成绩。评分是1−CMNDF，强分音一致性、RMS、削波、跟踪门控另行拒绝，评分高也可能被判无效。',
        '', '## 逐条件完整摘要','', '| 组/场景 | Hz | 幅度 | 采样率 | 有效率 | 误差P95(cents) | 高评分有效帧 |','|---|---|---|---|---|---|---|']
    for c in cases:
        lines.append(f"| {c['group']}/{c['case']} | {float(c['hz']):.6g} | {float(c['amplitude']):.3g} | {c['sample_rate']} | {float(c['coverage']):.2%} | {fmt(float(c['p95_abs_cents'])) if float(c['p95_abs_cents'])>=0 else '—'} | {c['high_score_valid']} |")
    lines += ['', '## 环境与边界','',f"{env['platform']}，{env['compiler']}，{env['cpu']}。全部样本计算耗时P95={result['overall_compute_p95_ms']:.6g} ms，包含细节图数据生成。主机仅串行基准，不是整机CPU/内存测试。",'',
        f"独立测试进程的峰值驻留内存={profile['peak_resident_bytes']} bytes、进程用户+内核CPU累计时间={profile['process_cpu_seconds']} s、wall={profile['wall_seconds']} s（Windows GetProcessMemoryInfo/GetProcessTimes）。该内存包括测试生成器、CSV输出和算法，不是Android App内存或手机CPU/PSS。",'',
        '原始CSV/JSON位于被忽略的artifacts/dsp；可用tools/test-dsp.ps1和tools/report_dsp.py重新生成。当前没有真机、真实人声录音或实琴验证。未验证96kHz和8–192kHz其他采样率、蓝牙/USB路由及多机型噪声处理。不向A0–C8全域推广。', '', 'CSV SHA-256：', '', '```json', json.dumps(result['evidence_sha256'],indent=2), '```','']
    (ROOT/'docs/stage-2-dsp-results.md').write_text('\n'.join(lines),encoding='utf-8')
    print(json.dumps({k:result[k] for k in ['cases','total_frames','groups','dynamic','overall_compute_p95_ms']},indent=2))
if __name__=='__main__': main()
