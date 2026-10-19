"""Export complete implementation source with reviewed user/developer documentation.
Run only after the candidate is committed and clean. No remote operations.
"""
import argparse,hashlib,json,re,subprocess,zipfile
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
 if name.startswith('docs/evaluation-stage25/'): return True
 if name.startswith('docs/evidence/'): return name.removeprefix('docs/evidence/') in public_evidence
 if name.startswith('docs/screenshots/'): return name.removeprefix('docs/screenshots/') in public_screenshots
 if name.startswith('docs/'): return name.removeprefix('docs/') in public_docs
 return True
files=[]
for entry in entries:
 meta,name=entry.split('\t',1);mode,kind,oid=meta.split()
 if not public_file(name): continue
 assert kind=='blob' and mode in ['100644','100755'],f'Unsupported archive entry: {name}'
 assert not blocked.search(name),f'Private file type/path: {name}'
 data=subprocess.check_output(['git','cat-file','blob',oid],cwd=root)
 if b'\0' not in data:
  text=data.decode('utf-8',errors='replace')
  assert not private_path.search(text),f'Personal absolute path in {name}'
  assert not secrets.search(text),f'Credential marker in {name}'
 files.append((name,data,mode))
assert not a.output.exists(),'Refuse overwriting an existing export'
a.output.mkdir(parents=True)
archive=a.output/'OpenTuner-reviewed-source.zip'
manifest={'kind':'Complete implementation source with maintained technical documentation; no builds, credentials or machine data','source_commit':commit,'files':[]}
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
