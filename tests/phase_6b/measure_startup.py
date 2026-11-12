from pathlib import Path
import ctypes as c
from ctypes import wintypes as w
import json, subprocess, time

root = Path(__file__).resolve().parents[2]
qa = root / 'tests/phase_6b'
folder = Path(json.loads((qa/'extract_location.json').read_text())['path'])
exe = folder/'Unnamed Souls.exe'
assert exe.is_file()
class PMC(c.Structure):
    _fields_ = [('cb',w.DWORD),('PageFaultCount',w.DWORD)]+[(name,c.c_size_t) for name in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage']]
api = c.WinDLL('psapi')
api.GetProcessMemoryInfo.argtypes = [w.HANDLE,c.POINTER(PMC),w.DWORD]
dest = qa/'evidence/startup.png'
start = time.perf_counter()
with (qa/'startup_stdout.log').open('w',encoding='utf-8') as log:
    proc = subprocess.Popen([str(exe),'--write-movie',str(dest),'--quit-after','3','--log-file',str(qa/'startup_release.log')],cwd=folder,stdout=log,stderr=subprocess.STDOUT)
    first = None
    memory = []
    while proc.poll() is None and time.perf_counter()-start < 30:
        images = list(dest.parent.glob('startup*.png'))
        if first is None and any(f.stat().st_size for f in images): first = time.perf_counter()-start
        value = PMC()
        value.cb = c.sizeof(value)
        if api.GetProcessMemoryInfo(w.HANDLE(int(proc._handle)),c.byref(value),c.sizeof(value)):
            memory.append({'working_set':value.WorkingSetSize,'private_bytes':value.PrivateUsage})
        time.sleep(.02)
    timed_out = proc.poll() is None
    if timed_out:
        proc.terminate()
        proc.wait()
result = {'executable':str(exe),'first_png_seconds':first,'exit_seconds':time.perf_counter()-start,'exit':proc.returncode,'timed_out':timed_out,'working_set_peak':max((v['working_set'] for v in memory),default=0),'private_bytes_peak':max((v['private_bytes'] for v in memory),default=0),'scope':'Actual extracted Release, normal entry; first PNG includes encoding/IO; 3 frames then automatic quit. Menu only; not full-level RAM or sustained FPS.','frames':[str(f) for f in dest.parent.glob('startup*.png')]}
(qa/'startup_metrics.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
