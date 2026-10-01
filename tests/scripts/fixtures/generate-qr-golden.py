from pathlib import Path
import qrcode, qrcode.base, qrcode.util, qrcode.constants
import importlib.metadata, hashlib, json, base64
assert importlib.metadata.version('qrcode') == '8.2', 'Expected independent oracle qrcode==8.2'
out=Path(__file__).resolve().parent
levels=[qrcode.constants.ERROR_CORRECT_L,qrcode.constants.ERROR_CORRECT_M,qrcode.constants.ERROR_CORRECT_Q,qrcode.constants.ERROR_CORRECT_H]
rows=[]
for v in range(1,41):
 for level,ecc in enumerate(levels):
  n=(sum(b.data_count for b in qrcode.base.rs_blocks(v,ecc))*8-4-(8 if v<=9 else 16))//8
  payload=bytes(33+(i*17)%90 for i in range(n))
  qr=qrcode.QRCode(version=v,error_correction=ecc,mask_pattern=0,border=0)
  qr.add_data(qrcode.util.QRData(payload,mode=qrcode.util.MODE_8BIT_BYTE),optimize=0)
  qr.make(fit=False)
  bits=''.join('1' if c else '0' for row in qr.modules for c in row).encode()
  rows.append([v,level,n,base64.b64encode(hashlib.sha256(bits).digest()).decode()])
obj={'schema':1,'oracle':'python-qrcode '+importlib.metadata.version('qrcode'),'mode':'8-bit byte, explicit ECC, fixed mask 0, no border','payload':'ASCII code 33 + (index * 17) % 90','digest':'base64(SHA256(row-major ASCII 0/1 modules))','oracleSourceSha256':{Path(m.__file__).name:hashlib.sha256(Path(m.__file__).read_bytes()).hexdigest() for m in [qrcode.base,qrcode.util]},'alignmentCenters':[qrcode.util.pattern_position(v) for v in range(1,41)],'vectors':rows}
p=out/'qr-golden.json';p.write_text(json.dumps(obj,indent=None,separators=(',',':'))+'\n')
print('QR_VECTORS',len(rows),'ORACLE',obj['oracle'],'BYTES',p.stat().st_size)
