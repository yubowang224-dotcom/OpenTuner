"""Original stiff-string WAVs for computer-speaker -> phone functional checks, NOT piano validation."""
import json,math,wave
from pathlib import Path
import numpy as np
out=Path('artifacts/m3/test-tones');out.mkdir(parents=True,exist_ok=True)
rate=48000;t=np.arange(rate*3)/rate;manifest=[]
for midi,b in zip([33,45,57,69,81,93],[.0015,.0004,.0001,.0001,.0004,.0015]):
 first=440*2**((midi-69)/12);ideal=first/math.sqrt(1+b);x=np.zeros_like(t)
 for n in range(1,17):
  hz=n*ideal*math.sqrt(1+b*n*n)
  if hz>=min(18000,rate*.42):continue
  if n in [1,4]:continue
  x+=.12/n**.7*np.exp(-t*(.15+.025*n))*np.sin(2*np.pi*hz*t+.17*n)
 envelope=np.minimum(1,t/.01)*np.minimum(1,(3-t)/.03);x*=envelope
 assert np.max(np.abs(x))<1
 name=f'A{(midi-33)//12+1}-missing-first-B{b:g}.wav'
 with wave.open(str(out/name),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(np.rint(x*32767).astype('<i2').tobytes())
 manifest.append(dict(file=name,midi=midi,first_model_hz=first,ideal_hz=ideal,b=b,missing_orders=[1,4],rate=rate,seconds=3,peak_fs=float(np.max(np.abs(x)))))
(out/'manifest.json').write_text(json.dumps(dict(kind='Original synthetic WAV; airborne phone path unverified, not real-piano accuracy',tones=manifest),indent=2)+'\n',encoding='utf-8');print(out.resolve())
