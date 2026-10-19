"""Inspect signed local AOT release artifacts. Does not read any private signing material."""
import argparse,hashlib,json,re,zipfile
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path);parser.add_argument('--certificate-sha256',default='ae27b3e61d3d21419b6a45236bc9c56cbddcf05044a2311f56f4627d2eaf6892');a=parser.parse_args();summary=json.loads((a.directory/'summary.json').read_text(encoding='utf-8-sig'))
root=Path(__file__).resolve().parents[1];expected=a.certificate_sha256.lower();assert re.fullmatch('[a-f0-9]{64}',expected);assert summary['certificateSha256']==expected
assert hashlib.sha256((a.directory/'OpenTuner-release-public.cer').read_bytes()).hexdigest()==expected
version=re.search(r'^version:\s*(\S+)\+(\d+)',(root/'pubspec.yaml').read_text(encoding='utf-8'),re.M);assert version
records=[];findings=[]
for item in summary['packages']:
 p=a.directory/item['file'];abi=item['abi'];native=json.loads((a.directory/f'{abi}-native.json').read_text(encoding='utf-8'));badging=(a.directory/f'{abi}-badging.txt').read_text(encoding='utf-8-sig');perms=(a.directory/f'{abi}-permissions.txt').read_text(encoding='utf-8-sig');manifest=(a.directory/f'{abi}-manifest.txt').read_text(encoding='utf-8-sig')
 assert native['static_check_passed'] and hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256']
 assert f"versionCode='{version[2]}'" in badging and f"versionName='{version[1]}'" in badging and "name='org.opentune.tuner'" in badging and "sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging
 assert 'android.permission.RECORD_AUDIO' in perms and 'android.permission.INTERNET' not in perms
 assert re.search(r'android:allowBackup[^\n]*=\(type 0x12\)0x0',manifest) and not re.search(r'android:debuggable[^\n]*0xffffffff',manifest)
 required={'arm64-v8a','armeabi-v7a','x86_64'} if abi=='universal' else {abi};assert set(native['abis'])==required
 with zipfile.ZipFile(p) as z:
  assert z.testzip() is None and 'assets/flutter_assets/kernel_blob.bin' not in z.namelist()
  for arch in required:
   data=z.read(f'lib/{arch}/libopentune_audio.so');disk=(root/f'build/app/intermediates/stripped_native_libs/release/stripReleaseDebugSymbols/out/lib/{arch}/libopentune_audio.so').read_bytes();assert data==disk
   symbols=set(re.findall(rb'Java_org_opentune_tuner_MainActivity_native[A-Za-z]+',data));assert len(symbols)==11 and b'Java_org_opentune_tuner_MainActivity_nativeMetroPause' in symbols
   app=z.read(f'lib/{arch}/libapp.so');url='https://github.com/yubowang224-dotcom/OpenTuner';assert url.encode() in app or url.encode('utf-16-le') in app
  for n in ['assets/flutter_assets/native/third_party/oboe/LICENSE','assets/flutter_assets/third_party/licenses/ndk-llvm-notice.txt','assets/flutter_assets/NOTICES.Z']:assert n in z.namelist()
  assert z.read('assets/flutter_assets/assets/branding/OpenTuner-icon-master.png')==(root/'assets/branding/OpenTuner-icon-master.png').read_bytes()
  for n in z.namelist():
   if re.search(rb'[A-Za-z]:[/\\]+Users[/\\]+[^/\\\s\x00]+',z.read(n)):findings.append({'file':p.name,'member':n,'type':'absolute_personal_path'})
 record=dict(item);record.update(aot=True,kernel_absent=True,native_matches_final_stripped=True,jni_exports_per_abi=11,verified_repository_url_in_aot=True,record_audio_no_internet=True,backup_disabled=True,offline_notices_present=True,elf_zip_16k_static=True)
 records.append(record)
assert not findings,findings
inputs={}
for base in ['lib','native','android/app/src']:
 for p in (root/base).rglob('*'):
  if p.is_file() and p.suffix in ['.dart','.cpp','.h','.kt','.java','.xml']:inputs[p.relative_to(root).as_posix()]=hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
for n in ['pubspec.yaml','pubspec.lock','android/app/build.gradle.kts','android/gradle.properties']:inputs[n]=hashlib.sha256((root/n).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
result={'kind':'Signed AOT local release static audit. No Android installation/acoustic verification','certificateSha256':expected,'version':version[1],'versionCode':int(version[2]),'packages':records,'personal_path_findings':findings,'source_inputs_sha256_lf':inputs,'limits':'Compiled input hashes and actual native byte comparison; no claim of bit-reproducible Dart AOT across build roots. Signature does not prove device compatibility.'}
(a.directory/'verified-release.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in result.items() if k!='source_inputs_sha256_lf'},indent=2))
