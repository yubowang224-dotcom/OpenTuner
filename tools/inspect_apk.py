"""Static ELF/ZIP inspection only; does not claim Android runtime validation."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile

def elf_loads(data):
    if data[:4] != b'\x7fELF' or data[5] != 1:
        raise ValueError('expected little-endian ELF')
    bits=64 if data[4]==2 else 32
    if bits==64:
        offset=struct.unpack_from('<Q',data,32)[0]
        entry,count=struct.unpack_from('<HH',data,54)
    else:
        offset=struct.unpack_from('<I',data,28)[0]
        entry,count=struct.unpack_from('<HH',data,42)
    loads=[]
    for i in range(count):
        at=offset+i*entry
        if struct.unpack_from('<I',data,at)[0]!=1: continue
        if bits==64:
            _,_,file_offset,vaddr,_,_,_,align=struct.unpack_from('<IIQQQQQQ',data,at)
        else:
            _,file_offset,vaddr,_,_,_,_,align=struct.unpack_from('<IIIIIIII',data,at)
        loads.append(dict(offset=file_offset,virtual_address=vaddr,alignment=align))
    return bits,loads

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk',type=Path)
    parser.add_argument('--output',type=Path,default=Path('artifacts/stage2-apk-native.json'))
    parser.add_argument('--abis',nargs='+',choices=['arm64-v8a','armeabi-v7a','x86_64'],default=['arm64-v8a','armeabi-v7a','x86_64'],help='Expected ABI inventory; each split is checked separately')
    args=parser.parse_args(); result=[]; abis={}; errors=[]
    with zipfile.ZipFile(args.apk) as apk, args.apk.open('rb') as raw:
        for info in apk.infolist():
            if not info.filename.startswith('lib/') or not info.filename.endswith('.so'): continue
            data=apk.read(info); bits,loads=elf_loads(data)
            raw.seek(info.header_offset+26); name_len,extra_len=struct.unpack('<HH',raw.read(4))
            payload_offset=info.header_offset+30+name_len+extra_len
            abi=info.filename.split('/')[1]; abis.setdefault(abi,[]).append(info.filename.split('/')[-1])
            required=bits==64
            aligned_elf=all(seg['alignment']>=16384 and (seg['offset']-seg['virtual_address'])%16384==0 for seg in loads)
            aligned_zip=info.compress_type!=zipfile.ZIP_STORED or payload_offset%16384==0
            if required and (not aligned_elf or not aligned_zip): errors.append(info.filename)
            result.append(dict(path=info.filename,bytes=len(data),elf_bits=bits,load_segments=loads,elf_16k_aligned=aligned_elf,
                zip_compressed=info.compress_type!=zipfile.ZIP_STORED,zip_data_offset=payload_offset,zip_16k_aligned=aligned_zip,
                required_for_android_16k=required,sha256=hashlib.sha256(data).hexdigest()))
        if set(abis)!=set(args.abis):errors.append('Unexpected ABI inventory')
        for abi in args.abis:
            for library in ['libopentune_audio.so','libc++_shared.so','libflutter.so']:
                if library not in abis.get(abi,[]): errors.append(f'{abi}/{library} missing')
    report=dict(apk=str(args.apk.resolve()),sha256=hashlib.sha256(args.apk.read_bytes()).hexdigest(),abis=abis,libraries=result,
        errors=errors,static_check_passed=not errors,
        limit='ELF64 LOAD and ZIP alignment only. Android 16KB runtime, API24 OpenSL ES, ABI execution and real microphone have not been tested on devices.')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ['sha256','abis','errors','static_check_passed']},indent=2))
    if errors: raise SystemExit(1)
if __name__=='__main__': main()
