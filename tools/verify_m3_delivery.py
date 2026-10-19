"""Verify the local M3 debug artifact against current production sources (static only)."""
import hashlib,json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'artifacts/m3';apk=root/'artifacts/OpenTuner-0.6.0-piano-experimental-debug.apk'
def sha(data):return hashlib.sha256(data).hexdigest()
s={'kind':'Static Debug artifact checks, NOT Android execution','apk_sha256':sha(apk.read_bytes()),'apk_bytes':apk.stat().st_size,'abis':{}}
with zipfile.ZipFile(apk) as z:
 kernel=z.read('assets/flutter_assets/kernel_blob.bin');s['dart_sources']={}
 for name in ['audio/calibration_page.dart','audio/audio_capture.dart','audio/piano_page.dart','model/piano_calibration.dart','model/piano_model.dart','model/profile_store.dart','model/app_state.dart','widgets/route_tooltips.dart']:
  content=(root/'lib'/name).read_bytes();assert content in kernel,name;s['dart_sources'][name]=sha(content)
 for abi in ['arm64-v8a','armeabi-v7a','x86_64']:
  data=z.read(f'lib/{abi}/libopentune_audio.so');disk=(root/f'build/app/intermediates/stripped_native_libs/debug/stripDebugDebugSymbols/out/lib/{abi}/libopentune_audio.so').read_bytes();assert data==disk
  symbols=set(re.findall(rb'Java_org_opentune_tuner_MainActivity_native[A-Za-z]+',data));assert len(symbols)==10,(abi,len(symbols));assert b'Java_org_opentune_tuner_MainActivity_nativePartialStart' in symbols
  elf=(out/f'elf-{abi}.txt').read_text(encoding='utf-8-sig');assert 'libaaudio.so' not in elf
  s['abis'][abi]={'stripped_library_matches':True,'jni_exports':sorted(x.decode() for x in symbols),'sha256':sha(data),'no_direct_libaaudio_dependency':True}
 dex=(out/'dex-main-activity.txt').read_text(encoding='utf-8-sig');assert 'nativePartialStart(JZDID)Ljava/lang/String;' in dex and 'nativeStart(JZDZ)Ljava/lang/String;' in dex
 s['jni_dex_signatures_match']=True
s['icon_sha256']=sha((root/'assets/branding/OpenTuner-icon-master.png').read_bytes());assert s['icon_sha256']=='95246ace495b05fce1bd4de28c61dfa1bbfbbca10f8b3d669d93c759d4db70b8'
badging=(root/'artifacts/build-0.6.0-piano-experimental/apk-badging.txt').read_text(encoding='utf-8-sig');assert "name='org.opentune.tuner' versionCode='15'" in badging and "sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging
cert=(root/'artifacts/build-0.6.0-piano-experimental/apk-signature.txt').read_text(encoding='utf-8-sig');assert 'a112fb5cd80d09a36b44cc7923fc8ce37884945fdcf05a7a5a53c6443add6064' in cert
s['version_code']=15;s['package']='org.opentune.tuner';s['min_sdk']=24;s['target_sdk']=36;s['same_debug_certificate']=True
for name,h in {'OpenTuner-0.5.0-piano-foundation-debug.apk':'38967d7a5803e6cb6264923e582939a7702df6bcf9a6799d3bc3efb4ac45502c','OpenTuner-0.4.0-guitar-presets-debug.apk':'6bc1187f0634c167fbce983390cd6efcd96098149faa86eae906b3ea582d731f','OpenTuner-0.3.2-appearance.1-debug.apk':'15790bedd3b5b7c12beb5f833dee7e98d877c769f8f946f9607424888f42feed'}.items():assert sha((root/'artifacts'/name).read_bytes())==h
s['protected_previous_apks_unchanged']=True
(out/'delivery-checks.json').write_text(json.dumps(s,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in s.items() if k not in ['abis','dart_sources']},indent=2))
