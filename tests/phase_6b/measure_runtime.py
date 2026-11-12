from pathlib import Path
import json, ctypes as c, time
from ctypes import wintypes as w
p=Path(__file__).resolve().parent
pid=json.loads((p/'extracted_process.json').read_text())['pid']
kernel=c.WinDLL('kernel32',use_last_error=True)
kernel.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD]
kernel.OpenProcess.restype=w.HANDLE
kernel.CloseHandle.argtypes=[w.HANDLE]
class PMC(c.Structure):
    _fields_=[('cb',w.DWORD),('PageFaultCount',w.DWORD)]+[(name,c.c_size_t) for name in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage']]
api=c.WinDLL('psapi')
api.GetProcessMemoryInfo.argtypes=[w.HANDLE,c.POINTER(PMC),w.DWORD]
handle=kernel.OpenProcess(0x410,False,pid)
if not handle: raise c.WinError(c.get_last_error())
samples=[]
for i in range(8):
    v=PMC();v.cb=c.sizeof(v)
    if not api.GetProcessMemoryInfo(handle,c.byref(v),c.sizeof(v)):raise c.WinError(c.get_last_error())
    samples.append({'working_set':v.WorkingSetSize,'peak_working_set':v.PeakWorkingSetSize,'private_bytes':v.PrivateUsage})
    time.sleep(1)
kernel.CloseHandle(handle)
result={'pid':pid,'samples':samples,'scope':'Actual extracted Release; stationary near initial bonfire in integrated forest; editor and QA engine closed. Not entire-route or target-hardware peak.'}
(p/'runtime_metrics.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
