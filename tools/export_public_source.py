"""Export complete implementation source with reviewed user/developer documentation.
Run only after the candidate is committed and clean. No remote operations.
"""
import argparse,csv,hashlib,io,json,re,subprocess,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
assert not subprocess.check_output(['git','status','--porcelain'],cwd=root).strip(),'Commit reviewed changes first'
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip()
entries=[x for x in subprocess.check_output(['git','ls-tree','-rz','HEAD'],cwd=root).decode().split('\0') if x]
blocked=re.compile(r'(^|/)(?:artifacts|build|\.local|\.git)(?:/|$)|(?:^|/)(?:local|key)\.properties$|(?:^|/)(?:signing\.private\.json|OFFLINE-RECOVERY\.private\.txt|pianos\.(?:json|bak))$|\.(?:apk|aab|wav|pcm|jks|keystore|pem|p12|log|zip)$',re.I)
private_path=re.compile(r'[A-Za-z]:[/\\]+Users[/\\]+[^/\\\s\"\']+|/(?:Users|home)/[^/\s\"\']+')
secrets=re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16})\b')
# An explicit documentation list keeps source distributions focused on maintained
# technical material. Application, native, test, resource and tool trees are complete.
public_docs = {
 'architecture.md','audio-bridge.md','audio-signal-processing.md','feature-extraction.md',
 'pitch-tracking-evaluation.md','piano-foundation.md','piano-calibration.md','piano-profiles.md',
 'guitar-presets.md','reference-synthesis.md','metronome.md','waveform-display.md',
 'privacy.md','dependencies.md','windows-setup.zh-CN.md','validation.md',
 'stage-2-test-protocol.md','stage-2-dsp-results.md','stage25-experiment-protocol.md','m3-protocol.md',
 'install-release.zh-CN.md','debug-to-release-migration.zh-CN.md','release-signing.md',
 'release-notes-0.7.0-beta.2.md','device-test-m3-template.md','release-package-metadata.json',
}
public_evidence = {
 'm1-pitch-source-hashes.json','m1-summary.json','m3-results.json','wave-trigger10ms.csv',
 'm1-preset-errors.png','m1-reference-rms.png','m1-reference-wave.png',
 'm3-curve-measurement-loop.png','m3-partial-coverage-error.png','m3-stretch-curves.png',
}
public_screenshots = {'m3-piano-focus-en-dark.png','m1-acknowledgements-zh-dark.png'}
def public_file(name):
 if name=='AGENTS.md': return False
 if name.startswith('docs/evaluation-stage25/'):
  return name.removeprefix('docs/evaluation-stage25/') not in {'cpu.json','environment.json','profile.json','regression-process.json','manifest.json'}
 if name.startswith('docs/evidence/'): return name.removeprefix('docs/evidence/') in public_evidence
 if name.startswith('docs/screenshots/'): return name.removeprefix('docs/screenshots/') in public_screenshots
 if name.startswith('docs/'): return name.removeprefix('docs/') in public_docs
 return True
def public_document(name, data):
 """Project stored test results to acoustic summaries, retaining raw local evidence."""
 if not (name.startswith('docs/') or name in {'README.md','README.en.md','README.zh-CN.md'}): return data
 if name in {'docs/evidence/m3-results.json','docs/evidence/m1-summary.json'}:
  def acoustic(value):
   if isinstance(value,dict):
    return {k:acoustic(v) for k,v in value.items() if not re.search(r'cpu|rss|processor|cores|^os$|platform|runtime|wall|memory|resource|compute|host_|timed_solves|warmup_solves|^python$',k,re.I)}
   if isinstance(value,list): return [acoustic(v) for v in value]
   return value
  return (json.dumps(acoustic(json.loads(data)),indent=2)+'\n').encode()
 if name.endswith('.csv'):
  reader=csv.DictReader(io.StringIO(data.decode('utf-8')))
  fields=[k for k in reader.fieldnames if not re.search(r'compute|cpu|rss|wall|memory',k,re.I)]
  output=io.StringIO(newline='');writer=csv.DictWriter(output,fieldnames=fields,lineterminator='\n');writer.writeheader()
  writer.writerows({k:row[k] for k in fields} for row in reader)
  return output.getvalue().encode()
 if not name.endswith('.md'): return data
 text=data.decode('utf-8')
 if name=='docs/stage-2-dsp-results.md':
  lines=text.splitlines();table=False;clean=[]
  for line in lines:
   if line.startswith('| 组 |') and '单帧' in line: table=True
   if table and line.startswith('|'):
    columns=line.split('|');line='|'.join(columns[:-2]+[''])
   elif table: table=False
   clean.append(line)
  text='\n'.join(clean)+'\n'
  if '## 环境与边界' in text:
   start=text.index('## 环境与边界');end=text.index('CSV SHA-256：',start)
   text=text[:start]+"""## 数据与验证边界

原始CSV/JSON可用tools/test-dsp.ps1和tools/report_dsp.py在本机重新生成。这里保留合成声学结果；不包含目标手机计算性能或端到端延迟测量。没有真实人声/实琴验证；不将结果推广到所有采样率、蓝牙/USB路由或厂商噪声处理。

"""+text[end:]
 if name=='docs/pitch-tracking-evaluation.md':
  text=text.replace(' · [环境/耗时](evaluation-stage25/profile.json)','')
  if '主机成本在profile.json' in text:
   start=text.index('主机成本在profile.json');end=text.index('## 复现',start)
   text=text[:start]+'计算性能、温升和端到端延迟应在目标设备独立测量；合成音频时间轴响应不包含硬件缓冲或屏幕延迟。\n\n'+text[end:]
  text=text.replace('当前已可用；版本见environment.json','版本见tools/requirements-evaluation.txt')
 if name=='docs/evaluation-stage25/results.md':
  text=text.split('| Full host pipeline |',1)[0].rstrip()+'\n'
 if name=='docs/validation.md':
  text='\n'.join(line for line in text.splitlines() if not line.startswith('| 分音计算耗时'))+'\n'
  text=re.sub(r'该次Windows/MSVC主机计时，[^。]+。','',text)
 text=text.replace('150.1s arm64','独立arm64').replace('a150.1s unsigned arm64','an unsigned arm64')
 return text.encode()
def check_public_document(name, data):
 if not name.startswith('docs/'): return
 if name.endswith(('.md','.json','.csv')):
  text=data.decode('utf-8')
  machine=re.compile(r'\b(?:AMD|Intel)\s+(?:Ryzen|Core|Xeon)|AuthenticAMD|GenuineIntel|AMD64 Family|Windows(?:-10)?[- ]10\.0\.\d+|Windows(?:\s+NT)?\s+10\.0\.\d+|NumberOf(?:LogicalProcessors|Cores)',re.I)
  assert not machine.search(text),f'Machine-specific value in public document: {name}'
 if name.endswith('.json'):
  def walk(value):
   if isinstance(value,dict):
    for key,item in value.items():
     assert not re.search(r'cpu|rss|processor|cores|^os$|platform|runtime|wall|memory|resource|compute|host_',key,re.I),f'Host telemetry field in public document: {name}'
     walk(item)
   elif isinstance(value,list):
    for item in value: walk(item)
  walk(json.loads(data))
 if name.endswith('.csv'):
  fields=next(csv.reader(io.StringIO(data.decode('utf-8'))))
  assert not any(re.search(r'compute|cpu|rss|wall|memory',key,re.I) for key in fields),f'Host timing column in public document: {name}'
files=[]
projected=[]
for entry in entries:
 meta,name=entry.split('\t',1);mode,kind,oid=meta.split()
 if not public_file(name): continue
 assert kind=='blob' and mode in ['100644','100755'],f'Unsupported archive entry: {name}'
 assert not blocked.search(name),f'Private file type/path: {name}'
 data=subprocess.check_output(['git','cat-file','blob',oid],cwd=root)
 public_data=public_document(name,data)
 if public_data!=data: projected.append(name)
 data=public_data
 check_public_document(name,data)
 if b'\0' not in data:
  text=data.decode('utf-8',errors='replace')
  assert not private_path.search(text),f'Personal absolute path in {name}'
  assert not secrets.search(text),f'Credential marker in {name}'
 files.append((name,data,mode))
assert not a.output.exists(),'Refuse overwriting an existing export'
a.output.mkdir(parents=True)
archive=a.output/'OpenTuner-reviewed-source.zip'
manifest={'kind':'Complete implementation source with maintained technical documentation; no builds, credentials or machine data','source_commit':commit,'documentation_projection':'portable-acoustic-results-v1','projected_files':projected,'files':[]}
with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for name,data,mode in files:
  info=zipfile.ZipInfo(name,date_time=(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=3;info.external_attr=(0o100755 if mode=='100755' else 0o100644)<<16
  z.writestr(info,data);manifest['files'].append({'path':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None and z.comment==b''
 assert z.namelist()==[f['path'] for f in manifest['files']]
 for f in manifest['files']:assert hashlib.sha256(z.read(f['path'])).hexdigest()==f['sha256']
manifest['archive_sha256']=hashlib.sha256(archive.read_bytes()).hexdigest();manifest['archive_bytes']=archive.stat().st_size
(a.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
(a.output/'SHA256SUMS.txt').write_text(manifest['archive_sha256']+'  '+archive.name+'\n',encoding='ascii')
print(json.dumps({'source_commit':commit,'files':len(files),'archive':str(archive.resolve()),'sha256':manifest['archive_sha256'],'bytes':manifest['archive_bytes']},indent=2))
